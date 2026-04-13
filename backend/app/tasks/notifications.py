from __future__ import annotations

from app.db.session import SessionLocal
from app.models.notifications import Notification
from app.worker import celery_app


@celery_app.task(name="tasks.send_notification")
def send_notification(user_id: str, title: str, body: str) -> dict:
    with SessionLocal() as db:
        n = Notification(
            user_id=user_id,
            title=title,
            body=body,
        )
        db.add(n)
        db.commit()
    return {"status": "sent", "user_id": user_id}
