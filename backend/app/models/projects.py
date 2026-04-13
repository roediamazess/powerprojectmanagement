from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Project(Base):
    __tablename__ = "projects"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    partner_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("partners.id", ondelete="RESTRICT"), nullable=False, index=True)
    cnc_id: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    name: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    type_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    status_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    start_date: Mapped[sa.Date | None] = mapped_column(sa.Date(), nullable=True)
    end_date: Mapped[sa.Date | None] = mapped_column(sa.Date(), nullable=True)
    spreadsheet_id: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    spreadsheet_url: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    pic_assignments: Mapped[list["ProjectPicAssignment"]] = relationship(
        "ProjectPicAssignment",
        back_populates="project",
        cascade="all, delete-orphan",
    )


class ProjectPicAssignment(Base):
    __tablename__ = "project_pic_assignments"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    project_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=False, index=True)
    pic_user_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True, index=True)
    start_date: Mapped[sa.Date | None] = mapped_column(sa.Date(), nullable=True)
    end_date: Mapped[sa.Date | None] = mapped_column(sa.Date(), nullable=True)
    assignment_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    status_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    release_state_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    project: Mapped[Project] = relationship("Project", back_populates="pic_assignments")

