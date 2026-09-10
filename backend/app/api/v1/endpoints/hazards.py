import math
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.hazard import HazardModel
from app.schemas.hazard import HazardCreate, HazardResponse, HazardListResponse

router = APIRouter()


def _compute_distance_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 3958.8
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


@router.post("/", response_model=HazardResponse, status_code=status.HTTP_201_CREATED, tags=["Sensory Hazards"])
def report_hazard(
    hazard_in: HazardCreate,
    db: Session = Depends(get_db),
):
    """
    Submit a real-time sensory incident/hazard to alert nearby users and trigger route re-scoring.
    """
    now = datetime.now(timezone.utc)
    duration = hazard_in.duration_hours or 3
    expires = now + timedelta(hours=duration)

    hazard = HazardModel(
        id=f"hz_{uuid.uuid4().hex[:8]}",
        hazard_type=hazard_in.hazard_type.lower(),
        title=hazard_in.title,
        description=hazard_in.description,
        severity=hazard_in.severity,
        lat=hazard_in.lat,
        lng=hazard_in.lng,
        reported_at=now,
        expires_at=expires,
        upvotes=1,
    )
    db.add(hazard)
    db.commit()
    db.refresh(hazard)
    return hazard


@router.get("/active", response_model=HazardListResponse, tags=["Sensory Hazards"])
def list_active_hazards(
    lat: Optional[float] = Query(None, description="Center latitude"),
    lng: Optional[float] = Query(None, description="Center longitude"),
    radius_miles: float = Query(10.0, description="Radius in miles to filter hazards"),
    hazard_type: Optional[str] = Query(None, description="Optional filter by hazard type"),
    db: Session = Depends(get_db),
):
    """
    Returns currently active, unexpired sensory hazard reports within search radius.
    """
    now = datetime.now(timezone.utc)
    query = db.query(HazardModel).filter(HazardModel.expires_at > now)

    if hazard_type:
        query = query.filter(HazardModel.hazard_type == hazard_type.lower())

    hazards = query.order_by(HazardModel.reported_at.desc()).all()

    if lat is not None and lng is not None:
        filtered = [
            h for h in hazards
            if _compute_distance_miles(lat, lng, h.lat, h.lng) <= radius_miles
        ]
        return HazardListResponse(total=len(filtered), hazards=filtered)

    return HazardListResponse(total=len(hazards), hazards=hazards)


@router.post("/{hazard_id}/upvote", response_model=HazardResponse, tags=["Sensory Hazards"])
def upvote_hazard(
    hazard_id: str,
    db: Session = Depends(get_db),
):
    """
    Community confirmation: upvoting increases credibility and extends expiry by 30 minutes.
    """
    hazard = db.query(HazardModel).filter(HazardModel.id == hazard_id).first()
    if not hazard:
        raise HTTPException(status_code=404, detail="Sensory hazard not found")

    hazard.upvotes += 1
    # Extend expiry slightly upon confirmation
    if hazard.expires_at:
        hazard.expires_at = hazard.expires_at + timedelta(minutes=30)

    db.commit()
    db.refresh(hazard)
    return hazard
