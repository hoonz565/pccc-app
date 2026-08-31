import asyncio
import logging
import sys
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import FastAPI, Request, Response

from firesafe_api.api.errors import register_error_handlers
from firesafe_api.api.routes.operational import router as operational_router
from firesafe_api.api.v1.router import router as v1_router
from firesafe_api.core.config import get_settings
from firesafe_api.db.session import create_database_engine, create_database_session_factory

logger = logging.getLogger(__name__)

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())


@asynccontextmanager
async def lifespan(application: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    engine = create_database_engine(settings.database_url)
    application.state.database_engine = engine
    application.state.database_session_factory = create_database_session_factory(engine)
    try:
        yield
    finally:
        await engine.dispose()


def create_app() -> FastAPI:
    application = FastAPI(title="FireSafe API", version="0.1.0", lifespan=lifespan)
    register_error_handlers(application)

    @application.middleware("http")
    async def add_request_context(
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        request_id = str(uuid4())
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        logger.info(
            "request_id=%s method=%s path=%s status=%s",
            request_id,
            request.method,
            request.url.path,
            response.status_code,
        )
        return response

    application.include_router(operational_router)
    application.include_router(v1_router)
    return application


app = create_app()
