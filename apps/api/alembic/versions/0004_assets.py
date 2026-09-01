"""Create manual Assets and attach Asset audit references.

Revision ID: 0004_assets
Revises: 0003_areas
Create Date: 2026-09-01
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0004_assets"
down_revision: str | Sequence[str] | None = "0003_areas"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "assets",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("area_id", sa.Uuid(), nullable=False),
        sa.Column("asset_code", sa.String(length=40), nullable=False),
        sa.Column("type", sa.String(length=120), nullable=False),
        sa.Column("subtype", sa.String(length=120), nullable=True),
        sa.Column("capacity_value", sa.Numeric(precision=12, scale=3), nullable=True),
        sa.Column("capacity_unit", sa.String(length=50), nullable=True),
        sa.Column("manufacturer", sa.String(length=200), nullable=True),
        sa.Column("model", sa.String(length=200), nullable=True),
        sa.Column("serial", sa.String(length=200), nullable=True),
        sa.Column("location_text", sa.String(length=500), nullable=True),
        sa.Column(
            "lifecycle_state",
            sa.String(length=32),
            server_default="ACTIVE",
            nullable=False,
        ),
        sa.Column("source", sa.String(length=32), server_default="MANUAL", nullable=False),
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
        sa.CheckConstraint("revision >= 1", name="ck_assets_revision_positive"),
        sa.CheckConstraint(
            "lifecycle_state IN ('ACTIVE', 'ARCHIVED')",
            name="ck_assets_lifecycle_state",
        ),
        sa.CheckConstraint("source = 'MANUAL'", name="ck_assets_source"),
        sa.CheckConstraint(
            "((capacity_value IS NULL AND capacity_unit IS NULL) OR "
            "(capacity_value IS NOT NULL AND capacity_unit IS NOT NULL))",
            name="ck_assets_capacity_pair",
        ),
        sa.CheckConstraint(
            "capacity_value IS NULL OR capacity_value > 0",
            name="ck_assets_capacity_value_positive",
        ),
        sa.ForeignKeyConstraint(["area_id"], ["areas.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("asset_code", name="uq_assets_asset_code"),
    )
    op.create_index("ix_assets_area_id", "assets", ["area_id"], unique=False)
    op.add_column("audit_events", sa.Column("asset_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_audit_events_asset_id_assets",
        "audit_events",
        "assets",
        ["asset_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_index(
        "ix_audit_events_asset_id",
        "audit_events",
        ["asset_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_audit_events_asset_id", table_name="audit_events")
    op.drop_constraint(
        "fk_audit_events_asset_id_assets",
        "audit_events",
        type_="foreignkey",
    )
    op.drop_column("audit_events", "asset_id")
    op.drop_index("ix_assets_area_id", table_name="assets")
    op.drop_table("assets")
