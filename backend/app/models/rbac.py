from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import CITEXT, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    email: Mapped[str] = mapped_column(CITEXT(), nullable=False, unique=True, index=True)
    name: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    password_hash: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    is_active: Mapped[bool] = mapped_column(sa.Boolean(), nullable=False, server_default=sa.text("true"))
    profile_photo_path: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    roles: Mapped[list["Role"]] = relationship("Role", secondary="user_roles", back_populates="users")


class Role(Base):
    __tablename__ = "roles"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    name: Mapped[str] = mapped_column(sa.Text(), nullable=False, unique=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    users: Mapped[list[User]] = relationship("User", secondary="user_roles", back_populates="roles")
    permissions: Mapped[list["Permission"]] = relationship("Permission", secondary="role_permissions", back_populates="roles")


class Permission(Base):
    __tablename__ = "permissions"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    key: Mapped[str] = mapped_column(sa.Text(), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    roles: Mapped[list[Role]] = relationship("Role", secondary="role_permissions", back_populates="permissions")


user_roles = sa.Table(
    "user_roles",
    Base.metadata,
    sa.Column("user_id", UUID(as_uuid=False), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
    sa.Column("role_id", UUID(as_uuid=False), sa.ForeignKey("roles.id", ondelete="CASCADE"), nullable=False),
    sa.UniqueConstraint("user_id", "role_id", name="uq_user_roles_user_id_role_id"),
)


role_permissions = sa.Table(
    "role_permissions",
    Base.metadata,
    sa.Column("role_id", UUID(as_uuid=False), sa.ForeignKey("roles.id", ondelete="CASCADE"), nullable=False),
    sa.Column("permission_id", UUID(as_uuid=False), sa.ForeignKey("permissions.id", ondelete="CASCADE"), nullable=False),
    sa.UniqueConstraint("role_id", "permission_id", name="uq_role_permissions_role_id_permission_id"),
)

