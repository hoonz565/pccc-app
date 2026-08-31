import asyncio
import sys
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from firesafe_api.api.routes.operational import router as operational_router
from firesafe_api.api.v1.router import router as v1_router
from firesafe_api.core.config import get_settings
from firesafe_api.db.session import create_database_engine

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())


@asynccontextmanager
async def lifespan(application: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    engine = create_database_engine(settings.database_url)
    application.state.database_engine = engine
    try:
        yield
    finally:
        await engine.dispose()


def create_app() -> FastAPI:
    application = FastAPI(title="FireSafe API", version="0.1.0", lifespan=lifespan)
    application.include_router(operational_router)
    application.include_router(v1_router)
    return application


app = create_app()
