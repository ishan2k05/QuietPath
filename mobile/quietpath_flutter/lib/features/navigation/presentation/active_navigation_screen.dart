import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';
import 'package:quietpath_flutter/core/services/tile_cache_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/features/explore/data/routes_provider.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_map_canvas.dart';
import 'package:quietpath_flutter/features/explore/presentation/widgets/sensory_tile_layer.dart';
import 'package:quietpath_flutter/features/navigation/services/tts_service.dart';

class NavStep {
  final String instruction;
  final String distance;
  final int decibels;
  final IconData icon;
  final String ttsPrompt;
  final double targetLat;
  final double targetLng;

  const NavStep({
    required this.instruction,
    required this.distance,
    required this.decibels,
    required this.icon,
    required this.ttsPrompt,
    required this.targetLat,
    required this.targetLng,
  });
}

class ActiveNavigationScreen extends ConsumerStatefulWidget {
  final String? destination;
  final bool isSafeSpaceExit;
  final String? quietSpot;

  const ActiveNavigationScreen({
    super.key,
    this.destination,
    this.isSafeSpaceExit = false,
    this.quietSpot,
  });

  @override
  ConsumerState<ActiveNavigationScreen> createState() => _ActiveNavigationScreenState();
}

class _ActiveNavigationScreenState extends ConsumerState<ActiveNavigationScreen> {
  bool _isRerouted = false;
  int _currentStepIndex = 0;
  String _liveDistanceCountdown = '';
  bool _isHeadsUp = false;
  int _offRouteCounter = 0;
  bool _isAutoRerouting = false;

  late List<NavStep> _steps;
  late List<UserCoordinates> _waypoints;
  late UserLocationNotifier _locationNotifier;

