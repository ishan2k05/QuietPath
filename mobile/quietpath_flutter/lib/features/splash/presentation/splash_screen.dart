import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/core/widgets/quietpath_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    _navigateNext();
  }

  Future<void> _requestInitialPermissions() async {
    try {
      await [
        Permission.location,
        Permission.microphone,
      ].request();
    } catch (e) {
      debugPrint('[Permissions] Error requesting initial permissions: $e');
    }
  }

  Future<void> _navigateNext() async {
    // Proactively request native Android runtime permissions (GPS & Microphone)
    // so fresh installations prompt the user immediately like standard Android apps.
    await _requestInitialPermissions();

    // Give user a brief, calm visual experience (1.4s)
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final hasCompleted = AppConfigService().hasCompletedOnboarding;
    if (hasCompleted) {
      context.go('/explore');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Leaf Logo with soft calming glow
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: QuietColors.primaryLight,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: QuietColors.primaryDark.withValues(alpha: 0.12),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: QuietPathLogo(size: 64),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'QuietPath',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: QuietColors.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Navigate at your own pace',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: QuietColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  // Subtle calm badge at bottom
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: QuietColors.background,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: QuietColors.borderLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.spa_rounded,
                          size: 15,
                          color: QuietColors.primaryDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sensory-Calm Urban Navigation',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: QuietColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
