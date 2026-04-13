from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0006_time_boxings"
down_revision = "0005_projects"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE SEQUENCE IF NOT EXISTS time_boxings_no_seq")

    op.create_table(
        "time_boxings",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("no", sa.BigInteger(), nullable=False, unique=True, server_default=sa.text("nextval('time_boxings_no_seq')")),
        sa.Column("information_date", sa.Date(), nullable=False),
        sa.Column("type_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False),
        sa.Column("priority_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False),
        sa.Column("status_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("partner_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("partners.id"), nullable=True),
        sa.Column("project_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("projects.id"), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("action_solution", sa.Text(), nullable=True),
        sa.Column("due_date", sa.Date(), nullable=True),
        sa.Column("completed_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("deleted_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("deleted_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_time_boxings_deleted_at", "time_boxings", ["deleted_at"], unique=False)
    op.create_index("ix_time_boxings_status_id", "time_boxings", ["status_id"], unique=False)
    op.create_index("ix_time_boxings_due_date", "time_boxings", ["due_date"], unique=False)
    op.create_index("ix_time_boxings_project_id", "time_boxings", ["project_id"], unique=False)
    op.create_index("ix_time_boxings_partner_id", "time_boxings", ["partner_id"], unique=False)
    op.create_index("ix_time_boxings_user_id", "time_boxings", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_time_boxings_user_id", table_name="time_boxings")
    op.drop_index("ix_time_boxings_partner_id", table_name="time_boxings")
    op.drop_index("ix_time_boxings_project_id", table_name="time_boxings")
    op.drop_index("ix_time_boxings_due_date", table_name="time_boxings")
    op.drop_index("ix_time_boxings_status_id", table_name="time_boxings")
    op.drop_index("ix_time_boxings_deleted_at", table_name="time_boxings")
    op.drop_table("time_boxings")
    op.execute("DROP SEQUENCE IF EXISTS time_boxings_no_seq")

