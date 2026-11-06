import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/interview_scheduling/domain/entities/interview_slot.dart';

void main() {
  Map<String, dynamic> slot() => {
    'id': 'synthetic-slot',
    'title': 'Synthetic availability',
    'start_utc': '2027-01-01T10:00:00Z',
    'end_utc': '2027-01-01T10:30:00Z',
    'mode': 'video',
    'is_available': false,
  };

  test('server availability and UTC interval are preserved', () {
    final parsed = InterviewSlot.fromJson(slot());
    expect(parsed.isAvailable, isFalse);
    expect(parsed.startUtc.isUtc, isTrue);
    expect(parsed.durationMinutes, 30);
  });

  for (final change in <Map<String, dynamic>>[
    {'start_utc': null},
    {'start_utc': 'invalid'},
    {'start_utc': '2027-01-01T10:00:00'},
    {'end_utc': '2027-01-01T09:00:00Z'},
    {'end_utc': '2027-01-01T10:00:00Z'},
    {'is_available': null},
    {'mode': 'invented'},
    {'id': ''},
    {'title': ''},
  ]) {
    test('malformed slot refuses availability: ${change.keys.join()}', () {
      expect(
        () => InterviewSlot.fromJson({...slot(), ...change}),
        throwsFormatException,
      );
    });
  }
}
