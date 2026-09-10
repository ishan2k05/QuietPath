import time
import os
import httpx
from typing import Dict, Any, Optional

_TELEMETRY_CACHE: Dict[str, Dict[str, Any]] = {}
CACHE_TTL_SECONDS = 600  # 10 minutes cache to prevent rate limits


class EnvironmentalService:
    @classmethod
    async def get_air_quality(cls, lat: float, lng: float) -> Dict[str, Any]:
        """
        Backward-compatible helper returning AQI data.
        """
        telemetry = await cls.get_environmental_telemetry(lat, lng)
        return telemetry.get("aqi", {
            "aqi_index": 52,
            "category": "Moderate",
            "pm2_5": 16.2,
            "pm10": 32.0,
            "stimulus_penalty": 0.28,
            "source": "baseline",
        })

    @classmethod
    async def get_environmental_telemetry(
        cls,
        lat: float,
        lng: float,
        waqi_api_key: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Fetches live multi-sensor environmental telemetry:
        1. AQI, PM2.5, PM10 (Open-Meteo Air Quality API or WAQI if key provided)
        2. UV Index, Solar Irradiance, Temperature (Open-Meteo Weather Forecast API)
        Computes deterministic sensory penalties for neurodivergent navigators.
        """
        cache_key = f"{round(lat, 2)},{round(lng, 2)}"
        now = time.time()

        if cache_key in _TELEMETRY_CACHE:
            cached = _TELEMETRY_CACHE[cache_key]
            if now - cached["timestamp"] < CACHE_TTL_SECONDS:
                return cached["data"]

        # Default calm baseline for Bangalore urban area
        aqi_payload = {
            "aqi_index": 52,
            "category": "Moderate",
            "pm2_5": 16.2,
            "pm10": 32.0,
            "stimulus_penalty": 0.28,
            "source": "baseline",
        }

        weather_payload = {
            "temperature_c": 24.5,
            "uv_index": 3.2,
            "apparent_temperature_c": 25.0,
            "weather_condition": "Clear / Part-Cloudy",
            "solar_glare_penalty": 0.15,
            "source": "baseline",
        }

        token = waqi_api_key or os.getenv("WAQI_API_KEY")

        # 1. Fetch Air Quality (Open-Meteo Air Quality or WAQI)
        try:
            if token:
                waqi_url = f"https://api.waqi.info/feed/geo:{lat};{lng}/?token={token}"
                async with httpx.AsyncClient(timeout=3.0) as client:
                    w_res = await client.get(waqi_url)
                    if w_res.status_code == 200 and w_res.json().get("status") == "ok":
                        w_data = w_res.json().get("data", {})
                        waqi_val = w_data.get("aqi", 52)
                        iaqi = w_data.get("iaqi", {})
                        pm25 = iaqi.get("pm25", {}).get("v", 16.0)
                        pm10 = iaqi.get("pm10", {}).get("v", 32.0)
                        penalty = min(1.0, max(0.05, waqi_val / 200.0))
                        cat = "Good" if waqi_val <= 50 else ("Moderate" if waqi_val <= 100 else "Unhealthy for Sensitive")
                        aqi_payload = {
                            "aqi_index": int(waqi_val),
                            "category": cat,
                            "pm2_5": float(pm25),
                            "pm10": float(pm10),
                            "stimulus_penalty": round(penalty, 2),
                            "source": "waqi-live",
                        }
            if aqi_payload["source"] == "baseline":
                om_url = (
                    f"https://air-quality-api.open-meteo.com/v1/air-quality"
                    f"?latitude={lat}&longitude={lng}&current=pm10,pm2_5,european_aqi,us_aqi"
                )
                async with httpx.AsyncClient(timeout=3.0) as client:
                    res = await client.get(om_url)
                    if res.status_code == 200:
                        payload = res.json()
                        current = payload.get("current", {})
                        pm25 = current.get("pm2_5", 16.2)
                        pm10 = current.get("pm10", 32.0)
                        us_aqi = current.get("us_aqi", 52)
                        penalty = min(1.0, max(0.05, us_aqi / 200.0))
                        cat = "Good" if us_aqi <= 50 else ("Moderate" if us_aqi <= 100 else "Unhealthy for Sensitive")
                        aqi_payload = {
                            "aqi_index": int(us_aqi),
                            "category": cat,
                            "pm2_5": float(pm25),
                            "pm10": float(pm10),
                            "stimulus_penalty": round(penalty, 2),
                            "source": "open-meteo-live",
                        }
        except Exception:
            pass

        # 2. Fetch Solar & Weather Telemetry (Open-Meteo Weather)
        try:
            wx_url = (
                f"https://api.open-meteo.com/v1/forecast"
                f"?latitude={lat}&longitude={lng}&current=temperature_2m,apparent_temperature,uv_index,weather_code"
            )
            async with httpx.AsyncClient(timeout=3.0) as client:
                res = await client.get(wx_url)
                if res.status_code == 200:
                    payload = res.json()
                    current = payload.get("current", {})
                    temp = current.get("temperature_2m", 24.5)
                    apparent_temp = current.get("apparent_temperature", 25.0)
                    uv = current.get("uv_index", 3.2)
                    wcode = current.get("weather_code", 0)

                    # Interpret weather condition code
                    w_cond = "Clear / Sunny" if wcode == 0 else ("Partly Cloudy" if wcode in [1, 2, 3] else "Cloudy / Overcast")
                    if wcode in [51, 53, 55, 61, 63, 65]:
                        w_cond = "Rain / Showers"

                    # Calculate solar glare / heat stress penalty for light-sensitive individuals
                    # UV > 6 or Temp > 30C increases sensory fatigue
                    glare_penalty = min(1.0, max(0.05, (uv / 10.0) * 0.6 + max(0.0, (temp - 25.0) / 20.0) * 0.4))

                    weather_payload = {
                        "temperature_c": float(temp),
                        "apparent_temperature_c": float(apparent_temp),
                        "uv_index": float(uv),
                        "weather_condition": w_cond,
                        "solar_glare_penalty": round(glare_penalty, 2),
                        "source": "open-meteo-weather",
                    }
        except Exception:
            pass

        # Recommendations for sensory comfort
        sensory_implications = []
        gear = []
        if aqi_payload["aqi_index"] > 100:
            sensory_implications.append("High airborne particulates detected; favor park sanctuaries with tree canopy.")
            gear.append("Sensory Mask / Respirator")
        else:
            sensory_implications.append("Air quality is calm and suitable for sensory walks.")

        if weather_payload["uv_index"] > 5.0:
            sensory_implications.append("High solar glare; prefer shaded tree-lined avenues.")
            gear.append("Sunglasses / Tinted Glasses")

        combined = {
            "latitude": lat,
            "longitude": lng,
            "aqi": aqi_payload,
            "weather": weather_payload,
            "composite_stimulus_penalty": round(
                aqi_payload["stimulus_penalty"] * 0.6 + weather_payload["solar_glare_penalty"] * 0.4, 2
            ),
            "sensory_implications": sensory_implications,
            "recommended_gear": gear,
        }

        _TELEMETRY_CACHE[cache_key] = {"data": combined, "timestamp": now}
        return combined
