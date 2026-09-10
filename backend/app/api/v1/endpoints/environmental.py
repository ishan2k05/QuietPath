from fastapi import APIRouter, Query, Header
from typing import Optional
from app.services.environmental_service import EnvironmentalService

router = APIRouter()


@router.get("/live")
async def get_live_environmental_telemetry(
    lat: float = Query(12.9716, description="Latitude of location"),
    lng: float = Query(77.5946, description="Longitude of location"),
    x_waqi_key: Optional[str] = Header(None, alias="X-WAQI-Key", description="Optional WAQI API Key"),
):
    """
    Returns real-time environmental sensory telemetry:
    - Air Quality Index (AQI, PM2.5, PM10)
    - Solar & Weather Telemetry (UV index, temperature, solar glare penalty)
    - Deterministic sensory implications and gear recommendations
    """
    telemetry = await EnvironmentalService.get_environmental_telemetry(
        lat=lat,
        lng=lng,
        waqi_api_key=x_waqi_key,
    )
    return telemetry
