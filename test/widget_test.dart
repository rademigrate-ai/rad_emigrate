import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rad_emigrate/app/app.dart';
import 'package:rad_emigrate/core/theme/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots without crashing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const RadEmigrateApp(),
      ),
    );
    await tester.pump();
    // Splash or login should expose the shared RAD brand to assistive tech.
    expect(find.bySemanticsLabel('RAD International Institute'), findsWidgets);
  });
}
