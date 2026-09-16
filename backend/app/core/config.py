import os
from typing import List
from pydantic import BaseModel


def _get_cors_origins() -> List[str]:
    cors_env = os.getenv("CORS_ORIGINS")
    if cors_env:
        return [origin.strip() for origin in cors_env.split(",") if origin.strip()]
    return [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8000",
        "http://127.0.0.1",
        "http://127.0.0.1:8000",
        "http://10.0.2.2",
        "http://10.0.2.2:8000",
    ]


class Settings(BaseModel):
    PROJECT_NAME: str = "QuietPath API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    DEBUG: bool = os.getenv("DEBUG", "True").lower() in ("true", "1", "yes")

    SECRET_KEY: str = os.getenv("SECRET_KEY", "quietpath-academic-dev-key-change-in-prod")

    CORS_ORIGINS: List[str] = _get_cors_origins()

    GOOGLE_MAPS_API_KEY: str = os.getenv("GOOGLE_MAPS_API_KEY", "")
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./quietpath.db")


settings = Settings()
