import 'dart:math' as math;
import 'package:flutter/material.dart';

enum TileProviderType {
  esriStreet,
  esriCanvas,
  openStreetMap,
  cartoPositron,
}

class SensoryTileLayer extends StatelessWidget {
  final double width;
  final double height;
  final double centerLat;
  final double centerLng;
  final int zoom;
  final TileProviderType providerType;
  final double opacity;
  final bool isVisible;

  const SensoryTileLayer({
    super.key,
    required this.width,
    required this.height,
    this.centerLat = 12.9770,
    this.centerLng = 77.5910,
    this.zoom = 14,
    this.providerType = TileProviderType.esriStreet,
    this.opacity = 0.82,
    this.isVisible = true,
  });

  String _getTileUrl(int z, int x, int y) {
    switch (providerType) {
      case TileProviderType.esriStreet:
        // High-resolution real-time street cartography with roads, parks, and landmarks
        return 'https://services.arcgisonline.com/arcgis/rest/services/World_Street_Map/MapServer/tile/$z/$y/$x';
      case TileProviderType.esriCanvas:
        // Muted monochrome gray canvas
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

    final n = math.pow(2.0, zoom).toDouble();
    final centerTileX = n * ((centerLng + 180.0) / 360.0);
    final latRad = centerLat * math.pi / 180.0;
    final centerTileY = n * (1.0 - (math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi)) / 2.0;

    const tileSize = 256.0;
    final tilesNeededX = (width / tileSize).ceil() + 2;
    final tilesNeededY = (height / tileSize).ceil() + 2;

    final baseTileX = centerTileX.floor();
    final baseTileY = centerTileY.floor();

    final offsetX = (centerTileX - baseTileX) * tileSize;
    final offsetY = (centerTileY - baseTileY) * tileSize;

    final centerX = width / 2.0;
    final centerY = height / 2.0;

    final startCol = -(tilesNeededX ~/ 2);
    final endCol = tilesNeededX ~/ 2 + 1;
    final startRow = -(tilesNeededY ~/ 2);
    final endRow = tilesNeededY ~/ 2 + 1;

    final maxTileIndex = math.pow(2, zoom).toInt();

    final List<Widget> tileWidgets = [];

    for (int col = startCol; col <= endCol; col++) {
      for (int row = startRow; row <= endRow; row++) {
        final tileX = (baseTileX + col) % maxTileIndex;
        final tileY = (baseTileY + row);

        if (tileY < 0 || tileY >= maxTileIndex) continue;

        final left = centerX + (col * tileSize) - offsetX;
        final top = centerY + (row * tileSize) - offsetY;

        final url = _getTileUrl(zoom, tileX, tileY);

        tileWidgets.add(
          Positioned(
            left: left,
            top: top,
            width: tileSize,
            height: tileSize,
            child: Opacity(
              opacity: opacity,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                headers: const {
                  'User-Agent': 'QuietPath/1.0 (contact@quietpath.app)',
                },
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFFEFF2EE),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFFBDD9BB),
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (ctx, err, stack) {
                  debugPrint('TILE_ERROR: $url -> $err');
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2EE),
                      border: Border.all(color: const Color(0xFFE0E5DF), width: 0.5),
                    ),
                  );
                },
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
          // Sensory tint backing
          Container(color: const Color(0xFFEFF2EE)),
          ...tileWidgets,
        ],
      ),
    );
  }
}
