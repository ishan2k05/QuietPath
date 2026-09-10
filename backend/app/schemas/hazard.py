from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field


class HazardCreate(BaseModel):
    hazard_type: str = Field(..., description="Type of sensory hazard: noise, crowd, construction, light, air_quality")
    title: str = Field(..., description="Short title describing the stimulus hazard")
    description: Optional[str] = Field(None, description="Additional context or details")
    severity: int = Field(3, ge=1, le=5, description="Severity rating 1 (mild) to 5 (extreme distress)")
    lat: float = Field(..., description="Latitude coordinate")
    lng: float = Field(..., description="Longitude coordinate")
    duration_hours: Optional[int] = Field(3, ge=1, le=12, description="Expected duration in hours before auto-expiry")


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
