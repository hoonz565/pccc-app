from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict


class UserResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: UUID
    email: str
    terms_version: str
    terms_accepted_at: datetime
    privacy_version: str
    privacy_accepted_at: datetime
    created_at: datetime
