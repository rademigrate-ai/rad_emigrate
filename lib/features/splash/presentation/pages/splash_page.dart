import '../../../../core/theme/premium_tokens.dart';

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
    final destination = restoredProtectedDestination(widget.destination);
    if (session != null && session.isAuthenticated) {
      context.go(destination);
    } else {
      if (widget.destination != null && isProtectedPath(widget.destination!)) {
        context.go(
          Uri(
            path: '/login',
            queryParameters: {'from': destination},
          ).toString(),
        );
      } else {
        context.go(destination);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: PremiumCanvas(
        accent: AppColors.teal,
        showEditorialRule: false,
        child: SafeArea(
          child: Stack(
            children: [
              PositionedDirectional(
                top: 28,
                start: 24,
                child: EditorialKicker(
                  index: '01',
                  label: AppLocalizations.of(context).immigrationJourney,
                ),
              ),
              LoadingState.splash(
                message: l10n.splashLoadingStatus,
                dark: context.premium.isDark,
              ),
              PositionedDirectional(
                bottom: 28,
                start: 24,
                end: 24,
                child: Text(
                  l10n.brandIntroTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: context.premium.text,
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
