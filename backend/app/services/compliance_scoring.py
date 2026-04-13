from __future__ import annotations

from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.health_score import (
    HealthScoreAnswer,
    HealthScoreQuestion,
    HealthScoreQuestionOption,
    HealthScoreSection,
    HealthScoreSurvey,
)


def recompute_scores(db: Session, survey_id: str) -> None:
    survey = db.get(HealthScoreSurvey, survey_id)
    if not survey:
        return

    sections = db.execute(
        select(HealthScoreSection).where(HealthScoreSection.template_id == survey.template_id).order_by(HealthScoreSection.sort_order.asc())
    ).scalars().all()
    section_ids = [s.id for s in sections]
    questions = db.execute(
        select(HealthScoreQuestion).where(HealthScoreQuestion.section_id.in_(section_ids)).order_by(HealthScoreQuestion.sort_order.asc())
    ).scalars().all()
    question_ids = [q.id for q in questions]

    options = db.execute(select(HealthScoreQuestionOption).where(HealthScoreQuestionOption.question_id.in_(question_ids))).scalars().all()
    option_score: dict[str, Decimal] = {o.id: Decimal(str(o.score_value)) for o in options}

    answers = db.execute(select(HealthScoreAnswer).where(HealthScoreAnswer.survey_id == survey_id)).scalars().all()
    answer_by_question: dict[str, HealthScoreAnswer] = {a.question_id: a for a in answers}

    questions_by_section: dict[str, list[HealthScoreQuestion]] = {}
    for q in questions:
        questions_by_section.setdefault(q.section_id, []).append(q)

    section_scores: dict[str, float] = {}
    module_scores_sum: dict[str, Decimal] = {}
    module_scores_weight: dict[str, Decimal] = {}

    total_weight_sum = Decimal("0")
    total_weighted_sum = Decimal("0")

    for s in sections:
        qlist = questions_by_section.get(s.id, [])
        if not qlist:
            continue

        section_w_sum = Decimal("0")
        section_sum = Decimal("0")

        for q in qlist:
            a = answer_by_question.get(q.id)
            score = None
            if a and a.selected_option_id:
                score = option_score.get(a.selected_option_id)
            if score is None:
                continue

            qw = Decimal(str(q.weight))
            section_w_sum += qw
            section_sum += score * qw

            if q.module:
                module_scores_sum[q.module] = module_scores_sum.get(q.module, Decimal("0")) + score * qw
                module_scores_weight[q.module] = module_scores_weight.get(q.module, Decimal("0")) + qw

        if section_w_sum == 0:
            continue

        section_avg = section_sum / section_w_sum
        sw = Decimal(str(s.weight))
        total_weight_sum += sw
        total_weighted_sum += section_avg * sw
        section_scores[s.name] = float(section_avg)

    module_scores: dict[str, float] = {}
    for module, ssum in module_scores_sum.items():
        w = module_scores_weight.get(module) or Decimal("0")
        if w == 0:
            continue
        module_scores[module] = float(ssum / w)

    score_total = float(total_weighted_sum / total_weight_sum) if total_weight_sum != 0 else None

    survey.score_total = score_total
    survey.score_by_category = section_scores or None
    survey.score_by_module = module_scores or None
    survey.score_by_scope = {"partner_id": survey.partner_id, "project_id": survey.project_id} if (survey.partner_id or survey.project_id) else None
