from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class HazardCreate(BaseModel):
    hazard_type: str = Field(
        ...,
        min_length=2,
        max_length=40,
        pattern=r"^[a-zA-Z_\-\s]+$",
        description="Type of sensory hazard: noise, crowd, construction, light, air_quality",
    )
    title: str = Field(..., min_length=3, max_length=120, description="Short title describing the stimulus hazard")
    description: Optional[str] = Field(None, max_length=1000, description="Additional context or details")
    severity: int = Field(3, ge=1, le=5, description="Severity rating 1 (mild) to 5 (extreme distress)")
    lat: float = Field(..., ge=-90.0, le=90.0, description="Latitude coordinate between -90 and 90")
    lng: float = Field(..., ge=-180.0, le=180.0, description="Longitude coordinate between -180 and 180")
    duration_hours: Optional[int] = Field(3, ge=1, le=24, description="Expected duration in hours (1-24) before auto-expiry")


class HazardResponse(BaseModel):
    id: str
    hazard_type: str
    title: str
    description: Optional[str] = None
    severity: int
    lat: float
    lng: float
    reported_at: datetime
    expires_at: datetime
    upvotes: int

    class Config:
        from_attributes = True


class HazardListResponse(BaseModel):
    total: int
    hazards: List[HazardResponse]
