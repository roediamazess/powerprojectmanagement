from __future__ import annotations

from typing import Any
from fastapi import APIRouter, Depends
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from datetime import date

from app.db.session import get_db
from app.models.holidays import Holiday

router = APIRouter()

class HolidaySchema(BaseModel):
    id: str | None = None
    name: str
    date: date
    is_active: bool = True

class HolidayCreate(BaseModel):
    name: str
    date: date
    is_active: bool = True

@router.get("/")
async def list_holidays(db: AsyncSession = Depends(get_db)) -> Any:
    result = await db.execute(select(Holiday).order_by(Holiday.date.desc()))
    return {"data": result.scalars().all()}

@router.post("/")
async def create_holiday(data: HolidayCreate, db: AsyncSession = Depends(get_db)) -> Any:
    holiday = Holiday(
        name=data.name,
        date=data.date,
        is_active=data.is_active
    )
    db.add(holiday)
    await db.commit()
    await db.refresh(holiday)
    return holiday

@router.patch("/{holiday_id}")
async def update_holiday(holiday_id: str, data: HolidayCreate, db: AsyncSession = Depends(get_db)) -> Any:
    await db.execute(
        update(Holiday)
        .where(Holiday.id == holiday_id)
        .values(name=data.name, date=data.date, is_active=data.is_active)
    )
    await db.commit()
    return {"message": "Updated"}

@router.delete("/{holiday_id}")
async def delete_holiday(holiday_id: str, db: AsyncSession = Depends(get_db)) -> Any:
    await db.execute(delete(Holiday).where(Holiday.id == holiday_id))
    await db.commit()
    return {"message": "Deleted"}
