import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rad_emigrate/app/app.dart';

void main() {
  testWidgets('App boots without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RadEmigrateApp()));
    await tester.pump();
    // Splash or login should render RAD branding or Sign in.
    expect(find.textContaining('RAD'), findsWidgets);
  });
}
