from typing import Annotated

from fastapi import APIRouter, Depends

from firesafe_api.auth.dependencies import get_current_user
from firesafe_api.users.models import User
from firesafe_api.users.schemas import UserResponse
from firesafe_api.users.service import build_user_response

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserResponse)
async def current_user(
    user: Annotated[User, Depends(get_current_user)],
) -> UserResponse:
    return build_user_response(user)
