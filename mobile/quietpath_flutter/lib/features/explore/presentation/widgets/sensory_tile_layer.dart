import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quietpath_flutter/core/services/tile_cache_service.dart';

enum TileProviderType {
  googleRoads,
  googleTerrain,
  esriStreet,
  esriCanvas,
  openStreetMap,
  cartoPositron,
}

class MercatorProjection {
  static const double tileSize = 256.0;

  static double lngToPixelX(double lng, double zoom) {
    final n = math.pow(2.0, zoom).toDouble();
    return (lng + 180.0) / 360.0 * tileSize * n;
  }

  static double latToPixelY(double lat, double zoom) {
    final n = math.pow(2.0, zoom).toDouble();
    final latRad = lat.clamp(-85.0511, 85.0511) * math.pi / 180.0;
    return (1.0 - (math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi)) / 2.0 * tileSize * n;
  }

  static double pixelXToLng(double pixelX, double zoom) {
    final n = math.pow(2.0, zoom).toDouble();
    return (pixelX / (tileSize * n)) * 360.0 - 180.0;
  }

  static double pixelYToLat(double pixelY, double zoom) {
    final n = math.pow(2.0, zoom).toDouble();
    final yNorm = 1.0 - 2.0 * (pixelY / (tileSize * n));
    final latRad = 2.0 * math.atan(math.exp(yNorm * math.pi)) - math.pi / 2.0;
    return latRad * 180.0 / math.pi;
  }

  static Offset latLngToScreen({
    required double lat,
    required double lng,
    required double centerLat,
    required double centerLng,
    required double zoom,
    required Size screenSize,
  }) {
    final targetX = lngToPixelX(lng, zoom);
    final targetY = latToPixelY(lat, zoom);
    final centerX = lngToPixelX(centerLng, zoom);
    final centerY = latToPixelY(centerLat, zoom);

    final screenX = (targetX - centerX) + (screenSize.width / 2.0);
    final screenY = (targetY - centerY) + (screenSize.height / 2.0);
    return Offset(screenX, screenY);
  }

  static ({double lat, double lng}) screenToLatLng({
    required Offset screenPos,
    required double centerLat,
    required double centerLng,
    required double zoom,
    required Size screenSize,
  }) {
    final centerX = lngToPixelX(centerLng, zoom);
    final centerY = latToPixelY(centerLat, zoom);

    final targetPixelX = centerX + (screenPos.dx - screenSize.width / 2.0);
    final targetPixelY = centerY + (screenPos.dy - screenSize.height / 2.0);

    final lng = pixelXToLng(targetPixelX, zoom);
    final lat = pixelYToLat(targetPixelY, zoom);
    return (lat: lat, lng: lng);
  }
}

class SensoryTileLayer extends StatelessWidget {
  final double width;
  final double height;
  final double centerLat;
  final double centerLng;
  final double zoom;
  final TileProviderType providerType;
  final double opacity;
  final bool isVisible;

  const SensoryTileLayer({
    super.key,
    required this.width,
    required this.height,
    this.centerLat = 12.9770,
    this.centerLng = 77.5910,
    this.zoom = 14.0,
    this.providerType = TileProviderType.googleRoads,
    this.opacity = 0.95,
    this.isVisible = true,
  });

