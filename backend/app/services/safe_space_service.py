from typing import List
from app.schemas.safe_space import SafeSpace, SafeSpaceListResponse


class SafeSpaceService:
    # High fidelity places matching design mockup
    SAMPLE_SPACES = [
        SafeSpace(
            id="sp_1",
            name="Central Public Library",
            category="Library",
            distance_miles=0.3,
            capacity_percentage=25,
            capacity_status="Empty",
            feature_tags=["Silence Required", "Soft Seating"],
            quiet_zone_info="Quiet Zone: Floor 3",
            best_spot="Floor 3 North Corner",
            lat=12.9750,
            lng=77.5910,
        ),
        SafeSpace(
            id="sp_2",
            name="Botanical Gardens Conservatory",
            category="Park / Nature",
            distance_miles=0.8,
            capacity_percentage=40,
            capacity_status="Low",
            feature_tags=["Natural Environment", "White Noise (Fountain)"],
            quiet_zone_info=None,
            best_spot="Fern Room",
            lat=12.9790,
            lng=77.5870,
        ),
        SafeSpace(
            id="sp_3",
            name="Mute Coffee Shop",
            category="Cafe",
            distance_miles=1.2,
            capacity_percentage=69,
            capacity_status="Moderate",
            feature_tags=["Dim Lighting", "No Background Music"],
            quiet_zone_info="Dedicated Quiet Hour: Now",
            best_spot="Courtyard Bench",
            lat=12.9830,
            lng=77.5950,
        ),
    ]

    @classmethod
    def get_safe_spaces(cls) -> SafeSpaceListResponse:
        return SafeSpaceListResponse(
            total=len(cls.SAMPLE_SPACES),
            safe_spaces=cls.SAMPLE_SPACES,
        )
