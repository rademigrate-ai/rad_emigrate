import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Secondary screens pop real in-app history, with a safe direct-entry target.
/// Flutter's BackButtonIcon mirrors once for RTL and provides a 48 px target.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.fallback, this.onPressed});
  final String fallback;
  final VoidCallback? onPressed;

  static void goBack(BuildContext context, {required String fallback}) {
    final router = GoRouter.maybeOf(context);
    if (router != null && router.canPop()) {
      router.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      router?.go(fallback);
    }
  }

  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: onPressed ?? () => goBack(context, fallback: fallback),
  );
}

/// Direct entry to a secondary screen must not make Android Back exit the app.
/// Real navigator history (including sheets) is always allowed to pop normally.
class BackFallbackScope extends StatelessWidget {
  const BackFallbackScope({
    super.key,
    required this.fallback,
    required this.child,
  });
  final String fallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final hasHistory = router?.canPop() ?? Navigator.of(context).canPop();
    return PopScope(
      canPop: hasHistory,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppBackButton.goBack(context, fallback: fallback);
      },
      child: child,
    );
  }
}
