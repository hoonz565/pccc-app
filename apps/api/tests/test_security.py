from datetime import UTC, datetime, timedelta
from uuid import uuid4

import jwt
from pydantic import SecretStr

from firesafe_api.core.security import (
    create_access_token,
    create_refresh_token,
    decode_access_token,
    digest_refresh_token,
    hash_password,
    verify_password,
)


def test_password_is_argon2id_hash_and_verifies() -> None:
    password = "a secure passphrase"

    password_hash = hash_password(password)

    assert password_hash.startswith("$argon2id$")
    assert password not in password_hash
    assert verify_password(password, password_hash)
    assert not verify_password("wrong password", password_hash)


def test_refresh_token_has_256_bits_of_entropy_and_only_digest_is_stable() -> None:
    refresh_token = create_refresh_token()

    assert len(refresh_token) >= 43
    assert len(digest_refresh_token(refresh_token)) == 64
    assert refresh_token not in digest_refresh_token(refresh_token)


def test_access_token_contains_only_required_identity_claims() -> None:
    user_id = uuid4()
    session_id = uuid4()
    secret = SecretStr("test-signing-secret-with-at-least-32-characters")

    token = create_access_token(
        user_id=user_id,
        session_id=session_id,
        signing_secret=secret,
        lifetime_minutes=15,
    )

    assert decode_access_token(token, secret).user_id == user_id
    payload = jwt.decode(token, secret.get_secret_value(), algorithms=["HS256"])
    assert set(payload) == {"sub", "sid", "iat", "exp"}


def test_expired_access_token_is_rejected() -> None:
    secret = SecretStr("test-signing-secret-with-at-least-32-characters")
    token = create_access_token(
        user_id=uuid4(),
        session_id=uuid4(),
        signing_secret=secret,
        lifetime_minutes=1,
        now=datetime.now(UTC) - timedelta(minutes=2),
    )

    try:
        decode_access_token(token, secret)
    except jwt.ExpiredSignatureError:
        pass
    else:
        raise AssertionError("Expired access token was accepted")
