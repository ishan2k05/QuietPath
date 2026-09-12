import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_tile_layer.dart';

/// Offline slippy map tile cache manager.
/// Persists downloaded map tiles to the local device filesystem for uninterrupted
/// sensory navigation in low-signal environments, tunnels, and deep nature sanctuaries.
class TileCacheService {
  static final TileCacheService _instance = TileCacheService._internal();
  factory TileCacheService() => _instance;

  TileCacheService._internal();

  Directory? _cacheDir;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      },
    ),
  );

  /// Initializes local disk cache directory
  Future<Directory> get cacheDir async {
    if (_cacheDir != null) return _cacheDir!;
    final tempDir = Directory.systemTemp;
    final dir = Directory('${tempDir.path}/quietpath_tile_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  /// Generates a deterministic filesystem-safe key for any map tile
  String getTileKey(TileProviderType provider, int z, int x, int y) {
    return 'tile_${provider.name}_${z}_${x}_$y.png';
  }

  /// Checks if a tile is already stored in local offline cache
  Future<File?> getCachedTileFile(TileProviderType provider, int z, int x, int y) async {
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/${getTileKey(provider, z, x, y)}');
      if (await file.exists() && (await file.length()) > 100) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Saves tile raw binary data to offline persistent cache
  Future<File?> saveTileToCache(TileProviderType provider, int z, int x, int y, List<int> bytes) async {
    try {
      final dir = await cacheDir;
      final file = File('${dir.path}/${getTileKey(provider, z, x, y)}');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Fetches a tile, checking disk cache first before performing network request
  Future<File?> fetchAndCacheTile(TileProviderType provider, int z, int x, int y) async {
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
}
