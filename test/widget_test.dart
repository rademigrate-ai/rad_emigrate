import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rad_emigrate/app/app.dart';

void main() {
  testWidgets('App boots and shows splash or login', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RadEmigrateApp()));
    await tester.pump();
    // Splash shows RAD branding.
    expect(find.textContaining('RAD'), findsWidgets);
  });
}
