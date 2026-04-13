from __future__ import annotations

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class HealthScoreTemplate(Base):
    __tablename__ = "health_score_templates"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    name: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    status: Mapped[str] = mapped_column(sa.Text(), nullable=False, server_default=sa.text("'Active'"))
    version: Mapped[int] = mapped_column(sa.Integer(), nullable=False, server_default=sa.text("1"))
    created_by: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))


class HealthScoreSection(Base):
    __tablename__ = "health_score_sections"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    template_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("health_score_templates.id", ondelete="CASCADE"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    weight: Mapped[float] = mapped_column(sa.Numeric(8, 2), nullable=False, server_default=sa.text("1"))
    sort_order: Mapped[int] = mapped_column(sa.Integer(), nullable=False, server_default=sa.text("0"))
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))


class HealthScoreQuestion(Base):
    __tablename__ = "health_score_questions"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    section_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("health_score_sections.id", ondelete="CASCADE"), nullable=False, index=True)
    module: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    question_text: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    answer_type: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    scoring_rule: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    weight: Mapped[float] = mapped_column(sa.Numeric(8, 2), nullable=False, server_default=sa.text("1"))
    sort_order: Mapped[int] = mapped_column(sa.Integer(), nullable=False, server_default=sa.text("0"))
    required: Mapped[bool] = mapped_column(sa.Boolean(), nullable=False, server_default=sa.text("true"))
    note_instruction: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))


class HealthScoreQuestionOption(Base):
    __tablename__ = "health_score_question_options"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    question_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("health_score_questions.id", ondelete="CASCADE"), nullable=False, index=True)
    label: Mapped[str] = mapped_column(sa.Text(), nullable=False)
    score_value: Mapped[float] = mapped_column(sa.Numeric(8, 2), nullable=False, server_default=sa.text("0"))
    sort_order: Mapped[int] = mapped_column(sa.Integer(), nullable=False, server_default=sa.text("0"))
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))


class HealthScoreSurvey(Base):
    __tablename__ = "health_score_surveys"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    template_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("health_score_templates.id", ondelete="RESTRICT"), nullable=False, index=True)
    template_version: Mapped[int] = mapped_column(sa.Integer(), nullable=False, server_default=sa.text("1"))
    partner_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("partners.id"), nullable=True)
    project_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("projects.id"), nullable=True)
    year: Mapped[int] = mapped_column(sa.SmallInteger(), nullable=False)
    quarter: Mapped[int] = mapped_column(sa.SmallInteger(), nullable=False)
    status: Mapped[str] = mapped_column(sa.Text(), nullable=False, server_default=sa.text("'Draft'"))
    score_total: Mapped[float | None] = mapped_column(sa.Numeric(8, 2), nullable=True)
    score_by_category: Mapped[dict | None] = mapped_column(JSONB(), nullable=True)
    score_by_scope: Mapped[dict | None] = mapped_column(JSONB(), nullable=True)
    score_by_module: Mapped[dict | None] = mapped_column(JSONB(), nullable=True)
    created_by: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True)
    submitted_at: Mapped[sa.DateTime | None] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=True)
    share_token: Mapped[str | None] = mapped_column(sa.Text(), nullable=True, unique=True)
    public_enabled: Mapped[bool] = mapped_column(sa.Boolean(), nullable=False, server_default=sa.text("true"))
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.UniqueConstraint("partner_id", "project_id", "year", "quarter", name="uq_health_score_surveys_partner_project_year_quarter"),
    )


class HealthScoreAnswer(Base):
    __tablename__ = "health_score_answers"

    id: Mapped[str] = mapped_column(UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()"))
    survey_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("health_score_surveys.id", ondelete="CASCADE"), nullable=False, index=True)
    question_id: Mapped[str] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("health_score_questions.id", ondelete="RESTRICT"), nullable=False, index=True)
    selected_option_id: Mapped[str | None] = mapped_column(UUID(as_uuid=False), sa.ForeignKey("health_score_question_options.id", ondelete="SET NULL"), nullable=True)
    value_date: Mapped[sa.Date | None] = mapped_column(sa.Date(), nullable=True)
    value_text: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    note: Mapped[str | None] = mapped_column(sa.Text(), nullable=True)
    score_value: Mapped[float | None] = mapped_column(sa.Numeric(8, 2), nullable=True)
    created_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))
    updated_at: Mapped[sa.DateTime] = mapped_column(sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()"))

    __table_args__ = (
        sa.UniqueConstraint("survey_id", "question_id", name="uq_health_score_answers_survey_question"),
    )

