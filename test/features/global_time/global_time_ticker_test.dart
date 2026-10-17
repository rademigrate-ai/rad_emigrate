import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/global_time/data/favorites_repository.dart';
import 'package:rad_emigrate/features/global_time/presentation/providers/global_time_controller.dart';

void main() {
  test('live clock state publishes a fresh tick every second', () async {
    final container = ProviderContainer(
      overrides: [favoritesRepositoryProvider.overrideWithValue(null)],
    );
    addTearDown(container.dispose);

    container.read(globalTimeControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final before = container.read(globalTimeControllerProvider);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final after = container.read(globalTimeControllerProvider);

    expect(identical(after, before), isFalse);
  });
}
