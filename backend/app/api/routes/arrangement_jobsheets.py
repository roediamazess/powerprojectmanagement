from __future__ import annotations

from datetime import date
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session
from fastapi import APIRouter, Depends, HTTPException

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.arrangements import (
    ArrangementJobsheetPeriod,
    ArrangementJobsheetEntry,
    ArrangementPickup,
    ArrangementSchedule,
)
from app.models.rbac import User
from app.services.audit_log import write_audit_log
import sqlalchemy as sa

router = APIRouter(dependencies=[Depends(csrf_protect)])

class PeriodCreate(BaseModel):
    name: str
    start_date: date
    end_date: date

class EntryUpsert(BaseModel):
    period_id: str
    user_id: str
    start_date: date
    end_date: date
    code: str

class EntryClear(BaseModel):
    period_id: str
    user_id: str
    start_date: date
    end_date: date


@router.get("/periods")
def list_periods(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    rows = db.execute(
        select(ArrangementJobsheetPeriod).order_by(ArrangementJobsheetPeriod.start_date.desc())
    ).scalars().all()
    
    return {
        "data": [
            {
                "id": p.id,
                "name": p.name,
                "slug": p.slug,
                "start_date": p.start_date.isoformat() if p.start_date else None,
                "end_date": p.end_date.isoformat() if p.end_date else None,
                "is_default": p.is_default
            }
            for p in rows
        ],
        "meta": None,
        "error": None
    }

@router.post("/periods")
def create_period(
    payload: PeriodCreate, 
    db: Session = Depends(get_db), 
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("arrangements.jobsheet.manage"))
):
    import re
    slug = re.sub(r'[^a-z0-9]+', '-', payload.name.lower()).strip('-')
    
    if payload.end_date < payload.start_date:
        raise HTTPException(422, "End date cannot be before start date")
        
    p = ArrangementJobsheetPeriod(
        name=payload.name,
        slug=slug,
        start_date=payload.start_date,
        end_date=payload.end_date,
        created_by=user.id,
    )
    db.add(p)
    db.flush()
    write_audit_log(db, user.id, "create", "arrangement_jobsheet_period", p.id, after={"name": p.name, "slug": p.slug})
    db.commit()
    return {"id": p.id}

@router.post("/periods/{period_id}/set-default")
def set_default_period(
    period_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("arrangements.jobsheet.manage"))
):
    p = db.get(ArrangementJobsheetPeriod, period_id)
    if not p:
        raise HTTPException(404, "Period not found")
        
    db.execute(
        sa.update(ArrangementJobsheetPeriod)
        .values(is_default=False)
    )
    p.is_default = True
    write_audit_log(db, user.id, "set_default", "arrangement_jobsheet_period", p.id)
    db.commit()
    return {"ok": True}

