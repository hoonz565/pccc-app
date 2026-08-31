import httpx


async def test_registration_validation_does_not_echo_password(
    client: httpx.AsyncClient,
) -> None:
    password = "too-short"

    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "user@example.test",
            "password": password,
            "terms_accepted": True,
            "privacy_accepted": True,
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
    assert password not in response.text


async def test_registration_requires_explicit_consent(client: httpx.AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "user@example.test",
            "password": "a secure passphrase",
            "terms_accepted": False,
            "privacy_accepted": True,
        },
    )

    assert response.status_code == 422


async def test_registration_rejects_unexpected_fields(client: httpx.AsyncClient) -> None:
    response = await client.post(
        "/api/v1/auth/register",
        json={
            "email": "user@example.test",
            "password": "a secure passphrase",
            "terms_accepted": True,
            "privacy_accepted": True,
            "owner_user_id": "not-allowed",
        },
    )

    assert response.status_code == 422


async def test_login_validation_does_not_echo_password(
    client: httpx.AsyncClient,
) -> None:
    password = "not-valid-for-this-request"

    response = await client.post(
        "/api/v1/auth/login",
        json={
            "email": "not-an-email",
            "password": password,
            "unexpected": True,
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
    assert password not in response.text
