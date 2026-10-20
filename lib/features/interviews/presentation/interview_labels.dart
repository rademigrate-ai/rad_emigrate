// Interview/appointment presentation labels.
// Bilingual (FA/EN) copy following the GlobalTimeLabels pattern.

class InterviewLabels {
  const InterviewLabels(this.language);

  final String language;

  bool get fa => language == 'fa';

  String get title => fa ? 'مصاحبه و نوبت‌دهی' : 'Interviews & appointments';
  String get intro => fa
      ? 'درخواست نوبت برای جلسه داخلی RAD ثبت کنید. RAD نوبت سفارت یا کنسولگری را رزرو نمی‌کند و ظرفیت رسمی نمایش نمی‌دهد.'
      : 'Request a slot for an internal RAD session. RAD does not book embassy or consulate appointments and never displays official availability.';
  String get overviewTitle => fa ? 'نوبت‌های من' : 'My appointments';
  String get requestTitle =>
      fa ? 'درخواست نوبت جدید' : 'Request a new appointment';
  String get kindLabel => fa ? 'نوع نوبت' : 'Appointment type';
  String get kindRadSession => fa
      ? 'جلسه داخلی RAD (مصاحبه/مشاوره)'
      : 'RAD internal session (interview/consultation)';
  String get kindExternal => fa
      ? 'نوبت سفارت/کنسولگری (فقط یادداشت شخصی)'
      : 'Embassy/consulate appointment (personal record only)';
  String get kindExternalHelp => fa
      ? 'RAD این نوبت را رزرو یا تأیید نمی‌کند؛ فقط برای یادداشت خودتان ثبتش کنید.'
      : 'RAD does not book or confirm this appointment; it is only your own record.';
  String get kindExternalRefused => fa
      ? 'RAD نوبت سفارت را رزرو نمی‌کند. این مورد را فقط می‌توانید شخصی ثبت کنید.'
      : 'RAD does not book embassy appointments. You can only keep this as a personal record.';
  String get titleLabel => fa ? 'موضوع نوبت' : 'Appointment title';
  String get titleHint => fa
      ? 'مثلاً: آماده‌سازی مصاحبه تحصیلی'
      : 'e.g. Study interview preparation';
  String get startLabel => fa ? 'زمان شروع' : 'Start time';
  String get endLabel => fa ? 'زمان پایان (اختیاری)' : 'End time (optional)';
  String get zoneLabel => fa ? 'منطقه زمانی' : 'Time zone';
  String get zoneDevice => fa ? 'منطقه دستگاه' : 'Device time zone';
  String get notesLabel => fa ? 'یادداشت (اختیاری)' : 'Notes (optional)';
  String get clearSlot => fa ? 'حذف زمان انتخابی' : 'Clear selected time';
  String get utcPreview => fa ? 'معادل UTC' : 'UTC equivalent';
  String get zonePreview => fa ? 'به وقت انتخابی' : 'In selected zone';
  String get ambiguousZone => fa
      ? 'این زمان به دلیل تغییر ساعت تابستانی دوبار رخ می‌دهد؛ نوبت اول در نظر گرفته شد.'
      : 'This civil time occurs twice due to daylight saving; the first occurrence was used.';
  String get dstGap => fa
      ? 'این زمان به دلیل تغییر ساعت تابستانی وجود ندارد. زمان دیگری انتخاب کنید.'
      : 'This local time does not exist because of daylight saving. Choose another time.';
  String get tzUnavailable => fa
      ? 'داده منطقه زمانی در دسترس نیست؛ تبدیل زمان انجام نشد.'
      : 'Timezone data is unavailable; the time could not be converted.';
  String get submit => fa ? 'ثبت درخواست نوبت' : 'Submit appointment request';
  String get success => fa
      ? 'درخواست نوبت ثبت شد و در انتظار بررسی است. تأیید قطعی پس از پاسخ کارشناس مشخص می‌شود.'
      : 'Your appointment request was submitted and is awaiting review. It is not confirmed until an advisor responds.';
  String get backendUnavailable => fa
      ? 'سیستم نوبت‌دهی آنلاین هنوز راه‌اندازی نشده است. درخواست شما ثبت نشد.'
      : 'Online scheduling is not deployed yet. Your request was not stored.';
  String get rescheduleUnavailable => fa
      ? 'تغییر زمان نوبت پس از استقرار قابلیت Backend فعال می‌شود.'
      : 'Rescheduling becomes available once the Backend capability is deployed.';
  String get cancelUnavailable => fa
      ? 'لغو نوبت پس از استقرار قابلیت Backend فعال می‌شود.'
      : 'Cancellation becomes available once the Backend capability is deployed.';
  String get reschedule => fa ? 'تغییر زمان' : 'Reschedule';
  String get cancel => fa ? 'لغو نوبت' : 'Cancel appointment';
  String get empty =>
      fa ? 'نوبتی ثبت نکرده‌اید.' : 'You have no appointment requests yet.';
  String get loadFailed =>
      fa ? 'بارگذاری نوبت‌ها ممکن نشد.' : 'Could not load appointments.';
  String get signInRequired => fa
      ? 'برای درخواست نوبت باید وارد شوید.'
      : 'Sign in to request an appointment.';
  String get signIn => fa ? 'ورود' : 'Sign in';
  String get retry => fa ? 'تلاش دوباره' : 'Retry';
  String get genericError => fa
      ? 'ثبت درخواست نوبت ممکن نشد.'
      : 'Could not submit the appointment request.';
  String get titleRequired =>
      fa ? 'موضوع نوبت الزامی است.' : 'Title is required.';
  String get titleTooShort => fa
      ? 'موضوع باید دست‌کم ۴ نویسه باشد.'
      : 'Title must be at least 4 characters.';
  String get titleTooLong => fa
      ? 'موضوع باید حداکثر ۱۲۰ نویسه باشد.'
      : 'Title must be at most 120 characters.';
  String get notesTooLong => fa
      ? 'یادداشت باید حداکثر ۶۰۰ نویسه باشد.'
      : 'Notes must be at most 600 characters.';
  String get startRequired =>
      fa ? 'زمان شروع را انتخاب کنید.' : 'Pick a start time.';
  String get startPast => fa
      ? 'زمان شروع نمی‌تواند در گذشته باشد.'
      : 'Start time cannot be in the past.';
  String get endBeforeStart => fa
      ? 'زمان پایان باید پس از زمان شروع باشد.'
      : 'End time must be after the start time.';
  String get tooShort => fa
      ? 'مدت نوبت باید دست‌کم ۱۵ دقیقه باشد.'
      : 'Duration must be at least 15 minutes.';
  String get tooLong => fa
      ? 'مدت نوبت نباید بیش از ۴ ساعت باشد.'
      : 'Duration must not exceed 4 hours.';
  String get statusRequested => fa ? 'درخواست‌شده' : 'Requested';
  String get statusInReview => fa ? 'در حال بررسی' : 'In review';
  String get statusConfirmed => fa ? 'تأییدشده' : 'Confirmed';
  String get statusRescheduled => fa ? 'تغییر زمان‌شده' : 'Rescheduled';
  String get statusCancelled => fa ? 'لغوشده' : 'Cancelled';
  String get statusCompleted => fa ? 'انجام‌شده' : 'Completed';
  String get statusUnknown => fa ? 'نامشخص' : 'Unknown';
  String get externalBadge => fa ? 'یادداشت شخصی' : 'Personal record';
  String get radBadge => fa ? 'جلسه RAD' : 'RAD session';
  String get notConfirmedNote => fa
      ? 'ثبت درخواست به معنی تأیید قطعی نیست.'
      : 'Submitting a request does not confirm the appointment.';
}

/// Maps an appointment status enum name to its localized label.
String appointmentStatusLabel(Object status, InterviewLabels labels) {
  final name = status is String ? status : status.toString();
  if (name.contains('confirmed')) return labels.statusConfirmed;
  if (name.contains('inReview')) return labels.statusInReview;
  if (name.contains('rescheduled')) return labels.statusRescheduled;
  if (name.contains('cancelled')) return labels.statusCancelled;
  if (name.contains('completed')) return labels.statusCompleted;
  if (name.contains('requested')) return labels.statusRequested;
  return labels.statusUnknown;
}
