import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.database import init_db, SessionLocal
from app.models.place import PlaceModel
from app.models.sensory_profile import SensoryProfileModel
from app.services.geocoding_service import GeocodingService


def test_database_and_seeding():
    init_db()
    db = SessionLocal()
    try:
        places = db.query(PlaceModel).all()
        assert len(places) >= 3
        names = [p.name for p in places]
        assert "Central Public Library" in names
        assert "Botanical Gardens Conservatory" in names
        assert "Mute Coffee Shop" in names
        print("Database seeding verified!")

        # Test profile save
        profile = SensoryProfileModel(
            user_id="test_user_42",
            noise_sensitivity=0.9,
            crowd_comfort=0.8,
            light_intensity=0.7,
        )
        db.merge(profile)
        db.commit()

        loaded = db.query(SensoryProfileModel).filter(SensoryProfileModel.user_id == "test_user_42").first()
        assert loaded is not None
        assert loaded.noise_sensitivity == 0.9
        print("Sensory profile ORM persistence verified!")
    finally:
        db.close()


def test_geocoding_service():
    results = GeocodingService.search("Golf")
    assert len(results) >= 1
    assert "Golf" in results[0]["name"]
    print("Geocoding autocomplete verified!")


if __name__ == "__main__":
    test_database_and_seeding()
    test_geocoding_service()
    print("All database & service tests passed successfully!")
