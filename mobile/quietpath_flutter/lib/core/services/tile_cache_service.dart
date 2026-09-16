import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_tile_layer.dart';

/// Metadata describing local offline map tile storage
class TileCacheInfo {
  final int tileCount;
  final double sizeInMb;
  final bool isPunePackInstalled;

  const TileCacheInfo({
    required this.tileCount,
    required this.sizeInMb,
    required this.isPunePackInstalled,
  });
}

/// Offline slippy map tile cache manager.
/// Persists downloaded map tiles to the local device filesystem for uninterrupted
/// sensory navigation in low-signal environments, tunnels, and deep nature sanctuaries.
class TileCacheService {
  static final TileCacheService _instance = TileCacheService._internal();
  factory TileCacheService() => _instance;

  TileCacheService._internal();

  Directory? _cacheDir;
  final Set<String> _inFlightFetches = {};
  final Set<String> _knownExistingTiles = {};

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      },
    ),
  );

  /// Returns the persistent cache directory for offline map tiles
  Future<Directory> get cacheDir async {
    if (_cacheDir != null) return _cacheDir!;
    Directory baseDir;
    try {
      if (Platform.isAndroid) {
        final androidDir = Directory('/data/user/0/com.example.quietpath_flutter/files');
        if (androidDir.existsSync()) {
          baseDir = androidDir;
        } else {
          final fallbackDir = Directory('/data/data/com.example.quietpath_flutter/files');
          baseDir = fallbackDir.existsSync() ? fallbackDir : Directory.systemTemp;
        }
      } else {
        baseDir = Directory.systemTemp;
      }
    } catch (_) {
      baseDir = Directory.systemTemp;
    }
    final dir = Directory('${baseDir.path}/map_tiles_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Generates a unique, sanitized file cache key for a tile coordinate
  String getTileKey(TileProviderType provider, int z, int x, int y) {
    return '${provider.name}_${z}_${x}_$y.png';
  }

  /// Checks if a tile file exists in the offline local disk cache
  Future<File?> getCachedTileFile(TileProviderType provider, int z, int x, int y) async {
    final key = getTileKey(provider, z, x, y);
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/$key');
      if (_knownExistingTiles.contains(key) || (await file.exists() && (await file.length()) > 100)) {
        _knownExistingTiles.add(key);
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Saves tile raw binary data to offline persistent cache
  Future<File?> saveTileToCache(TileProviderType provider, int z, int x, int y, List<int> bytes) async {
    final key = getTileKey(provider, z, x, y);
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/$key');
      await file.writeAsBytes(bytes, flush: true);
      _knownExistingTiles.add(key);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Fetches a tile, checking disk cache first before performing network request
  Future<File?> fetchAndCacheTile(TileProviderType provider, int z, int x, int y) async {
    final key = getTileKey(provider, z, x, y);

    // Fast-path: check if tile is already known to be cached
    if (_knownExistingTiles.contains(key)) {
      return getCachedTileFile(provider, z, x, y);
    }

    // Suppress redundant concurrent downloads for the exact same tile
    if (_inFlightFetches.contains(key)) {
      return null;
    }

    _inFlightFetches.add(key);
    try {
      final cached = await getCachedTileFile(provider, z, x, y);
      if (cached != null) return cached;

      final primaryUrl = SensoryTileLayer.getTileUrl(provider, z, x, y);
      try {
        final response = await _dio.get<List<int>>(
          primaryUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.statusCode == 200 && response.data != null) {
          return await saveTileToCache(provider, z, x, y, response.data!);
        }
      } catch (_) {
        // Try fallback provider on failure
        try {
          final fallbackUrl = (provider == TileProviderType.esriStreet)
              ? SensoryTileLayer.getTileUrl(TileProviderType.cartoPositron, z, x, y)
              : SensoryTileLayer.getTileUrl(TileProviderType.esriStreet, z, x, y);
          final resFallback = await _dio.get<List<int>>(
            fallbackUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          if (resFallback.statusCode == 200 && resFallback.data != null) {
            return await saveTileToCache(provider, z, x, y, resFallback.data!);
          }
        } catch (_) {}
      }
      return null;
    } finally {
      _inFlightFetches.remove(key);
    }
  }

  /// Pre-caches tiles along an active sensory route polyline
  /// so navigation continues uninterrupted without cellular coverage.
  Future<void> precacheRouteTiles({
    required List<UserCoordinates> waypoints,
    TileProviderType provider = TileProviderType.googleRoads,
    int zoom = 15,
  }) async {
    if (waypoints.isEmpty) return;

    try {
      final Set<String> tileCoordinates = {};
      for (final wp in waypoints) {
        final px = MercatorProjection.lngToPixelX(wp.longitude, zoom.toDouble());
        final py = MercatorProjection.latToPixelY(wp.latitude, zoom.toDouble());
        final tx = (px / MercatorProjection.tileSize).floor();
        final ty = (py / MercatorProjection.tileSize).floor();

        // Cache 3x3 surrounding tiles for smooth navigation buffer
        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            tileCoordinates.add('$zoom,${tx + dx},${ty + dy}');
          }
        }
      }

      // Download up to 30 route tiles in background
      final sample = tileCoordinates.take(30).toList();
      for (final coord in sample) {
        final parts = coord.split(',').map(int.parse).toList();
        await fetchAndCacheTile(provider, parts[0], parts[1], parts[2]);
      }
      debugPrint('[TileCacheService] Successfully pre-cached ${sample.length} tiles for route');
    } catch (e) {
      debugPrint('[TileCacheService] Route precache notice: $e');
    }
  }

  /// Calculates storage statistics of cached tiles
  Future<TileCacheInfo> getCachedTilesInfo() async {
    try {
      final dir = await cacheDir;
      if (!await dir.exists()) {
        return const TileCacheInfo(tileCount: 0, sizeInMb: 0.0, isPunePackInstalled: false);
      }
      final files = dir.listSync().whereType<File>().toList();
      final tileFiles = files.where((f) => f.path.endsWith('.png')).toList();
      int totalBytes = 0;
      for (final f in tileFiles) {
        totalBytes += f.lengthSync();
      }
      final sizeMb = totalBytes / (1024 * 1024);
      final isInstalled = tileFiles.length >= 60;
      return TileCacheInfo(
        tileCount: tileFiles.length,
        sizeInMb: double.parse(sizeMb.toStringAsFixed(1)),
        isPunePackInstalled: isInstalled,
      );
    } catch (_) {
      return const TileCacheInfo(tileCount: 0, sizeInMb: 0.0, isPunePackInstalled: false);
    }
  }

  /// Clears all cached tiles from local storage
  Future<void> clearTileCache() async {
    try {
      final dir = await cacheDir;
      if (await dir.exists()) {
        final files = dir.listSync().whereType<File>().toList();
        for (final f in files) {
          if (f.path.endsWith('.png')) {
            try {
              f.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  /// Downloads full city offline tile pack for uninterrupted calm navigation
  Future<int> downloadCityTilePack({
    double centerLat = 18.510408,
    double centerLng = 73.937475,
    String cityName = 'Pune Hadapsar',
    List<int> zoomLevels = const [13, 14, 15],
    double radiusKm = 3.5,
    TileProviderType provider = TileProviderType.googleRoads,
    void Function(int completed, int total, double percent)? onProgress,
  }) async {
    final List<({int z, int x, int y})> allTiles = [];
    final deltaLat = radiusKm / 111.0;
    final deltaLng = radiusKm / (111.0 * math.cos(centerLat * math.pi / 180.0));

    final minLat = centerLat - deltaLat;
    final maxLat = centerLat + deltaLat;
    final minLng = centerLng - deltaLng;
    final maxLng = centerLng + deltaLng;

    for (final z in zoomLevels) {
      final minPxX = MercatorProjection.lngToPixelX(minLng, z.toDouble());
      final maxPxX = MercatorProjection.lngToPixelX(maxLng, z.toDouble());
      final minPxY = MercatorProjection.latToPixelY(maxLat, z.toDouble());
      final maxPxY = MercatorProjection.latToPixelY(minLat, z.toDouble());

      final minTileX = (minPxX / MercatorProjection.tileSize).floor();
      final maxTileX = (maxPxX / MercatorProjection.tileSize).floor();
      final minTileY = (minPxY / MercatorProjection.tileSize).floor();
      final maxTileY = (maxPxY / MercatorProjection.tileSize).floor();

      for (int x = minTileX; x <= maxTileX; x++) {
        for (int y = minTileY; y <= maxTileY; y++) {
          allTiles.add((z: z, x: x, y: y));
        }
      }
    }

    final total = allTiles.length;
    int completed = 0;
    onProgress?.call(0, total, 0.0);

    // Concurrently download in batches of 4
    const batchSize = 4;
    for (int i = 0; i < allTiles.length; i += batchSize) {
      final batch = allTiles.sublist(i, math.min(i + batchSize, allTiles.length));
      await Future.wait(batch.map((tile) async {
        await fetchAndCacheTile(provider, tile.z, tile.x, tile.y);
        completed++;
        final pct = (completed / total).clamp(0.0, 1.0);
        onProgress?.call(completed, total, pct);
      }));
    }

    return completed;
  }
}
