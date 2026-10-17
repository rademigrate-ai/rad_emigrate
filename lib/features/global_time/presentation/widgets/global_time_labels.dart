/// Labels specific to the approved dashboard; all product copy is bilingual.
class GlobalTimeLabels {
  const GlobalTimeLabels(this.language);
  final String language;
  bool get fa => language == 'fa';
  String get title => fa ? 'ساعت جهانی RAD' : 'RAD Global Time';
  String get map => fa ? 'نقشه جهانی' : 'World map';
  String get clocks => fa ? 'ساعت‌های من' : 'My clocks';
  String get favorites => fa ? 'شهرهای مورد علاقه' : 'Favorite cities';
  String get remove => fa ? 'حذف شهر' : 'Remove city';
  String get originTime => fa ? 'ساعت در شهر مبدأ' : 'Time in origin city';
  String get converted => fa ? 'زمان متناظر' : 'Converted time';
  String get gap => fa
      ? 'این ساعت به دلیل تغییر ساعت تابستانی وجود ندارد. ساعت دیگری انتخاب کنید.'
      : 'This local time does not exist because of daylight saving. Choose another time.';
  String get fold => fa
      ? 'این ساعت دوبار رخ می‌دهد. نوبت مورد نظر را انتخاب کنید.'
      : 'This local time occurs twice. Select the intended occurrence.';
  String get first => fa ? 'نوبت اول' : 'First occurrence';
  String get second => fa ? 'نوبت دوم' : 'Second occurrence';
  String get assumptions => fa
      ? 'پیشنهادها: هر روز ۹ تا ۱۸ به وقت محلی هر دو شهر، بدون بررسی تعطیلات یا تقویم افراد. این‌ها زمان آزاد تأییدشده نیستند.'
      : 'Suggestions assume 09:00–18:00 local in both cities, every day. Holidays and personal calendars are not checked; these are not confirmed availability.';
  String get noOverlap => fa
      ? 'در ساعات کاری فرض‌شده، بازه مشترکی وجود ندارد.'
      : 'No shared window within the assumed working hours.';
  String get solar => fa
      ? 'نوار روشن: روز برآوردشده از موقعیت خورشید؛ وضعیت آب‌وهوا نیست.'
      : 'Light band: estimated solar daylight, not weather.';
  String get timezoneError => fa
      ? 'داده منطقه زمانی در دسترس نیست؛ ساعت‌ها نمایش داده نمی‌شوند.'
      : 'Timezone data is unavailable; clocks are withheld.';
  String get retry => fa ? 'تلاش دوباره' : 'Retry';
  String get compare =>
      fa ? 'مقایسه زمان در شهرها' : 'Compare time across cities';
}
