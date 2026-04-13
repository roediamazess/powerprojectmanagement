from __future__ import annotations

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="", extra="ignore")

    env: str = "dev"
    database_url: str
    redis_url: str = "redis://redis:6379/0"

    api_host: str = "0.0.0.0"
    api_port: int = 8000

    session_cookie_name: str = "ppm_session"
    csrf_cookie_name: str = "ppm_csrf"
    session_ttl_seconds: int = 60 * 60 * 12

    cookie_secure: bool = False
    cookie_samesite: str = "lax"

    cors_origins: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings()

