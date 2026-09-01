from datetime import datetime
from decimal import Decimal
from typing import Self
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

_EDITABLE_FIELDS = {
    "type",
    "subtype",
    "capacity_value",
    "capacity_unit",
    "manufacturer",
    "model",
    "serial",
    "location_text",
}


class _AssetProfileFields(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: str = Field(min_length=1, max_length=120)
    subtype: str | None = Field(default=None, max_length=120)
    capacity_value: Decimal | None = Field(
        default=None,
        gt=0,
        max_digits=12,
        decimal_places=3,
    )
    capacity_unit: str | None = Field(default=None, max_length=50)
    manufacturer: str | None = Field(default=None, max_length=200)
    model: str | None = Field(default=None, max_length=200)
    serial: str | None = Field(default=None, max_length=200)
    location_text: str | None = Field(default=None, max_length=500)

    @field_validator("type")
    @classmethod
    def normalize_required_string(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Field must not be blank")
        return normalized

    @field_validator(
        "subtype",
        "capacity_unit",
        "manufacturer",
        "model",
        "serial",
        "location_text",
    )
    @classmethod
    def normalize_optional_string(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None


class AssetCreateRequest(_AssetProfileFields):
    @model_validator(mode="after")
    def validate_capacity_pair(self) -> Self:
        if (self.capacity_value is None) != (self.capacity_unit is None):
            raise ValueError("capacity_value and capacity_unit must be provided together")
        return self


class AssetUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    base_revision: int = Field(ge=1)
    type: str | None = Field(default=None, max_length=120)
    subtype: str | None = Field(default=None, max_length=120)
    capacity_value: Decimal | None = Field(
        default=None,
        gt=0,
        max_digits=12,
        decimal_places=3,
    )
    capacity_unit: str | None = Field(default=None, max_length=50)
    manufacturer: str | None = Field(default=None, max_length=200)
    model: str | None = Field(default=None, max_length=200)
    serial: str | None = Field(default=None, max_length=200)
    location_text: str | None = Field(default=None, max_length=500)

    @field_validator(
        "type",
        "subtype",
        "capacity_unit",
        "manufacturer",
        "model",
        "serial",
        "location_text",
    )
    @classmethod
    def normalize_strings(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None

    @model_validator(mode="after")
    def validate_editable_fields(self) -> Self:
        if not (_EDITABLE_FIELDS & self.model_fields_set):
            raise ValueError("At least one editable Asset field is required")
        if "type" in self.model_fields_set and self.type is None:
            raise ValueError("type must not be blank")
        return self


class AssetResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: UUID
    area_id: UUID
    asset_code: str
    type: str
    subtype: str | None
    capacity_value: float | None
    capacity_unit: str | None
    manufacturer: str | None
    model: str | None
    serial: str | None
    location_text: str | None
    lifecycle_state: str
    source: str
    revision: int
    created_at: datetime
    updated_at: datetime
    operational_status: str | None = None
