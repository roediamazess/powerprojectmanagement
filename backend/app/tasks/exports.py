from __future__ import annotations

import csv
import os
import time
from datetime import UTC, datetime

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.projects import Project
from app.tasks.notifications import send_notification
from app.worker import celery_app


@celery_app.task(name="tasks.export_projects")
def export_projects(user_id: str) -> dict:
    # Simulate a time-consuming task
    time.sleep(3)
    
    export_dir = "/tmp/exports"
    os.makedirs(export_dir, exist_ok=True)
    
    filename = f"projects_{datetime.now(tz=UTC).strftime('%Y%m%d%H%M%S')}.csv"
    filepath = os.path.join(export_dir, filename)
    
    with SessionLocal() as db:
        projects = db.execute(select(Project).order_by(Project.name)).scalars().all()
        
        with open(filepath, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["ID", "Name", "Status", "Start Date", "End Date"])
            for p in projects:
                writer.writerow([
                    p.id,
                    p.name,
                    p.status,
                    p.start_date.isoformat() if p.start_date else "",
                    p.end_date.isoformat() if p.end_date else "",
                ])
                
    # Notify user when done
    send_notification.delay(
        user_id=user_id,
        title="Export Setup Completed",
        body=f"Your projects export is ready for download: {filename}"
    )
    
    return {"status": "success", "file": filepath}
