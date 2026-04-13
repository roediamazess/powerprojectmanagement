from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0008_health_score"
down_revision = "0007_arrangements"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "health_score_templates",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("status", sa.Text(), nullable=False, server_default=sa.text("'Active'")),
        sa.Column("version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("created_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    op.create_table(
        "health_score_sections",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("template_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("health_score_templates.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("weight", sa.Numeric(8, 2), nullable=False, server_default=sa.text("1")),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_health_score_sections_template_id", "health_score_sections", ["template_id"], unique=False)

    op.create_table(
        "health_score_questions",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("section_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("health_score_sections.id", ondelete="CASCADE"), nullable=False),
        sa.Column("module", sa.Text(), nullable=True),
        sa.Column("question_text", sa.Text(), nullable=False),
        sa.Column("answer_type", sa.Text(), nullable=False),
        sa.Column("scoring_rule", sa.Text(), nullable=True),
        sa.Column("weight", sa.Numeric(8, 2), nullable=False, server_default=sa.text("1")),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("required", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("note_instruction", sa.Text(), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_health_score_questions_section_id", "health_score_questions", ["section_id"], unique=False)

    op.create_table(
        "health_score_question_options",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("question_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("health_score_questions.id", ondelete="CASCADE"), nullable=False),
        sa.Column("label", sa.Text(), nullable=False),
        sa.Column("score_value", sa.Numeric(8, 2), nullable=False, server_default=sa.text("0")),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default=sa.text("0")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_health_score_question_options_question_id", "health_score_question_options", ["question_id"], unique=False)

    op.create_table(
        "health_score_surveys",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("template_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("health_score_templates.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("template_version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("partner_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("partners.id"), nullable=True),
        sa.Column("project_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("projects.id"), nullable=True),
        sa.Column("year", sa.SmallInteger(), nullable=False),
        sa.Column("quarter", sa.SmallInteger(), nullable=False),
        sa.Column("status", sa.Text(), nullable=False, server_default=sa.text("'Draft'")),
        sa.Column("score_total", sa.Numeric(8, 2), nullable=True),
        sa.Column("score_by_category", postgresql.JSONB(), nullable=True),
        sa.Column("score_by_scope", postgresql.JSONB(), nullable=True),
        sa.Column("score_by_module", postgresql.JSONB(), nullable=True),
        sa.Column("created_by", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("submitted_at", sa.TIMESTAMP(timezone=True), nullable=True),
        sa.Column("share_token", sa.Text(), nullable=True, unique=True),
        sa.Column("public_enabled", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("partner_id", "project_id", "year", "quarter", name="uq_health_score_surveys_partner_project_year_quarter"),
    )
    op.create_index("ix_health_score_surveys_template_id", "health_score_surveys", ["template_id"], unique=False)

    op.create_table(
        "health_score_answers",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("survey_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("health_score_surveys.id", ondelete="CASCADE"), nullable=False),
        sa.Column("question_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("health_score_questions.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("selected_option_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("health_score_question_options.id", ondelete="SET NULL"), nullable=True),
        sa.Column("value_date", sa.Date(), nullable=True),
        sa.Column("value_text", sa.Text(), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("score_value", sa.Numeric(8, 2), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("survey_id", "question_id", name="uq_health_score_answers_survey_question"),
    )
    op.create_index("ix_health_score_answers_survey_id", "health_score_answers", ["survey_id"], unique=False)
    op.create_index("ix_health_score_answers_question_id", "health_score_answers", ["question_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_health_score_answers_question_id", table_name="health_score_answers")
    op.drop_index("ix_health_score_answers_survey_id", table_name="health_score_answers")
    op.drop_table("health_score_answers")
    op.drop_index("ix_health_score_surveys_template_id", table_name="health_score_surveys")
    op.drop_table("health_score_surveys")
    op.drop_index("ix_health_score_question_options_question_id", table_name="health_score_question_options")
    op.drop_table("health_score_question_options")
    op.drop_index("ix_health_score_questions_section_id", table_name="health_score_questions")
    op.drop_table("health_score_questions")
    op.drop_index("ix_health_score_sections_template_id", table_name="health_score_sections")
    op.drop_table("health_score_sections")
    op.drop_table("health_score_templates")

