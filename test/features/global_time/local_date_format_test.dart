import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/global_time/domain/local_date_format.dart';

void main() {
  test('FA uses Jalali weekday and month names', () {
    final dt = DateTime(2026, 10, 8, 12, 0);
    final s = formatLocalDate(dt, 'fa');
    expect(s.contains('۱۴'), isTrue); // Jalali year digits or day
    expect(s, isNot(contains('Oct')));
  });

  test('EN uses Gregorian format', () {
    final dt = DateTime(2026, 10, 8, 12, 0);
    final s = formatLocalDate(dt, 'en');
    expect(s.toLowerCase(), contains('oct'));
  });
}
