from fastapi import APIRouter
from app.api.v1.endpoints import health, profiles, routes, places, search, hazards, environmental

api_router = APIRouter()

api_router.include_router(health.router)
api_router.include_router(profiles.router, prefix="/profiles")
api_router.include_router(routes.router, prefix="/routes")
api_router.include_router(places.router, prefix="/places")
api_router.include_router(search.router, prefix="/search")
api_router.include_router(hazards.router, prefix="/hazards")
api_router.include_router(environmental.router, prefix="/environmental")
