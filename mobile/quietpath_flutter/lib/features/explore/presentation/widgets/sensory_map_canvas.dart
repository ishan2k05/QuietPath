import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/features/explore/data/environmental_provider.dart';
import 'package:quietpath_flutter/features/explore/data/hazards_provider.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_tile_layer.dart';

class SensoryMapCanvas extends StatelessWidget {
  final bool isCalmestSelected;
  final String destinationName;
  final List<HazardData> hazards;
  final bool showSensoryZones;
  final String? selectedHazardId;
  final int? userStepIndex;
  final double? width;
  final double? height;
  final bool hasTileLayer;
  final bool isHardwareGps;
  final double? userLat;
  final double? userLng;
  final double? accuracy;
  final double? heading;
  final double cameraLat;
  final double cameraLng;
  final double zoom;
  final List<SurroundingZone>? surroundingZones;

  const SensoryMapCanvas({
    super.key,
    required this.isCalmestSelected,
    this.destinationName = 'Bangalore Golf Club',
    this.hazards = const [],
    this.showSensoryZones = true,
    this.selectedHazardId,
    this.userStepIndex,
    this.width,
    this.height,
    this.hasTileLayer = false,
    this.isHardwareGps = false,
    this.userLat,
    this.userLng,
    this.accuracy,
    this.heading,
    this.cameraLat = 12.9770,
    this.cameraLng = 77.5910,
    this.zoom = 14.0,
    this.surroundingZones,
  });

  static Offset getHazardOffset(
    HazardData hazard,
    Size size, {
    bool hasTileLayer = false,
    double cameraLat = 12.9770,
    double cameraLng = 77.5910,
    double zoom = 14.0,
  }) {
    if (hasTileLayer) {
      return MercatorProjection.latLngToScreen(
        lat: hazard.lat,
        lng: hazard.lng,
        centerLat: cameraLat,
        centerLng: cameraLng,
        zoom: zoom,
        screenSize: size,
      );
    }
    return getCoordinateOffset(hazard.lat, hazard.lng, size);
  }

  static Offset getCoordinateOffset(double lat, double lng, Size size) {
    const minLat = 12.9700;
    const maxLat = 12.9860;
    const minLng = 77.5830;
    const maxLng = 77.5990;

    final normX = ((lng - minLng) / (maxLng - minLng)).clamp(0.05, 0.95);
    final normY = (1.0 - ((lat - minLat) / (maxLat - minLat))).clamp(0.05, 0.95);
    return Offset(size.width * normX, size.height * normY);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: (width != null && height != null) ? Size(width!, height!) : Size.infinite,
      painter: _BangaloreMapPainter(
        isCalmestSelected: isCalmestSelected,
        destinationName: destinationName,
        hazards: hazards,
        showSensoryZones: showSensoryZones,
        selectedHazardId: selectedHazardId,
        userStepIndex: userStepIndex,
        hasTileLayer: hasTileLayer,
        isHardwareGps: isHardwareGps,
        userLat: userLat,
        userLng: userLng,
        accuracy: accuracy,
        heading: heading,
        cameraLat: cameraLat,
        cameraLng: cameraLng,
        zoom: zoom,
        surroundingZones: surroundingZones,
      ),
    );
  }
}

class _BangaloreMapPainter extends CustomPainter {
  final bool isCalmestSelected;
  final String destinationName;
  final List<HazardData> hazards;
  final bool showSensoryZones;
  final String? selectedHazardId;
  final int? userStepIndex;
  final bool hasTileLayer;
  final bool isHardwareGps;
  final double? userLat;
  final double? userLng;
  final double? accuracy;
  final double? heading;
  final double cameraLat;
  final double cameraLng;
  final double zoom;
  final List<SurroundingZone>? surroundingZones;

  _BangaloreMapPainter({
    required this.isCalmestSelected,
    required this.destinationName,
    this.hazards = const [],
    this.showSensoryZones = true,
    this.selectedHazardId,
    this.userStepIndex,
    this.hasTileLayer = false,
    this.isHardwareGps = false,
    this.userLat,
    this.userLng,
    this.accuracy,
    this.heading,
    required this.cameraLat,
    required this.cameraLng,
    required this.zoom,
    this.surroundingZones,
  });

  Offset _toScreen(double lat, double lng, Size size) {
    if (hasTileLayer) {
      return MercatorProjection.latLngToScreen(
        lat: lat,
        lng: lng,
        centerLat: cameraLat,
        centerLng: cameraLng,
        zoom: zoom,
        screenSize: size,
      );
    } else {
      return SensoryMapCanvas.getCoordinateOffset(lat, lng, size);
    }
  }

  Offset _getDestinationOffset(Size size) {
    final destCoord = LocationService.destinationCoordinates[destinationName] ??
        const UserCoordinates(latitude: 12.9860, longitude: 77.5850, label: 'Destination');
    return _toScreen(destCoord.latitude, destCoord.longitude, size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background (Calm off-white sensory canvas if no tile layer)
    if (!hasTileLayer) {
      final bgPaint = Paint()..color = const Color(0xFFEFF2EE);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    }

    // 2. Sensory Zones (drawn only in pure vector canvas mode; real map tiles already render native green spaces and roads)
    if (showSensoryZones && !hasTileLayer) {
      final parkPaint = Paint()
        ..color = const Color(0xFFD6E8D5).withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      final parkPath = Path()
        ..moveTo(size.width * 0.1, size.height * 0.22)
        ..quadraticBezierTo(size.width * 0.4, size.height * 0.15, size.width * 0.8, size.height * 0.25)
        ..quadraticBezierTo(size.width * 0.9, size.height * 0.45, size.width * 0.75, size.height * 0.65)
        ..quadraticBezierTo(size.width * 0.35, size.height * 0.75, size.width * 0.15, size.height * 0.55)
        ..close();
      canvas.drawPath(parkPath, parkPaint);

      final parkBorder = Paint()
        ..color = const Color(0xFFBDD9BB).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(parkPath, parkBorder);

      // Urban commercial stimulus buffer
      final urbanPaint = Paint()..color = const Color(0xFFE5DECE).withValues(alpha: 0.40);
      final urbanRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.42, size.width * 0.4, size.height * 0.24),
        const Radius.circular(16),
      );
      canvas.drawRRect(urbanRect, urbanPaint);
    }

    // 3. Grid road network (only drawn on synthetic vector mode; real street tiles show actual streets)
    if (!hasTileLayer) {
      final roadPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke;
      final roadCasing = Paint()
        ..color = const Color(0xFFD7DDD4)
        ..strokeWidth = 9
        ..style = PaintingStyle.stroke;

      final roadPath1 = Path()
        ..moveTo(0, size.height * 0.35)
        ..quadraticBezierTo(size.width * 0.5, size.height * 0.3, size.width, size.height * 0.4);
      canvas.drawPath(roadPath1, roadCasing);
      canvas.drawPath(roadPath1, roadPaint);

      final roadPath2 = Path()
        ..moveTo(size.width * 0.25, 0)
        ..quadraticBezierTo(size.width * 0.3, size.height * 0.5, size.width * 0.35, size.height);
      canvas.drawPath(roadPath2, roadCasing);
      canvas.drawPath(roadPath2, roadPaint);
    }

    // Dynamic Start & Destination Points in Geo-Space
    const startLat = 12.9716;
    const startLng = 77.5946;
    final startOffset = _toScreen(startLat, startLng, size);
    final destOffset = _getDestinationOffset(size);

    final waypoints = LocationService.getWaypointsForDestination(destinationName);

    // 4. Draw Route 2 (Quickest Route - via commercial corridor)
    final fastRoutePaint = Paint()
      ..color = isCalmestSelected
          ? const Color(0xFFD89D8B).withValues(alpha: 0.35)
          : const Color(0xFFC95B42)
      ..strokeWidth = isCalmestSelected ? 4 : 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final destCoord = LocationService.destinationCoordinates[destinationName] ??
        const UserCoordinates(latitude: 12.9860, longitude: 77.5850, label: 'Destination');
    final midFast = _toScreen(
      (startLat + destCoord.latitude) / 2 + 0.003,
      (startLng + destCoord.longitude) / 2 + 0.005,
      size,
    );

    final fastPath = Path()
      ..moveTo(startOffset.dx, startOffset.dy)
      ..quadraticBezierTo(
        midFast.dx,
        midFast.dy,
        destOffset.dx,
        destOffset.dy,
      );
    canvas.drawPath(fastPath, fastRoutePaint);

    // 5. Draw Route 1 (Calmest Route - geo-anchored along peaceful park & shaded corridors)
    final calmRoutePaint = Paint()
      ..color = isCalmestSelected ? QuietColors.primaryDark : QuietColors.primary.withValues(alpha: 0.4)
      ..strokeWidth = isCalmestSelected ? 7 : 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final calmPath = Path()..moveTo(startOffset.dx, startOffset.dy);
    for (int i = 1; i < waypoints.length; i++) {
      final wpOffset = _toScreen(waypoints[i].latitude, waypoints[i].longitude, size);
      calmPath.lineTo(wpOffset.dx, wpOffset.dy);
    }
    // Connect final waypoint to destination if not identical
    calmPath.lineTo(destOffset.dx, destOffset.dy);
    canvas.drawPath(calmPath, calmRoutePaint);

    // 6. User Location (Live Hardware GPS or Simulated walking position)
    final Offset userPos;
    if (userLat != null && userLng != null) {
      userPos = _toScreen(userLat!, userLng!, size);
    } else if (userStepIndex != null && waypoints.isNotEmpty) {
      final idx = userStepIndex!.clamp(0, waypoints.length - 1);
      userPos = _toScreen(waypoints[idx].latitude, waypoints[idx].longitude, size);
    } else {
      userPos = startOffset;
    }

    // Directional Compass Heading Beam
    if (heading != null) {
      final rad = (heading! - 90) * (math.pi / 180.0);
      const beamAngle = 36 * (math.pi / 180.0);
      const beamRadius = 32.0;
      final beamPath = Path()
        ..moveTo(userPos.dx, userPos.dy)
        ..arcTo(
          Rect.fromCircle(center: userPos, radius: beamRadius),
          rad - beamAngle / 2,
          beamAngle,
          false,
        )
        ..close();

      final beamColor = isHardwareGps ? const Color(0xFF1976D2) : QuietColors.primaryDark;
      final beamPaint = Paint()
        ..shader = ui.Gradient.radial(
          userPos,
          beamRadius,
          [
            beamColor.withValues(alpha: 0.38),
            beamColor.withValues(alpha: 0.0),
          ],
        );
      canvas.drawPath(beamPath, beamPaint);
    }

    if (isHardwareGps) {
      // Live Satellite GPS Pin with Accuracy Halo
      final haloRadius = (accuracy != null ? (accuracy! * 1.5).clamp(16.0, 48.0) : 22.0);
      final accuracyPaint = Paint()
        ..color = const Color(0xFF1976D2).withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(userPos, haloRadius, accuracyPaint);

      final gpsHalo = Paint()
        ..color = const Color(0xFF64B5F6).withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(userPos, 13, gpsHalo);

      final gpsPaint = Paint()..color = const Color(0xFF1565C0);
      canvas.drawCircle(userPos, 7, gpsPaint);
      canvas.drawCircle(userPos, 3, Paint()..color = Colors.white);
    } else {
      // Simulated Calm Green Pin
      final pinHalo = Paint()
        ..color = QuietColors.primaryLight.withValues(alpha: 0.7)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(userPos, 14, pinHalo);

      final pinPaint = Paint()..color = QuietColors.primaryDark;
      canvas.drawCircle(userPos, 7, pinPaint);
      canvas.drawCircle(userPos, 3, Paint()..color = Colors.white);
    }

    // 7. Destination Pin
    final destHalo = Paint()
      ..color = const Color(0xFF2B2D2F).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(destOffset, 15, destHalo);

    final destPaint = Paint()..color = const Color(0xFF2B2D2F);
    canvas.drawCircle(destOffset, 7, destPaint);
    canvas.drawCircle(destOffset, 3, Paint()..color = Colors.white);

    // 8. Surrounding Micro-Climate Telemetry Badges (Parks, Water, Corridors)
    if (surroundingZones != null && hasTileLayer) {
      for (final zone in surroundingZones!) {
        final zOffset = _toScreen(zone.lat, zone.lng, size);
        if (zOffset.dx >= -60 && zOffset.dx <= size.width + 60 &&
            zOffset.dy >= -30 && zOffset.dy <= size.height + 30) {
          _drawSurroundingBadge(canvas, zOffset, zone);
        }
      }
    }

    // 9. Sensory Hazard Markers (Clean aesthetic pins)
    for (final hazard in hazards) {
      _drawHazardMarker(canvas, size, hazard);
    }
  }

  void _drawSurroundingBadge(Canvas canvas, Offset offset, SurroundingZone zone) {
    final bool isGreen = zone.type == 'green_canopy';
    final bool isWater = zone.type == 'water_promenade';
    final Color badgeColor = isGreen
        ? const Color(0xFF2E7D32)
        : (isWater ? const Color(0xFF0288D1) : const Color(0xFFD97706));
    final Color badgeBg = isGreen
        ? const Color(0xFFF1F8F1)
        : (isWater ? const Color(0xFFE1F5FE) : const Color(0xFFFFF8E1));

    final text = '🍃 ${zone.name.split(" ").first}: AQI ${zone.aqi} • ${zone.temperatureC.round()}°C';
    final span = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: badgeColor,
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: offset, width: tp.width + 16, height: 22),
      const Radius.circular(11),
    );

    // Shadow
    canvas.drawRRect(
      rect.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
    // Background
    canvas.drawRRect(rect, Paint()..color = badgeBg);
    // Border
    canvas.drawRRect(
      rect,
      Paint()
        ..color = badgeColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    tp.paint(canvas, Offset(offset.dx - tp.width / 2, offset.dy - tp.height / 2));
  }

  void _drawHazardMarker(Canvas canvas, Size size, HazardData hazard) {
    final offset = _toScreen(hazard.lat, hazard.lng, size);
    final color = hazard.tagColor;
    final isSelected = hazard.id == selectedHazardId;

    // Glowing pulsating halo
    final haloPaint = Paint()
      ..color = color.withValues(alpha: isSelected ? 0.35 : 0.20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, isSelected ? 18 : 13, haloPaint);

    // Inner pin
    final pinPaint = Paint()..color = color;
    canvas.drawCircle(offset, isSelected ? 10 : 8, pinPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(offset, isSelected ? 10 : 8, borderPaint);

    // Category emoji / symbol
    String emoji = '⚠️';
    switch (hazard.hazardType) {
      case 'construction':
        emoji = '🚧';
        break;
      case 'noise':
        emoji = '📢';
        break;
      case 'crowd':
        emoji = '👥';
        break;
      case 'light':
      case 'glare':
        emoji = '💡';
        break;
      case 'air_quality':
        emoji = '💨';
        break;
    }

    final emojiSpan = TextSpan(
      text: emoji,
      style: TextStyle(fontSize: isSelected ? 11 : 9),
    );
    final emojiPainter = TextPainter(text: emojiSpan, textDirection: TextDirection.ltr)..layout();
    emojiPainter.paint(
      canvas,
      Offset(offset.dx - (emojiPainter.width / 2), offset.dy - (emojiPainter.height / 2)),
    );

    // Only draw callout bubble if selected by the user to keep map clean and uncluttered
    if (isSelected) {
      final labelText = '${hazard.title} (${hazard.upvotes} 👍)';
      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Color(0xFF2B2D2F),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();

      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.dx - (tp.width / 2) - 8, offset.dy - 32, tp.width + 16, 22),
        const Radius.circular(8),
      );
      canvas.drawRRect(badgeRect, Paint()..color = Colors.white);
      canvas.drawRRect(
        badgeRect,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      tp.paint(canvas, Offset(offset.dx - (tp.width / 2), offset.dy - 28));
    }
  }

  @override
  bool shouldRepaint(covariant _BangaloreMapPainter oldDelegate) {
    return oldDelegate.isCalmestSelected != isCalmestSelected ||
        oldDelegate.destinationName != destinationName ||
        oldDelegate.hazards != hazards ||
        oldDelegate.showSensoryZones != showSensoryZones ||
        oldDelegate.selectedHazardId != selectedHazardId ||
        oldDelegate.userStepIndex != userStepIndex ||
        oldDelegate.isHardwareGps != isHardwareGps ||
        oldDelegate.userLat != userLat ||
        oldDelegate.userLng != userLng ||
        oldDelegate.accuracy != accuracy ||
        oldDelegate.hasTileLayer != hasTileLayer ||
        oldDelegate.cameraLat != cameraLat ||
        oldDelegate.cameraLng != cameraLng ||
        oldDelegate.zoom != zoom ||
        oldDelegate.surroundingZones != surroundingZones;
  }
}


