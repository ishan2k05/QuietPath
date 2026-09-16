import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:quietpath_flutter/core/network/api_client.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';

class HazardData {
  final String id;
  final String hazardType;
  final String title;
  final String? description;
  final int severity;
  final double lat;
  final double lng;
  final DateTime reportedAt;
  final DateTime expiresAt;
  final int upvotes;

  const HazardData({
    required this.id,
    required this.hazardType,
    required this.title,
    this.description,
    required this.severity,
    required this.lat,
    required this.lng,
    required this.reportedAt,
    required this.expiresAt,
    required this.upvotes,
  });

  factory HazardData.fromJson(Map<String, dynamic> json) {
    return HazardData(
      id: json['id'] as String,
      hazardType: (json['hazard_type'] as String?)?.toLowerCase() ?? 'noise',
      title: json['title'] as String? ?? 'Sensory Hazard',
      description: json['description'] as String?,
      severity: (json['severity'] as num?)?.toInt() ?? 3,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      reportedAt: DateTime.tryParse(json['reported_at']?.toString() ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '') ??
          DateTime.now().add(const Duration(hours: 3)),
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 1,
    );
  }

  IconData get iconData {
    switch (hazardType) {
      case 'construction':
        return Icons.construction_rounded;
      case 'crowd':
        return Icons.groups_rounded;
      case 'light':
      case 'glare':
        return Icons.light_mode_rounded;
      case 'air_quality':
        return Icons.air_rounded;
      case 'noise':
      default:
        return Icons.volume_up_rounded;
    }
  }

  Color get tagColor {
    switch (hazardType) {
      case 'construction':
        return const Color(0xFFD97706); // Amber
      case 'crowd':
        return QuietColors.secondary; // Lavender
      case 'light':
      case 'glare':
        return const Color(0xFFEAB308); // Yellow
      case 'air_quality':
        return QuietColors.tertiary; // Eucalyptus Teal
      case 'noise':
      default:
        return QuietColors.alertRed;
    }
  }

  String get typeDisplayName {
    switch (hazardType) {
      case 'construction':
        return 'Construction';
      case 'crowd':
        return 'Crowded Area';
      case 'light':
      case 'glare':
        return 'Harsh Lighting';
      case 'air_quality':
        return 'Air Quality';
      case 'noise':
      default:
        return 'Noise Surge';
    }
  }
}

class HazardsState {
  final bool isLoading;
  final bool isSubmitting;
  final List<HazardData> hazards;
  final String? errorMessage;
  final String? successMessage;

  const HazardsState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.hazards = const [],
    this.errorMessage,
    this.successMessage,
  });

  HazardsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<HazardData>? hazards,
    String? errorMessage,
    String? successMessage,
  }) {
    return HazardsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      hazards: hazards ?? this.hazards,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class HazardsNotifier extends StateNotifier<HazardsState> {
  final Ref ref;

  HazardsNotifier(this.ref) : super(const HazardsState()) {
    fetchActiveHazards();
  }

  Future<void> fetchActiveHazards({
    double lat = 12.9750,
    double lng = 77.5920,
    double radiusMiles = 10.0,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dio = ApiClient().dio;
      final response = await dio.get(
        '/hazards/active',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius_miles': radiusMiles,
        },
      );

      final data = response.data;
      final List<dynamic> list = data['hazards'] as List<dynamic>? ?? [];
      final hazards = list.map((e) => HazardData.fromJson(e as Map<String, dynamic>)).toList();

      state = state.copyWith(
        isLoading: false,
        hazards: hazards,
      );
    } catch (e) {
      // Fallback to local representative hazards if offline/network error
      final fallbackHazards = [
        HazardData(
          id: 'hz_demo_1',
          hazardType: 'construction',
          title: 'Oak Trail Drilling & Paver Work',
          description: 'Loud concrete cutting machinery active near trail crossing',
          severity: 4,
          lat: 12.9758,
          lng: 77.5922,
          reportedAt: DateTime.now().subtract(const Duration(minutes: 25)),
          expiresAt: DateTime.now().add(const Duration(hours: 2)),
          upvotes: 4,
        ),
        HazardData(
          id: 'hz_demo_2',
          hazardType: 'crowd',
          title: 'Metro Gate 2 Congestion',
          description: 'High commuter density surge during evening transit',
          severity: 3,
          lat: 12.9770,
          lng: 77.5935,
          reportedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          upvotes: 2,
        ),
      ];
      state = state.copyWith(
        isLoading: false,
        hazards: fallbackHazards,
      );
    }
  }

  Future<bool> reportHazard({
    required String hazardType,
    required String title,
    String? description,
    required int severity,
    required double lat,
    required double lng,
    int durationHours = 3,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null, successMessage: null);
    try {
      final dio = ApiClient().dio;
      final response = await dio.post(
        '/hazards/',
        data: {
          'hazard_type': hazardType.toLowerCase(),
          'title': title,
          'description': description,
          'severity': severity,
          'lat': lat,
          'lng': lng,
          'duration_hours': durationHours,
        },
      );

      final newHazard = HazardData.fromJson(response.data as Map<String, dynamic>);
      state = state.copyWith(
        isSubmitting: false,
        hazards: [newHazard, ...state.hazards.where((h) => h.id != newHazard.id)],
        successMessage: 'Hazard reported! Nearby sensory routes recalculated.',
      );
      return true;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 422) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Validation failed: Please ensure all hazard details are valid.',
        );
        return false;
      }
      if (e is DioException && e.response?.statusCode == 429) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Pacing alert: Rate limit reached. Please pause before submitting again.',
        );
        return false;
      }

      // Local optimistic addition on client offline fallback
      final optimisticHazard = HazardData(
        id: 'hz_local_${DateTime.now().millisecondsSinceEpoch}',
        hazardType: hazardType.toLowerCase(),
        title: title,
        description: description,
        severity: severity,
        lat: lat,
        lng: lng,
        reportedAt: DateTime.now(),
        expiresAt: DateTime.now().add(Duration(hours: durationHours)),
        upvotes: 1,
      );
      state = state.copyWith(
        isSubmitting: false,
        hazards: [optimisticHazard, ...state.hazards],
        successMessage: 'Hazard logged locally (offline mode).',
      );
      return true;
    }
  }

  Future<bool> upvoteHazard(String id) async {
    try {
      final dio = ApiClient().dio;
      await dio.post('/hazards/$id/upvote');

      final updated = state.hazards.map((h) {
        if (h.id == id) {
          return HazardData(
            id: h.id,
            hazardType: h.hazardType,
            title: h.title,
            description: h.description,
            severity: h.severity,
            lat: h.lat,
            lng: h.lng,
            reportedAt: h.reportedAt,
            expiresAt: h.expiresAt.add(const Duration(minutes: 30)),
            upvotes: h.upvotes + 1,
          );
        }
        return h;
      }).toList();

      state = state.copyWith(hazards: updated, successMessage: 'Sensory hazard confirmed.');
      return true;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 429) {
        state = state.copyWith(
          errorMessage: 'You have already confirmed this sensory hazard recently.',
        );
      }
      return false;
    }
  }
}

final hazardsProvider = StateNotifierProvider<HazardsNotifier, HazardsState>((ref) {
  return HazardsNotifier(ref);
});
