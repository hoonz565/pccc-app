from firesafe_api.users.models import User
from firesafe_api.users.schemas import UserResponse


def build_user_response(user: User) -> UserResponse:
    return UserResponse(
        id=user.id,
        email=user.email_normalized,
        terms_version=user.terms_version,
        terms_accepted_at=user.terms_accepted_at,
        privacy_version=user.privacy_version,
        privacy_accepted_at=user.privacy_accepted_at,
        created_at=user.created_at,
    )
