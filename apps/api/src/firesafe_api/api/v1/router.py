from fastapi import APIRouter

from firesafe_api.areas.router import router as areas_router
from firesafe_api.assets.router import router as assets_router
from firesafe_api.auth.router import router as auth_router
from firesafe_api.facilities.router import router as facilities_router
from firesafe_api.users.router import router as users_router

router = APIRouter(prefix="/api/v1")
router.include_router(auth_router)
router.include_router(users_router)
router.include_router(facilities_router)
router.include_router(areas_router)
router.include_router(assets_router)
