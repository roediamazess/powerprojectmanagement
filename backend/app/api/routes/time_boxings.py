from __future__ import annotations

from datetime import date, datetime
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, joinedload

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.lookup import LookupCategory, LookupValue
from app.models.partners import Partner
from app.models.projects import Project
from app.models.rbac import User
from app.models.time_boxing import TimeBoxing
from app.services.audit_log import write_audit_log

router = APIRouter(dependencies=[Depends(csrf_protect)])


class TimeBoxingBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    information_date: date
    type_value: str
    priority_value: str
    status_value: str = "OPEN"
    user_position: str | None = None
    partner_id: str | None = None
    project_id: str | None = None
    description: str | None = None
    action_solution: str | None = None
    due_date: date | None = None


class TimeBoxingCreate(TimeBoxingBase):
    pass


class TimeBoxingUpdate(TimeBoxingBase):
    pass


def _lookup_id(db: Session, category_key: str, value: str) -> str:
    q = (
        select(LookupValue.id)
        .join(LookupCategory, LookupCategory.id == LookupValue.category_id)
        .where(LookupCategory.key == category_key)
        .where(LookupValue.value == value)
        .limit(1)
    )
    out = db.execute(q).scalar_one_or_none()
    if not out:
        # Try to find by label if value doesn't match
        q2 = (
            select(LookupValue.id)
            .join(LookupCategory, LookupCategory.id == LookupValue.category_id)
            .where(LookupCategory.key == category_key)
            .where(LookupValue.label == value)
            .limit(1)
        )
        out = db.execute(q2).scalar_one_or_none()
        if not out:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"Invalid lookup {category_key}:{value}")
    return out


@router.get("")
def list_time_boxings(
    status_filter: str | None = Query(None, alias="status"),
    statuses: list[str] = Query(default=[]),
    types: list[str] = Query(default=[]),
    priorities: list[str] = Query(default=[]),
    partner_ids: list[str] = Query(default=[]),
    project_id: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    due_from: date | None = None,
    due_to: date | None = None,
    q: str | None = None,
    sort_by: str = "no",
    sort_dir: str = "asc",
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("time_boxings.view")),
) -> dict:
    where = [TimeBoxing.deleted_at.is_(None)]

    # Permissions: non-admins only see their own
    # This logic depends on roles; let's check if user has 'Administrator' or 'Admin Officer'
    is_admin = any(r.name in ["Administrator", "Admin Officer"] for r in user.roles)
    if not is_admin:
        where.append(TimeBoxing.user_id == user.id)

    # Standard filters
    if status_filter:
        if status_filter == "active":
            # Assuming 'Completed' is the only non-active status for now
            where.append(
                TimeBoxing.status_id.notin_(
                    select(LookupValue.id)
                    .join(LookupCategory, LookupCategory.id == LookupValue.category_id)
                    .where(LookupCategory.key == "time_boxing.status")
                    .where(LookupValue.value == "Completed")
                )
            )
        elif status_filter != "all":
            where.append(TimeBoxing.status_id == _lookup_id(db, "time_boxing.status", status_filter))

    if statuses:
        where.append(TimeBoxing.status_id.in_([_lookup_id(db, "time_boxing.status", s) for s in statuses]))
    if types:
        where.append(TimeBoxing.type_id.in_([_lookup_id(db, "time_boxing.type", t) for t in types]))
    if priorities:
        where.append(TimeBoxing.priority_id.in_([_lookup_id(db, "time_boxing.priority", p) for p in priorities]))
    if partner_ids:
        where.append(TimeBoxing.partner_id.in_(partner_ids))
    if project_id:
        where.append(TimeBoxing.project_id == project_id)

    if date_from:
        where.append(TimeBoxing.information_date >= date_from)
    if date_to:
        where.append(TimeBoxing.information_date <= date_to)
    if due_from:
        where.append(TimeBoxing.due_date >= due_from)
    if due_to:
        where.append(TimeBoxing.due_date <= due_to)

    if q:
        qq = f"%{q.strip()}%"
        where.append(or_(TimeBoxing.description.ilike(qq), TimeBoxing.action_solution.ilike(qq)))

    # Sorting
    sort_map: dict[str, Any] = {
        "no": TimeBoxing.no,
        "information_date": TimeBoxing.information_date,
        "due_date": TimeBoxing.due_date,
        "created_at": TimeBoxing.created_at,
    }
    col = sort_map.get(sort_by, TimeBoxing.no)
    order = col.desc() if sort_dir == "desc" else col.asc()

    total = db.execute(select(func.count()).select_from(TimeBoxing).where(*where)).scalar_one()
    rows = (
        db.execute(
            select(TimeBoxing)
            .options(joinedload(TimeBoxing.partner), joinedload(TimeBoxing.project))
            .where(*where)
            .order_by(order)
            .limit(page_size)
            .offset((page - 1) * page_size)
        )
        .scalars()
        .all()
    )

    data = []
    for r in rows:
        data.append(
            {
                "id": r.id,
                "no": r.no,
                "information_date": r.information_date,
                "type_id": r.type_id,
                "priority_id": r.priority_id,
                "status_id": r.status_id,
                "user_position": r.user_position,
                "partner_id": r.partner_id,
                "partner": {"id": r.partner.id, "cnc_id": r.partner.cnc_id, "name": r.partner.name} if r.partner else None,
                "project_id": r.project_id,
                "project": {"id": r.project.id, "cnc_id": r.project.cnc_id, "project_name": r.project.project_name} if r.project else None,
                "description": r.description,
                "action_solution": r.action_solution,
                "due_date": r.due_date,
                "completed_at": r.completed_at,
                "created_at": r.created_at,
            }
        )

    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}}


