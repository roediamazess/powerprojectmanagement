from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user, require_permission
from app.models.health_score import (
    HealthScoreSurvey,
    HealthScoreTemplate,
    HealthScoreSection,
    HealthScoreQuestion,
)
from app.models.partners import Partner
from app.models.projects import Project
from app.models.rbac import User

router = APIRouter(dependencies=[Depends(csrf_protect)])


# ──────────── TEMPLATES ────────────

@router.get("/templates")
def list_templates(
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("health_score.view")),
) -> dict:
    rows = db.execute(select(HealthScoreTemplate).order_by(HealthScoreTemplate.created_at.desc())).scalars().all()
    data = [{"id": t.id, "name": t.name, "status": t.status, "version": t.version} for t in rows]
    return {"data": data, "meta": None, "error": None}


@router.get("/templates/{template_id}")
def get_template(
    template_id: str,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("health_score.view")),
) -> dict:
    t = db.get(HealthScoreTemplate, template_id)
    if not t:
        raise HTTPException(status_code=404, detail="Template not found")
    sections = db.execute(
        select(HealthScoreSection)
        .where(HealthScoreSection.template_id == template_id)
        .order_by(HealthScoreSection.sort_order)
    ).scalars().all()

    sections_data = []
    for sec in sections:
        questions = db.execute(
            select(HealthScoreQuestion)
            .where(HealthScoreQuestion.section_id == sec.id)
            .order_by(HealthScoreQuestion.sort_order)
        ).scalars().all()
        sections_data.append({
            "id": sec.id,
            "name": sec.name,
            "weight": float(sec.weight),
            "sort_order": sec.sort_order,
            "questions": [
                {
                    "id": q.id,
                    "question_text": q.question_text,
                    "answer_type": q.answer_type,
                    "weight": float(q.weight),
                    "required": q.required,
                    "sort_order": q.sort_order,
                }
                for q in questions
            ],
        })

    return {
        "data": {
            "id": t.id,
            "name": t.name,
            "status": t.status,
            "version": t.version,
            "sections": sections_data,
        },
        "meta": None,
        "error": None,
    }


# ──────────── SURVEYS ────────────

@router.get("/surveys")
def list_surveys(
    partner_id: str | None = None,
    project_id: str | None = None,
    year: int | None = None,
    quarter: int | None = None,
    page: int = 1,
    page_size: int = 50,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("health_score.view")),
) -> dict:
    page = max(1, page)
    page_size = max(1, min(200, page_size))

    where = []
    if partner_id:
        where.append(HealthScoreSurvey.partner_id == partner_id)
    if project_id:
        where.append(HealthScoreSurvey.project_id == project_id)
    if year:
        where.append(HealthScoreSurvey.year == year)
    if quarter:
        where.append(HealthScoreSurvey.quarter == quarter)

    total = db.execute(select(func.count()).select_from(HealthScoreSurvey).where(*where)).scalar_one()
    rows = (
        db.execute(
            select(HealthScoreSurvey)
            .where(*where)
            .order_by(HealthScoreSurvey.created_at.desc())
            .limit(page_size)
            .offset((page - 1) * page_size)
        )
        .scalars()
        .all()
    )

    data = []
    for s in rows:
        partner_name = None
        if s.partner_id:
            p = db.get(Partner, s.partner_id)
            partner_name = p.name if p else None
        project_name = None
        if s.project_id:
            proj = db.get(Project, s.project_id)
            project_name = proj.name if proj else None

        data.append({
            "id": s.id,
            "template_id": s.template_id,
            "partner_id": s.partner_id,
            "partner_name": partner_name,
            "project_id": s.project_id,
            "project_name": project_name,
            "year": s.year,
            "quarter": s.quarter,
            "status": s.status,
            "score_total": float(s.score_total) if s.score_total is not None else None,
            "created_at": s.created_at.isoformat() if s.created_at else None,
            "submitted_at": s.submitted_at.isoformat() if s.submitted_at else None,
        })

    return {"data": data, "meta": {"total": int(total), "page": page, "page_size": page_size}, "error": None}


@router.get("/surveys/{survey_id}")
def get_survey(
    survey_id: str,
    db: Session = Depends(get_db),
    _user: User = Depends(get_current_user),
    _perm: None = Depends(require_permission("health_score.view")),
) -> dict:
    s = db.get(HealthScoreSurvey, survey_id)
    if not s:
        raise HTTPException(status_code=404, detail="Survey not found")
    return {
        "data": {
            "id": s.id,
            "template_id": s.template_id,
            "partner_id": s.partner_id,
            "project_id": s.project_id,
            "year": s.year,
            "quarter": s.quarter,
            "status": s.status,
            "score_total": float(s.score_total) if s.score_total is not None else None,
            "score_by_category": s.score_by_category,
            "score_by_scope": s.score_by_scope,
            "score_by_module": s.score_by_module,
            "public_enabled": s.public_enabled,
            "share_token": s.share_token,
            "submitted_at": s.submitted_at.isoformat() if s.submitted_at else None,
        },
        "meta": None,
        "error": None,
    }
