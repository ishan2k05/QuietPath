from typing import List, Dict, Any
from fastapi import APIRouter, Query
from app.services.geocoding_service import GeocodingService

router = APIRouter()


@router.get("/autocomplete", response_model=List[Dict[str, Any]], tags=["Search & Geocoding"])
async def autocomplete(q: str = Query("", max_length=150, description="Destination search query")):
    """
    Returns live destination suggestions and geocoded coordinates matching query via OpenStreetMap.
    """
    clean_q = q.strip()[:150]
    return await GeocodingService.search_async(clean_q)
