from __future__ import annotations

import time

import psycopg

from app.core.settings import get_settings


def main() -> None:
    settings = get_settings()
    deadline = time.time() + 60
    last_error: Exception | None = None

    while time.time() < deadline:
        try:
            with psycopg.connect(settings.database_url.replace("postgresql+psycopg://", "postgresql://")) as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1")
                    cur.fetchone()
            return
        except Exception as e:
            last_error = e
            time.sleep(1)

    raise RuntimeError(f"Database not ready: {last_error}")


if __name__ == "__main__":
    main()

