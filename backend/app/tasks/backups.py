from __future__ import annotations

import os
import subprocess
from datetime import datetime
from pathlib import Path

from celery import shared_task

from app.db.session import SessionLocal
from app.models.backups import BackupRun
from app.services.audit_log import write_audit_log


def _pg_url() -> str:
    url = os.getenv("DATABASE_URL", "")
    return url.replace("postgresql+psycopg://", "postgresql://")


def _backup_dir() -> Path:
    p = Path(os.getenv("BACKUP_DIR", "/var/backups/ppm"))
    p.mkdir(parents=True, exist_ok=True)
    return p


@shared_task(name="tasks.backups.run_backup")
def run_backup(backup_run_id: str) -> dict:
    with SessionLocal() as db:
        row = db.get(BackupRun, backup_run_id)
        if not row:
            return {"ok": False, "error": "not_found"}

        row.status = "RUNNING"
        row.started_at = datetime.utcnow()
        row.updated_at = datetime.utcnow()
        db.commit()

    backup_dir = _backup_dir()
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    filename = f"backup_{backup_run_id}_{timestamp}.sql.gz"
    filepath = backup_dir / filename

    cmd = ["sh", "-lc", f"pg_dump --no-owner --no-privileges \"{_pg_url()}\" | gzip -c > \"{filepath}\""]

    try:
        subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        status = "SUCCEEDED"
        err = None
    except subprocess.CalledProcessError as e:
        status = "FAILED"
        err = (e.stderr or e.stdout or str(e))[:4000]
        if filepath.exists():
            try:
                filepath.unlink()
            except Exception:
                pass

    with SessionLocal() as db:
        row = db.get(BackupRun, backup_run_id)
        if not row:
            return {"ok": False, "error": "not_found_after"}

        row.status = status
        row.file_path = str(filepath) if status == "SUCCEEDED" else None
        row.finished_at = datetime.utcnow()
        row.error = err
        row.updated_at = datetime.utcnow()

        write_audit_log(
            db,
            actor_user_id=row.requested_by,
            action="backup_run",
            entity_type="backup_run",
            entity_id=row.id,
            meta={"status": status},
        )

        db.commit()

    return {"ok": status == "SUCCEEDED", "id": backup_run_id, "status": status}