  @override
  void initState() {
    super.initState();
    _locationNotifier = ref.read(userLocationProvider.notifier);
    final dest = widget.destination ?? 'Bangalore Golf Club';
    _waypoints = LocationService.activeRouteWaypoints ?? LocationService.getWaypointsForDestination(dest);

    final activeRoute = ref.read(routesProvider).selectedRoute;
    _steps = _buildSteps(dest, _waypoints, activeRoute, widget.isSafeSpaceExit, widget.quietSpot);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _locationNotifier.setStepWaypoint(0, dest);

      // Pre-cache map tiles along active route for uninterrupted offline navigation
      TileCacheService().precacheRouteTiles(waypoints: _waypoints);

      // Attempt to start hardware location stream
      final hasHardwareGps = await _locationNotifier.startHardwareLocationStream();
      // If hardware GPS is disabled (e.g. restricted PC host/emulator), auto-start simulated walk
      if (!hasHardwareGps && mounted) {
        _locationNotifier.startAutoWalk(_waypoints, onArrival: () {
          if (mounted && _currentStepIndex < _steps.length - 1) {
            setState(() {
              _currentStepIndex = _steps.length - 1;
              _liveDistanceCountdown = 'Safe arrival';
            });
            TtsService().speakCalm(_steps.last.ttsPrompt);
          }
        });
      }
    });

    if (_steps.isNotEmpty) {
      TtsService().speakCalm(_steps.first.ttsPrompt);
    }
  }

  @override
  void dispose() {
    _locationNotifier.stopAutoWalk();
    TtsService().stop();
    super.dispose();
  }

  List<NavStep> _buildSteps(
    String dest,
    List<UserCoordinates> waypoints,
    RouteOptionData? route,
    bool isSafeSpaceExit,
    String? quietSpot,
  ) {
    if (isSafeSpaceExit) {
      return [
        NavStep(
          instruction: 'Proceed to gentle exit towards $dest',
          distance: '↑ In 60 meters',
          decibels: 41,
          icon: Icons.directions_walk_rounded,
          ttsPrompt: 'Starting guided sanctuary exit to $dest. Take slow breaths, you are safe.',
          targetLat: waypoints.length > 1 ? waypoints[1].latitude : 12.9735,
          targetLng: waypoints.length > 1 ? waypoints[1].longitude : 77.5925,
        ),
        NavStep(
          instruction: 'Turn right into shaded pedestrian alley',
          distance: '↑ In 120 meters',
          decibels: 38,
          icon: Icons.turn_right_rounded,
          ttsPrompt: 'In 120 meters, turn right into the shaded pedestrian alley. Ambient sound is calm.',
          targetLat: waypoints.length > 2 ? waypoints[2].latitude : 12.9745,
          targetLng: waypoints.length > 2 ? waypoints[2].longitude : 77.5910,
        ),
        NavStep(
          instruction: 'Continue straight along tree-lined sanctuary corridor',
          distance: '↑ In 250 meters',
          decibels: 43,
          icon: Icons.straight_rounded,
          ttsPrompt: 'Continue straight for 250 meters along the tree-lined path.',
          targetLat: waypoints.last.latitude,
          targetLng: waypoints.last.longitude,
        ),
        NavStep(
          instruction: 'Arrived at safe sanctuary: $dest',
          distance: quietSpot != null ? 'Quiet zone: $quietSpot' : 'Safe arrival',
          decibels: 35,
          icon: Icons.spa_rounded,
          ttsPrompt: 'You have arrived at your quiet sanctuary. Breathe easy.',
          targetLat: waypoints.last.latitude,
          targetLng: waypoints.last.longitude,
        ),
      ];
    }

    if (route != null && route.turnInstructions.isNotEmpty) {
      final List<NavStep> dynamicSteps = [];
      final total = route.turnInstructions.length;

      for (int i = 0; i < total; i++) {
        final instr = route.turnInstructions[i];
        final isLast = i == total - 1;
        final lower = instr.toLowerCase();

        IconData icon;
        if (isLast || lower.contains('arrive')) {
          icon = Icons.check_circle_rounded;
        } else if (lower.contains('right')) {
          icon = Icons.turn_right_rounded;
        } else if (lower.contains('left')) {
          icon = Icons.turn_left_rounded;
        } else if (lower.contains('straight') || lower.contains('continue')) {
          icon = Icons.straight_rounded;
        } else if (lower.contains('roundabout')) {
          icon = Icons.roundabout_right_rounded;
        } else {
          icon = Icons.directions_walk_rounded;
        }

        final targetIdx = ((i + 1) * waypoints.length ~/ (total + 1)).clamp(0, waypoints.length - 1);
        final wp = waypoints.isNotEmpty
            ? waypoints[targetIdx]
            : const UserCoordinates(latitude: 18.5104, longitude: 73.9375);

        // Real-time dynamic decibel computation based on MCDA calm score and road classification
        final baseDb = (82 - (route.sensoryScore * 0.45)).round().clamp(36, 75);
        int stepDb = baseDb;
        if (lower.contains('path') || lower.contains('walkway') || lower.contains('canopy') || lower.contains('park') || lower.contains('garden')) {
          stepDb -= 4;
        } else if (lower.contains('main') || lower.contains('road') || lower.contains('highway') || lower.contains('chowk')) {
          stepDb += 3;
        }
        if (isLast) stepDb -= 2;

        dynamicSteps.add(
          NavStep(
            instruction: instr,
            distance: isLast ? 'Arrive at $dest' : 'Follow calm guidance',
            decibels: stepDb.clamp(34, 78),
            icon: icon,
            ttsPrompt: instr,
            targetLat: wp.latitude,
            targetLng: wp.longitude,
          ),
        );
      }
      return dynamicSteps;
    }

    final baseFallbackDb = (82 - ((route?.sensoryScore ?? 85.0) * 0.45)).round().clamp(36, 75);
    return [
      NavStep(
        instruction: 'Head towards $dest along calm pedestrian corridor',
        distance: '↑ In 150 meters',
        decibels: baseFallbackDb,
        icon: Icons.directions_walk_rounded,
        ttsPrompt: 'Starting navigation to $dest. Follow shaded pedestrian walkway.',
        targetLat: waypoints.length > 1 ? waypoints[1].latitude : 18.5104,
        targetLng: waypoints.length > 1 ? waypoints[1].longitude : 73.9375,
      ),
      NavStep(
        instruction: 'Continue along shaded avenue towards $dest',
        distance: '↑ In 350 meters',
        decibels: (baseFallbackDb - 3).clamp(34, 75),
        icon: Icons.straight_rounded,
        ttsPrompt: 'Continue along the quiet walkway for 350 meters. Minimal crowd detected.',
        targetLat: waypoints.length > 2 ? waypoints[2].latitude : 18.5140,
        targetLng: waypoints.length > 2 ? waypoints[2].longitude : 73.9350,
      ),
      NavStep(
        instruction: 'Gentle turn towards $dest entrance',
        distance: '↑ In 200 meters',
        decibels: baseFallbackDb,
        icon: Icons.turn_right_rounded,
        ttsPrompt: 'In 200 meters, take a gentle turn towards the destination.',
        targetLat: waypoints.isNotEmpty ? waypoints.last.latitude : 18.5186,
        targetLng: waypoints.isNotEmpty ? waypoints.last.longitude : 73.9341,
      ),
      NavStep(
        instruction: 'Arrived at destination: $dest',
        distance: 'Refuge reached safely',
        decibels: (baseFallbackDb - 4).clamp(32, 72),
        icon: Icons.check_circle_rounded,
        ttsPrompt: 'You have safely arrived at $dest. Enjoy your calm visit.',
        targetLat: waypoints.isNotEmpty ? waypoints.last.latitude : 18.5186,
        targetLng: waypoints.isNotEmpty ? waypoints.last.longitude : 73.9341,
      ),
    ];
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _liveDistanceCountdown = '';
      });
      ref.read(userLocationProvider.notifier).setStepWaypoint(
        _currentStepIndex,
        widget.destination ?? 'Bangalore Golf Club',
      );
      final step = _steps[_currentStepIndex];
      TtsService().speakCalm(step.ttsPrompt);
    }
  }

  void _previousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
        _liveDistanceCountdown = '';
      });
      ref.read(userLocationProvider.notifier).setStepWaypoint(
        _currentStepIndex,
        widget.destination ?? 'Bangalore Golf Club',
      );
      final step = _steps[_currentStepIndex];
      TtsService().speakCalm(step.ttsPrompt);
    }
  }

  Future<void> _triggerAutoReroute(UserCoordinates currentPos, String destName) async {
    if (_isAutoRerouting) return;
    _isAutoRerouting = true;
    setState(() {
      _isRerouted = true;
    });

    TtsService().speakCalm('Off designated path. Automatically recalculating quiet route to $destName.');

    try {
      await ref.read(routesProvider.notifier).fetchRoutes(
        originName: 'Current Location',
        destName: destName,
        originLat: currentPos.latitude,
        originLng: currentPos.longitude,
      );

      final updatedRoute = ref.read(routesProvider).selectedRoute;
      if (updatedRoute != null && LocationService.activeRouteWaypoints != null && LocationService.activeRouteWaypoints!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _waypoints = LocationService.activeRouteWaypoints!;
            _steps = _buildSteps(destName, _waypoints, updatedRoute, widget.isSafeSpaceExit, widget.quietSpot);
            _currentStepIndex = 0;
            _liveDistanceCountdown = '';
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: QuietColors.primaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.alt_route_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Auto-Rerouted: Nearest quiet corridor recalculated.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
    _isAutoRerouting = false;
  }

  void _triggerReroute() {
    final userLoc = ref.read(userLocationProvider);
    final dest = widget.destination ?? 'Bangalore Golf Club';
    _triggerAutoReroute(userLoc, dest);
  }

  double _getEffectiveHeading(double? heading, UserCoordinates userLoc, NavStep? step) {
    if (heading != null && heading > 0.0) return heading;
    if (userLoc.heading != null && userLoc.heading! > 0.0) return userLoc.heading!;
    if (step != null) {
      final dLng = (step.targetLng - userLoc.longitude) * math.pi / 180.0;
      final phi1 = userLoc.latitude * math.pi / 180.0;
      final phi2 = step.targetLat * math.pi / 180.0;
      final y = math.sin(dLng) * math.cos(phi2);
      final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dLng);
      return (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination ?? 'Bangalore Golf Club';
    final step = _steps.isNotEmpty ? _steps[_currentStepIndex.clamp(0, _steps.length - 1)] : null;
    final isArrived = _currentStepIndex == _steps.length - 1;
    final userLocation = ref.watch(userLocationProvider);
    final compassHeading = ref.watch(compassHeadingProvider);
    final isAutoWalkActive = ref.watch(userLocationProvider.notifier).isAutoWalkActive;
    final effectiveBearing = _getEffectiveHeading(compassHeading, userLocation, step);

    // Real-time GPS proximity listener for turn auto-advancement & dynamic countdown & auto-reroute
    ref.listen<UserCoordinates>(userLocationProvider, (previous, current) {
      if (!mounted) return;
      if (_currentStepIndex >= _steps.length - 1) return;

      final currentStep = _steps[_currentStepIndex];
      final distMeters = LocationService.calculateDistanceMeters(
        current.latitude,
        current.longitude,
        currentStep.targetLat,
        currentStep.targetLng,
      );

      // 1. Live Countdown Text
      String countdown;
      if (distMeters <= 18.0) {
        countdown = 'Turn now (${distMeters.round()}m)';
      } else if (distMeters < 1000) {
        countdown = '↑ In ${distMeters.round()} meters';
      } else {
        countdown = '↑ In ${(distMeters / 1000).toStringAsFixed(1)} km';
      }

      if (_liveDistanceCountdown != countdown) {
        if (!mounted) return;
        setState(() {
          _liveDistanceCountdown = countdown;
        });
      }

      // 2. Automatic Turn Progression when crossing within 25 meters
      if (distMeters <= 25.0 && _currentStepIndex < _steps.length - 1) {
        final nextIdx = _currentStepIndex + 1;
        if (!mounted) return;
        setState(() {
          _currentStepIndex = nextIdx;
          _liveDistanceCountdown = '';
        });
        TtsService().speakCalm(_steps[nextIdx].ttsPrompt);
        HapticFeedback.lightImpact();
      }

      // 3. Dynamic Off-Route Automatic Rerouting (>35m deviation for 4 consecutive seconds)
      final offRouteDist = LocationService.distanceToRoutePolyline(
        current.latitude,
        current.longitude,
        _waypoints,
      );

      if (offRouteDist > 35.0 && !_isAutoRerouting && !isArrived) {
        _offRouteCounter++;
        if (_offRouteCounter >= 4) {
          _triggerAutoReroute(current, dest);
        }
      } else {
        _offRouteCounter = 0;
      }
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        ref.read(userLocationProvider.notifier).stopAutoWalk();
        TtsService().stop();
      },
      child: Scaffold(
        backgroundColor: QuietColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Interactive Sensory Map in Background with dynamic GPS location & Heads-Up Compass orientation
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Transform.rotate(
                      angle: _isHeadsUp ? -(effectiveBearing * math.pi / 180.0) : 0.0,
                      alignment: Alignment.center,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: SensoryTileLayer(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              centerLat: userLocation.latitude,
                              centerLng: userLocation.longitude,
                              zoom: 15.5,
                              providerType: TileProviderType.googleRoads,
                            ),
                          ),
                          Positioned.fill(
                            child: SensoryMapCanvas(
                              isCalmestSelected: !_isRerouted,
                              destinationName: dest,
                              userStepIndex: _currentStepIndex,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              hasTileLayer: true,
                              isHardwareGps: userLocation.isHardwareGps,
                              userLat: userLocation.latitude,
                              userLng: userLocation.longitude,
                              accuracy: userLocation.accuracy,
                              heading: compassHeading,
                              cameraLat: userLocation.latitude,
                              cameraLng: userLocation.longitude,
                              zoom: 15.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 2. Frosted Translucent Header Shield
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: MediaQuery.of(context).padding.top + 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2EE).withValues(alpha: 0.92),
                      border: Border(
                        bottom: BorderSide(
                          color: const Color(0xFFCBD6CA).withValues(alpha: 0.90),
                          width: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Navigation Header & Turn Card
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Navigation Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco_rounded, color: QuietColors.primaryDark, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'QuietPath Nav',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: QuietColors.primaryDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFC04B37),
                            backgroundColor: const Color(0xFFFDECEB),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            ref.read(userLocationProvider.notifier).stopAutoWalk();
                            TtsService().stop();
                            context.pop();
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: Text(
                            'Exit',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, height: 1.2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Turn Card with Maneuver Icon
                    if (step != null)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Container(
                          key: ValueKey<int>(_currentStepIndex),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: isArrived ? const Color(0xFF385A27) : const Color(0xFF7CA467),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  step.icon,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.instruction,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: QuietColors.textCharcoal,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _liveDistanceCountdown.isNotEmpty
                                          ? _liveDistanceCountdown
                                          : step.distance,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _liveDistanceCountdown.startsWith('Turn now')
                                            ? const Color(0xFFC04B37)
                                            : QuietColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5EFE0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.volume_down_rounded, color: Color(0xFF385A27), size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${step.decibels} dB',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF385A27),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Telemetry & Hardware Status Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: userLocation.isHardwareGps
                            ? const Color(0xFFE5EFE0)
                            : const Color(0xFFF3F5F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: userLocation.isHardwareGps
                              ? const Color(0xFF90C28A)
                              : const Color(0xFFCBD6CA),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            userLocation.isHardwareGps
                                ? Icons.satellite_alt_rounded
                                : Icons.navigation_rounded,
                            size: 14,
                            color: userLocation.isHardwareGps
                                ? QuietColors.primaryDark
                                : QuietColors.textCharcoal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              userLocation.isHardwareGps
                                  ? 'Live Road-Snapped GPS Tracking (±${userLocation.accuracy?.toStringAsFixed(1) ?? '3.0'}m)'
                                  : (isAutoWalkActive
                                      ? 'Sensory Auto-Walk Simulation Active'
                                      : 'Sensory Walk Paused'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: userLocation.isHardwareGps
                                    ? QuietColors.primaryDark
                                    : QuietColors.textCharcoal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Simulation Stepper & Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Step navigation controls
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                icon: const Icon(Icons.arrow_back_ios_rounded, color: QuietColors.textCharcoal),
                                onPressed: _currentStepIndex > 0 ? _previousStep : null,
                              ),
                              Text(
                                '${_currentStepIndex + 1}/${_steps.length}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: QuietColors.textCharcoal,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                icon: const Icon(Icons.arrow_forward_ios_rounded, color: QuietColors.textCharcoal),
                                onPressed: _currentStepIndex < _steps.length - 1 ? _nextStep : null,
                              ),
                            ],
                          ),
                        ),

                        // Auto-Walk Play/Pause Toggle Pill
                        GestureDetector(
                          onTap: () {
                            final notifier = ref.read(userLocationProvider.notifier);
                            if (notifier.isAutoWalkActive) {
                              notifier.stopAutoWalk();
                            } else {
                              notifier.startAutoWalk(_waypoints, onArrival: () {
                                if (mounted && _currentStepIndex < _steps.length - 1) {
                                  setState(() {
                                    _currentStepIndex = _steps.length - 1;
                                    _liveDistanceCountdown = 'Safe arrival';
                                  });
                                  TtsService().speakCalm(_steps.last.ttsPrompt);
                                }
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: isAutoWalkActive ? const Color(0xFF385A27) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isAutoWalkActive ? const Color(0xFF385A27) : const Color(0xFFCBD6CA),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAutoWalkActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: isAutoWalkActive ? Colors.white : QuietColors.textCharcoal,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAutoWalkActive ? 'Pause Walk' : 'Auto Walk',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isAutoWalkActive ? Colors.white : QuietColors.textCharcoal,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Safe Sanctuary Quick Jump Pill
                        GestureDetector(
                          onTap: () => context.push('/safe-spaces-direct'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_outlined, color: Color(0xFF385A27), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Sanctuary',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF385A27),
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 4. Floating Heads-Up / North-Up Compass Button
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + 310,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isHeadsUp = !_isHeadsUp;
                  });
                  TtsService().speakCalm(_isHeadsUp ? 'Heads-up walking view enabled' : 'North-up map view enabled');
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(
                      color: _isHeadsUp ? QuietColors.primaryDark : const Color(0xFFE2E7E2),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: -(effectiveBearing * math.pi / 180.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 3,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC04B37),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                            ),
                          ),
                          Container(
                            width: 3,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF9E9E9E),
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Floating Sensory Alert / Comfort HUD at Bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isRerouted ? QuietColors.primary : const Color(0xFFB5A8D5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isRerouted ? const Color(0xFFE5EFE0) : const Color(0xFFF1EEF8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRerouted ? Icons.check_circle_outline_rounded : Icons.sensors_rounded,
                        color: _isRerouted ? QuietColors.primaryDark : QuietColors.secondaryDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isRerouted ? 'Sensory Shield Active' : 'Live Sensory Monitor',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: QuietColors.textCharcoal,
                                ),
                              ),
                              if (!_isRerouted)
                                GestureDetector(
                                  onTap: _triggerReroute,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F6F0),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFD6E8D5)),
                                    ),
                                    child: Text(
                                      'Reroute',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF385A27),
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isRerouted
                                ? 'Detour active: Avoiding urban noise via shaded greenway corridor.'
                                : 'Current pathway calm. Estimated ${step?.decibels ?? 38} dB ambient sound.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: QuietColors.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
