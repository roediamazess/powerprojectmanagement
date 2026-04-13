from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.settings import get_settings
from app.db.session import get_db
from app.models.rbac import Role, User, user_roles
from app.security.csrf import generate_csrf_token
from app.security.password import verify_password
from app.security.sessions import create_session, delete_session
from app.deps.auth import get_current_user

router = APIRouter()


class LoginRequest(BaseModel):
    email: str
    password: str


class UserMe(BaseModel):
    id: str
    email: str
    name: str
    roles: list[str]


def _set_csrf_cookie(response: Response) -> None:
    settings = get_settings()
    csrf = generate_csrf_token()
    response.set_cookie(
        key=settings.csrf_cookie_name,
        value=csrf,
        httponly=False,
        secure=settings.cookie_secure,
        samesite=settings.cookie_samesite,
        path="/",
    )


@router.get("/csrf")
def csrf(response: Response) -> dict:
    _set_csrf_cookie(response)
    return {"ok": True}


@router.post("/login", response_model=UserMe)
def login(payload: LoginRequest, response: Response, db: Session = Depends(get_db)) -> UserMe:
    settings = get_settings()
    email = payload.email.strip().lower()
    user = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    session = create_session(user.id)
    response.set_cookie(
        key=settings.session_cookie_name,
        value=session.session_id,
        httponly=True,
        secure=settings.cookie_secure,
        samesite=settings.cookie_samesite,
        path="/",
    )
    _set_csrf_cookie(response)

    roles = (
        db.execute(select(Role.name).select_from(user_roles).join(Role, Role.id == user_roles.c.role_id).where(user_roles.c.user_id == user.id))
        .scalars()
        .all()
    )
    return UserMe(id=user.id, email=user.email, name=user.name, roles=list(roles))


@router.post("/logout")
def logout(
    request: Request,
    response: Response,
    user: User = Depends(get_current_user),
) -> dict:
    settings = get_settings()
    delete_session(request.cookies.get(settings.session_cookie_name))
    response.delete_cookie(key=settings.session_cookie_name, path="/")
    response.delete_cookie(key=settings.csrf_cookie_name, path="/")
    return {"ok": True}


@router.get("/me", response_model=UserMe)
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)) -> UserMe:
    roles = (
        db.execute(select(Role.name).select_from(user_roles).join(Role, Role.id == user_roles.c.role_id).where(user_roles.c.user_id == user.id))
        .scalars()
        .all()
    )
    return UserMe(id=user.id, email=user.email, name=user.name, roles=list(roles))
