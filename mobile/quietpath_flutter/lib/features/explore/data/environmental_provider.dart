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
    final implications = (json['sensory_implications'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final gear = (json['recommended_gear'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return EnvironmentalTelemetry(
      aqiIndex: (aqi['aqi_index'] as num?)?.toInt() ?? 52,
      aqiCategory: (aqi['category'] as String?) ?? 'Moderate',
      pm25: (aqi['pm2_5'] as num?)?.toDouble() ?? 16.2,
      pm10: (aqi['pm10'] as num?)?.toDouble() ?? 32.0,
      temperatureC: (weather['temperature_c'] as num?)?.toDouble() ?? 24.0,
      weatherCondition: (weather['weather_condition'] as String?) ?? 'Partly Cloudy',
      uvIndex: (weather['uv_index'] as num?)?.toDouble() ?? 3.0,
      compositePenalty: (json['composite_stimulus_penalty'] as num?)?.toDouble() ?? 0.25,
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

final environmentalTelemetryProvider = FutureProvider<EnvironmentalTelemetry>((ref) async {
  final userLoc = ref.watch(userLocationProvider);
  try {
    final dio = ApiClient().dio;
    final res = await dio.get(
      '/environmental/live',
      queryParameters: {
        'lat': userLoc.latitude,
        'lng': userLoc.longitude,
      },
    );
    if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
      return EnvironmentalTelemetry.fromJson(res.data as Map<String, dynamic>);
    }
  } catch (_) {
    // Graceful offline fallback
  }
  return EnvironmentalTelemetry.defaultTelemetry;
});
