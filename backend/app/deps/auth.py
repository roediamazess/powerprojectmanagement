from __future__ import annotations

from collections.abc import Callable

from fastapi import Depends, Header, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.settings import get_settings
from app.db.session import get_db
from app.models.rbac import Permission, Role, User, role_permissions, user_roles
from app.security.csrf import validate_csrf
from app.security.sessions import get_user_id


def csrf_protect(
    request: Request,
    csrf_header: str | None = Header(default=None, alias="X-CSRF-Token"),
) -> None:
    if request.method in {"GET", "HEAD", "OPTIONS"}:
        return
    settings = get_settings()
    csrf_cookie = request.cookies.get(settings.csrf_cookie_name)
    if not validate_csrf(csrf_cookie, csrf_header):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="CSRF validation failed")


def get_current_user(
    request: Request,
    db: Session = Depends(get_db),
) -> User:
    settings = get_settings()
    user_id = get_user_id(request.cookies.get(settings.session_cookie_name))
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    user = db.get(User, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return user


def require_permission(permission_key: str) -> Callable[[Session, User], None]:
    def _dep(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> None:
        q = (
            select(Permission.key)
            .select_from(user_roles)
            .join(Role, Role.id == user_roles.c.role_id)
            .join(role_permissions, role_permissions.c.role_id == Role.id)
            .join(Permission, Permission.id == role_permissions.c.permission_id)
            .where(user_roles.c.user_id == user.id)
            .where(Permission.key == permission_key)
            .limit(1)
        )
        ok = db.execute(q).scalar_one_or_none() is not None
        if not ok:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    return _dep


def require_role(role_name: str) -> Callable[[Session, User], None]:
    def _dep(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> None:
        q = (
            select(Role.name)
            .select_from(user_roles)
            .join(Role, Role.id == user_roles.c.role_id)
            .where(user_roles.c.user_id == user.id)
            .where(Role.name == role_name)
            .limit(1)
        )
        ok = db.execute(q).scalar_one_or_none() is not None
        if not ok:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")

    return _dep
