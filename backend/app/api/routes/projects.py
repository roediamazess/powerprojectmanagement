from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.partners import Partner
from app.models.projects import Project
from app.models.rbac import User
from app.services.audit_log import write_audit_log
from app.tasks.exports import export_projects

router = APIRouter(dependencies=[Depends(csrf_protect)])


class ProjectCreate(BaseModel):
    partner_id: str
    name: str


@router.get("")
def list_projects(
    q: str | None = None,
    partner_id: str | None = None,
    sort: str = "-created_at",
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("projects.view")),
) -> dict:
    page = max(1, page)
    page_size = max(1, min(200, page_size))

    sort_key = sort.lstrip("-")
    desc = sort.startswith("-")
    sort_map = {"created_at": Project.created_at, "name": Project.name}
    col = sort_map.get(sort_key)
    if col is None:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid sort")

    where = []
    if partner_id:
        where.append(Project.partner_id == partner_id.strip())
    if q:
        qq = f"%{q.strip()}%"
        where.append(Project.name.ilike(qq))

    total = db.execute(select(func.count()).select_from(Project).where(*where)).scalar_one()
    stmt = select(Project).where(*where).order_by(col.desc() if desc else col.asc()).limit(page_size).offset((page - 1) * page_size)
    rows = db.execute(stmt).scalars().all()
    data = [{"id": r.id, "partner_id": r.partner_id, "name": r.name, "start_date": r.start_date, "end_date": r.end_date} for r in rows]
    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}


@router.post("")
def create_project(
    payload: ProjectCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("projects.create")),
) -> dict:
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="name is required")
    partner_id = payload.partner_id.strip()
    if not partner_id:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="partner_id is required")

    partner = db.get(Partner, partner_id)
    if not partner:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="partner_id is invalid")

    row = Project(partner_id=partner_id, name=name)
    db.add(row)
    db.flush()
    write_audit_log(
        db,
        actor_user_id=user.id,
        action="create",
        entity_type="project",
        entity_id=row.id,
        after={"partner_id": partner_id, "name": name},
    )
    db.commit()
    return {"id": row.id}
@router.post("/export")
def trigger_projects_export(
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("projects.view")),
) -> dict:
    export_projects.delay(user_id=user.id)
    return {"message": "Export task started in background. You will receive a notification when it's ready."}
