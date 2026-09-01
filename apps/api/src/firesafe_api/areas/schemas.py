from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


class AreaCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=200)

    @field_validator("name")
    @classmethod
    def strip_and_reject_blank(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Field must not be blank")
        return normalized


class AreaResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: UUID
    facility_id: UUID
    name: str
    revision: int
    created_at: datetime
    updated_at: datetime
