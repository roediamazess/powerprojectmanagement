from __future__ import annotations

import secrets


def generate_csrf_token() -> str:
    return secrets.token_urlsafe(32)


def validate_csrf(cookie_token: str | None, header_token: str | None) -> bool:
    if not cookie_token or not header_token:
        return False
    return secrets.compare_digest(cookie_token, header_token)

