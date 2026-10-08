import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/auth_redirect.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/rad_brand.dart';
import '../../../auth/presentation/providers/auth_controller.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key, this.destination});

  final String? destination;

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Visual animation is strictly decorative: routing begins immediately and
    // never waits for a minimum display time.
    try {
      await ref.read(appBootstrapProvider.future);
    } catch (_) {
      // Bootstrap failures are reflected as an unauthenticated route.
    }
    if (!mounted) return;

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session != null && session.isAuthenticated) {
      context.go(restoredProtectedDestination(widget.destination));
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: AmbientBackdrop(
        primary: AppColors.teal,
        secondary: AppColors.primaryRed,
        child: Center(
          child: MotionReveal(
            duration: AppMotion.emphasized,
            offset: const Offset(0, 0.05),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RadBrand(size: RadBrandSize.large, darkSurface: true),
                const SizedBox(height: 32),
                Container(
                  width: 96,
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: const LinearGradient(
                      colors: [AppColors.teal, AppColors.primaryRed],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  label: 'Loading',
                  liveRegion: true,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.25,
                      color: AppColors.cyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
