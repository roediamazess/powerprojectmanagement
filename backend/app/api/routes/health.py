from fastapi import APIRouter, Depends
from redis import Redis
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.settings import get_settings
from app.db.session import get_db

router = APIRouter()


@router.api_route("/health", methods=["GET", "HEAD"])
def health(db: Session = Depends(get_db)) -> dict:
    settings = get_settings()

    db_ok = True
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        db_ok = False

    redis_ok = True
    try:
        Redis.from_url(settings.redis_url, decode_responses=True).ping()
    except Exception:
        redis_ok = False

    return {"ok": True, "db_ok": db_ok, "redis_ok": redis_ok, "env": settings.env}
