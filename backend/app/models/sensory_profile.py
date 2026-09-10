from datetime import datetime
from sqlalchemy import Column, String, Float, DateTime
from app.core.database import Base


class SensoryProfileModel(Base):
    __tablename__ = "sensory_profiles"

    user_id = Column(String, primary_key=True, index=True)
    noise_sensitivity = Column(Float, default=0.8)
    crowd_comfort = Column(Float, default=0.7)
    light_intensity = Column(Float, default=0.5)
    traffic_sensitivity = Column(Float, default=0.7)
    construction_sensitivity = Column(Float, default=0.8)
    air_quality_sensitivity = Column(Float, default=0.6)
    time_penalty_tolerance = Column(Float, default=0.6)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
