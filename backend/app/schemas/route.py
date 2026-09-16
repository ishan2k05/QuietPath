from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
from app.schemas.sensory_profile import SensoryProfileBase


class RouteEvaluateRequest(BaseModel):
    origin: str = Field("Cubbon Park Metro", min_length=1, max_length=200, description="Starting point or coordinates")
    destination: str = Field("Bangalore Golf Club", min_length=1, max_length=200, description="Destination or coordinates")
    origin_lat: Optional[float] = Field(None, ge=-90.0, le=90.0, description="Starting latitude coordinate (-90 to 90)")
    origin_lng: Optional[float] = Field(None, ge=-180.0, le=180.0, description="Starting longitude coordinate (-180 to 180)")
    dest_lat: Optional[float] = Field(None, ge=-90.0, le=90.0, description="Destination latitude coordinate (-90 to 90)")
    dest_lng: Optional[float] = Field(None, ge=-180.0, le=180.0, description="Destination longitude coordinate (-180 to 180)")
    profile: Optional[SensoryProfileBase] = None


class RouteOption(BaseModel):
    id: str
    name: str  # "Calmest Route", "Quickest Route"
    duration_minutes: int
    distance_km: float
    sensory_score: float  # 0 to 100
    is_recommended: bool
    is_fastest: bool
    badges: List[str]
    factor_breakdown: Dict[str, Any]
    polyline_coords: List[List[float]]  # [[lat, lng], ...]
    turn_instructions: List[str]


class RouteEvaluationResponse(BaseModel):
    origin: str
    destination: str
    routes: List[RouteOption]
