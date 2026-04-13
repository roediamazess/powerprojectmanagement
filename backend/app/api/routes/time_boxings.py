from __future__ import annotations

from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.lookup import LookupCategory, LookupValue
from app.models.rbac import User
from app.models.time_boxing import TimeBoxing
from app.services.audit_log import write_audit_log

router = APIRouter(dependencies=[Depends(csrf_protect)])


class TimeBoxingCreate(BaseModel):
    information_date: date
    type_value: str
    priority_value: str
    description: str | None = None
    due_date: date | None = None


def _lookup_id(db: Session, category_key: str, value: str) -> str:
    q = (
        select(LookupValue.id)
        .join(LookupCategory, LookupCategory.id == LookupValue.category_id)
        .where(LookupCategory.key == category_key)
        .where(LookupValue.value == value)
        .where(LookupValue.is_active.is_(True))
        .limit(1)
    )
    out = db.execute(q).scalar_one_or_none()
    if not out:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Missing lookup {category_key}:{value}")
    return out


@router.get("")
def list_time_boxings(
    q: str | None = None,
    include_deleted: bool = False,
    sort: str = "-created_at",
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("time_boxings.view")),
) -> dict:
    page = max(1, page)
    page_size = max(1, min(200, page_size))

    sort_key = sort.lstrip("-")
    desc = sort.startswith("-")
    sort_map = {
        "created_at": TimeBoxing.created_at,
        "information_date": TimeBoxing.information_date,
        "due_date": TimeBoxing.due_date,
        "no": TimeBoxing.no,
    }
    col = sort_map.get(sort_key)
    if col is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid sort")

    where = []
    if not include_deleted:
        where.append(TimeBoxing.deleted_at.is_(None))
    if q:
        qq = f"%{q.strip()}%"
        where.append(TimeBoxing.description.ilike(qq))

    total = db.execute(select(func.count()).select_from(TimeBoxing).where(*where)).scalar_one()
    rows = (
        db.execute(
            select(TimeBoxing)
            .where(*where)
            .order_by(col.desc() if desc else col.asc())
            .limit(page_size)
            .offset((page - 1) * page_size)
        )
        .scalars()
        .all()
    )
    data = [
        {
            "id": r.id,
            "no": r.no,
            "information_date": r.information_date,
            "due_date": r.due_date,
            "description": r.description,
            "status_id": r.status_id,
            "deleted_at": r.deleted_at,
        }
        for r in rows
    ]
    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}


@router.post("")
def create_time_boxing(
    payload: TimeBoxingCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("time_boxings.create")),
) -> dict:
    type_id = _lookup_id(db, "time_boxing.type", payload.type_value)
    priority_id = _lookup_id(db, "time_boxing.priority", payload.priority_value)
    status_id = _lookup_id(db, "time_boxing.status", "OPEN")

    row = TimeBoxing(
        information_date=payload.information_date,
        type_id=type_id,
        priority_id=priority_id,
        status_id=status_id,
        user_id=user.id,
        description=(payload.description or "").strip() or None,
        due_date=payload.due_date,
    )
    db.add(row)
    db.flush()
    write_audit_log(
        db,
        actor_user_id=user.id,
        action="create",
        entity_type="time_boxing",
        entity_id=row.id,
        after={"information_date": str(payload.information_date), "due_date": str(payload.due_date) if payload.due_date else None},
    )
    db.commit()
    return {"id": row.id}


@router.post("/{time_boxing_id}/delete")
def soft_delete_time_boxing(
    time_boxing_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("time_boxings.delete")),
) -> dict:
    row = db.get(TimeBoxing, time_boxing_id)
    if not row or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    row.deleted_at = datetime.utcnow()
    row.deleted_by = user.id
    row.updated_at = datetime.utcnow()
    write_audit_log(
        db,
        actor_user_id=user.id,
        action="soft_delete",
        entity_type="time_boxing",
        entity_id=row.id,
    )
    db.commit()
    return {"ok": True}


@router.post("/{time_boxing_id}/restore")
def restore_time_boxing(
    time_boxing_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("time_boxings.restore")),
) -> dict:
    row = db.get(TimeBoxing, time_boxing_id)
    if not row or row.deleted_at is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    row.deleted_at = None
    row.deleted_by = None
    row.updated_at = datetime.utcnow()
    write_audit_log(
        db,
        actor_user_id=user.id,
        action="restore",
        entity_type="time_boxing",
        entity_id=row.id,
    )
    db.commit()
    return {"ok": True}
