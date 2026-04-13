from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import DATERANGE, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ArrangementBatch(Base):
    __tablename__ = "arrangement_batches"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    name: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    status_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False)
    min_requirement_points: Mapped[int] = mapped_column(sa.SmallInteger(), nullable=False, server_default=sa.text("0"))
    max_requirement_points: Mapped[int] = mapped_column(sa.SmallInteger(), nullable=False, server_default=sa.text("0"))
    pickup_start_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    pickup_end_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    created_by: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    approved_by: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True)
    approved_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.CheckConstraint("min_requirement_points <= max_requirement_points", name="ck_arrangement_batches_points_range"),
        sa.CheckConstraint(
            "(pickup_start_at IS NULL AND pickup_end_at IS NULL) OR (pickup_start_at IS NOT NULL AND pickup_end_at IS NOT NULL AND pickup_start_at < pickup_end_at)",
            name="ck_arrangement_batches_pickup_window",
        ),
    )


class ArrangementSchedule(Base):
    __tablename__ = "arrangement_schedules"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    batch_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("arrangement_batches.id", ondelete="SET NULL"), nullable=True, index=True)
    schedule_type_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False)
    note: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    start_date: Mapped[sa.Date] = mapped_column(sa.Date(), nullable=False)
    end_date: Mapped[sa.Date] = mapped_column(sa.Date(), nullable=False)
    slot_count: Mapped[int] = mapped_column(sa.SmallInteger(), nullable=False, server_default=sa.text("1"))
    status_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False, index=True)
    created_by: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.CheckConstraint("start_date <= end_date", name="ck_arrangement_schedules_date_range"),
        sa.CheckConstraint("slot_count > 0", name="ck_arrangement_schedules_slot_count"),
    )


class ArrangementPickup(Base):
    __tablename__ = "arrangement_pickups"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    schedule_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("arrangement_schedules.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    points: Mapped[int] = mapped_column(sa.SmallInteger(), nullable=False, server_default=sa.text("1"))
    status_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False, index=True)
    picked_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    picked_by: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    approved_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    approved_by: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True)
    cancelled_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    cancelled_by: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True)
    cancel_reason: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    pickup_start_date: Mapped[sa.Date] = mapped_column(sa.Date(), nullable=False)
    pickup_end_date: Mapped[sa.Date] = mapped_column(sa.Date(), nullable=False)
    pickup_range: Mapped[object] = mapped_column(DATERANGE(), sa.Computed("daterange(pickup_start_date, pickup_end_date, '[]')", persisted=True))
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.UniqueConstraint("schedule_id", "user_id", name="uq_arrangement_pickups_schedule_id_user_id"),
    )


class ArrangementJobsheetPeriod(Base):
    __tablename__ = "arrangement_jobsheet_periods"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    name: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    slug: Mapped[str] = mapped_column(sa.Text(), nullable=False, unique=True)
    start_date: Mapped[sa.Date] = mapped_column(sa.Date(), nullable=False)
    end_date: Mapped[sa.Date] = mapped_column(sa.Date(), nullable=False)
    is_default: Mapped[bool] = mapped_column(sa.Boolean(), nullable=False, server_default=sa.text("false"))
    created_by: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.CheckConstraint("start_date <= end_date", name="ck_arrangement_jobsheet_periods_date_range"),
        sa.Index("ix_arrangement_jobsheet_periods_start_end", "start_date", "end_date"),
    )


class ArrangementJobsheetEntry(Base):
    __tablename__ = "arrangement_jobsheet_entries"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    period_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("arrangement_jobsheet_periods.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    work_date: Mapped[sa.Date] = mapped_column(sa.Date(), nullable=False)
    code_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False)
    note: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    created_by: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    updated_by: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.UniqueConstraint("period_id", "user_id", "work_date", name="uq_arrangement_jobsheet_entries_period_user_date"),
        sa.Index("ix_arrangement_jobsheet_entries_user_work_date", "user_id", "work_date"),
    )

