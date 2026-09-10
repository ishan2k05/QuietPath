from typing import Optional
from app.algorithms.sensory_scorer import SensoryScorer
from app.schemas.route import RouteOption, RouteEvaluationResponse
from app.schemas.sensory_profile import SensoryProfileBase
from app.services.environmental_service import EnvironmentalService


class RouteService:
    @classmethod
    async def evaluate_routes(
        cls,
        origin: str,
        destination: str,
        profile: Optional[SensoryProfileBase] = None,
    ) -> RouteEvaluationResponse:
        # Default user profile weights if none provided
        if profile is None:
            user_weights = {
                "noise": 0.8,
                "crowd": 0.7,
                "traffic": 0.7,
                "construction": 0.8,
                "light": 0.5,
                "air_quality": 0.6,
            }
            time_tolerance = 0.6
        else:
            user_weights = {
                "noise": profile.noise_sensitivity,
                "crowd": profile.crowd_comfort,
                "traffic": profile.traffic_sensitivity,
                "construction": profile.construction_sensitivity,
                "light": profile.light_intensity,
                "air_quality": profile.air_quality_sensitivity,
            }
            time_tolerance = profile.time_penalty_tolerance

        # Fetch real-time AQI reading for the area
        aqi_data = await EnvironmentalService.get_air_quality(12.9763, 77.5929)
        live_aqi_penalty = aqi_data.get("stimulus_penalty", 0.35)

        # Query real-time active sensory hazards from database
        from datetime import datetime, timezone
        from app.core.database import SessionLocal
        from app.models.hazard import HazardModel

        active_hazards = []
        try:
            db = SessionLocal()
            now = datetime.now(timezone.utc)
            active_hazards = db.query(HazardModel).filter(HazardModel.expires_at > now).all()
            db.close()
        except Exception:
            pass

        # Calculate hazard penalty addition if nearby
        hazard_penalty = 0.0
        active_hazard_badge = None
        for h in active_hazards:
            hazard_penalty += (h.severity / 5.0) * 0.15
            if not active_hazard_badge:
                active_hazard_badge = f"Live Alert: {h.title}"

        # Route 1: Calmest Route (Parkside & shaded tree-lined lanes)
        calm_aqi_penalty = max(0.1, round(live_aqi_penalty * 0.7, 2))  # Trees buffer pollution
        calm_segments = [
            {"distance_meters": 600, "environmental_factors": {"noise": 0.15, "crowd": 0.20, "traffic": 0.10, "construction": 0.05, "light": 0.20, "air_quality": calm_aqi_penalty}},
            {"distance_meters": 900, "environmental_factors": {"noise": 0.10, "crowd": 0.15, "traffic": 0.05, "construction": 0.00, "light": 0.15, "air_quality": calm_aqi_penalty}},
            {"distance_meters": 700, "environmental_factors": {"noise": 0.25, "crowd": 0.30, "traffic": 0.20, "construction": 0.00, "light": 0.30, "air_quality": calm_aqi_penalty}},
            {"distance_meters": 200, "environmental_factors": {"noise": 0.20, "crowd": 0.25, "traffic": 0.15, "construction": 0.00, "light": 0.20, "air_quality": calm_aqi_penalty}},
        ]
        calm_eval = SensoryScorer.evaluate_route(
            segments=calm_segments,
            user_weights=user_weights,
            duration_minutes=16.0,
            fastest_duration_minutes=12.0,
            time_penalty_tolerance=time_tolerance,
        )

        # Route 2: Quickest Route (Main arterial roads & heavy commercial traffic + active hazards)
        fast_aqi_penalty = min(1.0, round(live_aqi_penalty * 1.3, 2))  # Exhaust on arterial roads
        base_const = min(1.0, 0.75 + hazard_penalty)
        fast_segments = [
            {"distance_meters": 700, "environmental_factors": {"noise": 0.85, "crowd": 0.70, "traffic": 0.90, "construction": base_const, "light": 0.80, "air_quality": fast_aqi_penalty}},
            {"distance_meters": 800, "environmental_factors": {"noise": 0.80, "crowd": 0.65, "traffic": 0.85, "construction": min(1.0, 0.80 + hazard_penalty), "light": 0.75, "air_quality": fast_aqi_penalty}},
            {"distance_meters": 600, "environmental_factors": {"noise": 0.75, "crowd": 0.60, "traffic": 0.70, "construction": 0.20, "light": 0.70, "air_quality": fast_aqi_penalty}},
        ]
        fast_eval = SensoryScorer.evaluate_route(
            segments=fast_segments,
            user_weights=user_weights,
            duration_minutes=12.0,
            fastest_duration_minutes=12.0,
            time_penalty_tolerance=time_tolerance,
        )

        calm_polyline = [
            [12.9763, 77.5929],
            [12.9785, 77.5912],
            [12.9810, 77.5898],
            [12.9835, 77.5885],
            [12.9860, 77.5892],
            [12.9880, 77.5910],
        ]
        fast_polyline = [
            [12.9763, 77.5929],
            [12.9780, 77.5960],
            [12.9820, 77.5950],
            [12.9850, 77.5935],
            [12.9880, 77.5910],
        ]

        route_1 = RouteOption(
            id="route_calmest",
            name="Calmest Route",
            duration_minutes=16,
            distance_km=2.4,
            sensory_score=calm_eval["sensory_score"],
            is_recommended=True,
            is_fastest=False,
            badges=["★ Recommended for You", "Low Noise", "Low Crowd", f"AQI: {aqi_data['aqi_index']} ({aqi_data['category']})"],
            factor_breakdown=calm_eval["factor_breakdown"],
            polyline_coords=calm_polyline,
            turn_instructions=[
                "Turn right onto Oak Trail (in 150m)",
                "Continue along Queen's Park Canopy (350m)",
                "Gentle left onto Lavender Walkway (800m)",
                "Arrive at destination safely",
            ],
        )

        route_2 = RouteOption(
            id="route_fastest",
            name="Quickest Route",
            duration_minutes=12,
            distance_km=2.1,
            sensory_score=fast_eval["sensory_score"],
            is_recommended=False,
            is_fastest=True,
            badges=["Quickest Route", "High Noise", "High Traffic"],
            factor_breakdown=fast_eval["factor_breakdown"],
            polyline_coords=fast_polyline,
            turn_instructions=[
                "Head north on Commercial Main Road",
                "Pass through Metro Construction Zone (High Noise)",
                "Turn right onto Expressway",
                "Arrive at destination",
            ],
        )

        return RouteEvaluationResponse(
            origin=origin,
            destination=destination,
            routes=[route_1, route_2],
        )
