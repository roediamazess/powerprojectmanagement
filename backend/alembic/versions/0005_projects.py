from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0005_projects"
down_revision = "0004_partners"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "projects",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("partner_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("partners.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("cnc_id", sa.Text(), nullable=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("type_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("status_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=True),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("spreadsheet_id", sa.Text(), nullable=True),
        sa.Column("spreadsheet_url", sa.Text(), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_projects_partner_id", "projects", ["partner_id"], unique=False)

    op.create_table(
        "project_pic_assignments",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("project_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("projects.id", ondelete="CASCADE"), nullable=False),
        sa.Column("pic_user_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=True),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("assignment_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("status_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("release_state_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_project_pic_assignments_project_id", "project_pic_assignments", ["project_id"], unique=False)
    op.create_index("ix_project_pic_assignments_pic_user_id", "project_pic_assignments", ["pic_user_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_project_pic_assignments_pic_user_id", table_name="project_pic_assignments")
    op.drop_index("ix_project_pic_assignments_project_id", table_name="project_pic_assignments")
    op.drop_table("project_pic_assignments")
    op.drop_index("ix_projects_partner_id", table_name="projects")
    op.drop_table("projects")

