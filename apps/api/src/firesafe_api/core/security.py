import hashlib
import secrets
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import UUID

import jwt
from argon2 import PasswordHasher, Type
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from pydantic import SecretStr

JWT_ALGORITHM = "HS256"
_password_hasher = PasswordHasher(type=Type.ID)


@dataclass(frozen=True)
class AccessTokenClaims:
    user_id: UUID
    session_id: UUID


def hash_password(password: str) -> str:
    return _password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _password_hasher.verify(password_hash, password)
    except (InvalidHashError, VerificationError, VerifyMismatchError):
        return False


def create_refresh_token() -> str:
    return secrets.token_urlsafe(32)


def digest_refresh_token(refresh_token: str) -> str:
    return hashlib.sha256(refresh_token.encode("utf-8")).hexdigest()


def create_access_token(
    *,
    user_id: UUID,
    session_id: UUID,
    signing_secret: SecretStr,
    lifetime_minutes: int,
    now: datetime | None = None,
) -> str:
    issued_at = now or datetime.now(UTC)
    return jwt.encode(
        {
            "sub": str(user_id),
            "sid": str(session_id),
            "iat": issued_at,
            "exp": issued_at + timedelta(minutes=lifetime_minutes),
        },
        signing_secret.get_secret_value(),
        algorithm=JWT_ALGORITHM,
    )


def decode_access_token(token: str, signing_secret: SecretStr) -> AccessTokenClaims:
    payload = jwt.decode(
        token,
        signing_secret.get_secret_value(),
        algorithms=[JWT_ALGORITHM],
        options={"require": ["sub", "sid", "iat", "exp"]},
    )
    return AccessTokenClaims(
        user_id=UUID(payload["sub"]),
        session_id=UUID(payload["sid"]),
    )
