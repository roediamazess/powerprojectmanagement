from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class BackupRun(Base):
    __tablename__ = "backup_runs"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    requested_by: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    status: Mapped[str] = mapped_column(sa.Text(), nullable=False, server_default=sa.text("'QUEUED'"), index=True)
    file_path: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    started_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    finished_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    error: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

