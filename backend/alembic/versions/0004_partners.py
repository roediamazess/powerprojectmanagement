from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0004_partners"
down_revision = "0003_lookup"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "partners",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("cnc_id", sa.Text(), nullable=False, unique=True),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("status_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("star", sa.SmallInteger(), nullable=True),
        sa.Column("room", sa.Text(), nullable=True),
        sa.Column("outlet", sa.Text(), nullable=True),
        sa.Column("system_live", sa.Date(), nullable=True),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column("area", sa.Text(), nullable=True),
        sa.Column("sub_area", sa.Text(), nullable=True),
        sa.Column("implementation_type_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("system_version_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("partner_type_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("partner_group_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("lookup_values.id"), nullable=True),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    op.create_table(
        "partner_contacts",
        sa.Column("id", postgresql.UUID(as_uuid=False), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("partner_id", postgresql.UUID(as_uuid=False), sa.ForeignKey("partners.id", ondelete="CASCADE"), nullable=False),
        sa.Column("role_key", sa.Text(), nullable=False),
        sa.Column("name", sa.Text(), nullable=True),
        sa.Column("email", postgresql.CITEXT(), nullable=True),
        sa.Column("phone", sa.Text(), nullable=True),
        sa.Column("is_primary", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("created_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.TIMESTAMP(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_partner_contacts_partner_id_role_key", "partner_contacts", ["partner_id", "role_key"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_partner_contacts_partner_id_role_key", table_name="partner_contacts")
    op.drop_table("partner_contacts")
    op.drop_table("partners")

