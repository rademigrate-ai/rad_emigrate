import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/auth_redirect.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
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
    try {
      await ref.read(appBootstrapProvider.future);
    } catch (_) {
      // Routing still proceeds to the safe unauthenticated path.
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
      body: PremiumCanvas(
        dark: true,
        accent: AppColors.teal,
        child: SafeArea(
          child: Center(
            child: MotionReveal(
              duration: AppMotion.emphasized,
              offset: const Offset(0, 0.05),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EditorialKicker(
                    index: '00',
                    label: 'RAD JOURNEY',
                    dark: true,
                  ),
                  const SizedBox(height: 30),
                  const RadOrbit(size: 250),
                  const SizedBox(height: 30),
                  Text(
                    'RAD',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 38,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Immigration journey, made visible',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: const Color(0xFFBED1D6)),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    label: 'Loading',
                    liveRegion: true,
                    child: SizedBox(
                      width: 132,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: const LinearProgressIndicator(
                          minHeight: 3,
                          color: AppColors.primaryRed,
                          backgroundColor: Color(0xFF1D4450),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
