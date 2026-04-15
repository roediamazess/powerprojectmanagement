from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.rbac import Permission, Role, User, role_permissions
from app.services.audit_log import write_audit_log

router = APIRouter(dependencies=[Depends(csrf_protect)])


class RoleCreate(BaseModel):
    name: str
    permission_ids: list[str] = []


class RoleUpdate(BaseModel):
    name: str | None = None
    permission_ids: list[str] | None = None


def _role_row(r: Role, db: Session) -> dict:
    perms = (
        db.execute(
            select(Permission.id, Permission.key, Permission.description)
            .select_from(role_permissions)
            .join(Permission, Permission.id == role_permissions.c.permission_id)
            .where(role_permissions.c.role_id == r.id)
            .order_by(Permission.key)
        )
        .all()
    )
    return {
        "id": r.id,
        "name": r.name,
        "created_at": r.created_at.isoformat() if r.created_at else None,
        "permissions": [{"id": p.id, "key": p.key, "description": p.description} for p in perms],
    }


# ──────────── ROLES ────────────

@router.get("")
def list_roles(
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("roles.view")),
) -> dict:
    rows = db.execute(select(Role).order_by(Role.name)).scalars().all()
    return {"data": [_role_row(r, db) for r in rows], "meta": None, "error": None}


@router.post("", status_code=status.HTTP_201_CREATED)
def create_role(
    payload: RoleCreate,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("roles.create")),
) -> dict:
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="name is required")
    existing = db.execute(select(Role).where(Role.name == name)).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=422, detail="Role name already exists")

    r = Role(name=name)
    db.add(r)
    db.flush()

    for perm_id in payload.permission_ids:
        perm = db.get(Permission, perm_id)
        if perm:
            db.execute(role_permissions.insert().values(role_id=r.id, permission_id=perm_id))

    write_audit_log(db, actor_user_id=actor.id, action="create", entity_type="role", entity_id=r.id,
                    after={"name": name})
    db.commit()
    return {"id": r.id}


@router.patch("/{role_id}")
def update_role(
    role_id: str,
    payload: RoleUpdate,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("roles.edit")),
) -> dict:
    r = db.get(Role, role_id)
    if not r:
        raise HTTPException(status_code=404, detail="Role not found")

    before = {"name": r.name}
    if payload.name is not None:
        r.name = payload.name.strip()

    if payload.permission_ids is not None:
        db.execute(role_permissions.delete().where(role_permissions.c.role_id == role_id))
        for perm_id in payload.permission_ids:
            perm = db.get(Permission, perm_id)
            if perm:
                db.execute(role_permissions.insert().values(role_id=role_id, permission_id=perm_id))

    write_audit_log(db, actor_user_id=actor.id, action="update", entity_type="role", entity_id=r.id,
                    before=before, after={"name": r.name})
    db.commit()
    return _role_row(r, db)


@router.delete("/{role_id}", status_code=status.HTTP_200_OK)
def delete_role(
    role_id: str,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("roles.delete")),
) -> None:
    r = db.get(Role, role_id)
    if not r:
        raise HTTPException(status_code=404, detail="Role not found")
    write_audit_log(db, actor_user_id=actor.id, action="delete", entity_type="role", entity_id=r.id,
                    before={"name": r.name})
    db.delete(r)
    db.commit()


# ──────────── PERMISSIONS ────────────

perm_router = APIRouter(dependencies=[Depends(csrf_protect)])


@perm_router.get("")
def list_permissions(
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("roles.view")),
) -> dict:
    rows = db.execute(select(Permission).order_by(Permission.key)).scalars().all()
    data = [{"id": p.id, "key": p.key, "description": p.description} for p in rows]
    return {"data": data, "meta": None, "error": None}
