from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.partners import Partner
from app.models.rbac import User
from app.services.audit_log import write_audit_log

router = APIRouter(dependencies=[Depends(csrf_protect)])


class PartnerCreate(BaseModel):
    cnc_id: str
    name: str


@router.get("")
def list_partners(
    q: str | None = None,
    sort: str = "-created_at",
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("partners.view")),
) -> dict:
    page = max(1, page)
    page_size = max(1, min(200, page_size))

    sort_key = sort.lstrip("-")
    desc = sort.startswith("-")
    sort_map = {"created_at": Partner.created_at, "cnc_id": Partner.cnc_id, "name": Partner.name}
    col = sort_map.get(sort_key)
    if col is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid sort")

    where = []
    if q:
        qq = f"%{q.strip()}%"
        where.append(or_(Partner.cnc_id.ilike(qq), Partner.name.ilike(qq)))

    total = db.execute(select(func.count()).select_from(Partner).where(*where)).scalar_one()
    stmt = select(Partner).where(*where).order_by(col.desc() if desc else col.asc()).limit(page_size).offset((page - 1) * page_size)
    rows = db.execute(stmt).scalars().all()
    data = [{"id": r.id, "cnc_id": r.cnc_id, "name": r.name, "star": r.star} for r in rows]
    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}


@router.post("")
def create_partner(
    payload: PartnerCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("partners.create")),
) -> dict:
    cnc = payload.cnc_id.strip()
    if not cnc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="cnc_id is required")
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="name is required")

    existing = db.execute(select(Partner.id).where(Partner.cnc_id == cnc)).scalar_one_or_none()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="cnc_id already exists")

    row = Partner(cnc_id=cnc, name=name)
    db.add(row)
    db.flush()
    write_audit_log(
        db,
        actor_user_id=user.id,
        action="create",
        entity_type="partner",
        entity_id=row.id,
        after={"cnc_id": cnc, "name": name},
    )
    db.commit()
    return {"id": row.id}
