import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.algorithms.sensory_scorer import SensoryScorer


def test_weight_normalization():
    raw = {"noise": 0.8, "crowd": 0.4, "traffic": 0.8, "construction": 0.0, "light": 0.0, "air_quality": 0.0}
    norm = SensoryScorer.normalize_weights(raw)
    assert abs(sum(norm.values()) - 1.0) < 1e-6
    assert norm["noise"] == 0.8 / 2.0
    assert norm["crowd"] == 0.4 / 2.0


def test_sensory_scoring_determinism():
    # Route with very high stimuli
    noisy_segments = [
        {"distance_meters": 1000, "environmental_factors": {"noise": 0.9, "crowd": 0.8, "traffic": 0.9, "construction": 0.9, "light": 0.7, "air_quality": 0.8}},
    ]
    # Route with low stimuli
    calm_segments = [
        {"distance_meters": 1000, "environmental_factors": {"noise": 0.1, "crowd": 0.1, "traffic": 0.05, "construction": 0.0, "light": 0.2, "air_quality": 0.15}},
    ]
    user_weights = {"noise": 0.9, "crowd": 0.8, "traffic": 0.7, "construction": 0.8, "light": 0.5, "air_quality": 0.5}

    eval_noisy = SensoryScorer.evaluate_route(
        segments=noisy_segments,
        user_weights=user_weights,
        duration_minutes=15.0,
        fastest_duration_minutes=15.0,
    )
    eval_calm = SensoryScorer.evaluate_route(
        segments=calm_segments,
        user_weights=user_weights,
        duration_minutes=18.0,
        fastest_duration_minutes=15.0,
        time_penalty_tolerance=0.8,
    )

    # Calm route should have significantly higher sensory score
    assert eval_calm["sensory_score"] > eval_noisy["sensory_score"]
    assert eval_calm["raw_comfort_score"] > 80.0
    assert eval_noisy["raw_comfort_score"] < 40.0
    # Factors should sum to ~100%
    breakdown = eval_calm["factor_breakdown"]
    total_pct = sum(v["impact_percentage"] for v in breakdown.values())
    assert abs(total_pct - 100.0) < 1.0


if __name__ == "__main__":
    test_weight_normalization()
    test_sensory_scoring_determinism()
    print("All algorithm tests passed!")
