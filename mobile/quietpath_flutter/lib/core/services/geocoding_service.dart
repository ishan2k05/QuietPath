import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';

class PlaceSearchResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final String badge;
  final bool isCalmCurated;
  final double? distanceMeters;
  final double? sensoryScore;

  const PlaceSearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.badge = 'Global POI',
    this.isCalmCurated = false,
    this.distanceMeters,
    this.sensoryScore,
  });

  String get formattedAddress => address;
  bool get isCuratedSanctuary => isCalmCurated;

  PlaceSearchResult copyWith({
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? category,
    String? badge,
    bool? isCalmCurated,
    double? distanceMeters,
    double? sensoryScore,
  }) {
    return PlaceSearchResult(
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      badge: badge ?? this.badge,
      isCalmCurated: isCalmCurated ?? this.isCalmCurated,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      sensoryScore: sensoryScore ?? this.sensoryScore,
    );
  }
}

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;

  GeocodingService._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        headers: {
          'User-Agent': 'QuietPath/1.0 (Sensory-Optimized Navigation; Mobile)',
        },
      ),
    );
  }

  late final Dio _dio;
  final Map<String, List<PlaceSearchResult>> _cache = {};

  /// Pre-curated calm sanctuaries with sensory badges
  static const List<PlaceSearchResult> curatedCalmPlaces = [
    PlaceSearchResult(
      name: 'Cubbon Park Sanctuary',
      address: 'Kasturba Road, Sampangi Rama Nagara, Bengaluru',
      category: 'Parks & Greenery',
      badge: 'Very Quiet • Low Stimulus',
      latitude: 12.9763,
      longitude: 77.5929,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Central Public Library',
      address: 'Cubbon Park, Sampangi Rama Nagara, Bengaluru',
      category: 'Safe Space / Library',
      badge: 'Silence Required',
      latitude: 12.9750,
      longitude: 77.5900,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Bangalore Golf Club',
      address: 'Sankey Road, High Grounds, Bengaluru',
      category: 'Parks & Greenery',
      badge: 'Low Noise Corridor',
      latitude: 12.9860,
      longitude: 77.5850,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Lalbagh Botanical Garden',
      address: 'Mavalli, Near South End, Bengaluru',
      category: 'Parks & Greenery',
      badge: 'Tree Canopy • Low Noise',
      latitude: 12.9507,
      longitude: 77.5848,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Ulsoor Lake Promenade',
      address: 'Ulsoor Road, Halasuru, Bengaluru',
      category: 'Water Promenades',
      badge: 'Fresh Water Breeze',
      latitude: 12.9815,
      longitude: 77.6200,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'National Gallery of Modern Art',
      address: '49 Palace Road, Vasanth Nagar, Bengaluru',
      category: 'Sanctuaries',
      badge: 'Peaceful Indoor Refuge',
      latitude: 12.9890,
      longitude: 77.5880,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Sankey Tank Peaceful Trail',
      address: '11th Cross, Sadashivanagar, Bengaluru',
      category: 'Water Promenades',
      badge: 'Waterfront Shade',
      latitude: 13.0070,
      longitude: 77.5730,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'IISc Botanical Garden',
      address: 'CV Raman Road, Mathikere, Bengaluru',
      category: 'Sanctuaries',
      badge: 'Dense Tree Sanctuary',
      latitude: 13.0180,
      longitude: 77.5680,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Commercial Street',
      address: 'Tasker Town, Shivaji Nagar, Bengaluru',
      category: 'Commercial',
      badge: 'Urban Vibrant',
      latitude: 12.9822,
      longitude: 77.6083,
      isCalmCurated: false,
    ),
  ];

  /// Pre-curated calm sanctuaries in Pune with sensory badges
  static const List<PlaceSearchResult> curatedPunePlaces = [
    PlaceSearchResult(
      name: 'Amanora Mall',
      address: 'Mundhwa - Kharadi Rd, Amanora Park Town, Hadapsar, Pune',
      category: 'Commercial & Leisure',
      badge: 'Air-Cooled • Spacious Promenade',
      latitude: 18.5186,
      longitude: 73.9341,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Seasons Mall',
      address: 'Magarpatta City, Hadapsar, Pune',
      category: 'Commercial & Leisure',
      badge: 'Open-Air Courtyards',
      latitude: 18.5197,
      longitude: 73.9315,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Magarpatta Cybercity',
      address: 'Hadapsar, Pune',
      category: 'Tech Parks & Greenery',
      badge: 'Spacious Tree-Lined Boulevards',
      latitude: 18.5144,
      longitude: 73.9264,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Phoenix Marketcity',
      address: 'Viman Nagar, Pune',
      category: 'Commercial & Leisure',
      badge: 'Wide Walkways',
      latitude: 18.5621,
      longitude: 73.9168,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Osho Teerth Bamboo Sanctuary',
      address: 'Koregaon Park, Pune, Maharashtra',
      category: 'Parks & Greenery',
      badge: 'Very Quiet • Zen Stream',
      latitude: 18.5362,
      longitude: 73.8941,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Empress Botanical Garden',
      address: 'Near Race Course, Camp, Pune',
      category: 'Parks & Greenery',
      badge: 'Heritage Banyan Canopy',
      latitude: 18.5135,
      longitude: 73.8916,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Shaniwar Wada',
      address: 'Shaniwar Peth, Pune',
      category: 'Sanctuaries',
      badge: 'Historic Open Lawns',
      latitude: 18.5196,
      longitude: 73.8553,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'FC Road',
      address: 'Fergusson College Road, Shivajinagar, Pune',
      category: 'Commercial',
      badge: 'Urban Walkway',
      latitude: 18.5246,
      longitude: 73.8415,
      isCalmCurated: false,
    ),
    PlaceSearchResult(
      name: 'The Pavillion Mall',
      address: 'Senapati Bapat Road, Pune',
      category: 'Commercial & Leisure',
      badge: 'Indoor Calm Oasis',
      latitude: 18.5332,
      longitude: 73.8306,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Westend Mall',
      address: 'Aundh, Pune',
      category: 'Commercial & Leisure',
      badge: 'Shaded Pedestrian Plaza',
      latitude: 18.5398,
      longitude: 73.8078,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Vetal Tekdi Nature Reserve',
      address: 'Senapati Bapat Road / Kothrud, Pune',
      category: 'Sanctuaries',
      badge: 'Zero Traffic • Forest Trail',
      latitude: 18.5284,
      longitude: 73.8182,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Pu La Deshpande Japanese Garden',
      address: 'Sinhagad Road, Pune',
      category: 'Sanctuaries',
      badge: 'Silence Observed • Koi Ponds',
      latitude: 18.4912,
      longitude: 73.8344,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'British Council Silent Reading Room',
      address: 'FC Road, Shivajinagar, Pune',
      category: 'Safe Space / Library',
      badge: 'Strict Silence • Soft Seating',
      latitude: 18.5298,
      longitude: 73.8443,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Saras Baug Lakeside Sanctuary',
      address: 'Swargate, Pune',
      category: 'Water Promenades',
      badge: 'Lakeside Shaded Lawns',
      latitude: 18.5009,
      longitude: 73.8540,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Pune University Heritage Woodlands',
      address: 'Ganeshkhind, Pune',
      category: 'Parks & Greenery',
      badge: 'Eucalyptus Canopy Walk',
      latitude: 18.5529,
      longitude: 73.8246,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Aga Khan Palace Memorial Lawns',
      address: 'Kalyani Nagar, Pune',
      category: 'Sanctuaries',
      badge: 'Peaceful Memorial Grounds',
      latitude: 18.5524,
      longitude: 73.9015,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Kamala Nehru Park',
      address: 'Prabhat Road, Erandwane, Pune',
      category: 'Parks & Greenery',
      badge: 'Gentle Shaded Walkway',
      latitude: 18.5140,
      longitude: 73.8335,
      isCalmCurated: true,
    ),
    PlaceSearchResult(
      name: 'Taljai Hills Forest Trail',
      address: 'Sahakar Nagar, Pune',
      category: 'Sanctuaries',
      badge: 'Forest Bird Sanctuary',
      latitude: 18.4815,
      longitude: 73.8491,
      isCalmCurated: true,
    ),
  ];

  /// Returns real-time suggestions dynamically tailored to user's current city / coordinates
  static List<PlaceSearchResult> getSuggestionsForLocation({
    required double userLat,
    required double userLng,
  }) {
    final distToPune = LocationService.calculateDistanceMeters(userLat, userLng, 18.5204, 73.8567);
    final distToBlr = LocationService.calculateDistanceMeters(userLat, userLng, 12.9716, 77.5946);

    List<PlaceSearchResult> basePlaces;
    if (distToPune < 250000) {
      basePlaces = curatedPunePlaces;
    } else if (distToBlr < 250000) {
      basePlaces = curatedCalmPlaces;
    } else {
      basePlaces = [...curatedPunePlaces, ...curatedCalmPlaces];
    }

    final decorated = basePlaces.map((p) {
      final dist = LocationService.calculateDistanceMeters(userLat, userLng, p.latitude, p.longitude);
      return p.copyWith(distanceMeters: dist);
    }).toList();

    decorated.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
    return decorated;
  }

  /// Instant 0ms local match resolution for curated places and city landmarks
  static List<PlaceSearchResult> getLocalMatches(
    String query, {
    required double userLat,
    required double userLng,
  }) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return getSuggestionsForLocation(userLat: userLat, userLng: userLng);
    }
    final allCurated = [...curatedPunePlaces, ...curatedCalmPlaces];
    final matches = allCurated.where((p) {
      return p.name.toLowerCase().contains(clean) ||
          p.address.toLowerCase().contains(clean) ||
          p.category.toLowerCase().contains(clean);
    }).toList();

    final decorated = matches.map((p) {
      final dist = LocationService.calculateDistanceMeters(userLat, userLng, p.latitude, p.longitude);
      return p.copyWith(distanceMeters: dist);
    }).toList();

    decorated.sort((a, b) => (a.distanceMeters ?? double.infinity).compareTo(b.distanceMeters ?? double.infinity));
    return decorated;
  }

  /// Performs fast universal geocoding & autocomplete across any place or address worldwide.
  Future<List<PlaceSearchResult>> searchPlaces(
    String query, {
    double userLat = 12.9716,
    double userLng = 77.5946,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return getSuggestionsForLocation(userLat: userLat, userLng: userLng);
    }

    final cacheKey = '${cleanQuery.toLowerCase()}_${userLat.toStringAsFixed(2)}_${userLng.toStringAsFixed(2)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // 1. First, check if query matches any coordinate formats like "12.97, 77.59"
    final coordMatch = RegExp(r'^\s*([-+]?\d+(\.\d+)?)\s*,\s*([-+]?\d+(\.\d+)?)\s*$').firstMatch(cleanQuery);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1) ?? '');
      final lng = double.tryParse(coordMatch.group(3) ?? '');
      if (lat != null && lng != null) {
        final dist = LocationService.calculateDistanceMeters(userLat, userLng, lat, lng);
        final pinResult = [
          PlaceSearchResult(
            name: 'GPS Coordinates ($lat, $lng)',
            address: 'Custom Coordinate Pin on World Map',
            latitude: lat,
            longitude: lng,
            category: 'Coordinates',
            badge: 'Direct Pin',
            distanceMeters: dist,
          ),
        ];
        _cache[cacheKey] = pinResult;
        return pinResult;
      }
    }

    // 2. Search local curated calm spots matching query
    final allCurated = [...curatedPunePlaces, ...curatedCalmPlaces];
    final localMatches = allCurated.where((p) {
      final qLower = cleanQuery.toLowerCase();
      return p.name.toLowerCase().contains(qLower) ||
          p.address.toLowerCase().contains(qLower) ||
          p.category.toLowerCase().contains(qLower);
    }).toList();

    // 3. Query Open-Source Photon Geocoding API (OpenStreetMap worldwide data)
    List<PlaceSearchResult> globalResults = [];
    try {
      final photonUrl =
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&lat=$userLat&lon=$userLng&limit=8';
      final response = await _dio.get(photonUrl);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final features = data['features'] as List<dynamic>? ?? [];

        for (final feature in features) {
          final props = feature['properties'] as Map<String, dynamic>? ?? {};
          final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geometry['coordinates'] as List<dynamic>? ?? [];

          if (coords.length >= 2) {
            final lng = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final name = props['name']?.toString() ?? props['street']?.toString() ?? cleanQuery;

            final addressParts = <String>[];
            if (props['street'] != null && props['street'] != name) {
              final street = props['street'].toString();
              final houseNum = props['housenumber']?.toString();
              addressParts.add(houseNum != null ? '$houseNum $street' : street);
            }
            if (props['district'] != null) addressParts.add(props['district'].toString());
            if (props['city'] != null) addressParts.add(props['city'].toString());
            if (props['state'] != null) addressParts.add(props['state'].toString());
            if (props['country'] != null) addressParts.add(props['country'].toString());

            final formattedAddress = addressParts.isNotEmpty ? addressParts.join(', ') : 'Nearby Location';

            final osmValue = props['osm_value']?.toString().toLowerCase() ?? '';
            String category = 'Place of Interest';
            String badge = 'Global Place';

            if (osmValue.contains('park') || osmValue.contains('garden') || osmValue.contains('nature')) {
              category = 'Parks & Greenery';
              badge = 'Green Canopy';
            } else if (osmValue.contains('library') || osmValue.contains('temple') || osmValue.contains('museum')) {
              category = 'Sanctuaries';
              badge = 'Low Noise';
            } else if (osmValue.contains('water') || osmValue.contains('lake') || osmValue.contains('river')) {
              category = 'Water Promenades';
              badge = 'Waterfront';
            } else if (osmValue.contains('station') || osmValue.contains('transit') || osmValue.contains('subway')) {
              category = 'Transit';
              badge = 'Transit Hub';
            }

            final dist = LocationService.calculateDistanceMeters(userLat, userLng, lat, lng);

            globalResults.add(
              PlaceSearchResult(
                name: name,
                address: formattedAddress,
                latitude: lat,
                longitude: lng,
                category: category,
                badge: badge,
                distanceMeters: dist,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[GeocodingService] Photon query error: $e. Falling back to Nominatim...');
      globalResults = await _fallbackNominatimSearch(cleanQuery, userLat, userLng);
    }

    // 4. City-Aware Google Maps Ranking:
    // Sort local matches by proximity
    final decoratedLocal = _decorateDistances(localMatches, userLat, userLng);
    decoratedLocal.sort((a, b) => (a.distanceMeters ?? double.infinity).compareTo(b.distanceMeters ?? double.infinity));

    // Sort global results by proximity
    globalResults.sort((a, b) => (a.distanceMeters ?? double.infinity).compareTo(b.distanceMeters ?? double.infinity));

    // Merge: Nearby same-city places (< 45km) come first, followed by others
    final combined = <PlaceSearchResult>[];
    final seenNames = <String>{};

    // First add curated matches in same city / region
    for (final loc in decoratedLocal) {
      if ((loc.distanceMeters ?? 0) < 45000) {
        combined.add(loc);
        seenNames.add(loc.name.toLowerCase());
      }
    }

    // Next add global results in same city / region
    for (final glob in globalResults) {
      if ((glob.distanceMeters ?? 0) < 45000 && !seenNames.contains(glob.name.toLowerCase())) {
        combined.add(glob);
        seenNames.add(glob.name.toLowerCase());
      }
    }

    // Then remaining curated and global matches
    for (final loc in decoratedLocal) {
      if (!seenNames.contains(loc.name.toLowerCase())) {
        combined.add(loc);
        seenNames.add(loc.name.toLowerCase());
      }
    }

    for (final glob in globalResults) {
      if (!seenNames.contains(glob.name.toLowerCase())) {
        combined.add(glob);
        seenNames.add(glob.name.toLowerCase());
      }
    }

    _cache[cacheKey] = combined;
    return combined;
  }

  /// OpenStreetMap Nominatim fallback if Photon is unavailable
  Future<List<PlaceSearchResult>> _fallbackNominatimSearch(
    String query,
    double userLat,
    double userLng,
  ) async {
    final results = <PlaceSearchResult>[];
    try {
      final nominatimUrl =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=6';
      final response = await _dio.get(nominatimUrl);

      if (response.statusCode == 200 && response.data != null) {
        final list = response.data is List ? response.data as List : [];
        for (final item in list) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lng = double.tryParse(item['lon']?.toString() ?? '');
          final displayName = item['display_name']?.toString() ?? query;

          if (lat != null && lng != null) {
            final split = displayName.split(',');
            final name = split.first.trim();
            final address = split.skip(1).take(3).map((s) => s.trim()).join(', ');
            final dist = LocationService.calculateDistanceMeters(userLat, userLng, lat, lng);

            results.add(
              PlaceSearchResult(
                name: name,
                address: address.isNotEmpty ? address : 'Global Address',
                latitude: lat,
                longitude: lng,
                category: 'Place of Interest',
                badge: 'OpenStreetMap',
                distanceMeters: dist,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[GeocodingService] Nominatim fallback error: $e');
    }
    return results;
  }

  List<PlaceSearchResult> _decorateDistances(
    List<PlaceSearchResult> places,
    double userLat,
    double userLng,
  ) {
    return places.map((p) {
      final dist = LocationService.calculateDistanceMeters(userLat, userLng, p.latitude, p.longitude);
      return p.copyWith(distanceMeters: dist);
    }).toList();
  }
}
