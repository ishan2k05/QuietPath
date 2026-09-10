"""
Sensory Scoring Algorithm (Deterministic & Explainable)
Strictly Non-LLM Multi-Criteria Decision Analysis (MCDA).
Designed for QuietPath academic evaluation & production routing.
"""
from typing import Dict, List, Any
import numpy as np


class SensoryScorer:
    """
    Evaluates environmental sensory stimuli against user sensitivity profiles
    to produce deterministic, explainable route comfort scores.
    """

    FACTOR_KEYS = ["noise", "crowd", "traffic", "construction", "light", "air_quality"]

    @classmethod
    def normalize_weights(cls, raw_weights: Dict[str, float]) -> Dict[str, float]:
        """
        Normalizes weights so that their sum equals 1.0.
        If all weights are zero, uniform weights are assigned.
        """
        total = sum(raw_weights.get(k, 0.0) for k in cls.FACTOR_KEYS)
        if total <= 0:
            uniform = 1.0 / len(cls.FACTOR_KEYS)
            return {k: uniform for k in cls.FACTOR_KEYS}
        return {k: raw_weights.get(k, 0.0) / total for k in cls.FACTOR_KEYS}

    @classmethod
    def calculate_segment_penalty(
        cls,
        environmental_factors: Dict[str, float],
        normalized_weights: Dict[str, float],
    ) -> float:
        """
        Computes the weighted stimulus penalty for a single spatial segment.
        Each environmental factor is clamped in [0.0, 1.0].
        Penalty is in [0.0, 1.0].
        """
        penalty = 0.0
        for k in cls.FACTOR_KEYS:
            env_val = max(0.0, min(1.0, environmental_factors.get(k, 0.0)))
            weight = normalized_weights.get(k, 0.0)
            penalty += weight * env_val
        return float(np.clip(penalty, 0.0, 1.0))

    @classmethod
    def evaluate_route(
        cls,
        segments: List[Dict[str, Any]],
        user_weights: Dict[str, float],
        duration_minutes: float,
        fastest_duration_minutes: float,
        time_penalty_tolerance: float = 0.5,
    ) -> Dict[str, Any]:
        """
        Evaluates an entire candidate route across its segmented polyline.

        Parameters:
        - segments: List of dicts with 'distance_meters' and 'environmental_factors'.
        - user_weights: Dict of sensitivity weights (0.0 to 1.0).
        - duration_minutes: Duration of this route.
        - fastest_duration_minutes: Duration of the quickest alternative route.
        - time_penalty_tolerance: How willing the user is to accept longer travel times
          for sensory comfort (0.0 = time sensitive, 1.0 = highly comfort seeking).
        """
        norm_weights = cls.normalize_weights(user_weights)

        total_distance = sum(s.get("distance_meters", 100.0) for s in segments)
        if total_distance <= 0:
            total_distance = 1.0

        # Accumulate weighted penalties and factor contributions
        weighted_penalties = []
        distances = []
        factor_penalties = {k: 0.0 for k in cls.FACTOR_KEYS}

        for seg in segments:
            dist = seg.get("distance_meters", 100.0)
            env = seg.get("environmental_factors", {})
            seg_penalty = cls.calculate_segment_penalty(env, norm_weights)

            weighted_penalties.append(seg_penalty * dist)
            distances.append(dist)

            for k in cls.FACTOR_KEYS:
                val = max(0.0, min(1.0, env.get(k, 0.0)))
                factor_penalties[k] += val * dist * norm_weights[k]

        avg_penalty = sum(weighted_penalties) / total_distance

        # Sensory comfort score on 0 - 100 scale
        # 100 = perfectly calm / low stimuli, 0 = overwhelming stimuli
        raw_sensory_score = round(100.0 * (1.0 - avg_penalty), 1)

        # Time tradeoff adjustment
        time_diff = max(0.0, duration_minutes - fastest_duration_minutes)
        if fastest_duration_minutes > 0:
            time_excess_ratio = time_diff / fastest_duration_minutes
        else:
            time_excess_ratio = 0.0

        # Higher time_penalty_tolerance means less score deduction for extra time
        time_penalty_alpha = 25.0 * (1.0 - (time_penalty_tolerance * 0.7))
        time_score_deduction = round(time_excess_ratio * time_penalty_alpha, 1)

        final_score = round(max(0.0, min(100.0, raw_sensory_score - time_score_deduction)), 1)

        # Factor contributions for explainability breakdown
        total_factor_sum = sum(factor_penalties.values())
        factor_breakdown = {}
        for k in cls.FACTOR_KEYS:
            if total_factor_sum > 0:
                pct = round((factor_penalties[k] / total_factor_sum) * 100, 1)
            else:
                pct = 0.0
            factor_breakdown[k] = {
                "impact_percentage": pct,
                "weighted_stimulus": round(factor_penalties[k] / total_distance, 3),
            }

        # Generate human-readable badges based on dominant factors
        badges = []
        if raw_sensory_score >= 80:
            badges.append("Calmest Route")
        if factor_breakdown["noise"]["impact_percentage"] < 25:
            badges.append("Low Noise")
        if factor_breakdown["crowd"]["impact_percentage"] < 25:
            badges.append("Low Crowd")
        if factor_breakdown["traffic"]["impact_percentage"] < 25:
            badges.append("Low Traffic")

        return {
            "sensory_score": final_score,
            "raw_comfort_score": raw_sensory_score,
            "time_penalty_deduction": time_score_deduction,
            "duration_minutes": duration_minutes,
            "distance_meters": total_distance,
            "badges": badges,
            "factor_breakdown": factor_breakdown,
            "is_calmest": False,  # Tagged by route comparison service
            "is_fastest": (duration_minutes <= fastest_duration_minutes + 0.1),
        }
