from datetime import datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Uuid,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from firesafe_api.db.base import Base


class Asset(Base):
    __tablename__ = "assets"
    __table_args__ = (
        CheckConstraint("revision >= 1", name="ck_assets_revision_positive"),
        CheckConstraint(
            "lifecycle_state IN ('ACTIVE', 'ARCHIVED')",
            name="ck_assets_lifecycle_state",
        ),
        CheckConstraint("source = 'MANUAL'", name="ck_assets_source"),
        CheckConstraint(
            "((capacity_value IS NULL AND capacity_unit IS NULL) OR "
            "(capacity_value IS NOT NULL AND capacity_unit IS NOT NULL))",
            name="ck_assets_capacity_pair",
        ),
        CheckConstraint(
            "capacity_value IS NULL OR capacity_value > 0",
            name="ck_assets_capacity_value_positive",
        ),
        Index("ix_assets_area_id", "area_id"),
    )

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    area_id: Mapped[UUID] = mapped_column(
        Uuid,
        ForeignKey("areas.id", ondelete="RESTRICT"),
        nullable=False,
    )
    asset_code: Mapped[str] = mapped_column(String(40), nullable=False, unique=True)
    type: Mapped[str] = mapped_column(String(120), nullable=False)
    subtype: Mapped[str | None] = mapped_column(String(120), nullable=True)
    capacity_value: Mapped[Decimal | None] = mapped_column(Numeric(12, 3), nullable=True)
    capacity_unit: Mapped[str | None] = mapped_column(String(50), nullable=True)
    manufacturer: Mapped[str | None] = mapped_column(String(200), nullable=True)
    model: Mapped[str | None] = mapped_column(String(200), nullable=True)
    serial: Mapped[str | None] = mapped_column(String(200), nullable=True)
    location_text: Mapped[str | None] = mapped_column(String(500), nullable=True)
    lifecycle_state: Mapped[str] = mapped_column(
        String(32),
        nullable=False,
        server_default="ACTIVE",
    )
    source: Mapped[str] = mapped_column(String(32), nullable=False, server_default="MANUAL")
    revision: Mapped[int] = mapped_column(Integer, nullable=False, server_default="1")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )
