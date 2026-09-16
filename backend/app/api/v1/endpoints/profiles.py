from datetime import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.sensory_profile import SensoryProfileModel
from app.schemas.sensory_profile import (
    SensoryProfileCreate,
    SensoryProfileResponse,
)

router = APIRouter()


@router.post("/", response_model=SensoryProfileResponse, tags=["Sensory Profiles"])
def save_sensory_profile(profile_in: SensoryProfileCreate, db: Session = Depends(get_db)):
    user_id = profile_in.user_id or "demo_user"
    existing = db.query(SensoryProfileModel).filter(SensoryProfileModel.user_id == user_id).first()

    if not existing:
        existing = SensoryProfileModel(user_id=user_id)
        db.add(existing)

    existing.noise_sensitivity = profile_in.noise_sensitivity
    existing.crowd_comfort = profile_in.crowd_comfort
    existing.light_intensity = profile_in.light_intensity
    existing.traffic_sensitivity = profile_in.traffic_sensitivity
    existing.construction_sensitivity = profile_in.construction_sensitivity
    existing.air_quality_sensitivity = profile_in.air_quality_sensitivity
    existing.time_penalty_tolerance = profile_in.time_penalty_tolerance
    existing.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(existing)

    return SensoryProfileResponse(
        user_id=existing.user_id,
        noise_sensitivity=existing.noise_sensitivity,
        crowd_comfort=existing.crowd_comfort,
        light_intensity=existing.light_intensity,
        traffic_sensitivity=existing.traffic_sensitivity,
        construction_sensitivity=existing.construction_sensitivity,
        air_quality_sensitivity=existing.air_quality_sensitivity,
        time_penalty_tolerance=existing.time_penalty_tolerance,
        updated_at=existing.updated_at.isoformat() if existing.updated_at else None,
    )


@router.get("/me", response_model=SensoryProfileResponse, tags=["Sensory Profiles"])
def get_my_sensory_profile(
    user_id: str = Query("demo_user", min_length=1, max_length=64, pattern=r"^[a-zA-Z0-9_\-]+$"),
    db: Session = Depends(get_db),
):
    existing = db.query(SensoryProfileModel).filter(SensoryProfileModel.user_id == user_id).first()
    if existing:
        return SensoryProfileResponse(
            user_id=existing.user_id,
            noise_sensitivity=existing.noise_sensitivity,
            crowd_comfort=existing.crowd_comfort,
            light_intensity=existing.light_intensity,
            traffic_sensitivity=existing.traffic_sensitivity,
            construction_sensitivity=existing.construction_sensitivity,
            air_quality_sensitivity=existing.air_quality_sensitivity,
            time_penalty_tolerance=existing.time_penalty_tolerance,
            updated_at=existing.updated_at.isoformat() if existing.updated_at else None,
        )

    # Return default baseline
    return SensoryProfileResponse(
        user_id=user_id,
        noise_sensitivity=0.8,
        crowd_comfort=0.7,
        light_intensity=0.5,
        traffic_sensitivity=0.7,
        construction_sensitivity=0.8,
        air_quality_sensitivity=0.6,
        time_penalty_tolerance=0.6,
        updated_at=datetime.utcnow().isoformat(),
    )
