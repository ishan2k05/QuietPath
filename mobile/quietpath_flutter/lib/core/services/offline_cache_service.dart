import 'package:flutter/foundation.dart';

/// Lightweight in-memory and local fallback cache for offline sensory navigation.
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;

  OfflineCacheService._internal();

  final Map<String, dynamic> _memoryCache = {};

  void cacheData(String key, dynamic data) {
    _memoryCache[key] = {
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    };
    debugPrint('[OfflineCache] Cached key: $key');
  }

  T? getCachedData<T>(String key) {
    if (_memoryCache.containsKey(key)) {
      final entry = _memoryCache[key] as Map<String, dynamic>;
      debugPrint('[OfflineCache] Retrieved cached key: $key');
      return entry['data'] as T?;
    }
    return null;
  }

  bool hasKey(String key) => _memoryCache.containsKey(key);

  void clear() {
    _memoryCache.clear();
  }
}
