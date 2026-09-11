import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quietpath_flutter/core/services/location_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
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

  late final List<NavStep> _steps;
  late final List<UserCoordinates> _waypoints;

  @override
  void initState() {
    super.initState();
    final dest = widget.destination ?? 'Bangalore Golf Club';
    _waypoints = LocationService.getWaypointsForDestination(dest);

    if (widget.isSafeSpaceExit) {
      _steps = [
        NavStep(
          instruction: 'Proceed to gentle exit towards $dest',
          distance: '↑ In 60 meters',
          decibels: 41,
          icon: Icons.directions_walk_rounded,
          ttsPrompt: 'Starting guided sanctuary exit to $dest. Take slow breaths, you are safe.',
          targetLat: _waypoints.length > 1 ? _waypoints[1].latitude : 12.9735,
          targetLng: _waypoints.length > 1 ? _waypoints[1].longitude : 77.5925,
        ),
        NavStep(
          instruction: 'Turn right into shaded pedestrian alley',
          distance: '↑ In 120 meters',
          decibels: 38,
          icon: Icons.turn_right_rounded,
          ttsPrompt: 'In 120 meters, turn right into the shaded pedestrian alley. Ambient sound is calm.',
          targetLat: _waypoints.length > 2 ? _waypoints[2].latitude : 12.9745,
          targetLng: _waypoints.length > 2 ? _waypoints[2].longitude : 77.5910,
        ),
        NavStep(
          instruction: 'Continue straight along tree-lined sanctuary corridor',
          distance: '↑ In 250 meters',
          decibels: 43,
          icon: Icons.straight_rounded,
          ttsPrompt: 'Continue straight for 250 meters along the tree-lined path.',
          targetLat: _waypoints.last.latitude,
          targetLng: _waypoints.last.longitude,
        ),
        NavStep(
          instruction: 'Arrived at safe sanctuary: $dest',
          distance: widget.quietSpot != null ? 'Quiet zone: ${widget.quietSpot}' : 'Safe arrival',
          decibels: 35,
          icon: Icons.spa_rounded,
          ttsPrompt: 'You have arrived at your quiet sanctuary. Breathe easy.',
          targetLat: _waypoints.last.latitude,
          targetLng: _waypoints.last.longitude,
        ),
      ];
    } else {
      _steps = [
        NavStep(
          instruction: 'Turn right onto Oak Trail canopy',
          distance: '↑ In 150 meters',
          decibels: 42,
          icon: Icons.turn_right_rounded,
          ttsPrompt: 'Starting navigation to $dest. In 150 meters, turn right onto Oak Trail canopy.',
          targetLat: _waypoints.length > 1 ? _waypoints[1].latitude : 12.9768,
          targetLng: _waypoints.length > 1 ? _waypoints[1].longitude : 77.5912,
        ),
        NavStep(
          instruction: 'Continue straight along Queen\'s Park Walkway',
          distance: '↑ In 350 meters',
          decibels: 39,
          icon: Icons.straight_rounded,
          ttsPrompt: 'Continue along the quiet walkway for 350 meters. Minimal crowd detected.',
          targetLat: _waypoints.length > 2 ? _waypoints[2].latitude : 12.9815,
          targetLng: _waypoints.length > 2 ? _waypoints[2].longitude : 77.5878,
        ),
        NavStep(
          instruction: 'Gentle curve left onto High Grounds shaded avenue',
          distance: '↑ In 200 meters',
          decibels: 45,
          icon: Icons.turn_left_rounded,
          ttsPrompt: 'In 200 meters, take a gentle curve left onto High Grounds shaded avenue.',
          targetLat: _waypoints.last.latitude,
          targetLng: _waypoints.last.longitude,
        ),
        NavStep(
          instruction: 'Arrived at destination: $dest',
          distance: 'Refuge reached safely',
          decibels: 38,
          icon: Icons.check_circle_rounded,
          ttsPrompt: 'You have safely arrived at $dest. Enjoy your calm visit.',
          targetLat: _waypoints.last.latitude,
          targetLng: _waypoints.last.longitude,
        ),
      ];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(userLocationProvider.notifier);
      notifier.setStepWaypoint(0, dest);

      // Attempt to start hardware location stream
      final hasHardwareGps = await notifier.startHardwareLocationStream();
      // If hardware GPS is disabled (e.g. PC host location disabled by admin), auto-start simulated walk
      if (!hasHardwareGps && mounted) {
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
    });

    TtsService().speakCalm(_steps.first.ttsPrompt);
  }

  @override
  void dispose() {
    ref.read(userLocationProvider.notifier).stopAutoWalk();
    TtsService().stop();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _liveDistanceCountdown = '';
      });
      ref.read(userLocationProvider.notifier).setStepWaypoint(_currentStepIndex, widget.destination ?? 'Bangalore Golf Club');
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
      ref.read(userLocationProvider.notifier).setStepWaypoint(_currentStepIndex, widget.destination ?? 'Bangalore Golf Club');
      final step = _steps[_currentStepIndex];
      TtsService().speakCalm(step.ttsPrompt);
    }
  }

  void _triggerReroute() {
    setState(() {
      _isRerouted = true;
    });
    TtsService().speakCalm('Sensory alert avoided. Rerouting via peaceful park canopy.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: QuietColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Detour applied: Avoiding 78 dB construction zone ahead.',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination ?? 'Bangalore Golf Club';
    final step = _steps[_currentStepIndex];
    final isArrived = _currentStepIndex == _steps.length - 1;
    final userLocation = ref.watch(userLocationProvider);
    final compassHeading = ref.watch(compassHeadingProvider);
    final isAutoWalkActive = ref.watch(userLocationProvider.notifier).isAutoWalkActive;

    // Real-time GPS proximity listener for turn auto-advancement & dynamic countdown
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

      // 2. Automatic Turn Progression when crossing within 25 meters!
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
            // 1. Interactive Sensory Map in Background with dynamic GPS location
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
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
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: QuietColors.textCharcoal, size: 24),
                        onPressed: () {
                          ref.read(userLocationProvider.notifier).stopAutoWalk();
                          TtsService().stop();
                          context.pop();
                        },
                      ),
                      Text(
                        'QuietPath Nav',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: QuietColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
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
                            color: Colors.black.withOpacity(0.08),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: QuietColors.textCharcoal,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      _liveDistanceCountdown.isNotEmpty ? _liveDistanceCountdown : step.distance,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: _liveDistanceCountdown.contains('now') ? const Color(0xFFC04B37) : QuietColors.textMuted,
                                        fontWeight: _liveDistanceCountdown.contains('now') ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F6F0),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${step.decibels} dB',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: QuietColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Live Location Source Status Pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                ? 'Live Satellite GPS Tracking (±${userLocation.accuracy?.toStringAsFixed(1) ?? '3.0'}m)'
                                : (isAutoWalkActive
                                    ? 'Host GPS Disabled by Admin • Simulated Auto-Walk Active'
                                    : 'Host GPS Disabled by Admin • Walk Paused'),
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

                  // Simulation Stepper & Safe Space Pill Row
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
                            color: isAutoWalkActive ? const Color(0xFFE5EFE0) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isAutoWalkActive ? QuietColors.primaryDark : const Color(0xFFCBD6CA),
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
                                isAutoWalkActive ? Icons.pause_circle_rounded : Icons.play_circle_fill_rounded,
                                color: isAutoWalkActive ? QuietColors.primaryDark : QuietColors.textCharcoal,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isAutoWalkActive ? 'Auto-Walk' : 'Play Walk',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isAutoWalkActive ? QuietColors.primaryDark : QuietColors.textCharcoal,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Floating "Find Safe Space" pill button
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

          // 3. Floating Sensory Alert / Comfort HUD at Bottom
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
                    color: Colors.black.withOpacity(0.08),
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
                              : 'Current pathway calm. Light traffic and 42 dB ambient noise.',
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
