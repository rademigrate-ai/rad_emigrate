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
    return InterviewSlot(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startUtc:
          DateTime.tryParse(json['start_utc'] as String? ?? '') ??
          DateTime.now().toUtc(),
      endUtc:
          DateTime.tryParse(json['end_utc'] as String? ?? '') ??
          DateTime.now().toUtc(),
      mode: switch (json['mode'] as String?) {
        'phone' => InterviewMode.phone,
        'in_person' => InterviewMode.inPerson,
        _ => InterviewMode.video,
      },
      advisorTitle: json['advisor_title'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
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
