from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine


def create_database_engine(database_url: str) -> AsyncEngine:
    return create_async_engine(
        database_url,
        connect_args={"connect_timeout": 3},
        pool_pre_ping=True,
        pool_timeout=3,
    )
