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
            PlaceModel(
                id="sp_pune_1",
                name="Osho Teerth Bamboo Sanctuary",
                category="Park / Nature",
                distance_miles=0.5,
                capacity_percentage=18,
                capacity_status="Empty",
                feature_tags="Silence Required,Natural Environment,Dense Canopy",
                quiet_zone_info="Zen Bamboo Grove",
                best_spot="Stream Shaded Pavilion",
                lat=18.5362,
                lng=73.8941,
            ),
            PlaceModel(
                id="sp_pune_2",
                name="Empress Botanical Garden",
                category="Botanical Garden",
                distance_miles=0.8,
                capacity_percentage=35,
                capacity_status="Low",
                feature_tags="Natural Environment,White Noise (Fountain),Shaded Trees",
                quiet_zone_info="Heritage Banyan Lawn",
                best_spot="Canopy Pavilion",
                lat=18.5135,
                lng=73.8916,
            ),
            PlaceModel(
                id="sp_pune_3",
                name="Vetal Tekdi Hilltop Nature Refuge",
                category="Nature Reserve",
                distance_miles=1.2,
                capacity_percentage=15,
                capacity_status="Empty",
                feature_tags="Silence Required,Natural Environment,Zero Traffic",
                quiet_zone_info="Forest Trail Crest",
                best_spot="Sunrise Stone Outcrop",
                lat=18.5284,
                lng=73.8182,
            ),
            PlaceModel(
                id="sp_pune_4",
                name="Pu La Deshpande Tranquility Garden",
                category="Zen Garden",
                distance_miles=1.6,
                capacity_percentage=25,
                capacity_status="Low",
                feature_tags="Silence Required,Water White Noise,Natural Landscape",
                quiet_zone_info="Koi Pond & Water Stream",
                best_spot="Wooden Meditation Bridge",
                lat=18.4912,
                lng=73.8344,
            ),
            PlaceModel(
                id="sp_pune_5",
                name="British Council Silent Reading Room",
                category="Library",
                distance_miles=0.9,
                capacity_percentage=28,
                capacity_status="Low",
                feature_tags="Silence Required,Soft Seating,Air Conditioned",
                quiet_zone_info="Silent Reading Floor 2",
                best_spot="North Study Carrel",
                lat=18.5298,
                lng=73.8443,
            ),
            PlaceModel(
                id="sp_pune_6",
                name="Saras Baug Lakeside Sanctuary",
                category="Park / Nature",
                distance_miles=1.4,
                capacity_percentage=32,
                capacity_status="Low",
                feature_tags="Water White Noise,Natural Environment,Lawn Seating",
                quiet_zone_info="Lake Perimeter Lawn",
                best_spot="Lotus Pond Shaded Gazebo",
                lat=18.5009,
                lng=73.8540,
            ),
            PlaceModel(
                id="sp_pune_7",
                name="Pune University Heritage Woodlands",
                category="Park / Nature",
                distance_miles=2.1,
                capacity_percentage=20,
                capacity_status="Empty",
                feature_tags="Dense Canopy,Silence Required,Low Crowd",
                quiet_zone_info="Eucalyptus Woods Trail",
                best_spot="Old Heritage Quad",
                lat=18.5529,
                lng=73.8246,
            ),
            PlaceModel(
                id="sp_pune_8",
                name="Aga Khan Palace Memorial Lawns",
                category="Museum / Gallery",
                distance_miles=2.4,
                capacity_percentage=22,
                capacity_status="Empty",
                feature_tags="Soft Lighting,Silence Required,Expansive Lawns",
                quiet_zone_info="Rear Cloister Memorial Walk",
                best_spot="Samadhi Heritage Lawn",
                lat=18.5524,
                lng=73.9015,
            ),
        ]
        new_places = [p for p in initial_places if p.id not in existing_ids]
        if new_places:
            db.add_all(new_places)
            db.commit()
    finally:
        db.close()
