// Booking presentation labels.
// Bilingual (FA/EN) copy for the booking feature; follows the approved
// GlobalTimeLabels pattern of feature-local bilingual labels.

class BookingLabels {
  const BookingLabels(this.language);

  final String language;

  bool get fa => language == 'fa';

  String get title => fa ? 'رزرو خدمات' : 'Book a service';
  String get intro => fa
      ? 'خدمات RAD را مرور کنید و درخواست رزرو ثبت کنید. زمان انتخابی شما تنها یک ترجیح است و پس از تأیید کارشناس نهایی می‌شود.'
      : 'Browse RAD services and submit a booking request. Your chosen time is a preference only; a human advisor confirms the final slot.';
  String get catalogTitle => fa ? 'فهرست خدمات' : 'Services';
  String get myBookingsTitle => fa ? 'رزروهای من' : 'My bookings';
  String get serviceDetail => fa ? 'جزئیات خدمت' : 'Service details';
  String get requestBooking => fa ? 'ثبت درخواست رزرو' : 'Request booking';
  String get requestDetails => fa ? 'جزئیات درخواست' : 'Request details';
  String get messageLabel => fa ? 'توضیحات شما' : 'Your message';
  String get messageHint => fa
      ? 'وضعیت خود را کوتاه شرح دهید تا کارشناس بهتر آماده شود.'
      : 'Briefly describe your situation so the advisor can prepare.';
  String get preferredTime =>
      fa ? 'زمان ترجیحی (اختیاری)' : 'Preferred time (optional)';
  String get preferredTimeRequired => fa
      ? 'این خدمت به بازه زمانی ترجیحی نیاز دارد.'
      : 'This service requires a preferred time window.';
  String get pickTime => fa ? 'انتخاب تاریخ و ساعت' : 'Pick date and time';
  String get timeZoneLabel => fa ? 'منطقه زمانی انتخابی' : 'Selected time zone';
  String get submit => fa ? 'ارسال درخواست' : 'Submit request';
  String get submitting => fa ? 'در حال ارسال…' : 'Submitting…';
  String get success => fa
      ? 'درخواست رزرو ثبت شد. وضعیت آن پس از بررسی کارشناس اینجا نمایش داده می‌شود.'
      : 'Your booking request was submitted. Its status appears here once an advisor reviews it.';
  String get backendUnavailable => fa
      ? 'سیستم رزرو آنلاین هنوز راه‌اندازی نشده است. درخواست مشاوره انسانی همچنان فعال است.'
      : 'Online booking is not deployed yet. Human consultation requests still work.';
  String get bookingUnavailableAction =>
      fa ? 'رزرو زمان‌بندی‌شده در دسترس نیست' : 'Scheduled booking unavailable';
  String get emptyHistory => fa
      ? 'هنوز درخواست رزروی ثبت نکرده‌اید.'
      : 'You have not submitted any booking requests yet.';
  String get historyFailed => fa
      ? 'بارگذاری تاریخچه رزروها ممکن نشد.'
      : 'Could not load your booking history.';
  String get signInRequired =>
      fa ? 'برای رزرو خدمات باید وارد شوید.' : 'Sign in to book services.';
  String get signIn => fa ? 'ورود' : 'Sign in';
  String get retry => fa ? 'تلاش دوباره' : 'Retry';
  String get messageRequired =>
      fa ? 'توضیحات الزامی است.' : 'Message is required.';
  String get messageTooShort => fa
      ? 'توضیحات باید دست‌کم ۱۰ نویسه باشد.'
      : 'Message must be at least 10 characters.';
  String get messageTooLong => fa
      ? 'توضیحات باید حداکثر ۱۰۰۰ نویسه باشد.'
      : 'Message must be at most 1000 characters.';
  String get slotIncomplete => fa
      ? 'هر دو تاریخ شروع و پایان را انتخاب کنید.'
      : 'Choose both a start and an end time.';
  String get slotOrder => fa
      ? 'زمان پایان باید پس از زمان شروع باشد.'
      : 'End time must be after the start time.';
  String get slotTooShort => fa
      ? 'بازه انتخابی باید دست‌کم ۱۵ دقیقه باشد.'
      : 'The selected window must be at least 15 minutes.';
  String get slotTooLong => fa
      ? 'بازه انتخابی نباید بیش از ۲۴ ساعت باشد.'
      : 'The selected window must not exceed 24 hours.';
  String get slotPast => fa
      ? 'زمان انتخابی نمی‌تواند در گذشته باشد.'
      : 'The selected time cannot be in the past.';
  String get statusSubmitted => fa ? 'ارسال‌شده' : 'Submitted';
  String get statusInReview => fa ? 'در حال بررسی' : 'In review';
  String get statusConfirmed => fa ? 'تأییدشده' : 'Confirmed';
  String get statusRescheduled => fa ? 'تغییر زمان‌شده' : 'Rescheduled';
  String get statusCancelled => fa ? 'لغوشده' : 'Cancelled';
  String get statusCompleted => fa ? 'انجام‌شده' : 'Completed';
  String get statusUnknown => fa ? 'نامشخص' : 'Unknown';
  String get durationLabel => fa ? 'مدت تقریبی' : 'Approximate duration';
  String get minutesUnit => fa ? 'دقیقه' : 'min';
  String get noPriceNote => fa
      ? 'قیمت‌ها فقط پس از تأیید رسمی در Backend اینجا نمایش داده می‌شوند.'
      : 'Prices appear here only once the Backend publishes them officially.';
  String get durationUnavailable => fa
      ? 'مدت این خدمت هنوز اعلام نشده است.'
      : 'Duration for this service has not been published.';
  String get consultationBadge => fa ? 'گفتگوی انسانی' : 'Human conversation';
  String get scheduledBadge => fa ? 'نیازمند زمان‌بندی' : 'Scheduling required';
  String get backendCatalogNote =>
      fa ? 'خدمات منتشرشده توسط RAD' : 'Services published by RAD';
  String get genericError => fa
      ? 'ارسال درخواست رزرو ممکن نشد.'
      : 'Could not submit the booking request.';
  String get notConfirmedNote => fa
      ? 'ثبت درخواست به معنی تأیید قطعی نیست.'
      : 'Submitting a request does not confirm a booking.';
}

/// Maps a booking status enum to its localized label.
String bookingStatusLabel(Object status, BookingLabels labels) {
  final name = status is String ? status : status.toString();
  if (name.contains('confirmed')) return labels.statusConfirmed;
  if (name.contains('inReview')) return labels.statusInReview;
  if (name.contains('rescheduled')) return labels.statusRescheduled;
  if (name.contains('cancelled')) return labels.statusCancelled;
  if (name.contains('completed')) return labels.statusCompleted;
  if (name.contains('submitted')) return labels.statusSubmitted;
  return labels.statusUnknown;
}
