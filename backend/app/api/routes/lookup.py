from __future__ import annotations

import sqlalchemy as sa
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.lookup import LookupCategory, LookupValue
from app.models.rbac import User
from app.services.audit_log import write_audit_log

router = APIRouter(dependencies=[Depends(csrf_protect)])


class CategoryCreate(BaseModel):
    key: str


class ValueCreate(BaseModel):
    value: str
    label: str
    parent_id: str | None = None
    sort_order: int = 0
    is_active: bool = True


class ValueUpdate(BaseModel):
    label: str | None = None
    parent_id: str | None = None
    sort_order: int | None = None
    is_active: bool | None = None


@router.get("")
def list_categories(
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
) -> dict:
    rows = db.execute(
        select(LookupCategory).options(selectinload(LookupCategory.values)).order_by(LookupCategory.key)
    ).scalars().all()
    
    # Pre-fetch all labels for parent mapping if needed
    value_labels = {v.id: v.label for cat in rows for v in cat.values}

    data = [
        {
            "id": cat.id,
            "key": cat.key,
            "values": [
                {
                    "id": v.id, 
                    "value": v.value, 
                    "label": v.label, 
                    "parent_id": v.parent_id,
                    "parent_label": value_labels.get(v.parent_id) if v.parent_id else None,
                    "sort_order": v.sort_order, 
                    "is_active": v.is_active
                }
                for v in sorted(cat.values, key=lambda x: x.sort_order)
            ],
        }
        for cat in rows
    ]
    return {"data": data, "meta": None, "error": None}


@router.get("/{key}/values")
def list_values_by_key(
    key: str,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
) -> dict:
    cat = db.execute(select(LookupCategory).where(LookupCategory.key == key)).scalar_one_or_none()
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    rows = db.execute(
        select(LookupValue)
        .where(LookupValue.category_id == cat.id, LookupValue.is_active == sa.true())  # noqa: E712
        .order_by(LookupValue.sort_order, LookupValue.label)
    ).scalars().all()
    data = [{"id": v.id, "value": v.value, "label": v.label} for v in rows]
    return {"data": data, "meta": None, "error": None}


@router.post("", status_code=status.HTTP_201_CREATED)
def create_category(
    payload: CategoryCreate,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("lookup.manage")),
) -> dict:
    key = payload.key.strip().lower()
    if not key:
        raise HTTPException(status_code=422, detail="key is required")
    existing = db.execute(select(LookupCategory).where(LookupCategory.key == key)).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=422, detail="Category key already exists")
    cat = LookupCategory(key=key)
    db.add(cat)
    write_audit_log(db, actor_user_id=actor.id, action="create", entity_type="lookup_category",
                    entity_id=cat.id if cat.id else "new", after={"key": key})
    db.commit()
    return {"id": cat.id}


@router.post("/{category_id}/values", status_code=status.HTTP_201_CREATED)
def add_value(
    category_id: str,
    payload: ValueCreate,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("lookup.manage")),
) -> dict:
    cat = db.get(LookupCategory, category_id)
    if not cat:
        raise HTTPException(status_code=404, detail="Category not found")
    v = LookupValue(
        category_id=category_id,
        value=payload.value.strip(),
        label=payload.label.strip(),
        parent_id=payload.parent_id,
        sort_order=payload.sort_order,
        is_active=payload.is_active,
    )
    db.add(v)
    db.flush()
    write_audit_log(db, actor_user_id=actor.id, action="create", entity_type="lookup_value",
                    entity_id=v.id, after={"category_id": category_id, "value": v.value})
    db.commit()
    return {"id": v.id}


@router.patch("/values/{value_id}")
def update_value(
    value_id: str,
    payload: ValueUpdate,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("lookup.manage")),
) -> dict:
    v = db.get(LookupValue, value_id)
    if not v:
        raise HTTPException(status_code=404, detail="Value not found")
    before = {"label": v.label, "sort_order": v.sort_order, "is_active": v.is_active, "parent_id": v.parent_id}
    if payload.label is not None:
        v.label = payload.label.strip()
    if payload.parent_id is not None:
        v.parent_id = payload.parent_id
    if payload.sort_order is not None:
        v.sort_order = payload.sort_order
    if payload.is_active is not None:
        v.is_active = payload.is_active
    write_audit_log(db, actor_user_id=actor.id, action="update", entity_type="lookup_value",
                    entity_id=v.id, before=before, after={"label": v.label})
    db.commit()
    return {"id": v.id}


@router.delete("/values/{value_id}", status_code=status.HTTP_200_OK)
def delete_value(
    value_id: str,
    db: Session = Depends(get_db),
    actor: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("lookup.manage")),
) -> None:
    v = db.get(LookupValue, value_id)
    if not v:
        raise HTTPException(status_code=404, detail="Value not found")
    write_audit_log(db, actor_user_id=actor.id, action="delete", entity_type="lookup_value", entity_id=v.id,
                    before={"value": v.value, "label": v.label})
    db.delete(v)
    db.commit()