  static String getTileUrl(TileProviderType provider, int z, int x, int y) {
    switch (provider) {
      case TileProviderType.googleRoads:
        final s = (x + y).abs() % 4;
        return 'https://mt$s.google.com/vt/lyrs=m&x=$x&y=$y&z=$z&hl=en';
      case TileProviderType.googleTerrain:
        final s = (x + y).abs() % 4;
        return 'https://mt$s.google.com/vt/lyrs=p&x=$x&y=$y&z=$z&hl=en';
      case TileProviderType.esriStreet:
        return 'https://services.arcgisonline.com/arcgis/rest/services/World_Street_Map/MapServer/tile/$z/$y/$x';
      case TileProviderType.esriCanvas:
        return 'https://services.arcgisonline.com/arcgis/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/$z/$y/$x';
      case TileProviderType.openStreetMap:
        return 'https://tile.openstreetmap.org/$z/$x/$y.png';
      case TileProviderType.cartoPositron:
        final subdomains = ['a', 'b', 'c', 'd'];
        final sub = subdomains[(x + y).abs() % subdomains.length];
        return 'https://cartodb-basemaps-$sub.global.ssl.fastly.net/light_all/$z/$x/$y.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || width <= 0 || height <= 0) {
      return const SizedBox.shrink();
    }

    final clampedZoom = zoom.clamp(3.0, 19.0);
    final baseZoom = clampedZoom.floor();
    final scale = math.pow(2.0, clampedZoom - baseZoom).toDouble();

    // Center in baseZoom pixel coordinates
    final centerPixelX = MercatorProjection.lngToPixelX(centerLng, baseZoom.toDouble());
    final centerPixelY = MercatorProjection.latToPixelY(centerLat, baseZoom.toDouble());

    // Viewport dimensions in baseZoom pixel coordinates
    final viewWidthAtBase = width / scale;
    final viewHeightAtBase = height / scale;

    final viewMinX = centerPixelX - viewWidthAtBase / 2.0;
    final viewMaxX = centerPixelX + viewWidthAtBase / 2.0;
    final viewMinY = centerPixelY - viewHeightAtBase / 2.0;
    final viewMaxY = centerPixelY + viewHeightAtBase / 2.0;

    const tileSize = MercatorProjection.tileSize;
    // Buffer by 1 tile in every direction for crisp smooth loading without HTTP flood
    final minTileX = (viewMinX / tileSize).floor() - 1;
    final maxTileX = (viewMaxX / tileSize).floor() + 1;
    final minTileY = (viewMinY / tileSize).floor() - 1;
    final maxTileY = (viewMaxY / tileSize).floor() + 1;

    final maxTileIndex = math.pow(2, baseZoom).toInt();

    final List<Widget> tileWidgets = [];

    for (int ty = minTileY; ty <= maxTileY; ty++) {
      if (ty < 0 || ty >= maxTileIndex) continue; // North and South poles boundary

      for (int tx = minTileX; tx <= maxTileX; tx++) {
        final wrappedTileX = ((tx % maxTileIndex) + maxTileIndex) % maxTileIndex;

        // Position on screen
        final screenLeft = (tx * tileSize - centerPixelX) * scale + (width / 2.0);
        final screenTop = (ty * tileSize - centerPixelY) * scale + (height / 2.0);
        final screenTileSize = tileSize * scale;

        final primaryUrl = getTileUrl(providerType, baseZoom, wrappedTileX, ty);
        final fallbackUrl = (providerType == TileProviderType.esriStreet)
            ? getTileUrl(TileProviderType.cartoPositron, baseZoom, wrappedTileX, ty)
            : getTileUrl(TileProviderType.esriStreet, baseZoom, wrappedTileX, ty);

        tileWidgets.add(
          Positioned(
            left: screenLeft,
            top: screenTop,
            width: screenTileSize + 0.5, // slight overlap to prevent hairline seams
            height: screenTileSize + 0.5,
            child: Opacity(
              opacity: opacity,
              child: ResilientMapTile(
                key: ValueKey('$baseZoom-$wrappedTileX-$ty'),
                primaryUrl: primaryUrl,
                fallbackUrl: fallbackUrl,
                providerType: providerType,
                z: baseZoom,
                x: wrappedTileX,
                y: ty,
              ),
            ),
          ),
        );
      }
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFFEFF2EE)),
          ...tileWidgets,
        ],
      ),
    );
  }
}

/// A highly resilient slippy tile image that tries local offline disk cache first,
/// then primary URL, automatically falling back to an alternate global tile server if blocked or unavailable.
class ResilientMapTile extends StatefulWidget {
  final String primaryUrl;
  final String fallbackUrl;
  final TileProviderType? providerType;
  final int? z;
  final int? x;
  final int? y;

  const ResilientMapTile({
    super.key,
    required this.primaryUrl,
    required this.fallbackUrl,
    this.providerType,
    this.z,
    this.x,
    this.y,
  });

  @override
  State<ResilientMapTile> createState() => _ResilientMapTileState();
}

class _ResilientMapTileState extends State<ResilientMapTile> {
  bool _useFallback = false;
  File? _cachedFile;

  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  };

  @override
  void initState() {
    super.initState();
    _checkLocalCache();
  }

  Future<void> _checkLocalCache() async {
    if (widget.providerType != null && widget.z != null && widget.x != null && widget.y != null) {
      final file = await TileCacheService().getCachedTileFile(
        widget.providerType!,
        widget.z!,
        widget.x!,
        widget.y!,
      );
      if (file != null && mounted) {
        setState(() {
          _cachedFile = file;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ResilientMapTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.primaryUrl != oldWidget.primaryUrl) {
      setState(() {
        _useFallback = false;
        _cachedFile = null;
      });
      _checkLocalCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedFile != null) {
      return Image.file(
        _cachedFile!,
        key: ValueKey(_cachedFile!.path),
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _buildNetworkTile(),
      );
    }
    return _buildNetworkTile();
  }

  Widget _buildNetworkTile() {
    final activeUrl = _useFallback ? widget.fallbackUrl : widget.primaryUrl;

    return Image.network(
      activeUrl,
      key: ValueKey(activeUrl),
      fit: BoxFit.cover,
      headers: _browserHeaders,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) {
          // Asynchronously persist tile into disk cache for offline access
          if (widget.providerType != null && widget.z != null && widget.x != null && widget.y != null) {
            TileCacheService().fetchAndCacheTile(
              widget.providerType!,
              widget.z!,
              widget.x!,
              widget.y!,
            );
          }
          return child;
        }
        return Container(color: const Color(0xFFEFF2EE));
      },
      errorBuilder: (ctx, err, stack) {
        if (!_useFallback) {
          // Switch immediately to fallback tile server without showing a blank screen
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _useFallback = true;
              });
            }
          });
          return Container(color: const Color(0xFFEFF2EE));
        }

        // Both primary and fallback failed - render subtle soft grid
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEFF2EE),
            border: Border.all(color: const Color(0xFFE4E9E3), width: 0.5),
          ),
        );
      },
    );
  }
}
