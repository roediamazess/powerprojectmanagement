from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TimeBoxing(Base):
    __tablename__ = "time_boxings"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    no: Mapped[int] = mapped_column(sa.BigInteger(), nullable=False, unique=True, server_default=sa.text("nextval('time_boxings_no_seq')"))
    information_date: Mapped[sa.Date] = mapped_column(sa.Date(), nullable=False)
    type_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False)
    priority_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False)
    status_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=False)
    user_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    partner_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("partners.id"), nullable=True)
    project_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("projects.id"), nullable=True)
    description: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    action_solution: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    due_date: Mapped[sa.Date | None] = mapped_column(sa.Date(), nullable=True)
    completed_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    deleted_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True, index=True)
    deleted_by: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

