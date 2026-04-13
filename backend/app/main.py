from __future__ import annotations

import json
import logging
import time
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.router import api_router
from app.core.settings import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="Power Project Management API")

    logging.basicConfig(level=logging.INFO, format="%(message)s")
    logger = logging.getLogger("ppm")

    @app.middleware("http")
    async def request_id_middleware(request: Request, call_next):
        request_id = request.headers.get("X-Request-ID") or uuid4().hex
        request.state.request_id = request_id

        start = time.monotonic()
        try:
            response = await call_next(request)
        except Exception:
            duration_ms = int((time.monotonic() - start) * 1000)
            logger.exception(
                json.dumps(
                    {
                        "event": "request.error",
                        "request_id": request_id,
                        "method": request.method,
                        "path": request.url.path,
                        "duration_ms": duration_ms,
                    }
                )
            )
            raise

        response.headers["X-Request-ID"] = request_id
        duration_ms = int((time.monotonic() - start) * 1000)
        logger.info(
            json.dumps(
                {
                    "event": "request.completed",
                    "request_id": request_id,
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "duration_ms": duration_ms,
                }
            )
        )
        return response

    def _error_payload(request: Request, code: str, message: str, fields: dict | None = None) -> dict:
        err: dict = {"code": code, "message": message}
        if fields is not None:
            err["fields"] = fields
        request_id = getattr(request.state, "request_id", None)
        if request_id is not None:
            err["request_id"] = request_id
        return {"data": None, "meta": None, "error": err}

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(request: Request, exc: StarletteHTTPException):
        message = exc.detail if isinstance(exc.detail, str) else "Request failed"
        return JSONResponse(status_code=exc.status_code, content=_error_payload(request, "http_error", message))

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        field_errors: dict[str, list[str]] = {}
        for err in exc.errors():
            loc = ".".join(str(x) for x in err.get("loc", []) if x != "body")
            field_errors.setdefault(loc or "body", []).append(err.get("msg", "Invalid value"))
        return JSONResponse(
            status_code=422,
            content=_error_payload(request, "validation_error", "Validation failed", fields=field_errors),
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        logger.exception(
            json.dumps(
                {
                    "event": "unhandled_exception",
                    "request_id": getattr(request.state, "request_id", None),
                    "method": request.method,
                    "path": request.url.path,
                }
            )
        )
        return JSONResponse(status_code=500, content=_error_payload(request, "internal_error", "Internal server error"))

    origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
    if origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    app.include_router(api_router, prefix="/api")
    return app


app = create_app()
