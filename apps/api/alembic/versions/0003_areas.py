"""Create owned Areas and attach Area audit references.

Revision ID: 0003_areas
Revises: 0002_facilities_audit
Create Date: 2026-09-01
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0003_areas"
down_revision: str | Sequence[str] | None = "0002_facilities_audit"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "areas",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("facility_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=200), nullable=False),
        sa.Column("revision", sa.Integer(), server_default="1", nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.CheckConstraint("revision >= 1", name="ck_areas_revision_positive"),
        sa.ForeignKeyConstraint(["facility_id"], ["facilities.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_areas_facility_id", "areas", ["facility_id"], unique=False)
    op.add_column("audit_events", sa.Column("area_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_audit_events_area_id_areas",
        "audit_events",
        "areas",
        ["area_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_index(
        "ix_audit_events_area_id",
        "audit_events",
        ["area_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_audit_events_area_id", table_name="audit_events")
    op.drop_constraint(
        "fk_audit_events_area_id_areas",
        "audit_events",
        type_="foreignkey",
    )
    op.drop_column("audit_events", "area_id")
    op.drop_index("ix_areas_facility_id", table_name="areas")
    op.drop_table("areas")
