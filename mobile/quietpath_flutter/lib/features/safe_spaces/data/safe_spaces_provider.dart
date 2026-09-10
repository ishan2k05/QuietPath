import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quietpath_flutter/core/network/api_client.dart';

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
  try {
    final dio = ApiClient().dio;
    final query = (tag == 'All' || tag == 'Filters') ? '' : '?tag=${Uri.encodeComponent(tag)}';
    final response = await dio.get('/places/safe-spaces$query');
    final rawList = response.data['safe_spaces'] as List<dynamic>;
    return rawList.map((e) => SafeSpaceItem.fromJson(e as Map<String, dynamic>)).toList();
  } catch (e) {
    final allSpaces = [
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
      SafeSpaceItem(
        id: 'sp_3',
        name: 'Mute Coffee Shop',
        category: 'Cafe',
        distanceMiles: 1.2,
        capacityPercentage: 69,
        capacityStatus: 'Moderate',
        featureTags: ['Dim Lighting', 'No Background Music'],
        quietZoneInfo: 'Dedicated Quiet Hour: Now',
        sensoryMatchScore: 78,
      ),
    ];
    if (tag == 'Low Noise') {
      return allSpaces.where((s) => s.featureTags.any((t) => t.contains('Silence') || t.contains('Natural'))).toList();
    } else if (tag == 'Low Crowd') {
      return allSpaces.where((s) => s.capacityStatus == 'Empty' || s.capacityStatus == 'Low').toList();
    } else if (tag == 'Silence Required') {
      return allSpaces.where((s) => s.featureTags.any((t) => t.contains('Silence'))).toList();
    }
    return allSpaces;
  }
});
