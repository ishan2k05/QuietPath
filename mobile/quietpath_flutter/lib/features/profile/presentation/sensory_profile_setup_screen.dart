import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/features/profile/data/profile_provider.dart';

class SensoryProfileSetupScreen extends ConsumerStatefulWidget {
  final bool isStandaloneOnboarding;
  const SensoryProfileSetupScreen({super.key, this.isStandaloneOnboarding = true});

  @override
  ConsumerState<SensoryProfileSetupScreen> createState() =>
      _SensoryProfileSetupScreenState();
}

class _SensoryProfileSetupScreenState
    extends ConsumerState<SensoryProfileSetupScreen> {
  // 0 = low index (Prefer Quiet / Prefer Empty / Dim / Avoid Traffic / Extra Calm)
  // 1 = medium (Moderate / Some People / Standard / Moderate / Balanced)
  // 2 = high (Tolerate Loud / Busy is OK / Bright / Standard / Fastest)
  int _noiseIndex = 1;
  int _crowdIndex = 1;
  int _lightIndex = 1;
  int _trafficIndex = 1;
  int _timeToleranceIndex = 1;

  @override
  void initState() {
    super.initState();
    final p = AppConfigService().sensoryProfile;
    _noiseIndex = p.noiseSensitivity >= 0.7 ? 0 : (p.noiseSensitivity >= 0.4 ? 1 : 2);
    _crowdIndex = p.crowdComfort >= 0.7 ? 0 : (p.crowdComfort >= 0.4 ? 1 : 2);
    _lightIndex = p.lightIntensity >= 0.7 ? 0 : (p.lightIntensity >= 0.4 ? 1 : 2);
    _trafficIndex = p.trafficSensitivity >= 0.7 ? 0 : (p.trafficSensitivity >= 0.4 ? 1 : 2);
    _timeToleranceIndex = p.timePenaltyTolerance >= 0.7 ? 0 : (p.timePenaltyTolerance >= 0.35 ? 1 : 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Leaf logo
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: QuietColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.eco_rounded,
                  color: QuietColors.primaryDark,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.isStandaloneOnboarding ? 'Welcome to QuietPath' : 'Sensory Profile & Settings',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: QuietColors.textCharcoal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isStandaloneOnboarding
                    ? "Let's set up your sensory preferences to find\nenvironments that feel right for you."
                    : "Tune your comfort thresholds. Routes and safe spaces recalculate dynamically.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: QuietColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Sparkle card
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: QuietColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: QuietColors.borderLight),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: QuietColors.secondaryDark,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.isStandaloneOnboarding
                            ? 'We use these settings to filter out places that might be overwhelming. You can always adjust these later as your needs change.'
                            : 'Your preferences automatically shape the calmest, lowest-stimulus paths and sanctuaries for you in real-time.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: QuietColors.textCharcoal,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Preference 1: Noise Sensitivity
              _buildSensoryCategory(
                icon: Icons.hearing_rounded,
                iconBg: const Color(0xFFF1EEF8),
                iconColor: QuietColors.secondaryDark,
                title: 'Noise Sensitivity',
                labels: ['Prefer Quiet', 'Moderate', 'Tolerate Loud'],
                selectedIndex: _noiseIndex,
                onChanged: (idx) {
                  setState(() => _noiseIndex = idx);
                  final weight = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.2);
                  ref.read(sensoryProfileProvider.notifier).updateNoise(weight);
                },
              ),
              const SizedBox(height: 24),

              // Preference 2: Crowd Comfort
              _buildSensoryCategory(
                icon: Icons.groups_rounded,
                iconBg: const Color(0xFFE2F4EE),
                iconColor: QuietColors.tertiaryDark,
                title: 'Crowd Comfort',
                labels: ['Prefer Empty', 'Some People', 'Busy is OK'],
                selectedIndex: _crowdIndex,
                onChanged: (idx) {
                  setState(() => _crowdIndex = idx);
                  final weight = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.2);
                  ref.read(sensoryProfileProvider.notifier).updateCrowd(weight);
                },
              ),
              const SizedBox(height: 24),

              // Preference 3: Light Intensity
              _buildSensoryCategory(
                icon: Icons.wb_sunny_rounded,
                iconBg: const Color(0xFFFEF7E6),
                iconColor: const Color(0xFFB57C1E),
                title: 'Light Intensity',
                labels: ['Dim/Soft', 'Standard', 'Bright/Daylight'],
                selectedIndex: _lightIndex,
                onChanged: (idx) {
                  setState(() => _lightIndex = idx);
                  final weight = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.2);
                  ref.read(sensoryProfileProvider.notifier).updateLight(weight);
                },
              ),

              const SizedBox(height: 24),

              // Preference 4: Traffic Congestion Tolerance
              _buildSensoryCategory(
                icon: Icons.directions_car_rounded,
                iconBg: const Color(0xFFE8F1F5),
                iconColor: const Color(0xFF2C6E8F),
                title: 'Traffic Congestion',
                labels: ['Avoid Traffic', 'Moderate', 'Standard'],
                selectedIndex: _trafficIndex,
                onChanged: (idx) {
                  setState(() => _trafficIndex = idx);
                  final weight = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.2);
                  ref.read(sensoryProfileProvider.notifier).updateTraffic(weight);
                },
              ),
              const SizedBox(height: 24),

              // Preference 5: Detour Willingness
              _buildSensoryCategory(
                icon: Icons.alt_route_rounded,
                iconBg: const Color(0xFFF3ECE5),
                iconColor: const Color(0xFF9A5B2D),
                title: 'Detour Willingness for Calm',
                labels: ['Extra Calm (+40%)', 'Balanced (+20%)', 'Fastest Route'],
                selectedIndex: _timeToleranceIndex,
                onChanged: (idx) {
                  setState(() => _timeToleranceIndex = idx);
                  final tolerance = idx == 0 ? 0.85 : (idx == 1 ? 0.5 : 0.15);
                  ref.read(sensoryProfileProvider.notifier).updateTimeTolerance(tolerance);
                },
              ),

              const SizedBox(height: 36),

              // Primary CTA Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF456B34),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    await ref.read(sensoryProfileProvider.notifier).saveProfile();
                    if (widget.isStandaloneOnboarding) {
                      await AppConfigService().setOnboardingCompleted(true);
                    }
                    if (context.mounted) {
                      if (widget.isStandaloneOnboarding) {
                        context.go('/explore');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: QuietColors.primaryDark,
                            content: Text(
                              'Sensory profile updated and saved locally. Navigation routes will adapt accordingly.',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    widget.isStandaloneOnboarding ? 'Save & Start Exploring →' : 'Save Sensory Preferences',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensoryCategory({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: QuietColors.textCharcoal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Discrete track
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: List.generate(3, (index) {
              final isSelected = index == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [
                              BoxSideShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      labels[index],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? QuietColors.textCharcoal
                            : QuietColors.textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class BoxSideShadow extends BoxShadow {
  const BoxSideShadow({
    super.color,
    super.offset,
    super.blurRadius,
  });
}
