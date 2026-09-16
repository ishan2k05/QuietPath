import math
import uuid
from datetime import datetime, timezone, timedelta
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
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


_UPVOTE_REGISTRY: dict = {}
_MAX_UPVOTES = 250
_MAX_EXPIRY_HOURS = 48


@router.get("/active", response_model=HazardListResponse, tags=["Sensory Hazards"])
def list_active_hazards(
    lat: Optional[float] = Query(None, ge=-90.0, le=90.0, description="Center latitude (-90 to 90)"),
    lng: Optional[float] = Query(None, ge=-180.0, le=180.0, description="Center longitude (-180 to 180)"),
    radius_miles: float = Query(10.0, ge=0.1, le=100.0, description="Radius in miles (0.1 to 100)"),
    hazard_type: Optional[str] = Query(None, max_length=40, description="Optional filter by hazard type"),
    db: Session = Depends(get_db),
):
    """
    Returns currently active, unexpired sensory hazard reports within search radius.
    """
    now = datetime.now(timezone.utc)
    query = db.query(HazardModel).filter(HazardModel.expires_at > now)

    if hazard_type:
        query = query.filter(HazardModel.hazard_type == hazard_type.strip().lower())

    hazards = query.order_by(HazardModel.reported_at.desc()).limit(100).all()

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
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Community confirmation: upvoting increases credibility and extends expiry by 30 minutes.
    Anti-tampering: Limits 1 upvote per IP/hazard per hour and caps maximum hazard lifetime to 48 hours.
    """
    if len(hazard_id) > 64:
        raise HTTPException(status_code=400, detail="Invalid hazard ID format")

    hazard = db.query(HazardModel).filter(HazardModel.id == hazard_id).first()
    if not hazard:
        raise HTTPException(status_code=404, detail="Sensory hazard not found")

    forwarded = request.headers.get("X-Forwarded-For")
    client_ip = forwarded.split(",")[0].strip() if forwarded else (request.client.host if request.client else "unknown")
    voter_key = f"{client_ip}:{hazard_id}"
    now_epoch = datetime.now(timezone.utc).timestamp()

    if voter_key in _UPVOTE_REGISTRY:
        if now_epoch - _UPVOTE_REGISTRY[voter_key] < 3600.0:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="You have already confirmed this sensory hazard recently. Thank you for your contribution.",
            )

    _UPVOTE_REGISTRY[voter_key] = now_epoch

    # Bound upvotes to prevent integer overflow or artificial vote bloating
    if hazard.upvotes < _MAX_UPVOTES:
        hazard.upvotes += 1

    # Extend expiry slightly upon confirmation, bounded to max lifetime from report time
    if hazard.expires_at and hazard.reported_at:
        max_expiry = hazard.reported_at + timedelta(hours=_MAX_EXPIRY_HOURS)
        extended = hazard.expires_at + timedelta(minutes=30)
        hazard.expires_at = min(max_expiry, extended)

    db.commit()
    db.refresh(hazard)
    return hazard
