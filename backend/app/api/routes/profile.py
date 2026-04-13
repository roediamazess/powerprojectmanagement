from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user
from app.models.rbac import User
from app.security.password import hash_password, verify_password
from app.services.audit_log import write_audit_log

router = APIRouter(dependencies=[Depends(csrf_protect)])


class ProfileUpdate(BaseModel):
    name: str | None = None


class PasswordChange(BaseModel):
    current_password: str
    new_password: str


@router.get("/me")
def get_profile(user: User = Depends(get_current_user)) -> dict:
    return {
        "data": {
            "id": user.id,
            "email": user.email,
            "name": user.name,
            "is_active": user.is_active,
            "created_at": user.created_at.isoformat() if user.created_at else None,
        },
        "meta": None,
        "error": None,
    }


@router.patch("/me")
def update_profile(
    payload: ProfileUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    before = {"name": user.name}
    if payload.name is not None:
        user.name = payload.name.strip()
    write_audit_log(db, actor_user_id=user.id, action="update", entity_type="user", entity_id=user.id,
                    before=before, after={"name": user.name})
    db.commit()
    return {"data": {"id": user.id, "email": user.email, "name": user.name}, "meta": None, "error": None}


@router.post("/me/change-password")
def change_password(
    payload: PasswordChange,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    if not verify_password(payload.current_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    if len(payload.new_password) < 8:
        raise HTTPException(status_code=422, detail="New password must be at least 8 characters")
    user.password_hash = hash_password(payload.new_password)
    write_audit_log(db, actor_user_id=user.id, action="update", entity_type="user", entity_id=user.id,
                    after={"action": "password_changed"})
    db.commit()
    return {"ok": True}
