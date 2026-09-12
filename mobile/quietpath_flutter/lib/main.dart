import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quietpath_flutter/core/services/app_config_service.dart';
import 'package:quietpath_flutter/core/theme/quietpath_theme.dart';
import 'package:quietpath_flutter/features/profile/presentation/sensory_profile_setup_screen.dart';
import 'package:quietpath_flutter/features/shell/presentation/main_shell_screen.dart';
import 'package:quietpath_flutter/features/safe_spaces/presentation/safe_spaces_screen.dart';
import 'package:quietpath_flutter/features/navigation/presentation/active_navigation_screen.dart';
import 'package:quietpath_flutter/features/splash/presentation/splash_screen.dart';

import 'package:quietpath_flutter/core/services/local_database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfigService().init();
  await LocalDatabaseService().init();
  runApp(const ProviderScope(child: QuietPathApp()));
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const SensoryProfileSetupScreen(),
    ),
    GoRoute(
      path: '/explore',
      builder: (context, state) => const MainShellScreen(initialTab: 0),
    ),
    GoRoute(
      path: '/safe-spaces',
      builder: (context, state) => const MainShellScreen(initialTab: 1),
    ),
    GoRoute(
      path: '/safe-spaces-direct',
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: QuietColors.textCharcoal),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Back to Navigation', style: TextStyle(color: QuietColors.textCharcoal, fontSize: 16)),
        ),
        body: const SafeSpacesScreen(),
      ),
    ),
    GoRoute(
      path: '/navigation',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ActiveNavigationScreen(
          destination: extra?['destination'] as String?,
          isSafeSpaceExit: extra?['isSafeSpaceExit'] as bool? ?? false,
          quietSpot: extra?['quietSpot'] as String?,
        );
      },
    ),
  ],
);

class QuietPathApp extends StatelessWidget {
  const QuietPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'QuietPath',
      debugShowCheckedModeBanner: false,
      theme: QuietPathTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
