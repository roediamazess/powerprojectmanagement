from __future__ import annotations

from fastapi import APIRouter
from fastapi.routing import APIRoute
from starlette.responses import JSONResponse, Response

from app.api.routes import (
    arrangement_jobsheets, arrangements, audit_logs, auth, backups, compliance,
    dashboard, health, health_score, lookup, messages, notifications, office_agent, partners, profile,
    projects, roles, time_boxings, users,
)
from app.api.routes.roles import perm_router


class EnvelopeRoute(APIRoute):
    def get_route_handler(self):
        original_handler = super().get_route_handler()

        async def custom_route_handler(request) -> Response:
            result = await original_handler(request)
            if isinstance(result, Response):
                return result
            if isinstance(result, dict) and set(result.keys()) >= {"data", "meta", "error"}:
                return JSONResponse(content=result)
            return JSONResponse(content={"data": result, "meta": None, "error": None})

        return custom_route_handler

api_router = APIRouter(route_class=EnvelopeRoute)

# Core
api_router.include_router(health.router, tags=["health"])
api_router.include_router(dashboard.router, prefix="/dashboard", tags=["dashboard"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(profile.router, prefix="/profile", tags=["profile"])

# User & RBAC management
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(roles.router, prefix="/roles", tags=["roles"])
api_router.include_router(perm_router, prefix="/permissions", tags=["permissions"])

# Operations
api_router.include_router(partners.router, prefix="/partners", tags=["partners"])
api_router.include_router(projects.router, prefix="/projects", tags=["projects"])
api_router.include_router(arrangements.router, prefix="/arrangements", tags=["arrangements"])
api_router.include_router(arrangement_jobsheets.router, prefix="/arrangements/jobsheet", tags=["arrangements-jobsheet"])
api_router.include_router(time_boxings.router, prefix="/time-boxings", tags=["time-boxings"])
api_router.include_router(compliance.router, prefix="/compliance", tags=["compliance"])
api_router.include_router(health_score.router, prefix="/health-score", tags=["health-score"])

# System
api_router.include_router(lookup.router, prefix="/lookup", tags=["lookup"])
api_router.include_router(messages.router, prefix="/messages", tags=["messages"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
api_router.include_router(office_agent.router, prefix="/office-agent", tags=["office-agent"])
api_router.include_router(audit_logs.router, prefix="/audit-logs", tags=["audit-logs"])
api_router.include_router(backups.router, prefix="/backups", tags=["backups"])
