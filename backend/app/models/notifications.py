from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    user_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    type: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    title: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    body: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    url: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    read_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    actor_user_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.Index("ix_notifications_user_read_created", "user_id", "read_at", "created_at"),
    )

