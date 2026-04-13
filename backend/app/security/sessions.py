from __future__ import annotations

import secrets
from dataclasses import dataclass

from redis import Redis

from app.core.settings import get_settings


@dataclass(frozen=True)
class SessionData:
    session_id: str
    user_id: str


def _redis() -> Redis:
    settings = get_settings()
    return Redis.from_url(settings.redis_url, decode_responses=True)


def create_session(user_id: str) -> SessionData:
    settings = get_settings()
    session_id = secrets.token_urlsafe(32)
    r = _redis()
    r.setex(_key(session_id), settings.session_ttl_seconds, user_id)
    return SessionData(session_id=session_id, user_id=user_id)


def get_user_id(session_id: str | None) -> str | None:
    if not session_id:
        return None
    r = _redis()
    return r.get(_key(session_id))


def delete_session(session_id: str | None) -> None:
    if not session_id:
        return
    r = _redis()
    r.delete(_key(session_id))


def _key(session_id: str) -> str:
    return f"session:{session_id}"

