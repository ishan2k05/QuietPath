import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_security_headers_present():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    headers = response.headers
    assert headers.get("x-content-type-options") == "nosniff"
    assert headers.get("x-frame-options") == "DENY"
    assert headers.get("x-xss-protection") == "1; mode=block"
    assert headers.get("referrer-policy") == "strict-origin-when-cross-origin"
    print("Security headers test PASSED!")


def test_invalid_coordinates_rejected():
    # Lat > 90 should return 422
    bad_hazard = {
        "hazard_type": "noise",
        "title": "Loud Drilling",
        "severity": 4,
        "lat": 150.0,
        "lng": 77.59,
        "duration_hours": 3,
    }
    res = client.post("/api/v1/hazards/", json=bad_hazard)
    assert res.status_code == 422, f"Expected 422 for lat=150.0, got {res.status_code}"

    # Lng < -180 should return 422
    bad_hazard_lng = {
        "hazard_type": "noise",
        "title": "Loud Drilling",
        "severity": 4,
        "lat": 12.97,
        "lng": -250.0,
        "duration_hours": 3,
    }
    res2 = client.post("/api/v1/hazards/", json=bad_hazard_lng)
    assert res2.status_code == 422, f"Expected 422 for lng=-250.0, got {res2.status_code}"
    print("Invalid coordinates rejection test PASSED!")


def test_string_length_and_pattern_limits():
    # Title too short (<3)
    bad_title = {
        "hazard_type": "noise",
        "title": "ab",
        "severity": 3,
        "lat": 12.97,
        "lng": 77.59,
    }
    res = client.post("/api/v1/hazards/", json=bad_title)
    assert res.status_code == 422

    # Title too long (>120)
    bad_long_title = {
        "hazard_type": "noise",
        "title": "A" * 150,
        "severity": 3,
        "lat": 12.97,
        "lng": 77.59,
    }
    res_long = client.post("/api/v1/hazards/", json=bad_long_title)
    assert res_long.status_code == 422
    print("String length bounds test PASSED!")


def test_anti_tampering_upvote_deduplication():
    # Create valid hazard
    valid_hazard = {
        "hazard_type": "noise",
        "title": "Sudden Leaf Blower",
        "severity": 3,
        "lat": 18.5204,
        "lng": 73.8567,
        "duration_hours": 2,
    }
    create_res = client.post("/api/v1/hazards/", json=valid_hazard)
    assert create_res.status_code == 201
    hazard_id = create_res.json()["id"]

    # First upvote succeeds
    upvote_1 = client.post(f"/api/v1/hazards/{hazard_id}/upvote")
    assert upvote_1.status_code == 200

    # Immediate second upvote from same client IP must be rejected with 429
    upvote_2 = client.post(f"/api/v1/hazards/{hazard_id}/upvote")
    assert upvote_2.status_code == 429
    assert "already confirmed" in upvote_2.json()["detail"].lower()
    print("Anti-tampering duplicate upvote prevention test PASSED!")


def test_recommended_places_bounds():
    # Lat > 90
    bad_res = client.get("/api/v1/places/recommended?lat=120.0&lng=77.59")
    assert bad_res.status_code == 422

    # Negative radius
    bad_rad = client.get("/api/v1/places/recommended?lat=12.97&lng=77.59&radius_miles=-5.0")
    assert bad_rad.status_code == 422

    # Out-of-bound tolerance (>1.0)
    bad_tol = client.get("/api/v1/places/recommended?lat=12.97&lng=77.59&noise_tolerance=1.5")
    assert bad_tol.status_code == 422

    print("Recommended places bounds validation test PASSED!")


if __name__ == "__main__":
    test_security_headers_present()
    test_invalid_coordinates_rejected()
    test_string_length_and_pattern_limits()
    test_anti_tampering_upvote_deduplication()
    test_recommended_places_bounds()
    print("ALL SECURITY AND ANTI-TAMPERING TESTS PASSED!")

