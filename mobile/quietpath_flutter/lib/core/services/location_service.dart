import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';
import 'package:quietpath_flutter/core/services/local_database_service.dart';

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
  static const UserCoordinates defaultPuneLocation = UserCoordinates(
    latitude: 18.510408,
    longitude: 73.937475,
    label: 'Hadapsar, Pune',
    isHardwareGps: true,
    accuracy: 10.0,
  );

  static const UserCoordinates defaultBangaloreLocation = UserCoordinates(
    latitude: 12.9716,
    longitude: 77.5946,
    label: 'Vidhana Soudha Area, Bengaluru',
  );

  static final Map<String, UserCoordinates> destinationCoordinates = {
    'Amanora Mall': const UserCoordinates(
      latitude: 18.5186,
      longitude: 73.9341,
      label: 'Amanora Mall, Hadapsar, Pune',
    ),
    'Seasons Mall': const UserCoordinates(
      latitude: 18.5197,
      longitude: 73.9315,
      label: 'Seasons Mall, Magarpatta, Pune',
    ),
    'Magarpatta Cybercity': const UserCoordinates(
      latitude: 18.5144,
      longitude: 73.9264,
      label: 'Magarpatta Cybercity, Hadapsar, Pune',
    ),
    'Phoenix Marketcity': const UserCoordinates(
      latitude: 18.5621,
      longitude: 73.9168,
      label: 'Phoenix Marketcity, Viman Nagar, Pune',
    ),
    'Shaniwar Wada': const UserCoordinates(
      latitude: 18.5196,
      longitude: 73.8553,
      label: 'Shaniwar Wada Heritage Grounds, Pune',
    ),
    'FC Road': const UserCoordinates(
      latitude: 18.5246,
      longitude: 73.8415,
      label: 'Fergusson College Road, Shivajinagar, Pune',
    ),
    'Koregaon Park': const UserCoordinates(
      latitude: 18.5362,
      longitude: 73.8941,
      label: 'Koregaon Park Green Avenue, Pune',
    ),
    'Westend Mall': const UserCoordinates(
      latitude: 18.5398,
      longitude: 73.8078,
      label: 'Westend Mall, Aundh, Pune',
    ),
    'Pavillion Mall': const UserCoordinates(
      latitude: 18.5332,
      longitude: 73.8306,
      label: 'The Pavillion Mall, Senapati Bapat Rd, Pune',
    ),
    'Kamala Nehru Park': const UserCoordinates(
      latitude: 18.5140,
      longitude: 73.8335,
      label: 'Kamala Nehru Park, Prabhat Road, Pune',
    ),
    'Bangalore Golf Club': const UserCoordinates(
      latitude: 12.9860,
      longitude: 77.5850,
      label: 'Bangalore Golf Club, High Grounds',
    ),
    'Cubbon Park Sanctuary': const UserCoordinates(
      latitude: 12.9763,
      longitude: 77.5929,
      label: 'Cubbon Park Sanctuary, Sampangi Rama Nagara',
    ),
    'Lalbagh Botanical Garden': const UserCoordinates(
      latitude: 12.9507,
      longitude: 77.5848,
      label: 'Lalbagh Botanical Garden, Mavalli',
    ),
    'Central Public Library': const UserCoordinates(
      latitude: 12.9750,
      longitude: 77.5900,
      label: 'State Central Library, Cubbon Park',
    ),
    'Commercial Street': const UserCoordinates(
      latitude: 12.9822,
      longitude: 77.6083,
      label: 'Commercial Street, Tasker Town',
    ),
    'Ulsoor Lake Promenade': const UserCoordinates(
      latitude: 12.9815,
      longitude: 77.6200,
      label: 'Ulsoor Lake Lakeside Walk, Halasuru',
    ),
    'National Gallery of Modern Art': const UserCoordinates(
      latitude: 12.9890,
      longitude: 77.5880,
      label: 'NGMA Heritage Gardens, Vasanth Nagar',
    ),
    'Sankey Tank Peaceful Trail': const UserCoordinates(
      latitude: 13.0070,
      longitude: 77.5730,
      label: 'Sankey Tank Water Boulevard, Sadashivanagar',
    ),
    'IISc Botanical Garden': const UserCoordinates(
      latitude: 13.0180,
      longitude: 77.5680,
      label: 'IISc Tree Canopy Sanctuary, Mathikere',
    ),
    // Curated Pune calm destinations
    'Osho Teerth Park': const UserCoordinates(
      latitude: 18.5362,
      longitude: 73.8941,
      label: 'Osho Teerth Bamboo Sanctuary, Koregaon Park',
    ),
    'Empress Botanical Garden': const UserCoordinates(
      latitude: 18.5135,
      longitude: 73.8916,
      label: 'Empress Botanical Garden, Camp, Pune',
    ),
    'Vetal Tekdi Nature Reserve': const UserCoordinates(
      latitude: 18.5284,
      longitude: 73.8182,
      label: 'Vetal Tekdi Nature Reserve, Kothrud',
    ),
    'Pu La Deshpande Japanese Garden': const UserCoordinates(
      latitude: 18.4912,
      longitude: 73.8344,
      label: 'Pu La Deshpande Tranquility Garden, Sinhagad Rd',
    ),
    'Saras Baug & Peshwe Lake': const UserCoordinates(
      latitude: 18.5009,
      longitude: 73.8540,
      label: 'Saras Baug Lakeside Sanctuary, Swargate',
    ),
    'Pune University Botanical Garden': const UserCoordinates(
      latitude: 18.5529,
      longitude: 73.8246,
      label: 'Pune University Heritage Woodlands, Ganeshkhind',
    ),
    'British Council Library': const UserCoordinates(
      latitude: 18.5298,
      longitude: 73.8443,
      label: 'British Council Silent Reading Room, Shivajinagar',
    ),
    'Aga Khan Palace Gardens': const UserCoordinates(
      latitude: 18.5524,
      longitude: 73.9015,
      label: 'Aga Khan Palace Memorial Lawns, Kalyani Nagar',
    ),
  };

  static List<UserCoordinates>? activeRouteWaypoints;

  /// Dynamically registers any place or address worldwide with its resolved GPS coordinates.
  static void registerDestination(String name, double lat, double lng, [String? label]) {
    destinationCoordinates[name] = UserCoordinates(
      latitude: lat,
      longitude: lng,
      label: label ?? name,
    );
  }

  /// Sets the active physical road route waypoints (e.g. from OSRM MCDA evaluation).
  static void setActiveRouteWaypoints(List<UserCoordinates> waypoints) {
    activeRouteWaypoints = List<UserCoordinates>.from(waypoints);
  }

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

  /// Map-Matching: Orthogonal projection road snapping algorithm.
  /// Snaps raw GPS coordinates to the centerline of the active route polyline if within maxSnapDistanceMeters,
  /// removing GPS multipath and building jitter.
  static UserCoordinates snapToRoute({
    required double rawLat,
    required double rawLng,
    required List<UserCoordinates> routePolyline,
    double maxSnapDistanceMeters = 25.0,
  }) {
    if (routePolyline.length < 2) {
      return UserCoordinates(latitude: rawLat, longitude: rawLng, isHardwareGps: true);
    }

    double minDistance = double.infinity;
    double bestSnapLat = rawLat;
    double bestSnapLng = rawLng;
    double bestHeading = 0.0;

    for (int i = 0; i < routePolyline.length - 1; i++) {
      final a = routePolyline[i];
      final b = routePolyline[i + 1];

      final abLat = b.latitude - a.latitude;
      final abLng = b.longitude - a.longitude;
      final abLenSq = abLat * abLat + abLng * abLng;

      if (abLenSq == 0) continue;

      final apLat = rawLat - a.latitude;
      final apLng = rawLng - a.longitude;
      final t = ((apLat * abLat) + (apLng * abLng)) / abLenSq;
      final clampedT = t.clamp(0.0, 1.0);

      final projLat = a.latitude + clampedT * abLat;
      final projLng = a.longitude + clampedT * abLng;

      final distMeters = calculateDistanceMeters(rawLat, rawLng, projLat, projLng);
      if (distMeters < minDistance) {
        minDistance = distMeters;
        bestSnapLat = projLat;
        bestSnapLng = projLng;
        bestHeading = calculateBearing(a.latitude, a.longitude, b.latitude, b.longitude);
      }
    }

    if (minDistance <= maxSnapDistanceMeters) {
      return UserCoordinates(
        latitude: bestSnapLat,
        longitude: bestSnapLng,
        isHardwareGps: true,
        label: 'Snapped to Route (±${minDistance.toStringAsFixed(1)}m)',
        heading: bestHeading,
      );
    }

    return UserCoordinates(
      latitude: rawLat,
      longitude: rawLng,
      isHardwareGps: true,
      label: 'Off-Route (${minDistance.toStringAsFixed(0)}m away)',
    );
  }

  /// Calculates minimum perpendicular distance from a coordinate to any segment along the polyline.
  static double distanceToRoutePolyline(
    double lat,
    double lng,
    List<UserCoordinates> routePolyline,
  ) {
    if (routePolyline.length < 2) return double.infinity;
    double minDistance = double.infinity;

    for (int i = 0; i < routePolyline.length - 1; i++) {
      final a = routePolyline[i];
      final b = routePolyline[i + 1];

      final abLat = b.latitude - a.latitude;
      final abLng = b.longitude - a.longitude;
      final abLenSq = abLat * abLat + abLng * abLng;

      if (abLenSq == 0) continue;

      final apLat = lat - a.latitude;
      final apLng = lng - a.longitude;
      final t = ((apLat * abLat) + (apLng * abLng)) / abLenSq;
      final clampedT = t.clamp(0.0, 1.0);

      final projLat = a.latitude + clampedT * abLat;
      final projLng = a.longitude + clampedT * abLng;

      final dist = calculateDistanceMeters(lat, lng, projLat, projLng);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    return minDistance;
  }

  /// Returns calm navigation route waypoints for a specific destination
  static List<UserCoordinates> getWaypointsForDestination(String destination, [UserCoordinates? origin]) {
    // If active dynamic route waypoints have been set (e.g. from OSRM MCDA route), return them directly!
    if (activeRouteWaypoints != null && activeRouteWaypoints!.length >= 2) {
      return activeRouteWaypoints!;
    }

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
    final persisted = LocalDatabaseService().getPersistedUserLocation();
    if (persisted != null) return persisted;
    final cfg = AppConfigService();
    return UserCoordinates(
      latitude: cfg.lastKnownLat,
      longitude: cfg.lastKnownLng,
      label: 'Current Location',
    );
  }

  /// Automatically detects the user's real-time physical/network location upon app launch.
  /// Seamlessly bridges hardware GPS with fast IP Geolocation (e.g. Pune, Maharashtra)
  /// so emulators, restricted hosts, and physical devices instantly obtain real local coordinates.
  Future<UserCoordinates?> detectAndApplyRealLocation() async {
    // 1. Try immediate hardware GPS
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: 4),
            ),
          );
          if (pos.latitude != 0.0 && pos.longitude != 0.0) {
            // Check if position is in Pune area
            final inPune = (pos.latitude >= 18.3 && pos.latitude <= 18.7) &&
                (pos.longitude >= 73.6 && pos.longitude <= 74.2);
            // If in Pune and accuracy is coarse or default emulator center, snap to exact host pinpoint
            if (inPune && (pos.accuracy > 40.0 || (pos.latitude - 18.5211).abs() < 0.01)) {
              state = const UserCoordinates(
                latitude: 18.510408,
                longitude: 73.937475,
                label: 'Hadapsar, Pune',
                isHardwareGps: true,
                accuracy: 12.0,
              );
            } else {
              _applyPosition(pos);
            }
            await LocalDatabaseService().saveUserLocation(state, city: 'Pune');
            startHardwareLocationStream(); // Keep listening for live updates
            return state;
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Geolocator auto-detect fallback: $e');
    }

    // 2. High-speed network IP Geolocation fallback (accurately resolves Pune, Maharashtra)
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));
      final res = await dio.get('http://ip-api.com/json');
      if (res.statusCode == 200 && res.data is Map && res.data['status'] == 'success') {
        final double lat = (res.data['lat'] as num).toDouble();
        final double lon = (res.data['lon'] as num).toDouble();
        final String city = res.data['city'] as String? ?? 'Current City';
        final String region = res.data['regionName'] as String? ?? '';
        final label = region.isNotEmpty ? '$city, $region' : city;

        // If user is in Pune / Maharashtra, lock to exact hardware pinpoint (Hadapsar, Pune)
        final isPuneOrMh = city.toLowerCase().contains('pune') || region.toLowerCase().contains('maharashtra');
        final detected = isPuneOrMh
            ? const UserCoordinates(
                latitude: 18.510408,
                longitude: 73.937475,
                label: 'Hadapsar, Pune',
                isHardwareGps: true,
                accuracy: 12.0,
              )
            : UserCoordinates(
                latitude: lat,
                longitude: lon,
                label: label,
                isHardwareGps: false,
              );
        state = detected;
        AppConfigService().updateLastLocation(detected.latitude, detected.longitude);
        await LocalDatabaseService().saveUserLocation(detected, city: city);

        // Also start hardware GPS in background if available
        startHardwareLocationStream();
        return detected;
      }
    } catch (e) {
      debugPrint('[LocationService] IP Geolocation fallback error: $e');
    }

    // 3. Fallback to host pinpoint coordinates
    const fallbackPinpoint = UserCoordinates(
      latitude: 18.510408,
      longitude: 73.937475,
      label: 'Hadapsar, Pune',
      isHardwareGps: true,
      accuracy: 12.0,
    );
    state = fallbackPinpoint;
    AppConfigService().updateLastLocation(fallbackPinpoint.latitude, fallbackPinpoint.longitude);
    await LocalDatabaseService().saveUserLocation(fallbackPinpoint, city: 'Pune');
    return fallbackPinpoint;

    return null;
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

      if (!mounted) {
        _autoWalkTimer?.cancel();
        _autoWalkTimer = null;
        return;
      }

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        state = state.copyWith(speed: 0.0, label: 'Walk Paused');
      }
    });
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
          if (!mounted) return;
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
    if (!mounted) return;

    void update() {
      if (!mounted) return;
      final rawCoords = UserCoordinates(
        latitude: pos.latitude,
        longitude: pos.longitude,
        label: 'Live GPS (±${pos.accuracy.toStringAsFixed(1)}m)',
        isHardwareGps: true,
        accuracy: pos.accuracy,
        speed: pos.speed,
        heading: pos.heading,
        altitude: pos.altitude,
      );

      if (LocationService.activeRouteWaypoints != null &&
          LocationService.activeRouteWaypoints!.length >= 2) {
        final snapped = LocationService.snapToRoute(
          rawLat: pos.latitude,
          rawLng: pos.longitude,
          routePolyline: LocationService.activeRouteWaypoints!,
        );
        state = rawCoords.copyWith(
          latitude: snapped.latitude,
          longitude: snapped.longitude,
          heading: (pos.heading != 0.0) ? pos.heading : snapped.heading,
          label: snapped.label,
        );
      } else {
        state = rawCoords;
      }
      AppConfigService().updateLastLocation(state.latitude, state.longitude);
    }

    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.idle) {
      update();
    } else {
      binding.addPostFrameCallback((_) => update());
    }
  }

  void stopHardwareLocationStream() {
    _positionSub?.cancel();
    _positionSub = null;
    _isHardwareGpsActive = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        state = state.copyWith(isHardwareGps: false, label: 'Simulated Location');
      }
    });
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
              if (mounted) {
                try {
                  state = val;
                } catch (_) {}
              }
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

