from typing import Optional
from pydantic import BaseModel, Field


class SensoryProfileBase(BaseModel):
    noise_sensitivity: float = Field(0.8, ge=0.0, le=1.0, description="0=Tolerate loud, 1=Prefer quiet")
    crowd_comfort: float = Field(0.7, ge=0.0, le=1.0, description="0=Busy is OK, 1=Prefer empty")
    light_intensity: float = Field(0.5, ge=0.0, le=1.0, description="0=Bright/Daylight, 1=Dim/Soft")
    traffic_sensitivity: float = Field(0.7, ge=0.0, le=1.0, description="0=Tolerate traffic, 1=Low traffic")
    construction_sensitivity: float = Field(0.8, ge=0.0, le=1.0, description="0=Tolerate construction, 1=Avoid construction")
    air_quality_sensitivity: float = Field(0.6, ge=0.0, le=1.0, description="0=Tolerate low AQI, 1=Clean air")
    time_penalty_tolerance: float = Field(0.6, ge=0.0, le=1.0, description="Willingness to add minutes for comfort")


class SensoryProfileCreate(SensoryProfileBase):
    user_id: Optional[str] = "demo_user"


class SensoryProfileResponse(SensoryProfileBase):
    user_id: str
    updated_at: Optional[str] = None
