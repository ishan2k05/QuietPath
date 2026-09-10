from typing import List, Optional
from pydantic import BaseModel


class SafeSpace(BaseModel):
    id: str
    name: str
    category: str
    distance_miles: float
    capacity_percentage: int
    capacity_status: str  # "Empty", "Low", "Moderate", "High"
    feature_tags: List[str]
    quiet_zone_info: Optional[str] = None
    best_spot: Optional[str] = None
    lat: float
    lng: float
    sensory_match_score: Optional[int] = None


class SafeSpaceListResponse(BaseModel):
    total: int
    safe_spaces: List[SafeSpace]
