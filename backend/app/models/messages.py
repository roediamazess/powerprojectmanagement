from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    sender_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    recipient_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True)
    subject: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    body: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    read_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.Index("ix_messages_recipient_read_created", "recipient_id", "read_at", "created_at"),
        sa.Index("ix_messages_sender_created", "sender_id", "created_at"),
    )

