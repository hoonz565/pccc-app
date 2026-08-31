import logging
from typing import Literal

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncEngine

from firesafe_api.db.health import check_database

logger = logging.getLogger(__name__)
router = APIRouter(tags=["operations"])


class HealthResponse(BaseModel):
    status: Literal["ok"]


class ReadyResponse(BaseModel):
    status: Literal["ready"]
    database: Literal["connected"]


@router.get("/health", response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(status="ok")


@router.get(
    "/ready",
    response_model=ReadyResponse,
    responses={503: {"description": "PostgreSQL is unavailable"}},
)
async def ready(request: Request) -> ReadyResponse | JSONResponse:
    engine: AsyncEngine = request.app.state.database_engine
    try:
        await check_database(engine)
    except Exception as exc:
        logger.warning("Database readiness check failed: %s", type(exc).__name__)
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "database": "unavailable"},
        )

    return ReadyResponse(status="ready", database="connected")
