import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/auth_redirect.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: PremiumCanvas(
        dark: true,
        accent: AppColors.teal,
        showEditorialRule: false,
        child: SafeArea(
          child: Stack(
            children: [
              const PositionedDirectional(
                top: 28,
                start: 24,
                child: EditorialKicker(
                  index: '01',
                  label: 'IMMIGRATION JOURNEY',
                  dark: true,
                ),
              ),
              LoadingState.splash(
                message: l10n.splashLoadingStatus,
                dark: true,
              ),
              PositionedDirectional(
                bottom: 28,
                start: 24,
                end: 24,
                child: Text(
                  l10n.brandIntroTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Semantics(
                label: l10n.appTitle,
                image: true,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
