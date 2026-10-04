import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dependencies.dart';
import '../core/l10n/locale_controller.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../l10n/app_localizations.dart';

class RadEmigrateApp extends ConsumerWidget {
  const RadEmigrateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appBootstrapProvider);
    final themePref = ref.watch(themeControllerProvider);
    final appLocale = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      title: 'RAD International Institute',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themePref.themeMode,
      locale: appLocale.locale,
      supportedLocales: AppLocale.supported.map((e) => e.locale).toList(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: appLocale.textDirection,
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
