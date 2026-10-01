import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rad_emigrate/app/app.dart';

void main() {
  testWidgets('App boots without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RadEmigrateApp()));
    await tester.pump();
    // Splash or login should expose the shared RAD brand to assistive tech.
    expect(
      find.bySemanticsLabel('RAD International Institute of RAD'),
      findsWidgets,
    );
  });
}
