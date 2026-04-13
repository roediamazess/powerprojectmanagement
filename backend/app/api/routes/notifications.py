from __future__ import annotations

import sqlalchemy as sa
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user
from app.models.notifications import Notification
from app.models.rbac import User

router = APIRouter(dependencies=[Depends(csrf_protect)])


@router.get("")
def list_notifications(
    page: int = 1,
    page_size: int = 20,
    unread_only: bool = False,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    page = max(1, page)
    page_size = max(1, min(100, page_size))

    where = [Notification.user_id == user.id]
    if unread_only:
        where.append(Notification.is_read == sa.false())  # noqa: E712

    total = db.execute(select(func.count()).select_from(Notification).where(*where)).scalar_one()
    rows = (
        db.execute(
            select(Notification)
            .where(*where)
            .order_by(Notification.created_at.desc())
            .limit(page_size)
            .offset((page - 1) * page_size)
        )
        .scalars()
        .all()
    )
    data = [
        {
            "id": n.id,
            "title": n.title,
            "body": n.body,
            "is_read": n.is_read,
            "created_at": n.created_at.isoformat() if n.created_at else None,
        }
        for n in rows
    ]
    unread_count = db.execute(
        select(func.count()).select_from(Notification).where(Notification.user_id == user.id, Notification.is_read == sa.false())  # noqa: E712
    ).scalar_one()
    return {
        "data": data,
        "meta": {"total": int(total), "page": page, "page_size": page_size, "unread_count": int(unread_count)},
        "error": None,
    }


@router.patch("/{notification_id}/read")
def mark_read(
    notification_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    n = db.get(Notification, notification_id)
    if not n or n.user_id != user.id:
        raise HTTPException(status_code=404, detail="Notification not found")
    n.is_read = True
    db.commit()
    return {"ok": True}


@router.patch("/mark-all-read")
def mark_all_read(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    rows = db.execute(
        select(Notification).where(Notification.user_id == user.id, Notification.is_read == sa.false())  # noqa: E712
    ).scalars().all()
    for n in rows:
        n.is_read = True
    db.commit()
    return {"marked": len(rows)}
