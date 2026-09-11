import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quietpath_flutter/core/network/api_client.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';

class EnvironmentalTelemetry {
  final int aqiIndex;
  final String aqiCategory;
  final double pm25;
  final double pm10;
  final double temperatureC;
  final String weatherCondition;
  final double uvIndex;
  final double compositePenalty;
  final List<String> sensoryImplications;
  final List<String> recommendedGear;

  const EnvironmentalTelemetry({
    required this.aqiIndex,
    required this.aqiCategory,
    required this.pm25,
    required this.pm10,
    required this.temperatureC,
    required this.weatherCondition,
    required this.uvIndex,
    required this.compositePenalty,
    required this.sensoryImplications,
    required this.recommendedGear,
  });

  factory EnvironmentalTelemetry.fromJson(Map<String, dynamic> json) {
    final aqi = json['aqi'] as Map<String, dynamic>? ?? {};
    final weather = json['weather'] as Map<String, dynamic>? ?? {};
    final implications =
        (json['sensory_implications'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final gear =
        (json['recommended_gear'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return EnvironmentalTelemetry(
      aqiIndex: (aqi['aqi_index'] as num?)?.toInt() ?? 52,
      aqiCategory: (aqi['category'] as String?) ?? 'Moderate',
      pm25: (aqi['pm2_5'] as num?)?.toDouble() ?? 16.2,
      pm10: (aqi['pm10'] as num?)?.toDouble() ?? 32.0,
      temperatureC: (weather['temperature_c'] as num?)?.toDouble() ?? 24.0,
      weatherCondition:
          (weather['weather_condition'] as String?) ?? 'Partly Cloudy',
      uvIndex: (weather['uv_index'] as num?)?.toDouble() ?? 3.0,
      compositePenalty:
          (json['composite_stimulus_penalty'] as num?)?.toDouble() ?? 0.25,
      sensoryImplications: implications,
      recommendedGear: gear,
    );
  }

  static const EnvironmentalTelemetry defaultTelemetry = EnvironmentalTelemetry(
    aqiIndex: 52,
    aqiCategory: 'Moderate',
    pm25: 16.2,
    pm10: 32.0,
    temperatureC: 24.0,
    weatherCondition: 'Partly Cloudy',
    uvIndex: 3.0,
    compositePenalty: 0.25,
    sensoryImplications: ['Air quality is suitable for calm navigation.'],
    recommendedGear: [],
  );
}

class SurroundingZone {
  final String id;
  final String name;
  final String type;
  final double lat;
  final double lng;
  final int aqi;
  final double temperatureC;
  final String condition;
  final String sensoryAdvantage;

  const SurroundingZone({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
    required this.aqi,
    required this.temperatureC,
    required this.condition,
    required this.sensoryAdvantage,
  });

  factory SurroundingZone.fromJson(Map<String, dynamic> json) {
    return SurroundingZone(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'green_canopy',
      lat: (json['lat'] as num?)?.toDouble() ?? 12.9763,
      lng: (json['lng'] as num?)?.toDouble() ?? 77.5929,
      aqi: (json['aqi'] as num?)?.toInt() ?? 45,
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 24.0,
      condition: json['condition'] as String? ?? 'Calm Micro-climate',
      sensoryAdvantage: json['sensory_advantage'] as String? ?? '',
    );
  }
}

class SurroundingsTelemetry {
  final EnvironmentalTelemetry current;
  final List<SurroundingZone> zones;

  const SurroundingsTelemetry({
    required this.current,
    required this.zones,
  });

  static final defaultSurroundings = SurroundingsTelemetry(
    current: EnvironmentalTelemetry.defaultTelemetry,
    zones: [
      const SurroundingZone(
        id: 'cubbon_canopy',
        name: 'Cubbon Park Sanctuary',
        type: 'green_canopy',
        lat: 12.9763,
        lng: 77.5929,
        aqi: 45,
        temperatureC: 24.2,
        condition: 'Cooled by Bamboo & Mahogany Canopy',
        sensoryAdvantage: 'Dense tree canopy absorbs fine particulates (PM2.5) and shields from sunlight.',
      ),
      const SurroundingZone(
        id: 'ulsoor_lake',
        name: 'Ulsoor Lake Promenade',
        type: 'water_promenade',
        lat: 12.9825,
        lng: 77.6205,
        aqi: 48,
        temperatureC: 24.8,
        condition: 'Fresh Lake Breeze',
        sensoryAdvantage: 'Evaporative cooling and open water air circulation reduce heat stress.',
      ),
      const SurroundingZone(
        id: 'golf_green',
        name: 'Bangalore Golf Club Green Corridor',
        type: 'green_canopy',
        lat: 12.9890,
        lng: 77.5850,
        aqi: 42,
        temperatureC: 24.5,
        condition: 'Open Grassland & Tall Pines',
        sensoryAdvantage: 'Minimal traffic exhaust, low ambient particulate density.',
      ),
      const SurroundingZone(
        id: 'mg_road_corridor',
        name: 'MG Road Commercial Corridor',
        type: 'urban_heat_island',
        lat: 12.9750,
        lng: 77.6080,
        aqi: 78,
        temperatureC: 27.5,
        condition: 'Urban Concrete & Vehicle Exhaust',
        sensoryAdvantage: 'High vehicle emissions and reflective concrete surfaces create localized heat island.',
      ),
    ],
  );
}

final environmentalTelemetryProvider = FutureProvider<EnvironmentalTelemetry>((
  ref,
) async {
  final userLoc = ref.watch(userLocationProvider);
  try {
    final dio = ApiClient().dio;
    final res = await dio.get(
      '/environmental/live',
      queryParameters: {'lat': userLoc.latitude, 'lng': userLoc.longitude},
    );
    if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
      return EnvironmentalTelemetry.fromJson(res.data as Map<String, dynamic>);
    }
  } catch (_) {
    // Graceful offline fallback
  }
  return EnvironmentalTelemetry.defaultTelemetry;
});

final surroundingsTelemetryProvider = FutureProvider<SurroundingsTelemetry>((
  ref,
) async {
  final userLoc = ref.watch(userLocationProvider);
  try {
    final dio = ApiClient().dio;
    final res = await dio.get(
      '/environmental/surroundings',
      queryParameters: {'lat': userLoc.latitude, 'lng': userLoc.longitude},
    );
    if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
      final curData = res.data['current'] as Map<String, dynamic>? ?? {};
      final rawZones = res.data['surrounding_zones'] as List<dynamic>? ?? [];
      return SurroundingsTelemetry(
        current: EnvironmentalTelemetry.fromJson(curData),
        zones: rawZones.map((z) => SurroundingZone.fromJson(z as Map<String, dynamic>)).toList(),
      );
    }
  } catch (_) {
    // Graceful offline fallback
  }
  return SurroundingsTelemetry.defaultSurroundings;
});
