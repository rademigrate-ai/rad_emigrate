import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';

String consultationStatusLabel(Object? status, AppLocalizations l10n) =>
    switch (status) {
      'submitted' => l10n.statusSubmitted,
      'in_review' => l10n.statusReviewing,
      'contacted' => l10n.consultationContacted,
      'closed' => l10n.consultationClosed,
      _ => l10n.unavailable,
    };
String recordDateLabel(Object? timestamp, BuildContext context) {
  final date = DateTime.tryParse(timestamp?.toString() ?? '');
  if (date == null) return AppLocalizations.of(context).unavailable;
  final locale = Localizations.localeOf(context).languageCode;
  return DateFormat.yMMMd(locale).add_Hm().format(date.toLocal());
}
