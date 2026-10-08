import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/supabase/supabase_client.dart';
import 'core/theme/theme_controller.dart';
import 'features/global_time/domain/geo_timezone_resolver.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RadSupabaseClient.initialize();

  // IANA tzdata + timezone boundary polygons (native embedded / web asset).
  // Failures leave clocks usable; map resolve falls back to manual TZ.
  try {
    await GeoTimezoneResolver.ensureReady();
  } catch (_) {
    // Non-fatal: world clocks still work from catalog IANA ids.
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const RadEmigrateApp(),
    ),
  );
}
