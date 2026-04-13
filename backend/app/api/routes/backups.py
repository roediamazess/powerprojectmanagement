from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.backups import BackupRun
from app.models.rbac import User
from app.tasks.backups import run_backup

router = APIRouter(dependencies=[Depends(csrf_protect)])


@router.get("")
def list_backups(
    sort: str = "-created_at",
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("backups.view")),
) -> dict:
    page = max(1, page)
    page_size = max(1, min(200, page_size))

    sort_key = sort.lstrip("-")
    desc = sort.startswith("-")
    sort_map = {"created_at": BackupRun.created_at}
    col = sort_map.get(sort_key)
    if col is None:
        raise HTTPException(status_code=422, detail="Invalid sort")

    total = db.execute(select(func.count()).select_from(BackupRun)).scalar_one()
    rows = (
        db.execute(
            select(BackupRun)
            .order_by(col.desc() if desc else col.asc())
            .limit(page_size)
            .offset((page - 1) * page_size)
        )
        .scalars()
        .all()
    )
    data = [
        {
            "id": r.id,
            "requested_by": r.requested_by,
            "status": r.status,
            "file_path": r.file_path,
            "started_at": r.started_at,
            "finished_at": r.finished_at,
            "error": r.error,
            "created_at": r.created_at,
            "updated_at": r.updated_at,
        }
        for r in rows
    ]
    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}


@router.post("/run")
def trigger_backup(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("backups.run")),
) -> dict:
    row = BackupRun(requested_by=user.id, status="QUEUED")
    db.add(row)
    db.commit()
    db.refresh(row)

    try:
        run_backup.delay(row.id)
    except Exception:
        row.status = "FAILED"
        row.error = "Failed to enqueue backup task"
        db.add(row)
        db.commit()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Failed to enqueue backup task")

    return {"ok": True, "id": row.id, "status": row.status}


@router.get("/{backup_run_id}/download")
def download_backup(
    backup_run_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    _: None = Depends(require_permission("backups.download")),
) -> FileResponse:
    row = db.get(BackupRun, backup_run_id)
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    if row.status != "SUCCEEDED" or not row.file_path:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Backup file not available")

    p = Path(row.file_path)
    try:
        resolved = p.resolve(strict=True)
    except FileNotFoundError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found")

    backup_root = Path("/var/backups/ppm").resolve()
    try:
        resolved.relative_to(backup_root)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid backup path")

    return FileResponse(path=str(resolved), filename=resolved.name, media_type="application/gzip")
