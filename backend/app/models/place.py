from sqlalchemy import Column, String, Float, Integer
from app.core.database import Base


class PlaceModel(Base):
    __tablename__ = "places"

    id = Column(String, primary_key=True, index=True)
    name = Column(String, index=True)
    category = Column(String, index=True)
    distance_miles = Column(Float, default=0.0)
    capacity_percentage = Column(Integer, default=0)
    capacity_status = Column(String, default="Low")
    feature_tags = Column(String, default="")  # Comma-separated tags
    quiet_zone_info = Column(String, nullable=True)
    best_spot = Column(String, nullable=True)
    lat = Column(Float, default=0.0)
    lng = Column(Float, default=0.0)
