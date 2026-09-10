import 'package:flutter/material.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/features/explore/data/hazards_provider.dart';

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
  });

  static Offset getHazardOffset(HazardData hazard, Size size) {
    return getCoordinateOffset(hazard.lat, hazard.lng, size);
  }

  static Offset getCoordinateOffset(double lat, double lng, Size size) {
    const minLat = 12.9700;
    const maxLat = 12.9860;
    const minLng = 77.5830;
    const maxLng = 77.5990;

    final normX = ((lng - minLng) / (maxLng - minLng)).clamp(0.12, 0.88);
    final normY = (1.0 - ((lat - minLat) / (maxLat - minLat))).clamp(0.15, 0.85);
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
  });

  Offset _getDestinationOffset(Size size) {
    switch (destinationName) {
      case 'Cubbon Park Sanctuary':
        return Offset(size.width * 0.46, size.height * 0.38);
      case 'Lalbagh Botanical Garden':
        return Offset(size.width * 0.68, size.height * 0.68);
      case 'Central Public Library':
        return Offset(size.width * 0.38, size.height * 0.44);
      case 'Commercial Street':
        return Offset(size.width * 0.82, size.height * 0.42);
      case 'Bangalore Golf Club':
      default:
        return Offset(size.width * 0.75, size.height * 0.28);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Background (Calm off-white sensory canvas if no tile layer)
    if (!hasTileLayer) {
      final bgPaint = Paint()..color = const Color(0xFFEFF2EE);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    }

    // 2. Sensory Zones (Park Canopy & Commercial Shading - conditional on showSensoryZones)
    if (showSensoryZones) {
      final parkAlpha = hasTileLayer ? 0.42 : 0.85;
      final parkPaint = Paint()
        ..color = const Color(0xFFD6E8D5).withValues(alpha: parkAlpha)
        ..style = PaintingStyle.fill;
      final parkPath = Path()
        ..moveTo(size.width * 0.1, size.height * 0.22)
        ..quadraticBezierTo(size.width * 0.4, size.height * 0.15, size.width * 0.8, size.height * 0.25)
        ..quadraticBezierTo(size.width * 0.9, size.height * 0.45, size.width * 0.75, size.height * 0.65)
        ..quadraticBezierTo(size.width * 0.35, size.height * 0.75, size.width * 0.15, size.height * 0.55)
        ..close();
      canvas.drawPath(parkPath, parkPaint);

      final parkBorder = Paint()
        ..color = const Color(0xFFBDD9BB).withValues(alpha: hasTileLayer ? 0.45 : 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawPath(parkPath, parkBorder);

      // Urban commercial stimulus buffer
      final urbanAlpha = hasTileLayer ? 0.28 : 0.40;
      final urbanPaint = Paint()..color = const Color(0xFFE5DECE).withValues(alpha: urbanAlpha);
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

    // Dynamic Start & Destination Points
    final startOffset = Offset(size.width * 0.28, size.height * 0.72);
    final destOffset = _getDestinationOffset(size);

    // Midpoints for bezier routing
    final midX = (startOffset.dx + destOffset.dx) / 2;
    final midY = (startOffset.dy + destOffset.dy) / 2;

    // 4. Draw Route 2 (Quickest Route - via commercial corridor)
    final fastRoutePaint = Paint()
      ..color = isCalmestSelected
          ? const Color(0xFFD89D8B).withValues(alpha: 0.35)
          : const Color(0xFFC95B42)
      ..strokeWidth = isCalmestSelected ? 4 : 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fastPath = Path()
      ..moveTo(startOffset.dx, startOffset.dy)
      ..quadraticBezierTo(
        midX + size.width * 0.12,
        midY + size.height * 0.05,
        destOffset.dx,
        destOffset.dy,
      );
    canvas.drawPath(fastPath, fastRoutePaint);

    // 5. Draw Route 1 (Calmest Route - through peaceful park canopy)
    final calmRoutePaint = Paint()
      ..color = isCalmestSelected ? QuietColors.primaryDark : QuietColors.primary.withValues(alpha: 0.4)
      ..strokeWidth = isCalmestSelected ? 7 : 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final calmPath = Path()
      ..moveTo(startOffset.dx, startOffset.dy)
      ..quadraticBezierTo(
        midX - size.width * 0.14,
        midY - size.height * 0.08,
        destOffset.dx,
        destOffset.dy,
      );
    canvas.drawPath(calmPath, calmRoutePaint);

    // 6. User Location (Live Hardware GPS satellite beacon or Simulated waypoint pin)
    final Offset userPos;
    if (isHardwareGps && userLat != null && userLng != null) {
      userPos = SensoryMapCanvas.getCoordinateOffset(userLat!, userLng!, size);
    } else if (userStepIndex != null) {
      final t = (userStepIndex! / 3.0).clamp(0.0, 1.0);
      final control = isCalmestSelected
          ? Offset(midX - size.width * 0.14, midY - size.height * 0.08)
          : Offset(midX + size.width * 0.12, midY + size.height * 0.05);
      final px = (1 - t) * (1 - t) * startOffset.dx + 2 * (1 - t) * t * control.dx + t * t * destOffset.dx;
      final py = (1 - t) * (1 - t) * startOffset.dy + 2 * (1 - t) * t * control.dy + t * t * destOffset.dy;
      userPos = Offset(px, py);
    } else {
      userPos = startOffset;
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

    // 8. Sensory Hazard Markers (Clean aesthetic pins)
    for (final hazard in hazards) {
      _drawHazardMarker(canvas, size, hazard);
    }
  }

  void _drawHazardMarker(Canvas canvas, Size size, HazardData hazard) {
    final offset = SensoryMapCanvas.getHazardOffset(hazard, size);
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
        oldDelegate.hasTileLayer != hasTileLayer;
  }
}


