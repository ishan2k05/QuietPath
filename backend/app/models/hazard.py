from datetime import datetime, timezone, timedelta
from sqlalchemy import Column, String, Float, Integer, DateTime
from app.core.database import Base


class HazardModel(Base):
    __tablename__ = "sensory_hazards"

    id = Column(String, primary_key=True, index=True)
    hazard_type = Column(String, index=True)  # "noise", "crowd", "construction", "light", "air_quality"
    title = Column(String)
    description = Column(String, nullable=True)
    severity = Column(Integer, default=3)  # 1 to 5
    lat = Column(Float, index=True)
    lng = Column(Float, index=True)
    reported_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    expires_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc) + timedelta(hours=3),
    )
    upvotes = Column(Integer, default=1)
