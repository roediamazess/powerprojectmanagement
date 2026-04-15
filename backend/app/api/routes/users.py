from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.rbac import Role, User, user_roles
from app.security.password import hash_password
from app.services.audit_log import write_audit_log

router = APIRouter(dependencies=[Depends(csrf_protect)])


class UserCreate(BaseModel):
    email: EmailStr
    name: str
    password: str
    role_ids: list[str] = []


class UserUpdate(BaseModel):
    name: str | None = None
    password: str | None = None
    is_active: bool | None = None
    role_ids: list[str] | None = None


def _user_row(u: User, db: Session) -> dict:
    roles = (
        db.execute(
            select(Role.id, Role.name)
            .select_from(user_roles)
            .join(Role, Role.id == user_roles.c.role_id)
            .where(user_roles.c.user_id == u.id)
        )
        .all()
    )
    return {
        "id": u.id,
        "email": u.email,
        "name": u.name,
        "is_active": u.is_active,
        "created_at": u.created_at.isoformat() if u.created_at else None,
        "roles": [{"id": r.id, "name": r.name} for r in roles],
    }


@router.get("")
def list_users(
    q: str | None = None,
    sort: str = "-created_at",
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("users.view")),
) -> dict:
    page = max(1, page)
    page_size = max(1, min(200, page_size))

    sort_key = sort.lstrip("-")
    desc = sort.startswith("-")
    sort_map = {"created_at": User.created_at, "name": User.name, "email": User.email}
    col = sort_map.get(sort_key)
    if col is None:
        raise HTTPException(status_code=422, detail="Invalid sort field")

    where = []
    if q:
        qq = f"%{q.strip()}%"
        where.append((User.name.ilike(qq)) | (User.email.ilike(qq)))

    total = db.execute(select(func.count()).select_from(User).where(*where)).scalar_one()
    stmt = (
        select(User)
        .where(*where)
        .order_by(col.desc() if desc else col.asc())
        .limit(page_size)
        .offset((page - 1) * page_size)
    )
    rows = db.execute(stmt).scalars().all()
    data = [_user_row(u, db) for u in rows]
    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}


@router.post("", status_code=status.HTTP_201_CREATED)
def create_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("users.create")),
) -> dict:
    email = payload.email.strip().lower()
    existing = db.execute(select(User).where(User.email == email)).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=422, detail="Email already exists")

    u = User(
        email=email,
        name=payload.name.strip(),
        password_hash=hash_password(payload.password),
    )
    db.add(u)
    db.flush()

    # Assign roles
    if payload.role_ids:
        for role_id in payload.role_ids:
            role = db.get(Role, role_id)
            if role:
                db.execute(user_roles.insert().values(user_id=u.id, role_id=role_id))

    write_audit_log(db, actor_user_id=actor.id, action="create", entity_type="user", entity_id=u.id,
                    after={"email": email, "name": u.name})
    db.commit()
    return {"id": u.id}


@router.patch("/{user_id}")
def update_user(
    user_id: str,
    payload: UserUpdate,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("users.edit")),
) -> dict:
    u = db.get(User, user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")

    before: dict = {"name": u.name, "is_active": u.is_active}
    if payload.name is not None:
        u.name = payload.name.strip()
    if payload.password is not None:
        u.password_hash = hash_password(payload.password)
    if payload.is_active is not None:
        u.is_active = payload.is_active

    if payload.role_ids is not None:
        db.execute(user_roles.delete().where(user_roles.c.user_id == user_id))
        for role_id in payload.role_ids:
            role = db.get(Role, role_id)
            if role:
                db.execute(user_roles.insert().values(user_id=user_id, role_id=role_id))

    write_audit_log(db, actor_user_id=actor.id, action="update", entity_type="user", entity_id=u.id,
                    before=before, after={"name": u.name, "is_active": u.is_active})
    db.commit()
    return _user_row(u, db)


@router.delete("/{user_id}", status_code=status.HTTP_200_OK)
def delete_user(
    user_id: str,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("users.delete")),
) -> None:
    u = db.get(User, user_id)
    if not u:
        raise HTTPException(status_code=404, detail="User not found")
    if u.id == actor.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    write_audit_log(db, actor_user_id=actor.id, action="delete", entity_type="user", entity_id=u.id,
                    before={"email": u.email, "name": u.name})
    db.delete(u)
    db.commit()
