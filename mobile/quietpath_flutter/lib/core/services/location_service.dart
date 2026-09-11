import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    'Ulsoor Lake Promenade': UserCoordinates(
      latitude: 12.9815,
      longitude: 77.6200,
      label: 'Ulsoor Lake Lakeside Walk, Halasuru',
    ),
    'National Gallery of Modern Art': UserCoordinates(
      latitude: 12.9890,
      longitude: 77.5880,
      label: 'NGMA Heritage Gardens, Vasanth Nagar',
    ),
    'Sankey Tank Peaceful Trail': UserCoordinates(
      latitude: 13.0070,
      longitude: 77.5730,
      label: 'Sankey Tank Water Boulevard, Sadashivanagar',
    ),
    'IISc Botanical Garden': UserCoordinates(
      latitude: 13.0180,
      longitude: 77.5680,
      label: 'IISc Tree Canopy Sanctuary, Mathikere',
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

  /// Calculates Haversine distance in meters between two coordinates
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  /// Calculates true compass bearing in degrees (0 - 360) from point 1 to point 2
  static double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final double phi1 = _toRadians(lat1);
    final double phi2 = _toRadians(lat2);
    final double deltaLambda = _toRadians(lon2 - lon1);

    final double y = math.sin(deltaLambda) * math.cos(phi2);
    final double x = math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);

    final double theta = math.atan2(y, x);
    return (theta * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// Returns calm navigation route waypoints for a specific destination
  static List<UserCoordinates> getWaypointsForDestination(String destination, [UserCoordinates? origin]) {
    if (destination.contains('Library')) {
      return const [
        UserCoordinates(
          latitude: 12.9716,
          longitude: 77.5946,
          label: 'Starting at K.R. Circle / Vidhana Soudha',
        ),
        UserCoordinates(
          latitude: 12.9735,
          longitude: 77.5925,
          label: "Enter Queen's Park Walkway via Shade",
        ),
        UserCoordinates(
          latitude: 12.9745,
          longitude: 77.5910,
          label: 'Kasturba Road Quiet Footpath',
        ),
        UserCoordinates(
          latitude: 12.9750,
          longitude: 77.5900,
          label: 'State Central Library Sanctuary',
        ),
      ];
    } else if (destination.contains('Lalbagh')) {
      return const [
        UserCoordinates(
          latitude: 12.9716,
          longitude: 77.5946,
          label: 'Starting at Vidhana Soudha',
        ),
        UserCoordinates(
          latitude: 12.9640,
          longitude: 77.5905,
          label: 'Mission Road Shaded Footway',
        ),
        UserCoordinates(
          latitude: 12.9565,
          longitude: 77.5870,
          label: 'Double Road Tree Line',
        ),
        UserCoordinates(
          latitude: 12.9507,
          longitude: 77.5848,
          label: 'Lalbagh Botanical Garden Sanctuary',
        ),
      ];
    } else if (destination.contains('Cubbon')) {
      return const [
        UserCoordinates(
          latitude: 12.9716,
          longitude: 77.5946,
          label: 'Starting at Vidhana Soudha',
        ),
        UserCoordinates(
          latitude: 12.9738,
          longitude: 77.5938,
          label: 'Seshadri Road Pedestrian Crossing',
        ),
        UserCoordinates(
          latitude: 12.9752,
          longitude: 77.5932,
          label: 'Bamboo Grove Quiet Trail',
        ),
        UserCoordinates(
          latitude: 12.9763,
          longitude: 77.5929,
          label: 'Cubbon Park Sanctuary Gazebo',
        ),
      ];
    } else if (destination.contains('Commercial')) {
      return const [
        UserCoordinates(
          latitude: 12.9716,
          longitude: 77.5946,
          label: 'Starting at Vidhana Soudha',
        ),
        UserCoordinates(
          latitude: 12.9750,
          longitude: 77.5990,
          label: 'Infantry Road Shaded Sidewalk',
        ),
        UserCoordinates(
          latitude: 12.9790,
          longitude: 77.6040,
          label: 'Dispensary Road Calm Corridor',
        ),
        UserCoordinates(
          latitude: 12.9822,
          longitude: 77.6083,
          label: 'Commercial Street Refuge',
        ),
      ];
    }
    
    // Dynamic calm waypoint generation for any searched location or coordinates
    final target = resolveDestinationCoordinates(destination);
    final start = origin ?? defaultBangaloreLocation;
    return [
      start,
      UserCoordinates(
        latitude: start.latitude + (target.latitude - start.latitude) * 0.33,
        longitude: start.longitude + (target.longitude - start.longitude) * 0.33,
        label: 'Calm Tree-Lined Corridor',
      ),
      UserCoordinates(
        latitude: start.latitude + (target.latitude - start.latitude) * 0.66,
        longitude: start.longitude + (target.longitude - start.longitude) * 0.66,
        label: 'Low-Noise Pedestrian Footpath',
      ),
      target,
    ];
  }

  /// Resolves any place name or "lat, lng" coordinates string into a valid UserCoordinates target
  static UserCoordinates resolveDestinationCoordinates(String dest) {
    if (destinationCoordinates.containsKey(dest)) {
      return destinationCoordinates[dest]!;
    }
    for (final entry in destinationCoordinates.entries) {
      if (entry.key.toLowerCase().contains(dest.toLowerCase()) ||
          dest.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    // Try parsing "lat, lng"
    final coordMatch = RegExp(r'^\s*([-+]?\d+(\.\d+)?)\s*,\s*([-+]?\d+(\.\d+)?)\s*$').firstMatch(dest);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1) ?? '');
      final lng = double.tryParse(coordMatch.group(3) ?? '');
      if (lat != null && lng != null) {
        return UserCoordinates(latitude: lat, longitude: lng, label: 'GPS Pin: $dest');
      }
    }

    // Hash-based deterministic nearby offset around city center for arbitrary named locations
    final hash = dest.hashCode.abs();
    final dLat = ((hash % 100) - 50) * 0.0003;
    final dLng = (((hash ~/ 100) % 100) - 50) * 0.0003;
    return UserCoordinates(
      latitude: defaultBangaloreLocation.latitude + dLat,
      longitude: defaultBangaloreLocation.longitude + dLng,
      label: dest,
    );
  }

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
  Timer? _autoWalkTimer;
  int _autoWalkLegIndex = 0;
  double _autoWalkProgress = 0.0;
  bool _isAutoWalkActive = false;
  List<UserCoordinates>? _activeWaypoints;
  VoidCallback? _onArrivalCallback;

  bool _isHardwareGpsActive = false;
  bool _isLocating = false;

  bool get isHardwareGpsActive => _isHardwareGpsActive;
  bool get isAutoWalkActive => _isAutoWalkActive;
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

  /// Starts smooth realistic simulated walking along route waypoints.
  /// Ideal for testing, emulators, or PCs where Windows Location services are disabled by admin.
  void startAutoWalk(List<UserCoordinates> waypoints, {VoidCallback? onArrival}) {
    if (waypoints.length < 2) return;
    _positionSub?.cancel();
    _positionSub = null;
    _isHardwareGpsActive = false;

    _activeWaypoints = waypoints;
    _onArrivalCallback = onArrival;
    _autoWalkLegIndex = 0;
    _autoWalkProgress = 0.0;
    _isAutoWalkActive = true;

    // Set initial position
    final startWp = waypoints.first;
    state = startWp.copyWith(
      isHardwareGps: false,
      label: 'Simulated Walk (Live GPS)',
      speed: 1.35,
      accuracy: 2.0,
    );
    AppConfigService().updateLastLocation(startWp.latitude, startWp.longitude);

    _autoWalkTimer?.cancel();
    _autoWalkTimer = Timer.periodic(const Duration(milliseconds: 650), (timer) {
      if (!_isAutoWalkActive || _activeWaypoints == null) {
        timer.cancel();
        return;
      }

      if (_autoWalkLegIndex >= _activeWaypoints!.length - 1) {
        final finalWp = _activeWaypoints!.last;
        state = finalWp.copyWith(
          isHardwareGps: false,
          label: 'Arrived at Destination',
          speed: 0.0,
          accuracy: 1.5,
        );
        _isAutoWalkActive = false;
        timer.cancel();
        _onArrivalCallback?.call();
        return;
      }

      final p1 = _activeWaypoints![_autoWalkLegIndex];
      final p2 = _activeWaypoints![_autoWalkLegIndex + 1];
      final legDistanceMeters = LocationService.calculateDistanceMeters(
        p1.latitude,
        p1.longitude,
        p2.latitude,
        p2.longitude,
      );

      // Advance ~ 12 meters per tick (~ 18 km/h demo pace so user sees turn auto-advancement smoothly)
      const double stepMeters = 12.0;
      final double progressIncrement = (legDistanceMeters > 0) ? (stepMeters / legDistanceMeters) : 0.25;

      _autoWalkProgress += progressIncrement;
      if (_autoWalkProgress >= 1.0) {
        _autoWalkLegIndex++;
        _autoWalkProgress = 0.0;
      }

      final currentP1 = _activeWaypoints![math.min(_autoWalkLegIndex, _activeWaypoints!.length - 1)];
      final currentP2 = _activeWaypoints![math.min(_autoWalkLegIndex + 1, _activeWaypoints!.length - 1)];

      final double interpLat = currentP1.latitude + (currentP2.latitude - currentP1.latitude) * _autoWalkProgress;
      final double interpLng = currentP1.longitude + (currentP2.longitude - currentP1.longitude) * _autoWalkProgress;
      final double heading = LocationService.calculateBearing(
        currentP1.latitude,
        currentP1.longitude,
        currentP2.latitude,
        currentP2.longitude,
      );

      state = UserCoordinates(
        latitude: interpLat,
        longitude: interpLng,
        label: 'Live Auto-Walk (1.4 m/s)',
        isHardwareGps: false,
        speed: 1.4,
        heading: heading,
        accuracy: 2.2,
      );
      AppConfigService().updateLastLocation(interpLat, interpLng);
    });
  }

  void stopAutoWalk() {
    _autoWalkTimer?.cancel();
    _autoWalkTimer = null;
    _isAutoWalkActive = false;
    state = state.copyWith(speed: 0.0, label: 'Walk Paused');
  }

  void toggleAutoWalk(List<UserCoordinates> waypoints, {VoidCallback? onArrival}) {
    if (_isAutoWalkActive) {
      stopAutoWalk();
    } else {
      startAutoWalk(waypoints, onArrival: onArrival);
    }
  }

  /// Attempts to enable real-time hardware GPS location streaming.
  /// Falls back gracefully to simulated/default coordinates if permissions are denied or GPS is disabled.
  Future<bool> startHardwareLocationStream() async {
    try {
      stopAutoWalk();
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
    stopAutoWalk();
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
    stopAutoWalk();
    final waypoints = LocationService.getWaypointsForDestination(destination);
    if (stepIndex >= 0 && stepIndex < waypoints.length) {
      final wp = waypoints[stepIndex];
      state = wp;
      AppConfigService().updateLastLocation(wp.latitude, wp.longitude);
    }
  }

  void resetToDefault() {
    stopHardwareLocationStream();
    stopAutoWalk();
    state = LocationService.defaultBangaloreLocation;
    AppConfigService().updateLastLocation(
      LocationService.defaultBangaloreLocation.latitude,
      LocationService.defaultBangaloreLocation.longitude,
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _autoWalkTimer?.cancel();
    super.dispose();
  }
}

final userLocationProvider =
    StateNotifierProvider<UserLocationNotifier, UserCoordinates>((ref) {
  return UserLocationNotifier();
});

/// Streams real-time magnetic compass bearing (0° - 360°) from device sensors via native EventChannel.
/// Falls back gracefully when running in emulators or on devices without a magnetometer.
class CompassHeadingNotifier extends StateNotifier<double?> {
  static const EventChannel _compassChannel = EventChannel('com.quietpath/compass');
  StreamSubscription<dynamic>? _compassSub;
  bool _isListening = false;
  int _lastEmitMs = 0;

  CompassHeadingNotifier() : super(null) {
    initCompass();
  }

  void initCompass() {
    if (_isListening) return;
    try {
      _isListening = true;
      _compassSub = _compassChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (!mounted) return;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastEmitMs < 150) return; // Throttle to ~6.5Hz
          _lastEmitMs = now;
          if (event is num) {
            final val = event.toDouble();
            if (state == null || (val - (state ?? 0.0)).abs() >= 1.5) {
              scheduleMicrotask(() {
                if (mounted) {
                  try {
                    state = val;
                  } catch (_) {}
                }
              });
            }
          }
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[Compass] Failed to initialize native compass: $e');
    }
  }

  void setHeading(double deg) {
    if (mounted) {
      try {
        state = deg;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _isListening = false;
    super.dispose();
  }
}

final compassHeadingProvider =
    StateNotifierProvider<CompassHeadingNotifier, double?>((ref) {
  return CompassHeadingNotifier();
});

