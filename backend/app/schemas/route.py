from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
from app.schemas.sensory_profile import SensoryProfileBase


class RouteEvaluateRequest(BaseModel):
    origin: str = Field("Cubbon Park Metro", description="Starting point or coordinates")
    destination: str = Field("Bangalore Golf Club", description="Destination or coordinates")
    origin_lat: Optional[float] = Field(None, description="Starting latitude coordinate")
    origin_lng: Optional[float] = Field(None, description="Starting longitude coordinate")
    dest_lat: Optional[float] = Field(None, description="Destination latitude coordinate")
    dest_lng: Optional[float] = Field(None, description="Destination longitude coordinate")
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
