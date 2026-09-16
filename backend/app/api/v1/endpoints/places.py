import math
from typing import Optional, List
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.place import PlaceModel
from app.schemas.safe_space import SafeSpace, SafeSpaceListResponse

from app.services.overpass_service import OverpassService

router = APIRouter()


def _compute_distance_miles(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Haversine distance calculation in miles."""
    if lat1 == 0.0 or lon1 == 0.0 or lat2 == 0.0 or lon2 == 0.0:
        return 0.5
    R = 3958.8  # Earth radius in miles
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return round(R * c, 2)


def _compute_sensory_match_score(
    capacity_pct: int,
    feature_tags: List[str],
    dist_miles: float,
    noise_tol: float = 0.3,
    crowd_tol: float = 0.3,
    light_tol: float = 0.4,
) -> int:
    """
    Deterministic MCDA calculation of sensory match score for academic defense.
    No LLM involved.
    """
    # Sensitivity weights (inversely proportional to user tolerance)
    w_crowd = max(0.1, 1.0 - crowd_tol)
    w_noise = max(0.1, 1.0 - noise_tol)
    w_light = max(0.1, 1.0 - light_tol)
    total_w = w_crowd + w_noise + w_light

    nw_crowd = w_crowd / total_w
    nw_noise = w_noise / total_w
    nw_light = w_light / total_w

    # Attribute costs [0, 1]
    crowd_cost = capacity_pct / 100.0

    tags_joined = " ".join(feature_tags).lower()
    if "silence" in tags_joined:
        noise_cost = 0.08
    elif "natural" in tags_joined or "water" in tags_joined or "canopy" in tags_joined:
        noise_cost = 0.16
    elif "no background music" in tags_joined:
        noise_cost = 0.22
    else:
        noise_cost = 0.40

    if "dim lighting" in tags_joined or "soft" in tags_joined:
        light_cost = 0.10
    else:
        light_cost = 0.32

    dist_cost = min(1.0, dist_miles / 5.0) * 0.15

    discomfort = (nw_crowd * crowd_cost + nw_noise * noise_cost + nw_light * light_cost) * 0.85 + dist_cost
    score = int(round((1.0 - discomfort) * 100))
    return max(55, min(98, score))


@router.get("/safe-spaces", response_model=SafeSpaceListResponse, tags=["Safe Spaces"])
async def list_safe_spaces(
    tag: Optional[str] = Query(None, max_length=50, description="Filter by feature or sensory tag"),
    lat: Optional[float] = Query(None, ge=-90.0, le=90.0, description="User latitude (-90 to 90)"),
    lng: Optional[float] = Query(None, ge=-180.0, le=180.0, description="User longitude (-180 to 180)"),
    db: Session = Depends(get_db),
):
    """
    Returns nearby verified low-stimulation venues with dynamic OpenStreetMap Overpass discovery.
    """
    query = db.query(PlaceModel)
    if tag and tag.lower() != "all" and tag.lower() != "filters":
        clean_tag = tag.strip()[:50]
        if clean_tag.lower() == "low noise":
            query = query.filter(
                (PlaceModel.feature_tags.ilike("%silence%"))
                | (PlaceModel.feature_tags.ilike("%natural%"))
                | (PlaceModel.feature_tags.ilike("%quiet%"))
            )
        elif clean_tag.lower() == "low crowd":
            query = query.filter(PlaceModel.capacity_status.in_(["Empty", "Low"]))
        else:
            escaped_tag = clean_tag.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
            query = query.filter(PlaceModel.feature_tags.ilike(f"%{escaped_tag}%"))

    places = query.all()
    results = []
    nearby_db_count = 0
    for p in places:
        dist = p.distance_miles
        if lat is not None and lng is not None and p.lat != 0.0:
            calc_d = _compute_distance_miles(lat, lng, p.lat, p.lng)
            if calc_d > 0.05:
                dist = calc_d
            if calc_d <= 25.0:
                nearby_db_count += 1
            else:
                continue  # Exclude distant cities when user GPS is specified

        tags = [t.strip() for t in p.feature_tags.split(",") if t.strip()]
        match_score = _compute_sensory_match_score(p.capacity_percentage, tags, dist)

        results.append(
            SafeSpace(
                id=p.id,
                name=p.name,
                category=p.category,
                distance_miles=dist,
                capacity_percentage=p.capacity_percentage,
                capacity_status=p.capacity_status,
                feature_tags=tags,
                quiet_zone_info=p.quiet_zone_info,
                best_spot=p.best_spot,
                lat=p.lat,
                lng=p.lng,
                sensory_match_score=match_score,
            )
        )

    # Dynamic global discovery: if few local sanctuaries exist near user coordinates, query Overpass
    if lat is not None and lng is not None and nearby_db_count < 3:
        try:
            osm_spaces = await OverpassService.fetch_nearby_safe_spaces(lat, lng)
            if osm_spaces:
                # Apply tag filter if present
                if tag and tag.lower() != "all" and tag.lower() != "filters":
                    t_low = tag.lower()
                    osm_filtered = [
                        s for s in osm_spaces
                        if any(t_low in ft.lower() for ft in s.feature_tags)
                        or (t_low == "low noise" and any("silence" in ft.lower() or "natural" in ft.lower() for ft in s.feature_tags))
                        or (t_low == "low crowd" and s.capacity_status in ["Empty", "Low"])
                    ]
                    results = osm_filtered + results
                else:
                    results = osm_spaces + results
        except Exception:
            pass

    # Resilient fallback: if no local or OSM sanctuaries were discovered, show seeded sample places
    if not results:
        for p in places[:5]:
            tags = [t.strip() for t in p.feature_tags.split(",") if t.strip()]
            results.append(
                SafeSpace(
                    id=p.id,
                    name=p.name,
                    category=p.category,
                    distance_miles=p.distance_miles,
                    capacity_percentage=p.capacity_percentage,
                    capacity_status=p.capacity_status,
                    feature_tags=tags,
                    quiet_zone_info=p.quiet_zone_info,
                    best_spot=p.best_spot,
                    lat=p.lat,
                    lng=p.lng,
                    sensory_match_score=85,
                )
            )

    # Sort nearest places first so user always sees local sanctuaries
    if lat is not None and lng is not None:
        results.sort(key=lambda s: (s.distance_miles, -(s.sensory_match_score or 0)))

    return SafeSpaceListResponse(
        total=len(results),
        safe_spaces=results,
    )


@router.get("/recommended", response_model=SafeSpaceListResponse, tags=["Safe Spaces"])
def get_recommended_places(
    lat: float = Query(12.9716, ge=-90.0, le=90.0, description="User latitude (-90 to 90)"),
    lng: float = Query(77.5946, ge=-180.0, le=180.0, description="User longitude (-180 to 180)"),
    radius_miles: float = Query(10.0, ge=0.1, le=100.0, description="Search radius in miles (0.1 to 100)"),
    noise_tolerance: float = Query(0.3, ge=0.0, le=1.0, description="User noise tolerance 0-1"),
    crowd_tolerance: float = Query(0.3, ge=0.0, le=1.0, description="User crowd tolerance 0-1"),
    light_tolerance: float = Query(0.4, ge=0.0, le=1.0, description="User light tolerance 0-1"),
    db: Session = Depends(get_db),
):
    """
    Ranks safe spaces using Multi-Criteria Decision Analysis (MCDA) tailored to the user's sensory profile.
    """
    places = db.query(PlaceModel).all()
    candidates = []

    for p in places:
        dist = _compute_distance_miles(lat, lng, p.lat, p.lng)
        if dist > radius_miles:
            continue

        tags = [t.strip() for t in p.feature_tags.split(",") if t.strip()]
        score = _compute_sensory_match_score(
            p.capacity_percentage,
            tags,
            dist,
            noise_tol=noise_tolerance,
            crowd_tol=crowd_tolerance,
            light_tol=light_tolerance,
        )

        candidates.append(
            SafeSpace(
                id=p.id,
                name=p.name,
                category=p.category,
                distance_miles=dist,
                capacity_percentage=p.capacity_percentage,
                capacity_status=p.capacity_status,
                feature_tags=tags,
                quiet_zone_info=p.quiet_zone_info,
                best_spot=p.best_spot,
                lat=p.lat,
                lng=p.lng,
                sensory_match_score=score,
            )
        )

    # Sort descending by sensory match score
    candidates.sort(key=lambda s: s.sensory_match_score or 0, reverse=True)

    return SafeSpaceListResponse(
        total=len(candidates),
        safe_spaces=candidates,
    )
