from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[int] = mapped_column(sa.BigInteger(), primary_key=True, autoincrement=True)
    actor_user_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    action: Mapped[str] = mapped_column(sa.Text(), nullable=False, index=True)
    entity_type: Mapped[str] = mapped_column(sa.Text(), nullable=False, index=True)
    entity_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), nullable=True, index=True)
    before: Mapped[dict | None] = mapped_column(JSONB(), nullable=True)
    after: Mapped[dict | None] = mapped_column(JSONB(), nullable=True)
    meta: Mapped[dict | None] = mapped_column(JSONB(), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.Index("ix_audit_logs_entity_type_entity_id", "entity_type", "entity_id"),
        sa.Index("ix_audit_logs_actor_created_at", "actor_user_id", "created_at"),
    )

