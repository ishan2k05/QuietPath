import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quietpath_flutter/core/network/api_client.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';
import 'package:quietpath_flutter/core/services/local_database_service.dart';

class SafeSpaceItem {
  final String id;
  final String name;
  final String category;
  final double distanceMiles;
  final int capacityPercentage;
  final String capacityStatus;
  final List<String> featureTags;
  final String? quietZoneInfo;
  final String? bestSpot;
  final int? sensoryMatchScore;

  SafeSpaceItem({
    required this.id,
    required this.name,
    required this.category,
    required this.distanceMiles,
    required this.capacityPercentage,
    required this.capacityStatus,
    required this.featureTags,
    this.quietZoneInfo,
    this.bestSpot,
    this.sensoryMatchScore,
  });

  factory SafeSpaceItem.fromJson(Map<String, dynamic> json) {
    return SafeSpaceItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      distanceMiles: (json['distance_miles'] as num).toDouble(),
      capacityPercentage: json['capacity_percentage'] as int,
      capacityStatus: json['capacity_status'] as String,
      featureTags: (json['feature_tags'] as List<dynamic>).map((e) => e.toString()).toList(),
      quietZoneInfo: json['quiet_zone_info'] as String?,
      bestSpot: json['best_spot'] as String?,
      sensoryMatchScore: json['sensory_match_score'] as int?,
    );
  }
}

final selectedSpaceTagProvider = StateProvider<String>((ref) => 'All');

