import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient
from app.core.database import init_db
from app.main import app

init_db()
client = TestClient(app)

def test_health():
    res = client.get("/api/v1/health")
    assert res.status_code == 200
    assert res.json()["status"] == "healthy"

def test_routes():
    res = client.post("/api/v1/routes/evaluate", json={"origin": "Cubbon Park", "destination": "Bangalore Golf Club"})
    assert res.status_code == 200
    data = res.json()
    assert len(data["routes"]) == 2
    assert data["routes"][0]["name"] == "Calmest Route"
    assert data["routes"][0]["sensory_score"] > 75

def test_safe_spaces():
    res = client.get("/api/v1/places/safe-spaces")
    assert res.status_code == 200
    data = res.json()
    assert data["total"] >= 3

    # Test filtering by Low Noise
    res_filtered = client.get("/api/v1/places/safe-spaces?tag=Low Noise")
    assert res_filtered.status_code == 200
    data_filtered = res_filtered.json()
    assert data_filtered["total"] >= 1

def test_recommended_places():
    res = client.get("/api/v1/places/recommended?lat=12.9716&lng=77.5946&noise_tolerance=0.2&crowd_tolerance=0.2")
    assert res.status_code == 200
    data = res.json()
    assert data["total"] >= 1
    assert data["safe_spaces"][0]["sensory_match_score"] is not None
    # Verify sorted descending
    scores = [s["sensory_match_score"] for s in data["safe_spaces"]]
    assert scores == sorted(scores, reverse=True)


def test_search():
    res = client.get("/api/v1/search/autocomplete?q=Cubbon")
    assert res.status_code == 200
    results = res.json()
    assert len(results) >= 1
    assert "Cubbon" in results[0]["name"]


def test_hazards():
    # 1. Report a new sensory hazard
    payload = {
        "hazard_type": "construction",
        "title": "Drilling and Roadwork",
        "description": "Loud drilling work near entrance",
        "severity": 4,
        "lat": 12.9750,
        "lng": 77.5920,
        "duration_hours": 2,
    }
    res = client.post("/api/v1/hazards/", json=payload)
    assert res.status_code == 201
    data = res.json()
    assert data["title"] == "Drilling and Roadwork"
    assert data["hazard_type"] == "construction"
    assert data["upvotes"] == 1
    hazard_id = data["id"]

    # 2. Query active hazards
    res_list = client.get("/api/v1/hazards/active?lat=12.9750&lng=77.5920&radius_miles=5.0")
    assert res_list.status_code == 200
    list_data = res_list.json()
    assert list_data["total"] >= 1
    found = any(h["id"] == hazard_id for h in list_data["hazards"])
    assert found is True

    # 3. Upvote the hazard
    res_upvote = client.post(f"/api/v1/hazards/{hazard_id}/upvote")
    assert res_upvote.status_code == 200
    upvote_data = res_upvote.json()
    assert upvote_data["upvotes"] == 2


if __name__ == "__main__":
    test_health()
    test_routes()
    test_safe_spaces()
    test_recommended_places()
    test_search()
    test_hazards()
    print("All updated API endpoint tests passed successfully!")

