from __future__ import annotations

from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.arrangements import ArrangementBatch, ArrangementPickup, ArrangementSchedule
from app.models.lookup import LookupCategory, LookupValue
from app.models.rbac import User
from app.services.audit_log import write_audit_log

router = APIRouter(dependencies=[Depends(csrf_protect)])


class BatchCreate(BaseModel):
    name: str
    min_requirement_points: int = 0
    max_requirement_points: int = 0
    pickup_start_at: datetime | None = None
    pickup_end_at: datetime | None = None


class ScheduleCreate(BaseModel):
    batch_id: str | None = None
    schedule_type_value: str
    start_date: date
    end_date: date
    slot_count: int = 1
    note: str | None = None


class PickupCreate(BaseModel):
    schedule_id: str
    points: int = 1


class PickupAction(BaseModel):
    reason: str | None = None


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


@router.get("/batches")
def list_batches(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[dict]:
    rows = db.execute(select(ArrangementBatch).order_by(ArrangementBatch.created_at.desc()).limit(200)).scalars().all()
    return [{"id": r.id, "name": r.name, "status_id": r.status_id} for r in rows]


@router.post("/batches")
def create_batch(payload: BatchCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    status_id = _lookup_id(db, "arrangement.batch_status", "OPEN")
    row = ArrangementBatch(
        name=payload.name,
        status_id=status_id,
        min_requirement_points=payload.min_requirement_points,
        max_requirement_points=payload.max_requirement_points,
        pickup_start_at=payload.pickup_start_at,
        pickup_end_at=payload.pickup_end_at,
        created_by=user.id,
    )
    db.add(row)
    db.flush()
    write_audit_log(
        db,
        actor_user_id=user.id,
        action="create",
        entity_type="arrangement_batch",
        entity_id=row.id,
        after={"name": payload.name},
    )
    db.commit()
    return {"id": row.id}


@router.post("/schedules")
def create_schedule(payload: ScheduleCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    status_id = _lookup_id(db, "arrangement.schedule_status", "OPEN")
    schedule_type_id = _lookup_id(db, "arrangement.schedule_type", payload.schedule_type_value)
    row = ArrangementSchedule(
        batch_id=payload.batch_id,
        schedule_type_id=schedule_type_id,
        note=payload.note,
        start_date=payload.start_date,
        end_date=payload.end_date,
        slot_count=payload.slot_count,
        status_id=status_id,
        created_by=user.id,
    )
    db.add(row)
    db.flush()
    write_audit_log(
        db,
        actor_user_id=user.id,
        action="create",
        entity_type="arrangement_schedule",
        entity_id=row.id,
        after={"batch_id": payload.batch_id, "start_date": str(payload.start_date), "end_date": str(payload.end_date)},
    )
    db.commit()
    return {"id": row.id}


@router.post("/pickups")
def pick_schedule(payload: PickupCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    picked_status_id = _lookup_id(db, "arrangement.pickup_status", "PICKED")
    approved_status_id = _lookup_id(db, "arrangement.pickup_status", "APPROVED")

    with db.begin():
        schedule = (
            db.execute(select(ArrangementSchedule).where(ArrangementSchedule.id == payload.schedule_id).with_for_update())
            .scalars()
            .one_or_none()
        )
        if not schedule:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Schedule not found")

        active_count = db.execute(
            select(func.count())
            .select_from(ArrangementPickup)
            .where(ArrangementPickup.schedule_id == schedule.id)
            .where(ArrangementPickup.status_id.in_([picked_status_id, approved_status_id]))
        ).scalar_one()

        if int(active_count) >= int(schedule.slot_count):
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Schedule is full")

        row = ArrangementPickup(
            schedule_id=schedule.id,
            user_id=user.id,
            points=payload.points,
            status_id=picked_status_id,
            picked_by=user.id,
            pickup_start_date=schedule.start_date,
            pickup_end_date=schedule.end_date,
        )
        db.add(row)
        db.flush()
        write_audit_log(
            db,
            actor_user_id=user.id,
            action="create",
            entity_type="arrangement_pickup",
            entity_id=row.id,
            after={"schedule_id": payload.schedule_id, "points": payload.points},
        )

    db.refresh(row)
    return {"id": row.id}


@router.post("/pickups/{pickup_id}/approve", dependencies=[Depends(require_permission("arrangements.pickup.approve"))])
def approve_pickup(pickup_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    picked_status_id = _lookup_id(db, "arrangement.pickup_status", "PICKED")
    approved_status_id = _lookup_id(db, "arrangement.pickup_status", "APPROVED")

    with db.begin():
        row = db.get(ArrangementPickup, pickup_id)
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pickup not found")
        if row.status_id != picked_status_id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Pickup not in pickable state")
        row.status_id = approved_status_id
        row.approved_by = user.id
        row.approved_at = datetime.utcnow()
        row.updated_at = datetime.utcnow()
        write_audit_log(
            db,
            actor_user_id=user.id,
            action="approve",
            entity_type="arrangement_pickup",
            entity_id=row.id,
        )

    return {"ok": True}


@router.post("/pickups/{pickup_id}/cancel")
def cancel_pickup(pickup_id: str, payload: PickupAction, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    picked_status_id = _lookup_id(db, "arrangement.pickup_status", "PICKED")
    cancelled_status_id = _lookup_id(db, "arrangement.pickup_status", "CANCELLED")

    with db.begin():
        row = db.get(ArrangementPickup, pickup_id)
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pickup not found")
        if row.user_id != user.id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        if row.status_id != picked_status_id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Pickup cannot be cancelled")
        row.status_id = cancelled_status_id
        row.cancelled_by = user.id
        row.cancelled_at = datetime.utcnow()
        row.cancel_reason = payload.reason
        row.updated_at = datetime.utcnow()
        write_audit_log(
            db,
            actor_user_id=user.id,
            action="cancel",
            entity_type="arrangement_pickup",
            entity_id=row.id,
            meta={"reason": payload.reason},
        )

    return {"ok": True}


@router.post(
    "/pickups/{pickup_id}/override-cancel",
    dependencies=[Depends(require_permission("arrangements.pickup.override_cancel"))],
)
def override_cancel_pickup(pickup_id: str, payload: PickupAction, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    approved_status_id = _lookup_id(db, "arrangement.pickup_status", "APPROVED")
    cancelled_status_id = _lookup_id(db, "arrangement.pickup_status", "CANCELLED")

    with db.begin():
        row = db.get(ArrangementPickup, pickup_id)
        if not row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pickup not found")
        if row.status_id != approved_status_id:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Only approved pickup can be override-cancelled")
        row.status_id = cancelled_status_id
        row.cancelled_by = user.id
        row.cancelled_at = datetime.utcnow()
        row.cancel_reason = payload.reason
        row.updated_at = datetime.utcnow()
        write_audit_log(
            db,
            actor_user_id=user.id,
            action="override_cancel",
            entity_type="arrangement_pickup",
            entity_id=row.id,
            meta={"reason": payload.reason},
        )

    return {"ok": True}
