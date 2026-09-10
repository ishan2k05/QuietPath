import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/features/explore/presentation/explore_map_screen.dart';
import 'package:quietpath_flutter/features/safe_spaces/presentation/safe_spaces_screen.dart';
import 'package:quietpath_flutter/features/profile/presentation/sensory_profile_setup_screen.dart';
import 'package:quietpath_flutter/features/navigation/services/tts_service.dart';

class MainShellScreen extends StatefulWidget {
  final int initialTab;
  const MainShellScreen({super.key, this.initialTab = 0});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;
  bool _voiceEnabled = true;
  double _voiceSpeechRate = 0.45;
  String? _activePlayingCue;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _voiceEnabled = AppConfigService().ttsVoiceEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const ExploreMapScreen(),
      const SafeSpacesScreen(),
      _buildVoiceTab(),
      const SensoryProfileSetupScreen(isStandaloneOnboarding: false),
    ];

    return Scaffold(
      backgroundColor: QuietColors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.015, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.explore_rounded, 'Explore'),
              _buildNavItem(1, Icons.shield_outlined, 'Safe Spaces'),
              _buildNavItem(2, Icons.mic_none_rounded, 'Voice'),
              _buildNavItem(3, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    if (isSelected) {
      // Active pill button matching UI mockup
      return GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF456B34),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: QuietColors.textMuted, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: QuietColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceTab() {
    return Scaffold(
      backgroundColor: QuietColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Hero Icon with gentle pulse styling
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: _voiceEnabled ? QuietColors.primaryLight : const Color(0xFFF1F3F5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _voiceEnabled ? QuietColors.primary : Colors.grey.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _voiceEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                  color: _voiceEnabled ? QuietColors.primaryDark : QuietColors.textMuted,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Calm Voice Guidance',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: QuietColors.textCharcoal,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'QuietPath uses gentle, low-cadence voice cues to keep you oriented without sensory or cognitive overload.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: QuietColors.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Master Toggle Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: QuietColors.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          color: _voiceEnabled ? QuietColors.primaryDark : QuietColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Prompts',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: QuietColors.textCharcoal,
                              ),
                            ),
                            Text(
                              _voiceEnabled ? 'Auditory guidance enabled' : 'Muted (visual cues only)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: QuietColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _voiceEnabled,
                      activeThumbColor: QuietColors.primaryDark,
                      activeTrackColor: QuietColors.primaryLight,
                      onChanged: (val) {
                        setState(() => _voiceEnabled = val);
                        AppConfigService().setTtsVoiceEnabled(val);
                        if (!val) {
                          TtsService().stop();
                        } else {
                          TtsService().speakCalm('Voice cues enabled.');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Speech Cadence Selection
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: QuietColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Cadence & Pacing',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: QuietColors.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Slower speech rates reduce cognitive processing strain.',
                      style: GoogleFonts.inter(fontSize: 12, color: QuietColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildCadencePill(0.38, 'Gentle (0.38x)'),
                        const SizedBox(width: 8),
                        _buildCadencePill(0.45, 'Calm (0.45x)'),
                        const SizedBox(width: 8),
                        _buildCadencePill(0.55, 'Normal (0.55x)'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sample Audio Prompts Tester
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: QuietColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Gentle Voice Prompts',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: QuietColors.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap any cue to hear how QuietPath guides you:',
                      style: GoogleFonts.inter(fontSize: 12, color: QuietColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    _buildCueButton(
                      title: 'Standard Turn Maneuver',
                      subtitle: 'In 150 meters, turn right onto Oak Trail.',
                      prompt: 'In 150 meters, turn right onto Oak Trail. The path is calm.',
                    ),
                    const SizedBox(height: 8),
                    _buildCueButton(
                      title: 'Sensory Detour Alert',
                      subtitle: 'Construction spike ahead. Calmer detour ready.',
                      prompt: 'Sensory alert. Ambient construction noise ahead. Calmer detour is ready via the park.',
                    ),
                    const SizedBox(height: 8),
                    _buildCueButton(
                      title: 'Safe Sanctuary Arrival',
                      subtitle: 'Approaching Central Library. Silence zone active.',
                      prompt: 'Arrived at Central Public Library. Silence zone is active. Please enter and relax.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCadencePill(double rate, String label) {
    final isSelected = (_voiceSpeechRate - rate).abs() < 0.02;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _voiceSpeechRate = rate);
          TtsService().speakCalm('Speech cadence set to $label.');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? QuietColors.primaryLight : const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? QuietColors.primaryDark : const Color(0xFFE9ECEF),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? QuietColors.primaryDark : QuietColors.textCharcoal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCueButton({
    required String title,
    required String subtitle,
    required String prompt,
  }) {
    final isPlaying = _activePlayingCue == title;

    return GestureDetector(
      onTap: () async {
        if (!_voiceEnabled) return;
        setState(() => _activePlayingCue = title);
        await TtsService().speakCalm(prompt);
        if (mounted) setState(() => _activePlayingCue = null);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isPlaying ? const Color(0xFFF1F8EE) : const Color(0xFFF9FAF9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPlaying ? QuietColors.primary : const Color(0xFFE9ECEF),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPlaying ? QuietColors.primary : QuietColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.volume_up_rounded : Icons.play_arrow_rounded,
                color: isPlaying ? Colors.white : QuietColors.primaryDark,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: QuietColors.textCharcoal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: QuietColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
