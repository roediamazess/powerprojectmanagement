from __future__ import annotations

from typing import Any
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, or_, and_, func, update
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user
from app.models.messages import SiteMessage
from app.models.rbac import User
from app.services.audit_log import write_audit_log
from datetime import datetime

router = APIRouter(dependencies=[Depends(csrf_protect)])

class MessageSend(BaseModel):
    recipient_id: str
    subject: str | None = None
    body: str

@router.get("/threads")
def list_threads(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    recent = db.execute(
        select(SiteMessage)
        .where(or_(SiteMessage.sender_id == user.id, SiteMessage.recipient_id == user.id))
        .order_by(SiteMessage.created_at.desc())
        .limit(300)
    ).scalars().all()

    thread_map = {}
    for m in recent:
        other_id = m.recipient_id if m.sender_id == user.id else m.sender_id
        if not other_id:
            continue
        if other_id not in thread_map:
            thread_map[other_id] = m

    other_user_ids = list(thread_map.keys())
    users = {u.id: u for u in db.execute(select(User).where(User.id.in_(other_user_ids))).scalars().all()} if other_user_ids else {}

    # Count unread
    unread_counts = dict(
        db.execute(
            select(SiteMessage.sender_id, func.count())
            .where(SiteMessage.recipient_id == user.id)
            .where(SiteMessage.read_at.is_(None))
            .where(SiteMessage.sender_id.in_(other_user_ids))
            .group_by(SiteMessage.sender_id)
        ).all()
    ) if other_user_ids else {}

    threads = []
    for other_id, m in thread_map.items():
        u = users.get(other_id)
        body = m.body
        if len(body) > 160:
            body = body[:160] + "…"

        threads.append({
            "user": {
                "id": str(other_id),
                "name": u.name if u else "Unknown",
                "email": u.email if u else None
            },
            "last_message": {
                "id": str(m.id),
                "sender_id": str(m.sender_id),
                "subject": m.subject,
                "body": body,
                "created_at": m.created_at.isoformat() if m.created_at else None,
                "read_at": m.read_at.isoformat() if m.read_at else None
            },
            "unread_count": unread_counts.get(other_id, 0)
        })

    all_users = db.execute(select(User).where(User.status == 'Active').order_by(User.name)).scalars().all()
    
    return {
        "data": {
            "threads": threads,
            "users": [{"id": str(u.id), "name": u.name, "email": u.email} for u in all_users]
        },
        "meta": None,
        "error": None
    }

@router.get("/threads/{other_id}")
def show_thread(other_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    messages = db.execute(
        select(SiteMessage)
        .where(
            or_(
                and_(SiteMessage.sender_id == user.id, SiteMessage.recipient_id == other_id),
                and_(SiteMessage.sender_id == other_id, SiteMessage.recipient_id == user.id)
            )
        )
        .order_by(SiteMessage.created_at.desc())
        .limit(200)
    ).scalars().all()

    # Mark as read
    db.execute(
        update(SiteMessage)
        .where(SiteMessage.sender_id == other_id, SiteMessage.recipient_id == user.id, SiteMessage.read_at.is_(None))
        .values(read_at=datetime.utcnow())
    )
    db.commit()

    other_user = db.get(User, other_id)
    if not other_user:
        raise HTTPException(status_code=404, detail="User not found")

    messages.reverse()
    return {
        "data": {
            "other_user": {
                "id": str(other_user.id),
                "name": other_user.name,
                "email": other_user.email
            },
            "messages": [{
                "id": str(m.id),
                "sender_id": str(m.sender_id),
                "subject": m.subject,
                "body": m.body,
                "created_at": m.created_at.isoformat() if m.created_at else None,
                "read_at": m.read_at.isoformat() if m.read_at else None
            } for m in messages]
        },
        "meta": None,
        "error": None
    }

@router.post("")
def send_message(payload: MessageSend, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    other = db.get(User, payload.recipient_id)
    if not other:
        raise HTTPException(status_code=400, detail="Invalid recipient")

    m = SiteMessage(
        sender_id=user.id,
        recipient_id=other.id,
        subject=payload.subject,
        body=payload.body
    )
    db.add(m)
    db.flush()
    write_audit_log(db, user.id, "create", "site_message", m.id)
    db.commit()
    return {"id": m.id}
