from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.settings import get_settings

settings = get_settings()

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)

laravel_engine = create_engine(settings.laravel_database_url, pool_pre_ping=True) if settings.laravel_database_url else None
LaravelSessionLocal = sessionmaker(bind=laravel_engine, autocommit=False, autoflush=False) if laravel_engine else None


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_laravel_db() -> Generator[Session, None, None]:
    if LaravelSessionLocal is None:
        raise RuntimeError("Laravel DB is not configured (LARAVEL_DATABASE_URL is empty)")
    db = LaravelSessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_laravel_db_optional() -> Generator[Session | None, None, None]:
    if LaravelSessionLocal is None:
        yield None
        return
    db = LaravelSessionLocal()
    try:
        yield db
    finally:
        db.close()
