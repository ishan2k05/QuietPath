from fastapi import APIRouter, Query, Header
from typing import Optional
from app.services.environmental_service import EnvironmentalService

router = APIRouter()


@router.get("/live")
async def get_live_environmental_telemetry(
    lat: float = Query(12.9716, ge=-90.0, le=90.0, description="Latitude of location (-90 to 90)"),
    lng: float = Query(77.5946, ge=-180.0, le=180.0, description="Longitude of location (-180 to 180)"),
    x_waqi_key: Optional[str] = Header(None, alias="X-WAQI-Key", max_length=128, description="Optional WAQI API Key"),
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


@router.get("/surroundings")
async def get_live_surroundings_telemetry(
    lat: float = Query(12.9716, ge=-90.0, le=90.0, description="Latitude of location (-90 to 90)"),
    lng: float = Query(77.5946, ge=-180.0, le=180.0, description="Longitude of location (-180 to 180)"),
    x_waqi_key: Optional[str] = Header(None, alias="X-WAQI-Key", max_length=128, description="Optional WAQI API Key"),
):
    """
    Returns real-time environmental sensory telemetry for current location
    along with surrounding micro-climates (green canopies, water breezes, urban corridors).
    """
    return await EnvironmentalService.get_surroundings_telemetry(
        lat=lat,
        lng=lng,
        waqi_api_key=x_waqi_key,
    )