final safeSpacesProvider = FutureProvider<List<SafeSpaceItem>>((ref) async {
  final tag = ref.watch(selectedSpaceTagProvider);
  final userLocation = ref.watch(userLocationProvider);

  try {
    final dio = ApiClient().dio;
    final queryParams = <String>[];
    if (tag != 'All' && tag != 'Filters') {
      queryParams.add('tag=${Uri.encodeComponent(tag)}');
    }
    queryParams.add('lat=${userLocation.latitude}');
    queryParams.add('lng=${userLocation.longitude}');
    final queryString = '?${queryParams.join('&')}';

    final response = await dio.get('/places/safe-spaces$queryString');
    final rawList = response.data['safe_spaces'] as List<dynamic>;
    final items = rawList.map((e) => SafeSpaceItem.fromJson(e as Map<String, dynamic>)).toList();

    // Cache locally for offline APK persistence
    LocalDatabaseService().saveSafeSpaces(items.map((i) => {
      'id': i.id,
      'name': i.name,
      'category': i.category,
      'distance_miles': i.distanceMiles,
      'capacity_percentage': i.capacityPercentage,
      'capacity_status': i.capacityStatus,
      'feature_tags': i.featureTags,
      'quiet_zone_info': i.quietZoneInfo,
      'best_spot': i.bestSpot,
      'sensory_match_score': i.sensoryMatchScore,
    }).toList());

    return items;
  } catch (e) {
    // Offline local database fallback
    final cached = LocalDatabaseService().getCachedSafeSpaces();
    if (cached.isNotEmpty) {
      final cachedItems = cached.map((e) => SafeSpaceItem.fromJson(e)).toList();
      return _filterByTag(cachedItems, tag);
    }

    final distToPune = LocationService.calculateDistanceMeters(userLocation.latitude, userLocation.longitude, 18.5204, 73.8567);
    final isPune = distToPune < 250000;

    final allSpaces = isPune
        ? [
            SafeSpaceItem(
              id: 'sp_pune_1',
              name: 'Osho Teerth Bamboo Sanctuary',
              category: 'Park / Nature',
              distanceMiles: 0.6,
              capacityPercentage: 18,
              capacityStatus: 'Empty',
              featureTags: ['Silence Required', 'Natural Environment', 'Dense Canopy'],
              quietZoneInfo: 'Zen Bamboo Grove',
              bestSpot: 'Stream Shaded Pavilion',
              sensoryMatchScore: 96,
            ),
            SafeSpaceItem(
              id: 'sp_pune_5',
              name: 'British Council Silent Reading Room',
              category: 'Library',
              distanceMiles: 0.9,
              capacityPercentage: 28,
              capacityStatus: 'Low',
              featureTags: ['Silence Required', 'Soft Seating', 'Air Conditioned'],
              quietZoneInfo: 'Silent Reading Floor 2',
              bestSpot: 'North Study Carrel',
              sensoryMatchScore: 94,
            ),
            SafeSpaceItem(
              id: 'sp_pune_2',
              name: 'Empress Botanical Garden',
              category: 'Botanical Garden',
              distanceMiles: 1.4,
              capacityPercentage: 35,
              capacityStatus: 'Low',
              featureTags: ['Natural Environment', 'White Noise (Fountain)', 'Shaded Trees'],
              quietZoneInfo: 'Heritage Banyan Lawn',
              bestSpot: 'Canopy Pavilion',
              sensoryMatchScore: 92,
            ),
            SafeSpaceItem(
              id: 'sp_pune_3',
              name: 'Vetal Tekdi Hilltop Nature Refuge',
              category: 'Nature Reserve',
              distanceMiles: 1.8,
              capacityPercentage: 15,
              capacityStatus: 'Empty',
              featureTags: ['Silence Required', 'Natural Environment', 'Zero Traffic'],
              quietZoneInfo: 'Forest Trail Crest',
              bestSpot: 'Sunrise Stone Outcrop',
              sensoryMatchScore: 95,
            ),
            SafeSpaceItem(
              id: 'sp_pune_4',
              name: 'Pu La Deshpande Tranquility Garden',
              category: 'Zen Garden',
              distanceMiles: 2.2,
              capacityPercentage: 25,
              capacityStatus: 'Low',
              featureTags: ['Silence Required', 'Water White Noise', 'Natural Landscape'],
              quietZoneInfo: 'Koi Pond & Water Stream',
              bestSpot: 'Wooden Meditation Bridge',
              sensoryMatchScore: 91,
            ),
          ]
        : [
            SafeSpaceItem(
              id: 'sp_1',
              name: 'Central Public Library',
              category: 'Library',
              distanceMiles: 0.3,
              capacityPercentage: 25,
              capacityStatus: 'Empty',
              featureTags: ['Silence Required', 'Soft Seating'],
              quietZoneInfo: 'Quiet Zone: Floor 3',
              sensoryMatchScore: 94,
            ),
            SafeSpaceItem(
              id: 'sp_4',
              name: 'Cubbon Park Bamboo Grove',
              category: 'Park / Nature',
              distanceMiles: 0.4,
              capacityPercentage: 15,
              capacityStatus: 'Empty',
              featureTags: ['Silence Required', 'Natural Environment', 'Dense Canopy'],
              quietZoneInfo: 'Inner Grove Sanctuary',
              sensoryMatchScore: 96,
            ),
            SafeSpaceItem(
              id: 'sp_2',
              name: 'Botanical Gardens Conservatory',
              category: 'Park / Nature',
              distanceMiles: 0.8,
              capacityPercentage: 40,
              capacityStatus: 'Low',
              featureTags: ['Natural Environment', 'White Noise (Fountain)'],
              bestSpot: 'Fern Room',
              sensoryMatchScore: 91,
            ),
            SafeSpaceItem(
              id: 'sp_5',
              name: 'National Gallery of Modern Art',
              category: 'Museum / Gallery',
              distanceMiles: 1.1,
              capacityPercentage: 30,
              capacityStatus: 'Low',
              featureTags: ['Soft Lighting', 'Silence Required', 'Air Conditioned'],
              quietZoneInfo: 'Sculpture Garden & Gallery 2',
              sensoryMatchScore: 89,
            ),
          ];

    return _filterByTag(allSpaces, tag);
  }
});

List<SafeSpaceItem> _filterByTag(List<SafeSpaceItem> items, String tag) {
  if (tag == 'Low Noise') {
    return items.where((s) => s.featureTags.any((t) => t.contains('Silence') || t.contains('Natural'))).toList();
  } else if (tag == 'Low Crowd') {
    return items.where((s) => s.capacityStatus == 'Empty' || s.capacityStatus == 'Low').toList();
  } else if (tag == 'Silence Required') {
    return items.where((s) => s.featureTags.any((t) => t.contains('Silence'))).toList();
  }
  return items;
}
