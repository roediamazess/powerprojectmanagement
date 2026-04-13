from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import CITEXT, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Partner(Base):
    __tablename__ = "partners"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    cnc_id: Mapped[str] = mapped_column(sa.Text(), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    status_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    star: Mapped[int | None] = mapped_column(sa.SmallInteger(), nullable=True)
    room: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    outlet: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    system_live: Mapped[sa.Date | None] = mapped_column(sa.Date(), nullable=True)
    address: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    area: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    sub_area: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    implementation_type_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    system_version_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    partner_type_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    partner_group_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    contacts: Mapped[list["PartnerContact"]] = relationship("PartnerContact", back_populates="partner", cascade="all, delete-orphan")


class PartnerContact(Base):
    __tablename__ = "partner_contacts"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    partner_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("partners.id", ondelete="CASCADE"), nullable=False)
    role_key: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    name: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    email: Mapped[str | None] = mapped_column(CITEXT(), nullable=True)
    phone: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    is_primary: Mapped[bool] = mapped_column(sa.Boolean(), nullable=False, server_default=sa.text("false"))
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    partner: Mapped[Partner] = relationship("Partner", back_populates="contacts")

    __table_args__ = (
        sa.Index("ix_partner_contacts_partner_id_role_key", "partner_id", "role_key"),
    )

