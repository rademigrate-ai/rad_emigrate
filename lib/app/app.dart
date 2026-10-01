import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';

class RadEmigrateApp extends ConsumerWidget {
  const RadEmigrateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'RAD Emigrate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