@router.get("/active-data")
def get_jobsheet_data(
    period_id: str | None = None,
    db: Session = Depends(get_db), 
    user: User = Depends(get_current_user)
):
    if period_id:
        period = db.get(ArrangementJobsheetPeriod, period_id)
    else:
        period = db.execute(
            select(ArrangementJobsheetPeriod).where(ArrangementJobsheetPeriod.is_default == sa.true())
        ).scalar_one_or_none()
        
    if not period:
        return {"data": {"period": None, "manual_entries": [], "approved_assignments": []}, "meta": None, "error": None}
        
    # Get manual entries
    entries = db.execute(
        select(ArrangementJobsheetEntry).where(ArrangementJobsheetEntry.period_id == period.id)
    ).scalars().all()
    
    # Get approved assignments overlapping with this period
    # We join Pickup -> Schedule -> Status to check "approved" status
    # Note: Using simple direct overlap logic
    from app.models.lookup import LookupCategory, LookupValue
    
    approved_status_id = db.execute(
        select(LookupValue.id)
        .join(LookupCategory, LookupCategory.id == LookupValue.category_id)
        .where(LookupCategory.key == "arrangement.pickup_status", LookupValue.value == "APPROVED")
    ).scalar_one_or_none()

    assignments = []
    if approved_status_id:
        pickups = db.execute(
            select(ArrangementPickup, ArrangementSchedule)
            .join(ArrangementSchedule, ArrangementSchedule.id == ArrangementPickup.schedule_id)
            .where(ArrangementPickup.status_id == approved_status_id)
            .where(ArrangementSchedule.start_date <= period.end_date)
            .where(ArrangementSchedule.end_date >= period.start_date)
        ).all()
        
        for pickup, schedule in pickups:
            # Need schedule type key
            stype = db.get(LookupValue, schedule.schedule_type_id)
            assignments.append({
                "user_id": pickup.user_id,
                "schedule_type": stype.value if stype else "UNKNOWN",
                "start_date": schedule.start_date.isoformat(),
                "end_date": schedule.end_date.isoformat(),
            })

    return {
        "data": {
            "period": {
                "id": period.id,
                "name": period.name,
                "start_date": period.start_date.isoformat(),
                "end_date": period.end_date.isoformat(),
            },
            "manual_entries": [
                {
                    "user_id": e.user_id,
                    "work_date": e.work_date.isoformat(),
                    "code": db.get(LookupValue, e.code_id).value if e.code_id else ""
                }
                for e in entries
            ],
            "approved_assignments": assignments
        },
        "meta": None,
        "error": None
    }

@router.post("/entries/upsert")
def upsert_entries(
    payload: EntryUpsert,
    db: Session = Depends(get_db), 
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("arrangements.jobsheet.manage"))
):
    period = db.get(ArrangementJobsheetPeriod, payload.period_id)
    if not period:
        raise HTTPException(404, "Period not found")
        
    if payload.start_date < period.start_date or payload.end_date > period.end_date:
        raise HTTPException(422, "Date range outside of period boundaries")
        
    from app.models.lookup import LookupCategory, LookupValue
    code_val = db.execute(
        select(LookupValue)
        .join(LookupCategory)
        .where(LookupCategory.key == "arrangement.jobsheet_code", LookupValue.value == payload.code)
    ).scalar_one_or_none()
    
    if not code_val:
        raise HTTPException(422, f"Invalid code: {payload.code}")
        
    from datetime import timedelta
    curr = payload.start_date
    while curr <= payload.end_date:
        # Check existing
        entry = db.execute(
            select(ArrangementJobsheetEntry)
            .where(
                ArrangementJobsheetEntry.period_id == payload.period_id,
                ArrangementJobsheetEntry.user_id == payload.user_id,
                ArrangementJobsheetEntry.work_date == curr
            )
        ).scalar_one_or_none()
        
        if entry:
            entry.code_id = code_val.id
            entry.updated_by = user.id
        else:
            new_entry = ArrangementJobsheetEntry(
                period_id=payload.period_id,
                user_id=payload.user_id,
                work_date=curr,
                code_id=code_val.id,
                created_by=user.id
            )
            db.add(new_entry)
            
        curr += timedelta(days=1)
        
    write_audit_log(db, user.id, "upsert", "arrangement_jobsheet_entry", None, meta={"range": f"{payload.start_date} to {payload.end_date}"})
    db.commit()
    return {"ok": True}

@router.post("/entries/clear")
def clear_entries(
    payload: EntryClear,
    db: Session = Depends(get_db), 
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("arrangements.jobsheet.manage"))
):
    q = (
        sa.delete(ArrangementJobsheetEntry)
        .where(ArrangementJobsheetEntry.period_id == payload.period_id)
        .where(ArrangementJobsheetEntry.user_id == payload.user_id)
        .where(ArrangementJobsheetEntry.work_date >= payload.start_date)
        .where(ArrangementJobsheetEntry.work_date <= payload.end_date)
    )
    db.execute(q)
    write_audit_log(db, user.id, "delete", "arrangement_jobsheet_entry", None, meta={"range": f"{payload.start_date} to {payload.end_date}"})
    db.commit()
    return {"ok": True}
