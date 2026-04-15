from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.orm import Session, aliased

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.lookup import LookupValue
from app.models.partners import Partner
from app.models.projects import Project
from app.models.rbac import User
from app.services.audit_log import write_audit_log
# from app.tasks.exports import export_projects

router = APIRouter(dependencies=[Depends(csrf_protect)])


class ProjectCreate(BaseModel):
    partner_id: str
    name: str
    type_id: str | None = None
    status_id: str | None = None


class ProjectUpdate(BaseModel):
    partner_id: str | None = None
    name: str | None = None
    type_id: str | None = None
    status_id: str | None = None


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

    TypeLV = aliased(LookupValue)
    StatusLV = aliased(LookupValue)

    stmt = (
        select(
            Project,
            Partner.name.label("partner_name"),
            TypeLV.label.label("type_label"),
            StatusLV.label.label("status_label"),
        )
        .join(Partner, Project.partner_id == Partner.id)
        .outerjoin(TypeLV, Project.type_id == TypeLV.id)
        .outerjoin(StatusLV, Project.status_id == StatusLV.id)
        .where(*where)
        .order_by(col.desc() if desc else col.asc())
        .limit(page_size)
        .offset((page - 1) * page_size)
    )
    rows = db.execute(stmt).all()
    data = [
        {
            "id": r.Project.id,
            "partner_id": r.Project.partner_id,
            "partner_name": r.partner_name,
            "name": r.Project.name,
            "type_id": r.Project.type_id,
            "type_label": r.type_label,
            "status_id": r.Project.status_id,
            "status_label": r.status_label,
            "start_date": r.Project.start_date.isoformat() if r.Project.start_date else None,
            "end_date": r.Project.end_date.isoformat() if r.Project.end_date else None,
        }
        for r in rows
    ]
    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}


@router.get("/{id}")
def get_project(
    id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("projects.view")),
) -> dict:
    TypeLV = aliased(LookupValue)
    StatusLV = aliased(LookupValue)
    stmt = (
        select(
            Project,
            Partner.name.label("partner_name"),
            TypeLV.label.label("type_label"),
            StatusLV.label.label("status_label"),
        )
        .join(Partner, Project.partner_id == Partner.id)
        .outerjoin(TypeLV, Project.type_id == TypeLV.id)
        .outerjoin(StatusLV, Project.status_id == StatusLV.id)
        .where(Project.id == id)
    )
    r = db.execute(stmt).first()
    if not r:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    row = r.Project
    return {
        "id": row.id,
        "partner_id": row.partner_id,
        "partner_name": r.partner_name,
        "name": row.name,
        "type_id": row.type_id,
        "type_label": r.type_label,
        "status_id": row.status_id,
        "status_label": r.status_label,
        "start_date": row.start_date.isoformat() if row.start_date else None,
        "end_date": row.end_date.isoformat() if row.end_date else None,
    }


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

    row = Project(
        partner_id=partner_id,
        name=name,
        type_id=payload.type_id.strip() if payload.type_id else None,
        status_id=payload.status_id.strip() if payload.status_id else None,
    )
    db.add(row)
    db.flush()
    write_audit_log(
        db,
        actor_user_id=user.id,
        action="create",
        entity_type="project",
        entity_id=row.id,
        after={
            "partner_id": partner_id,
            "name": name,
            "type_id": row.type_id,
            "status_id": row.status_id,
        },
    )
    db.commit()
    return {"id": row.id}


@router.put("/{id}")
def update_project(
    id: str,
    payload: ProjectUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("projects.update")),
) -> dict:
    row = db.get(Project, id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Project not found")

    before = {
        "partner_id": row.partner_id,
        "name": row.name,
        "type_id": row.type_id,
        "status_id": row.status_id,
        "start_date": row.start_date.isoformat() if row.start_date else None,
        "end_date": row.end_date.isoformat() if row.end_date else None,
    }

    data = payload.model_dump(exclude_unset=True)

    if "partner_id" in data and data["partner_id"] is not None:
        new_partner_id = data["partner_id"].strip()
        if not new_partner_id:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="partner_id is invalid")
        partner = db.get(Partner, new_partner_id)
        if not partner:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="partner_id is invalid")
        row.partner_id = new_partner_id

    if "name" in data and data["name"] is not None:
        new_name = data["name"].strip()
        if not new_name:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="name is required")
        row.name = new_name

    if "type_id" in data:
        row.type_id = data["type_id"].strip() if data["type_id"] else None
    if "status_id" in data:
        row.status_id = data["status_id"].strip() if data["status_id"] else None

    db.flush()
    after = {
        "partner_id": row.partner_id,
        "name": row.name,
        "type_id": row.type_id,
        "status_id": row.status_id,
        "start_date": row.start_date.isoformat() if row.start_date else None,
        "end_date": row.end_date.isoformat() if row.end_date else None,
    }

    write_audit_log(
        db,
        actor_user_id=user.id,
        action="update",
        entity_type="project",
        entity_id=row.id,
        before=before,
        after=after,
    )
    db.commit()
    return {"id": row.id}
# @router.post("/export")
# def trigger_projects_export(
#     user: User = Depends(get_current_user),
#     _: None = Depends(require_permission("projects.view")),
# ) -> dict:
#     export_projects.delay(user_id=user.id)
#     return {"message": "Export task started in background. You will receive a notification when it's ready."}
