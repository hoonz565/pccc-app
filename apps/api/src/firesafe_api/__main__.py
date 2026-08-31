import asyncio
import sys

import uvicorn

from firesafe_api.core.config import get_settings


def selector_loop_factory(use_subprocess: bool = False) -> asyncio.AbstractEventLoop:
    del use_subprocess
    return asyncio.SelectorEventLoop()


def main() -> None:
    settings = get_settings()
    loop_factory = "auto"
    if sys.platform == "win32":
        loop_factory = "firesafe_api.__main__:selector_loop_factory"

    config = uvicorn.Config(
        "firesafe_api.main:app",
        host=settings.api_host,
        port=settings.api_port,
        loop=loop_factory,
    )
    uvicorn.Server(config).run()


if __name__ == "__main__":
    main()
