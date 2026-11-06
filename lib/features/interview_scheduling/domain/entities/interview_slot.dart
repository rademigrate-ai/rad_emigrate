// Interview scheduling domain entities.
//
// Fails closed and strictly avoids fabricating appointment availability or
// official examiner claims.

enum InterviewMode { video, phone, inPerson }

extension InterviewModeX on InterviewMode {
  String label(bool fa) => switch (this) {
    InterviewMode.video => fa ? 'مصاحبه ویدیویی' : 'Video interview',
    InterviewMode.phone => fa ? 'تماس تلفنی' : 'Phone call',
    InterviewMode.inPerson => fa ? 'حضوری' : 'In person',
  };
}

class InterviewSlot {
  const InterviewSlot({
    required this.id,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    this.mode = InterviewMode.video,
    this.advisorTitle,
    this.isAvailable = true,
  });

  final String id;
  final String title;
  final DateTime startUtc;
  final DateTime endUtc;
  final InterviewMode mode;
  final String? advisorTitle;
  final bool isAvailable;

  int get durationMinutes => endUtc.difference(startUtc).inMinutes;

  factory InterviewSlot.fromJson(Map<String, dynamic> json) {
    DateTime timestamp(String field) {
      final value = json[field];
      final parsed = value is String ? DateTime.tryParse(value) : null;
      if (parsed == null || !parsed.isUtc) {
        throw const FormatException('invalid_interview_slot');
      }
      return parsed.toUtc();
    }

    final start = timestamp('start_utc');
    final end = timestamp('end_utc');
    if (json['id'] is! String ||
        (json['id'] as String).trim().isEmpty ||
        json['title'] is! String ||
        (json['title'] as String).trim().isEmpty ||
        !end.isAfter(start) ||
        json['is_available'] is! bool ||
        !{'video', 'phone', 'in_person'}.contains(json['mode'])) {
      throw const FormatException('invalid_interview_slot');
    }
    return InterviewSlot(
      id: json['id'] as String,
      title: json['title'] as String,
      startUtc: start,
      endUtc: end,
      mode: switch (json['mode'] as String?) {
        'phone' => InterviewMode.phone,
        'in_person' => InterviewMode.inPerson,
        _ => InterviewMode.video,
      },
      advisorTitle: json['advisor_title'] as String?,
      isAvailable: json['is_available'] as bool,
    );
  }
}

class InterviewBookingRecord {
  const InterviewBookingRecord({
    required this.id,
    required this.slotId,
    required this.scheduledStartUtc,
    required this.status,
    required this.createdAtUtc,
  });

  final String id;
  final String slotId;
  final DateTime scheduledStartUtc;
  final String status;
  final DateTime createdAtUtc;
}
