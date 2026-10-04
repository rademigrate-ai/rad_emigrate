// Generated-style localization facade for RAD Emigrate.
// Keep in sync with lib/l10n/app_en.arb and app_fa.arb.
// Running `flutter gen-l10n` will regenerate official delegates;
// this file provides a stable compile-time API for the app.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

abstract class AppLocalizations {
  AppLocalizations(this.localeName);

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    final instance =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(instance != null, 'No AppLocalizations found in context');
    return instance!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('fa'),
  ];

  String get appTitle;
  String get signIn;
  String get signInSubtitle;
  String get email;
  String get password;
  String get showPassword;
  String get hidePassword;
  String get required;
  String get createAccount;
  String get continueWithOtp;
  String get forgotPassword;
  String get signUp;
  String get alreadyHaveAccount;
  String get fullName;
  String get phone;
  String get confirmPassword;
  String get passwordsDoNotMatch;
  String get passwordTooShort;
  String get invalidEmail;
  String get otpTitle;
  String get otpSubtitle;
  String get otpCode;
  String get verify;
  String get resendCode;
  String resendIn(int seconds);
  String get profileCompletionTitle;
  String get profileCompletionSubtitle;
  String get saveAndContinue;
  String get home;
  String get visa;
  String get cases;
  String get docs;
  String get profile;
  String get feed;
  String get aiAssistant;
  String get admin;
  String get dashboard;
  String get logout;
  String get settings;
  String get language;
  String get theme;
  String get themeLight;
  String get themeDark;
  String get themeSystem;
  String get english;
  String get persian;
  String get loading;
  String get retry;
  String get errorGeneric;
  String get errorNetwork;
  String get errorAuthInvalid;
  String get errorAuthSession;
  String get emptyState;
  String get cancel;
  String get save;
  String get delete;
  String get confirm;
  String get back;
  String get next;
  String get search;
  String get filter;
  String get status;
  String get documents;
  String get applications;
  String get noDocuments;
  String get noApplications;
  String get uploadDocument;
  String get viewDetails;
  String get resetPassword;
  String get setNewPassword;
  String get newPassword;
  String get passwordResetSent;
  String get passwordUpdated;
  String get sendResetLink;
  String get backToSignIn;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fa'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'fa':
      return AppLocalizationsFa();
    case 'en':
    default:
      return AppLocalizationsEn();
  }
}
