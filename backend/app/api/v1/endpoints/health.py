from fastapi import APIRouter
from datetime import datetime

router = APIRouter()


@router.get("/health", tags=["System"])
def health_check():
    return {
        "status": "healthy",
        "app": "QuietPath API",
        "timestamp": datetime.utcnow().isoformat(),
        "deterministic_engine": "active",
    }
