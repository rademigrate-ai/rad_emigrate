// Generated-style localization facade for RAD Emigrate.
// Keep in sync with lib/l10n/app_en.arb and app_fa.arb.
// generate: false — this custom facade is intentional.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_localizations_en.dart';
import 'app_localizations_fa.dart';

abstract class AppLocalizations {
  AppLocalizations(this.localeName);

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    final instance = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
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

  static const List<Locale> supportedLocales = [Locale('en'), Locale('fa')];

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
  String get yourJourney;
  String helloName(String name);
  String get travelerFallback;
  String get needsYourAction;
  String get needsActionSubtitle;
  String get completeProfileTitle;
  String get completeProfileSubtitle;
  String documentsMissingCount(int count);
  String get documentMissingOne;
  String get reviewRequiredFiles;
  String get actionBadge;
  String get caseOverview;
  String get caseOverviewSubtitle;
  String get allCases;
  String get activeCases;
  String get documentsMissing;
  String get quickActions;
  String get quickActionsSubtitle;
  String get visaPrograms;
  String get radUpdates;
  String get shortcuts;
  String get profileShortcutSubtitle;
  String get askAssistant;
  String get askAssistantSubtitle;
  String get nextStepReady;
  String get onTrack;
  String get nextStepDescription;
  String get onTrackDescription;
  String get reviewNextStep;
  String get viewApplications;
  String get refresh;
  String get progress;
  String get updateStatus;
  String get updateStatusHint;
  String get newDraft;
  String get creating;
  String get loadingApplications;
  String get noApplicationsSubtitle;
  String get statusDraft;
  String get statusSubmitted;
  String get statusReviewing;
  String get statusDocumentsRequired;
  String get statusApproved;
  String get statusRejected;
  String get statusCompleted;
  String get loadingDocuments;
  String get addType;
  String get missingSection;
  String get missingSectionSubtitle;
  String get allDocuments;
  String get submittedSection;
  String get noDocumentsSubtitle;
  String get chooseFileUpload;
  String get deleteDocument;
  String get deleteDocumentTitle;
  String get deleteDocumentBody;
  String get close;
  String get acceptedFormats;
  String get couldNotReadFile;
  String get fileTooLarge;
  String get uploadFailed;
  String get deleteFailed;
  String get typeLabel;
  String get statusLabel;
  String get aiDisclaimer;
  String get howCanWeHelp;
  String get askAboutVisas;
  String get askQuestionHint;
  String freeQuota(int used, int limit);
  String get aiQuotaExhausted;
  String get couldNotSaveQuestion;
  String get sourceLabel;
  String get adminOperations;
  String get loadingOperational;
  String get adminLoadFailed;
  String get adminRestricted;
  String get superAdmin;
  String get operationalOverview;
  String get researchJobs;
  String get aiRequests;
  String get documentJobs;
  String get openTasks;
  String get auditEvents;
  String get serverEnforcedAccess;
  String get serverEnforcedAccessBody;
  String get visaPathways;
  String get loadingCatalogue;
  String get catalogueUnavailable;
  String get findPathway;
  String get catalogueDisclaimer;
  String get searchProgrammes;
  String get allDestinations;
  String get allServices;
  String get noProgrammeFound;
  String get tryChangingFilters;
  String get publishedTimeline;
  String get publishedFee;
  String get publishedRequirements;
  String get source;
  String get visaDisclaimer;
  String get feedTitle;
  String get loadingUpdates;
  String get updatesLoadFailed;
  String get noReviewedUpdates;
  String get bookmark;
  String get removeBookmark;
  String get backToApplications;
  String get couldNotCreateDraft;
  String get couldNotUpdateStatus;
  String get newApplicationDraft;
  String get toBeSelected;
  String get pageNotFound;
  String get nationality;
  String get firstName;
  String get lastName;
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
