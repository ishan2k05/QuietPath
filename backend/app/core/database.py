import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from app.core.config import settings

# If using sqlite, configure check_same_thread=False
connect_args = {}
if settings.DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
    echo=False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    from app.models.user import User  # noqa
    from app.models.sensory_profile import SensoryProfileModel  # noqa
    from app.models.place import PlaceModel  # noqa
    from app.models.hazard import HazardModel  # noqa

    Base.metadata.create_all(bind=engine)

    # Seed initial safe spaces if none exist
    db = SessionLocal()
    try:
        existing_ids = {p.id for p in db.query(PlaceModel.id).all()}
        initial_places = [
            PlaceModel(
                id="sp_1",
                name="Central Public Library",
                category="Library",
                distance_miles=0.3,
                capacity_percentage=25,
                capacity_status="Empty",
                feature_tags="Silence Required,Soft Seating",
                quiet_zone_info="Quiet Zone: Floor 3",
                best_spot="Floor 3 North Corner",
                lat=12.9750,
                lng=77.5910,
            ),
            PlaceModel(
                id="sp_2",
                name="Botanical Gardens Conservatory",
                category="Park / Nature",
                distance_miles=0.8,
                capacity_percentage=40,
                capacity_status="Low",
                feature_tags="Natural Environment,White Noise (Fountain)",
                quiet_zone_info="Natural Canopy",
                best_spot="Fern Room",
                lat=12.9790,
                lng=77.5870,
            ),
            PlaceModel(
                id="sp_3",
                name="Mute Coffee Shop",
                category="Cafe",
                distance_miles=1.2,
                capacity_percentage=69,
                capacity_status="Moderate",
                feature_tags="Dim Lighting,No Background Music",
                quiet_zone_info="Dedicated Quiet Hour: Now",
                best_spot="Courtyard Bench",
                lat=12.9830,
                lng=77.5950,
            ),
            PlaceModel(
                id="sp_4",
                name="Cubbon Park Bamboo Grove",
                category="Park / Nature",
                distance_miles=0.4,
                capacity_percentage=15,
                capacity_status="Empty",
                feature_tags="Silence Required,Natural Environment,Dense Canopy",
                quiet_zone_info="Inner Grove Sanctuary",
                best_spot="Bamboo Shaded Pavilion",
                lat=12.9760,
                lng=77.5925,
            ),
            PlaceModel(
                id="sp_5",
                name="National Gallery of Modern Art",
                category="Museum / Gallery",
                distance_miles=1.1,
                capacity_percentage=30,
                capacity_status="Low",
                feature_tags="Soft Lighting,Silence Required,Air Conditioned",
                quiet_zone_info="Sculpture Garden & Gallery 2",
                best_spot="Heritage Wing Courtyard",
                lat=12.9890,
                lng=77.5880,
            ),
            PlaceModel(
                id="sp_6",
                name="Atta Galatta Reading Corner",
                category="Bookstore / Cafe",
                distance_miles=1.8,
                capacity_percentage=35,
                capacity_status="Low",
                feature_tags="Dim Lighting,Soft Seating,Herbal Tea Sanctuary",
                quiet_zone_info="Mezzanine Reading Room",
                best_spot="Window Alcove Bench",
                lat=12.9340,
                lng=77.6210,
            ),
            PlaceModel(
                id="sp_7",
                name="Sankey Tank Quiet Promenade",
                category="Lake / Nature",
                distance_miles=2.3,
                capacity_percentage=22,
                capacity_status="Empty",
                feature_tags="Water White Noise,Natural Environment,Shaded Benches",
                quiet_zone_info="North Forest Walkway",
                best_spot="Waterfront Stone Benches",
                lat=13.0080,
                lng=77.5730,
            ),
        ]
        new_places = [p for p in initial_places if p.id not in existing_ids]
        if new_places:
            db.add_all(new_places)
            db.commit()
    finally:
        db.close()
