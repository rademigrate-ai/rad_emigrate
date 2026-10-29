import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/theme_controller.dart';
import 'core/web/url_strategy.dart';
import 'features/global_time/domain/geo_timezone_resolver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Path-based URLs on web so /world-clock, /register, etc. work on refresh
  // and direct links. No-op on Android/iOS.
  configureUrlStrategy();
  await RadSupabaseClient.initialize();

  // IANA tzdata + timezone boundary polygons (native embedded / web asset).
  // Non-blocking initialization so first frame paint is not delayed by large assets.
  unawaited(GeoTimezoneResolver.ensureReady().catchError((_) {}));

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const RadEmigrateApp(),
    ),
  );
}
