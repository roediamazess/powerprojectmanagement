from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class LookupCategory(Base):
    __tablename__ = "lookup_categories"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    key: Mapped[str] = mapped_column(sa.Text(), nullable=False, unique=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    values: Mapped[list["LookupValue"]] = relationship("LookupValue", back_populates="category", cascade="all, delete-orphan")


class LookupValue(Base):
    __tablename__ = "lookup_values"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    category_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_categories.id", ondelete="CASCADE"), nullable=False)
    parent_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id", ondelete="SET NULL"), nullable=True)
    value: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    label: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    sort_order: Mapped[int] = mapped_column(sa.Integer(), nullable=False, server_default=sa.text("0"))
    is_active: Mapped[bool] = mapped_column(sa.Boolean(), nullable=False, server_default=sa.text("true"))
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    category: Mapped[LookupCategory] = relationship("LookupCategory", back_populates="values")
    parent: Mapped[LookupValue | None] = relationship("LookupValue", remote_side=[id], backref="children")

    __table_args__ = (
        sa.UniqueConstraint("category_id", "value", name="uq_lookup_values_category_id_value"),
    )