@router.post("")
def create_time_boxing(
    payload: TimeBoxingCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("time_boxings.create")),
) -> dict:
    type_id = _lookup_id(db, "time_boxing.type", payload.type_value)
    priority_id = _lookup_id(db, "time_boxing.priority", payload.priority_value)
    status_id = _lookup_id(db, "time_boxing.status", payload.status_value)

    row = TimeBoxing(
        information_date=payload.information_date,
        type_id=type_id,
        priority_id=priority_id,
        status_id=status_id,
        user_id=user.id,
        user_position=payload.user_position,
        partner_id=payload.partner_id,
        project_id=payload.project_id,
        description=payload.description,
        action_solution=payload.action_solution,
        due_date=payload.due_date,
    )

    if payload.status_value == "Completed":
        row.completed_at = datetime.utcnow()

    db.add(row)
    db.flush()
    write_audit_log(db, actor_user_id=user.id, action="create", entity_type="time_boxing", entity_id=row.id, after=payload.model_dump(mode="json"))
    db.commit()
    return {"id": row.id}


@router.put("/{time_boxing_id}")
def update_time_boxing(
    time_boxing_id: str,
    payload: TimeBoxingUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("time_boxings.update")),
) -> dict:
    row = db.get(TimeBoxing, time_boxing_id)
    if not row or row.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    is_admin = any(r.name in ["Administrator", "Admin Officer"] for r in user.roles)
    if not is_admin and row.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    before = TimeBoxingCreate.model_validate(row).model_dump(mode="json")

    row.information_date = payload.information_date
    row.type_id = _lookup_id(db, "time_boxing.type", payload.type_value)
    row.priority_id = _lookup_id(db, "time_boxing.priority", payload.priority_value)
    
    old_status_id = row.status_id
    new_status_id = _lookup_id(db, "time_boxing.status", payload.status_value)
    row.status_id = new_status_id
    
    # Check if status became Completed
    completed_status_id = _lookup_id(db, "time_boxing.status", "Completed")
    if new_status_id == completed_status_id and old_status_id != completed_status_id:
        row.completed_at = datetime.utcnow()
    elif new_status_id != completed_status_id:
        row.completed_at = None

    row.user_position = payload.user_position
    row.partner_id = payload.partner_id
    row.project_id = payload.project_id
    row.description = payload.description
    row.action_solution = payload.action_solution
    row.due_date = payload.due_date
    row.updated_at = datetime.utcnow()

    write_audit_log(
        db,
        actor_user_id=user.id,
        action="update",
        entity_type="time_boxing",
        entity_id=row.id,
        before=before,
        after=payload.model_dump(mode="json"),
    )
    db.commit()
    return {"ok": True}


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

    is_admin = any(r.name in ["Administrator", "Admin Officer"] for r in user.roles)
    if not is_admin and row.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized")

    row.deleted_at = datetime.utcnow()
    row.deleted_by = user.id
    row.updated_at = datetime.utcnow()
    write_audit_log(db, actor_user_id=user.id, action="soft_delete", entity_type="time_boxing", entity_id=row.id)
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
    write_audit_log(db, actor_user_id=user.id, action="restore", entity_type="time_boxing", entity_id=row.id)
    db.commit()
    return {"ok": True}
