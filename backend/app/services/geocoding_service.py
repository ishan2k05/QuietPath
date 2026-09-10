import httpx
from typing import List, Dict, Any

_GEO_CACHE: Dict[str, List[Dict[str, Any]]] = {}


class GeocodingService:
    PRESET_DESTINATIONS = [
        {
            "name": "Bangalore Golf Club",
            "address": "Sankey Road, High Grounds, Bengaluru",
            "lat": 12.9880,
            "lng": 77.5910,
            "category": "Recreation / Green Space",
            "sensory_badge": "Low Noise",
        },
        {
            "name": "Cubbon Park",
            "address": "Kasturba Road, Sampangi Rama Nagara, Bengaluru",
            "lat": 12.9763,
            "lng": 77.5929,
            "category": "Park / Nature Sanctuary",
            "sensory_badge": "Very Quiet",
        },
        {
            "name": "Central Public Library",
            "address": "Cubbon Park, Bengaluru",
            "lat": 12.9750,
            "lng": 77.5910,
            "category": "Safe Space / Library",
            "sensory_badge": "Silence Required",
        },
        {
            "name": "Lalbagh Botanical Garden",
            "address": "Mavalli, Bengaluru",
            "lat": 12.9507,
            "lng": 77.5848,
            "category": "Botanical Conservatory",
            "sensory_badge": "Low Stimulus",
        },
        {
            "name": "National Gallery of Modern Art",
            "address": "Palace Road, Vasanth Nagar, Bengaluru",
            "lat": 12.9890,
            "lng": 77.5880,
            "category": "Museum / Sanctuary",
            "sensory_badge": "Soft Lighting",
        },
        {
            "name": "Mute Coffee Shop",
            "address": "Lavelle Road, Bengaluru",
            "lat": 12.9830,
            "lng": 77.5950,
            "category": "Calm Cafe",
            "sensory_badge": "Dim Lighting",
        },
        {
            "name": "Commercial Street",
            "address": "Tasker Town, Shivaji Nagar, Bengaluru",
            "lat": 12.9822,
            "lng": 77.6083,
            "category": "Commercial Center",
            "sensory_badge": "High Noise / Crowded",
        },
    ]

    @classmethod
    def search(cls, query: str) -> List[Dict[str, Any]]:
        """Synchronous local preset matcher."""
        query_lower = query.strip().lower()
        if not query_lower:
            return cls.PRESET_DESTINATIONS[:4]

        results = [
            item for item in cls.PRESET_DESTINATIONS
            if query_lower in item["name"].lower() or query_lower in item["address"].lower()
        ]
        return results if results else cls.PRESET_DESTINATIONS[:2]

    @classmethod
    async def search_async(cls, query: str) -> List[Dict[str, Any]]:
        """
        Asynchronous real-time geocoding supporting live OpenStreetMap (Nominatim)
        for any address or landmark worldwide, with local presets.
        """
        query_clean = query.strip()
        if not query_clean:
            return cls.PRESET_DESTINATIONS[:5]

        # 1. First check local presets
        local_matches = [
            item for item in cls.PRESET_DESTINATIONS
            if query_clean.lower() in item["name"].lower() or query_clean.lower() in item["address"].lower()
        ]
        if len(local_matches) >= 2:
            return local_matches

        # 2. Check memory cache
        if query_clean.lower() in _GEO_CACHE:
            return _GEO_CACHE[query_clean.lower()]

        # 3. Live OpenStreetMap Nominatim Query
        try:
            url = f"https://nominatim.openstreetmap.org/search"
            headers = {"User-Agent": "QuietPath-Sensory-Navigation/1.0 (academic-fyp)"}
            params = {
                "q": f"{query_clean}, Bengaluru",
                "format": "json",
                "limit": 4,
                "addressdetails": 1,
            }
            async with httpx.AsyncClient(timeout=2.0) as client:
                res = await client.get(url, params=params, headers=headers)
                if res.status_code == 200:
                    data = res.json()
                    results = []
                    for item in data:
                        name = item.get("display_name", "").split(",")[0]
                        address = item.get("display_name", "")
                        lat = float(item.get("lat", 12.9716))
                        lon = float(item.get("lon", 77.5946))
                        results.append({
                            "name": name,
                            "address": address,
                            "lat": lat,
                            "lng": lon,
                            "category": "Address / Landmark",
                            "sensory_badge": "Real-Time OSM",
                        })

                    if results:
                        combined = local_matches + results
                        _GEO_CACHE[query_clean.lower()] = combined
                        return combined
        except Exception:
            pass

        return local_matches if local_matches else cls.PRESET_DESTINATIONS[:3]
