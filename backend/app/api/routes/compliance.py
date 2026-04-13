from __future__ import annotations

import secrets
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import case, desc, func, select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.deps.auth import csrf_protect, get_current_user
from app.models.health_score import (
    HealthScoreAnswer,
    HealthScoreQuestion,
    HealthScoreQuestionOption,
    HealthScoreSection,
    HealthScoreSurvey,
    HealthScoreTemplate,
)
from app.models.partners import Partner
from app.models.projects import Project
from app.models.rbac import User
from app.services.audit_log import write_audit_log
from app.services.compliance_scoring import recompute_scores

router = APIRouter(dependencies=[Depends(csrf_protect)])


@router.get("/templates")
def list_templates(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[dict]:
    rows = db.execute(select(HealthScoreTemplate).order_by(HealthScoreTemplate.created_at.desc()).limit(50)).scalars().all()
    return [{"id": r.id, "name": r.name, "version": r.version, "status": r.status} for r in rows]


@router.get("/surveys")
def list_surveys(db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> list[dict]:
    q = (
        select(
            HealthScoreSurvey,
            Partner.name.label("partner_name"),
            Project.name.label("project_name"),
            HealthScoreTemplate.name.label("template_name"),
        )
        .select_from(HealthScoreSurvey)
        .join(HealthScoreTemplate, HealthScoreTemplate.id == HealthScoreSurvey.template_id)
        .outerjoin(Partner, Partner.id == HealthScoreSurvey.partner_id)
        .outerjoin(Project, Project.id == HealthScoreSurvey.project_id)
        .order_by(HealthScoreSurvey.created_at.desc())
        .limit(300)
    )
    rows = db.execute(q).all()
    return [
        {
            "id": s.id,
            "template_id": s.template_id,
            "template_name": template_name,
            "partner_id": s.partner_id,
            "partner_name": partner_name,
            "project_id": s.project_id,
            "project_name": project_name,
            "year": s.year,
            "quarter": s.quarter,
            "status": s.status,
            "score_total": float(s.score_total) if s.score_total is not None else None,
            "share_token": s.share_token,
            "public_enabled": s.public_enabled,
            "created_at": s.created_at,
        }
        for (s, partner_name, project_name, template_name) in rows
    ]


class SurveyCreate(BaseModel):
    template_id: str
    partner_id: str | None = None
    project_id: str | None = None
    year: int
    quarter: int


@router.post("/surveys")
def create_survey(payload: SurveyCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    if payload.quarter not in (1, 2, 3, 4):
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="quarter must be 1..4")

    template = db.get(HealthScoreTemplate, payload.template_id)
    if not template:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Template not found")

    if payload.partner_id is not None:
        partner = db.get(Partner, payload.partner_id)
        if not partner:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="partner_id is invalid")

    if payload.project_id is not None:
        project = db.get(Project, payload.project_id)
        if not project:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="project_id is invalid")
        if payload.partner_id is not None and project.partner_id != payload.partner_id:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="project_id does not belong to partner_id")

    exists = (
        db.execute(
            select(HealthScoreSurvey.id)
            .where(HealthScoreSurvey.partner_id == payload.partner_id)
            .where(HealthScoreSurvey.project_id == payload.project_id)
            .where(HealthScoreSurvey.year == payload.year)
            .where(HealthScoreSurvey.quarter == payload.quarter)
        ).scalar_one_or_none()
        is not None
    )
    if exists:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Survey already exists for this partner/project/year/quarter")

    token = secrets.token_urlsafe(16)
    row = HealthScoreSurvey(
        template_id=template.id,
        template_version=int(template.version),
        partner_id=payload.partner_id,
        project_id=payload.project_id,
        year=payload.year,
        quarter=payload.quarter,
        status="Draft",
        created_by=user.id,
        share_token=token,
        public_enabled=True,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    db.add(row)
    db.flush()
    write_audit_log(
        db,
        actor_user_id=user.id,
        action="create",
        entity_type="compliance_survey",
        entity_id=row.id,
        after={"year": payload.year, "quarter": payload.quarter, "partner_id": payload.partner_id, "project_id": payload.project_id},
    )
    db.commit()
    return {"id": row.id}


@router.get("/surveys/{survey_id}")
def get_survey(survey_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    survey = db.get(HealthScoreSurvey, survey_id)
    if not survey:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    template = db.get(HealthScoreTemplate, survey.template_id)
    sections = (
        db.execute(select(HealthScoreSection).where(HealthScoreSection.template_id == survey.template_id).order_by(HealthScoreSection.sort_order.asc()))
        .scalars()
        .all()
    )
    section_ids = [s.id for s in sections]
    questions = (
        db.execute(select(HealthScoreQuestion).where(HealthScoreQuestion.section_id.in_(section_ids)).order_by(HealthScoreQuestion.sort_order.asc()))
        .scalars()
        .all()
    )
    question_ids = [q.id for q in questions]
    options = db.execute(select(HealthScoreQuestionOption).where(HealthScoreQuestionOption.question_id.in_(question_ids))).scalars().all()

    answers = db.execute(select(HealthScoreAnswer).where(HealthScoreAnswer.survey_id == survey_id)).scalars().all()
    answer_by_question = {a.question_id: a for a in answers}
    options_by_question: dict[str, list[HealthScoreQuestionOption]] = {}
    for o in options:
        options_by_question.setdefault(o.question_id, []).append(o)
    for qid in list(options_by_question.keys()):
        options_by_question[qid].sort(key=lambda x: x.sort_order)

    questions_by_section: dict[str, list[HealthScoreQuestion]] = {}
    for q in questions:
        questions_by_section.setdefault(q.section_id, []).append(q)

    return {
        "survey": {
            "id": survey.id,
            "status": survey.status,
            "year": survey.year,
            "quarter": survey.quarter,
            "score_total": float(survey.score_total) if survey.score_total is not None else None,
            "score_by_category": survey.score_by_category,
            "score_by_module": survey.score_by_module,
            "share_token": survey.share_token,
        },
        "template": {"id": template.id, "name": template.name, "version": template.version} if template else None,
        "sections": [
            {
                "id": s.id,
                "name": s.name,
                "weight": float(s.weight),
                "questions": [
                    {
                        "id": q.id,
                        "module": q.module,
                        "question_text": q.question_text,
                        "answer_type": q.answer_type,
                        "required": q.required,
                        "weight": float(q.weight),
                        "options": [{"id": o.id, "label": o.label, "score_value": float(o.score_value)} for o in options_by_question.get(q.id, [])],
                        "answer": {
                            "id": a.id,
                            "selected_option_id": a.selected_option_id,
                            "note": a.note,
                        }
                        if (a := answer_by_question.get(q.id))
                        else None,
                    }
                    for q in questions_by_section.get(s.id, [])
                ],
            }
            for s in sections
        ],
    }


class AnswerUpsert(BaseModel):
    question_id: str
    selected_option_id: str | None = None
    note: str | None = None


@router.post("/surveys/{survey_id}/answers")
def upsert_answer(survey_id: str, payload: AnswerUpsert, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    survey = db.get(HealthScoreSurvey, survey_id)
    if not survey:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    q = db.get(HealthScoreQuestion, payload.question_id)
    if not q:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Question not found")
    section = db.get(HealthScoreSection, q.section_id)
    if not section or section.template_id != survey.template_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid question")

    if payload.selected_option_id:
        opt = db.get(HealthScoreQuestionOption, payload.selected_option_id)
        if not opt or opt.question_id != q.id:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Invalid option")
    else:
        opt = None

    row = (
        db.execute(select(HealthScoreAnswer).where(HealthScoreAnswer.survey_id == survey_id).where(HealthScoreAnswer.question_id == q.id))
        .scalar_one_or_none()
    )
    if not row:
        row = HealthScoreAnswer(survey_id=survey_id, question_id=q.id)
        db.add(row)
        db.flush()

    row.selected_option_id = payload.selected_option_id
    row.note = payload.note
    row.score_value = float(opt.score_value) if opt else None
    row.updated_at = datetime.utcnow()

    recompute_scores(db, survey_id)
    write_audit_log(db, actor_user_id=user.id, action="answer", entity_type="compliance_survey", entity_id=survey_id, meta={"question_id": q.id})
    db.commit()
    return {"ok": True}


@router.post("/surveys/{survey_id}/submit")
def submit_survey(survey_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)) -> dict:
    survey = db.get(HealthScoreSurvey, survey_id)
    if not survey:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    sections = db.execute(select(HealthScoreSection.id).where(HealthScoreSection.template_id == survey.template_id)).scalars().all()
    questions = db.execute(select(HealthScoreQuestion).where(HealthScoreQuestion.section_id.in_(sections))).scalars().all()
    required_ids = [q.id for q in questions if q.required]
    answered_ids = set(
        db.execute(select(HealthScoreAnswer.question_id).where(HealthScoreAnswer.survey_id == survey_id).where(HealthScoreAnswer.selected_option_id.is_not(None)))
        .scalars()
        .all()
    )
    missing = [qid for qid in required_ids if qid not in answered_ids]
    if missing:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail={"missing_question_ids": missing})

    survey.status = "Submitted"
    survey.submitted_at = datetime.utcnow()
    survey.updated_at = datetime.utcnow()
    recompute_scores(db, survey_id)
    write_audit_log(db, actor_user_id=user.id, action="submit", entity_type="compliance_survey", entity_id=survey_id)
    db.commit()
    return {"ok": True, "id": survey_id}


@router.get("/summary")
def summary(
    year: int | None = None,
    quarter: int | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    where = []
    if year is not None:
        where.append(HealthScoreSurvey.year == year)
    if quarter is not None:
        where.append(HealthScoreSurvey.quarter == quarter)

    rows = db.execute(
        select(
            HealthScoreSurvey.year,
            HealthScoreSurvey.quarter,
            Partner.name.label("partner_name"),
            Project.name.label("project_name"),
            HealthScoreSurvey.status,
            HealthScoreSurvey.score_total,
        )
        .select_from(HealthScoreSurvey)
        .outerjoin(Partner, Partner.id == HealthScoreSurvey.partner_id)
        .outerjoin(Project, Project.id == HealthScoreSurvey.project_id)
        .where(*where)
        .order_by(desc(HealthScoreSurvey.created_at))
        .limit(300)
    ).all()

    stats = db.execute(
        select(
            func.count(HealthScoreSurvey.id),
            func.avg(HealthScoreSurvey.score_total),
            func.sum(case((HealthScoreSurvey.status == "Submitted", 1), else_=0)),
            func.sum(case((HealthScoreSurvey.status != "Submitted", 1), else_=0)),
        )
        .where(*where)
    ).one()

    return {
        "stats": {
            "count": int(stats[0] or 0),
            "avg_score": float(stats[1]) if stats[1] is not None else None,
            "submitted": int(stats[2] or 0),
            "draft": int(stats[3] or 0),
        },
        "rows": [
            {
                "year": y,
                "quarter": q,
                "partner_name": partner_name,
                "project_name": project_name,
                "status": st,
                "score_total": float(sc) if sc is not None else None,
            }
            for (y, q, partner_name, project_name, st, sc) in rows
        ],
    }


@router.get("/trends")
def trends(
    limit: int = 8,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> dict:
    limit = max(1, min(24, limit))
    rows = db.execute(
        select(
            HealthScoreSurvey.year,
            HealthScoreSurvey.quarter,
            func.count(HealthScoreSurvey.id).label("count"),
            func.avg(HealthScoreSurvey.score_total).label("avg_score"),
        )
        .group_by(HealthScoreSurvey.year, HealthScoreSurvey.quarter)
        .order_by(desc(HealthScoreSurvey.year), desc(HealthScoreSurvey.quarter))
        .limit(limit)
    ).all()

    out = [
        {
            "year": y,
            "quarter": q,
            "count": int(c or 0),
            "avg_score": float(a) if a is not None else None,
            "label": f"{y} Q{q}",
        }
        for (y, q, c, a) in reversed(rows)
    ]
    return {"points": out}


@router.get("/public/{token}")
def public_survey(token: str, db: Session = Depends(get_db)) -> dict:
    s = db.execute(select(HealthScoreSurvey).where(HealthScoreSurvey.share_token == token)).scalar_one_or_none()
    if not s or not s.public_enabled:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    template = db.get(HealthScoreTemplate, s.template_id)
    partner = db.get(Partner, s.partner_id) if s.partner_id else None
    project = db.get(Project, s.project_id) if s.project_id else None
    return {
        "id": s.id,
        "template": {"id": template.id, "name": template.name, "version": template.version} if template else None,
        "partner_id": s.partner_id,
        "partner_name": partner.name if partner else None,
        "project_id": s.project_id,
        "project_name": project.name if project else None,
        "year": s.year,
        "quarter": s.quarter,
        "status": s.status,
        "score_total": float(s.score_total) if s.score_total is not None else None,
        "score_by_category": s.score_by_category,
        "score_by_module": s.score_by_module,
    }
