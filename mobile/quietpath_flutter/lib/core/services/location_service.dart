import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';

class UserCoordinates {
  final double latitude;
  final double longitude;
  final String label;
  final bool isHardwareGps;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;

  const UserCoordinates({
    required this.latitude,
    required this.longitude,
    this.label = 'Current Location',
    this.isHardwareGps = false,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
  });

  UserCoordinates copyWith({
    double? latitude,
    double? longitude,
    String? label,
    bool? isHardwareGps,
    double? accuracy,
    double? speed,
    double? heading,
    double? altitude,
  }) {
    return UserCoordinates(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      isHardwareGps: isHardwareGps ?? this.isHardwareGps,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      altitude: altitude ?? this.altitude,
    );
  }

  @override
  String toString() => '$latitude, $longitude ($label, GPS: $isHardwareGps)';
}

class LocationService {
  static const UserCoordinates defaultBangaloreLocation = UserCoordinates(
    latitude: 12.9716,
    longitude: 77.5946,
    label: 'Vidhana Soudha Area, Bengaluru',
  );

  static const Map<String, UserCoordinates> destinationCoordinates = {
    'Bangalore Golf Club': UserCoordinates(
      latitude: 12.9860,
      longitude: 77.5850,
      label: 'Bangalore Golf Club, High Grounds',
    ),
    'Cubbon Park Sanctuary': UserCoordinates(
      latitude: 12.9763,
      longitude: 77.5929,
      label: 'Cubbon Park Sanctuary, Sampangi Rama Nagara',
    ),
    'Lalbagh Botanical Garden': UserCoordinates(
      latitude: 12.9507,
      longitude: 77.5848,
      label: 'Lalbagh Botanical Garden, Mavalli',
    ),
    'Central Public Library': UserCoordinates(
      latitude: 12.9750,
      longitude: 77.5900,
      label: 'State Central Library, Cubbon Park',
    ),
    'Commercial Street': UserCoordinates(
      latitude: 12.9822,
      longitude: 77.6083,
      label: 'Commercial Street, Tasker Town',
    ),
  };

  /// Pre-computed calm navigation waypoints between Start (Vidhana Soudha) and Golf Club
  static const List<UserCoordinates> calmRouteWaypoints = [
    UserCoordinates(
      latitude: 12.9716,
      longitude: 77.5946,
      label: 'Starting at K.R. Circle / Vidhana Soudha',
    ),
    UserCoordinates(
      latitude: 12.9768,
      longitude: 77.5912,
      label: "Queen's Park Walkway Canopy",
    ),
    UserCoordinates(
      latitude: 12.9815,
      longitude: 77.5878,
      label: 'Palace Road Shaded Boulevard',
    ),
    UserCoordinates(
      latitude: 12.9860,
      longitude: 77.5850,
      label: 'Bangalore Golf Club Refuge',
    ),
  ];

  /// Calculates Haversine distance in miles between two coordinates
  static double calculateDistanceMiles(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMiles = 3958.8;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return double.parse((earthRadiusMiles * c).toStringAsFixed(2));
  }

  static double _toRadians(double degree) => degree * (math.pi / 180.0);
}

class UserLocationNotifier extends StateNotifier<UserCoordinates> {
  StreamSubscription<Position>? _positionSub;
  bool _isHardwareGpsActive = false;
  bool _isLocating = false;

  bool get isHardwareGpsActive => _isHardwareGpsActive;
  bool get isLocating => _isLocating;

  UserLocationNotifier() : super(_initialCoordinates());

  static UserCoordinates _initialCoordinates() {
    final cfg = AppConfigService();
    return UserCoordinates(
      latitude: cfg.lastKnownLat,
      longitude: cfg.lastKnownLng,
      label: 'Current Location',
    );
  }

  /// Attempts to enable real-time hardware GPS location streaming.
  /// Falls back gracefully to simulated/default coordinates if permissions are denied or GPS is disabled.
  Future<bool> startHardwareLocationStream() async {
    try {
      _isLocating = true;
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services are disabled.');
        _isLocating = false;
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permissions denied.');
          _isLocating = false;
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permissions are permanently denied.');
        _isLocating = false;
        return false;
      }

      // 1. Get immediate current position
      try {
        final currentPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        _applyPosition(currentPos);
      } catch (e) {
        debugPrint('[LocationService] Could not get immediate position: $e');
      }

      // 2. Subscribe to continuous stream with 3-meter distance filter
      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen(
        (Position pos) {
          _applyPosition(pos);
        },
        onError: (err) {
          debugPrint('[LocationService] GPS Stream error: $err');
        },
      );

      _isHardwareGpsActive = true;
      _isLocating = false;
      return true;
    } catch (e) {
      debugPrint('[LocationService] Exception starting GPS stream: $e');
      _isLocating = false;
      return false;
    }
  }

  void _applyPosition(Position pos) {
    state = UserCoordinates(
      latitude: pos.latitude,
      longitude: pos.longitude,
      label: 'Live GPS (±${pos.accuracy.toStringAsFixed(1)}m)',
      isHardwareGps: true,
      accuracy: pos.accuracy,
      speed: pos.speed,
      heading: pos.heading,
      altitude: pos.altitude,
    );
    AppConfigService().updateLastLocation(pos.latitude, pos.longitude);
  }

  void stopHardwareLocationStream() {
    _positionSub?.cancel();
    _positionSub = null;
    _isHardwareGpsActive = false;
    state = state.copyWith(isHardwareGps: false, label: 'Simulated Location');
  }

  Future<void> toggleHardwareGps() async {
    if (_isHardwareGpsActive) {
      stopHardwareLocationStream();
    } else {
      await startHardwareLocationStream();
    }
  }

  void updateLocation(double lat, double lng, [String? label]) {
    stopHardwareLocationStream();
    state = UserCoordinates(
      latitude: lat,
      longitude: lng,
      label: label ?? state.label,
      isHardwareGps: false,
    );
    AppConfigService().updateLastLocation(lat, lng);
  }

  void setStepWaypoint(int stepIndex, [String destination = 'Bangalore Golf Club']) {
    stopHardwareLocationStream();
    if (stepIndex >= 0 && stepIndex < LocationService.calmRouteWaypoints.length) {
      final wp = LocationService.calmRouteWaypoints[stepIndex];
      state = wp;
      AppConfigService().updateLastLocation(wp.latitude, wp.longitude);
    }
  }

  void resetToDefault() {
    stopHardwareLocationStream();
    state = LocationService.defaultBangaloreLocation;
    AppConfigService().updateLastLocation(
      LocationService.defaultBangaloreLocation.latitude,
      LocationService.defaultBangaloreLocation.longitude,
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }
}

final userLocationProvider =
    StateNotifierProvider<UserLocationNotifier, UserCoordinates>((ref) {
  return UserLocationNotifier();
});
