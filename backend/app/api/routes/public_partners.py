from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.partners import Partner

router = APIRouter()


@router.get("/partners")
def list_public_partners(
    q: str | None = None,
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
) -> dict:
    page = max(1, page)
    page_size = max(1, min(200, page_size))

    where = []
    if q:
        qq = f"%{q.strip()}%"
        where.append(or_(Partner.cnc_id.ilike(qq), Partner.name.ilike(qq)))

    total = db.execute(select(func.count()).select_from(Partner).where(*where)).scalar_one()
    stmt = (
        select(Partner)
        .where(*where)
        .order_by(Partner.name.asc())
        .limit(page_size)
        .offset((page - 1) * page_size)
    )
    rows = db.execute(stmt).scalars().all()
    data = [
        {
            "id": r.id,
            "cnc_id": r.cnc_id,
            "name": r.name,
            "star": r.star,
            "area": r.area,
            "sub_area": r.sub_area,
        }
        for r in rows
    ]
    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}
