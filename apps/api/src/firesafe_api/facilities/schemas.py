from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class FacilityCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=200)
    type: str = Field(min_length=1, max_length=120)
    province: str = Field(min_length=1, max_length=120)
    address: str = Field(min_length=1, max_length=500)

    @field_validator("name", "type", "province", "address")
    @classmethod
    def strip_and_reject_blank(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Field must not be blank")
        return normalized


class FacilityResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: UUID
    name: str
    type: str
    province: str
    address: str
    revision: int
    created_at: datetime
    updated_at: datetime
