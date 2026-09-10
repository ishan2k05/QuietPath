import 'dart:ui';
import 'package:flutter/material.dart';
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

  const NavStep({
    required this.instruction,
    required this.distance,
    required this.decibels,
    required this.icon,
    required this.ttsPrompt,
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

  late final List<NavStep> _steps;

  @override
  void initState() {
    super.initState();
    final dest = widget.destination ?? 'Bangalore Golf Club';

    if (widget.isSafeSpaceExit) {
      _steps = [
        NavStep(
          instruction: 'Proceed to gentle exit towards $dest',
          distance: '↑ In 60 meters',
          decibels: 41,
          icon: Icons.directions_walk_rounded,
          ttsPrompt: 'Starting guided sanctuary exit to $dest. Take slow breaths, you are safe.',
        ),
        NavStep(
          instruction: 'Turn right into shaded pedestrian alley',
          distance: '↑ In 120 meters',
          decibels: 38,
          icon: Icons.turn_right_rounded,
          ttsPrompt: 'In 120 meters, turn right into the shaded pedestrian alley. Ambient sound is calm.',
        ),
        NavStep(
          instruction: 'Continue straight along tree-lined sanctuary corridor',
          distance: '↑ In 250 meters',
          decibels: 43,
          icon: Icons.straight_rounded,
          ttsPrompt: 'Continue straight for 250 meters along the tree-lined path.',
        ),
        NavStep(
          instruction: 'Arrived at safe sanctuary: $dest',
          distance: widget.quietSpot != null ? 'Quiet zone: ${widget.quietSpot}' : 'Safe arrival',
          decibels: 35,
          icon: Icons.spa_rounded,
          ttsPrompt: 'You have arrived at your quiet sanctuary. Breathe easy.',
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
        ),
        NavStep(
          instruction: 'Continue straight along Queen\'s Park Walkway',
          distance: '↑ In 350 meters',
          decibels: 39,
          icon: Icons.straight_rounded,
          ttsPrompt: 'Continue along the quiet walkway for 350 meters. Minimal crowd detected.',
        ),
        NavStep(
          instruction: 'Gentle curve left onto High Grounds shaded avenue',
          distance: '↑ In 200 meters',
          decibels: 45,
          icon: Icons.turn_left_rounded,
          ttsPrompt: 'In 200 meters, take a gentle curve left onto High Grounds shaded avenue.',
        ),
        NavStep(
          instruction: 'Arrived at destination: $dest',
          distance: 'Refuge reached safely',
          decibels: 38,
          icon: Icons.check_circle_rounded,
          ttsPrompt: 'You have safely arrived at $dest. Enjoy your calm visit.',
        ),
      ];
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userLocationProvider.notifier).setStepWaypoint(0, dest);
    });

    TtsService().speakCalm(_steps.first.ttsPrompt);
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
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

    return Scaffold(
      backgroundColor: QuietColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Interactive Sensory Map in Background with dynamic GPS location
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(350),
                  minScale: 0.8,
                  maxScale: 3.5,
                  child: SizedBox(
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
                            zoom: 15,
                            providerType: TileProviderType.esriStreet,
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
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: QuietColors.textCharcoal, size: 24),
                        onPressed: () {
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
                                      step.distance,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: QuietColors.textMuted,
                                        fontWeight: FontWeight.w500,
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
                  const SizedBox(height: 10),

                  // Simulation Stepper & Safe Space Pill Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Step navigation controls
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
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
                              iconSize: 20,
                              icon: const Icon(Icons.arrow_back_ios_rounded, color: QuietColors.textCharcoal),
                              onPressed: _currentStepIndex > 0 ? _previousStep : null,
                            ),
                            Text(
                              'Step ${_currentStepIndex + 1} of ${_steps.length}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: QuietColors.textCharcoal,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              icon: const Icon(Icons.arrow_forward_ios_rounded, color: QuietColors.textCharcoal),
                              onPressed: _currentStepIndex < _steps.length - 1 ? _nextStep : null,
                            ),
                          ],
                        ),
                      ),

                      // Floating "Find Safe Space" pill button
                      GestureDetector(
                        onTap: () => context.push('/safe-spaces-direct'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield_outlined, color: Color(0xFF385A27), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Find Sanctuary',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
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
    );
  }
}
