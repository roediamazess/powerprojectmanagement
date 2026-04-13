from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.audit import AuditLog
from app.models.rbac import User

router = APIRouter(dependencies=[Depends(csrf_protect)])


@router.get("")
def list_audit_logs(
    q: str | None = None,
    entity_type: str | None = None,
    actor_user_id: str | None = None,
    sort: str = "-created_at",
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("audit_logs.view")),
) -> dict:
    page = max(1, page)
    page_size = max(1, min(200, page_size))

    sort_key = sort.lstrip("-")
    desc = sort.startswith("-")
    sort_map = {"created_at": AuditLog.created_at}
    col = sort_map.get(sort_key)
    if col is None:
        raise HTTPException(status_code=422, detail="Invalid sort")

    where = []
    if q:
        qq = f"%{q.strip()}%"
        where.append(AuditLog.entity_id.ilike(qq))
    if entity_type:
        where.append(AuditLog.entity_type == entity_type)
    if actor_user_id:
        where.append(AuditLog.actor_user_id == actor_user_id)

    total = db.execute(select(func.count()).select_from(AuditLog).where(*where)).scalar_one()
    q = (
        select(AuditLog, User.name, User.email)
        .select_from(AuditLog)
        .outerjoin(User, User.id == AuditLog.actor_user_id)
        .where(*where)
        .order_by(col.desc() if desc else col.asc())
        .limit(page_size)
        .offset((page - 1) * page_size)
    )
    rows = db.execute(q).all()
    data = [
        {
            "id": log.id,
            "created_at": log.created_at,
            "actor_user_id": log.actor_user_id,
            "actor_name": actor_name,
            "actor_email": actor_email,
            "action": log.action,
            "entity_type": log.entity_type,
            "entity_id": log.entity_id,
            "before": log.before,
            "after": log.after,
            "meta": log.meta,
        }
        for (log, actor_name, actor_email) in rows
    ]
    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}
