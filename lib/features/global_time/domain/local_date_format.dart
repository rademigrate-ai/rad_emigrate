import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

/// Formats a wall-clock [DateTime] for display.
/// FA → Jalali (شمسی); EN → Gregorian.
String formatLocalDate(DateTime dt, String languageCode) {
  if (languageCode == 'fa') {
    final j = Jalali.fromDateTime(dt);
    final f = j.formatter;
    // e.g. دوشنبه، ۱۵ مهر ۱۴۰۵
    return '${f.wN}، ${f.d} ${f.mN} ${f.yyyy}';
  }
  return DateFormat('EEE, d MMM yyyy').format(dt);
}

String formatLocalTime(DateTime dt) => DateFormat('HH:mm').format(dt);
