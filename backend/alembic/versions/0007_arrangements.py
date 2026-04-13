from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0007_arrangements"
down_revision = "0006_time_boxings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "arrangement_batches",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("status_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False),
        sa.Column("min_requirement_points", sa.SmallInteger(), nullable=False, server_default=sa.text("0")),
        sa.Column("max_requirement_points", sa.SmallInteger(), nullable=False, server_default=sa.text("0")),
        sa.Column("pickup_start_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("pickup_end_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("created_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("approved_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("approved_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.CheckConstraint("min_requirement_points <= max_requirement_points", name="ck_arrangement_batches_points_range"),
        sa.CheckConstraint(
            "(pickup_start_at IS NULL AND pickup_end_at IS NULL) OR (pickup_start_at IS NOT NULL AND pickup_end_at IS NOT NULL AND pickup_start_at < pickup_end_at)",
            name="ck_arrangement_batches_pickup_window",
        ),
    )
    op.create_index("ix_arrangement_batches_created_by", "arrangement_batches", ["created_by"], unique=False)

    op.create_table(
        "arrangement_schedules",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("batch_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("arrangement_batches.id", ondelete="SET NULL"), nullable=True),
        sa.Column("schedule_type_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("slot_count", sa.SmallInteger(), nullable=False, server_default=sa.text("1")),
        sa.Column("status_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False),
        sa.Column("created_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.CheckConstraint("start_date <= end_date", name="ck_arrangement_schedules_date_range"),
        sa.CheckConstraint("slot_count > 0", name="ck_arrangement_schedules_slot_count"),
    )
    op.create_index("ix_arrangement_schedules_batch_id", "arrangement_schedules", ["batch_id"], unique=False)
    op.create_index("ix_arrangement_schedules_status_id", "arrangement_schedules", ["status_id"], unique=False)
    op.create_index("ix_arrangement_schedules_created_by", "arrangement_schedules", ["created_by"], unique=False)

    op.create_table(
        "arrangement_pickups",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("schedule_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("arrangement_schedules.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("points", sa.SmallInteger(), nullable=False, server_default=sa.text("1")),
        sa.Column("status_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False),
        sa.Column("picked_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("picked_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("approved_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("approved_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("cancelled_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("cancelled_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("cancel_reason", sa.Text(), nullable=True),
        sa.Column("pickup_start_date", sa.Date(), nullable=False),
        sa.Column("pickup_end_date", sa.Date(), nullable=False),
        sa.Column(
            "pickup_range",
            postgresql.DATERANGE(),
            sa.Computed("daterange(pickup_start_date, pickup_end_date, '[]')", persisted=True),
            nullable=True,
        ),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("schedule_id", "user_id", name="uq_arrangement_pickups_schedule_id_user_id"),
    )
    op.create_index("ix_arrangement_pickups_schedule_id", "arrangement_pickups", ["schedule_id"], unique=False)
    op.create_index("ix_arrangement_pickups_user_id", "arrangement_pickups", ["user_id"], unique=False)
    op.create_index("ix_arrangement_pickups_status_id", "arrangement_pickups", ["status_id"], unique=False)

    op.execute(
        "ALTER TABLE arrangement_pickups "
        "ADD CONSTRAINT ex_arrangement_pickups_user_overlap "
        "EXCLUDE USING gist (user_id WITH =, pickup_range WITH &&) "
        "WHERE (cancelled_at IS NULL)"
    )

    op.execute(
        """
        CREATE OR REPLACE FUNCTION sync_arrangement_pickup_dates()
        RETURNS trigger AS $$
        BEGIN
          SELECT start_date, end_date
            INTO NEW.pickup_start_date, NEW.pickup_end_date
            FROM arrangement_schedules
           WHERE id = NEW.schedule_id;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """
    )
    op.execute(
        """
        CREATE TRIGGER trg_arrangement_pickups_sync_dates
        BEFORE INSERT OR UPDATE OF schedule_id
        ON arrangement_pickups
        FOR EACH ROW
        EXECUTE FUNCTION sync_arrangement_pickup_dates();
        """
    )
    op.execute(
        """
        CREATE OR REPLACE FUNCTION propagate_arrangement_schedule_dates()
        RETURNS trigger AS $$
        BEGIN
          UPDATE arrangement_pickups
             SET pickup_start_date = NEW.start_date,
                 pickup_end_date = NEW.end_date,
                 updated_at = now()
           WHERE schedule_id = NEW.id;
          RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """
    )
    op.execute(
        """
        CREATE TRIGGER trg_arrangement_schedules_propagate_dates
        AFTER UPDATE OF start_date, end_date
        ON arrangement_schedules
        FOR EACH ROW
        EXECUTE FUNCTION propagate_arrangement_schedule_dates();
        """
    )

    op.create_table(
        "arrangement_jobsheet_periods",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("slug", sa.Text(), nullable=False, unique=True),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.CheckConstraint("start_date <= end_date", name="ck_arrangement_jobsheet_periods_date_range"),
    )
    op.create_index("ix_arrangement_jobsheet_periods_created_by", "arrangement_jobsheet_periods", ["created_by"], unique=False)
    op.create_index("ix_arrangement_jobsheet_periods_start_end", "arrangement_jobsheet_periods", ["start_date", "end_date"], unique=False)

    op.create_table(
        "arrangement_jobsheet_entries",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("period_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("arrangement_jobsheet_periods.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("work_date", sa.Date(), nullable=False),
        sa.Column("code_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("updated_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("period_id", "user_id", "work_date", name="uq_arrangement_jobsheet_entries_period_user_date"),
    )
    op.create_index("ix_arrangement_jobsheet_entries_period_id", "arrangement_jobsheet_entries", ["period_id"], unique=False)
    op.create_index("ix_arrangement_jobsheet_entries_user_id", "arrangement_jobsheet_entries", ["user_id"], unique=False)
    op.create_index("ix_arrangement_jobsheet_entries_user_work_date", "arrangement_jobsheet_entries", ["user_id", "work_date"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_arrangement_jobsheet_entries_user_work_date", table_name="arrangement_jobsheet_entries")
    op.drop_index("ix_arrangement_jobsheet_entries_user_id", table_name="arrangement_jobsheet_entries")
    op.drop_index("ix_arrangement_jobsheet_entries_period_id", table_name="arrangement_jobsheet_entries")
    op.drop_table("arrangement_jobsheet_entries")
    op.drop_index("ix_arrangement_jobsheet_periods_start_end", table_name="arrangement_jobsheet_periods")
    op.drop_index("ix_arrangement_jobsheet_periods_created_by", table_name="arrangement_jobsheet_periods")
    op.drop_table("arrangement_jobsheet_periods")

    op.execute("DROP TRIGGER IF EXISTS trg_arrangement_schedules_propagate_dates ON arrangement_schedules")
    op.execute("DROP FUNCTION IF EXISTS propagate_arrangement_schedule_dates")
    op.execute("DROP TRIGGER IF EXISTS trg_arrangement_pickups_sync_dates ON arrangement_pickups")
    op.execute("DROP FUNCTION IF EXISTS sync_arrangement_pickup_dates")
    op.execute("ALTER TABLE arrangement_pickups DROP CONSTRAINT IF EXISTS ex_arrangement_pickups_user_overlap")

    op.drop_index("ix_arrangement_pickups_status_id", table_name="arrangement_pickups")
    op.drop_index("ix_arrangement_pickups_user_id", table_name="arrangement_pickups")
    op.drop_index("ix_arrangement_pickups_schedule_id", table_name="arrangement_pickups")
    op.drop_table("arrangement_pickups")
    op.drop_index("ix_arrangement_schedules_created_by", table_name="arrangement_schedules")
    op.drop_index("ix_arrangement_schedules_status_id", table_name="arrangement_schedules")
    op.drop_index("ix_arrangement_schedules_batch_id", table_name="arrangement_schedules")
    op.drop_table("arrangement_schedules")
    op.drop_index("ix_arrangement_batches_created_by", table_name="arrangement_batches")
    op.drop_table("arrangement_batches")

