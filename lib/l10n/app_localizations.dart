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
  String get signUpSubtitle;
  String get passwordResetSubtitle;
  String get passwordResetFailed;
  String get passwordResetRateLimited;
  String get passwordResetLinkInvalid;
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
  String get splashLoadingStatus;
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
  String get structuredDetailsPending;
  String get structuredDetailsPendingBody;
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
  String get aboutYou;
  String get nationalityOptional;
  String get changesSaved;
  String get accountAlreadyExists;
  String get otpInvalidOrExpired;
  String get otpResent;
  String get more;
  String get sendMessage;
  String get suggestionStudyPermitDocuments;
  String get suggestionVisaProcessingTime;
  String get suggestionGteStatement;
  String aiUnavailableResponse(String question);
  String get newDocument;
  String get documentTypePassport;
  String get documentTypeIdentity;
  String get documentTypeEducation;
  String get documentTypeFinancial;
  String get documentTypeVisa;
  String get documentTypeOther;
  String get documentStatusMissing;
  String get documentStatusUploaded;
  String get documentStatusUnderReview;
  String get documentStatusVerified;
  String get documentStatusRejected;
  String get adminAiConfig;
  String get providerModelConnection;
  String get credentialsServerOnly;
  String get configurationUnavailable;
  String get noProviderConfigured;
  String get addOrUpdateProvider;
  String get slugLabel;
  String get displayName;
  String get adapterType;
  String get publicHttpsOnly;
  String get apiKeyWriteOnly;
  String get keyMinimumEight;
  String get keepCurrentCredential;
  String get enabled;
  String get priority;
  String get saveProvider;
  String get credentialConfigured;
  String get credentialMissing;
  String get testProvider;
  String get discoverModels;
  String get runtimeScope;
  String get trustClass;
  String get researchSource;
  String get queueResearchRun;
  String get adminResearchAssistant;
  String get adminResearchSubtitle;
  String get untrustedResearchDisclaimer;
  String get providerSaved;
  String get providerSaveFailed;
  String get providerTestFailed;
  String get modelDiscoveryFailed;
  String get disabled;
  String get active;
  String get inactive;
  String get critical;
  String get unavailable;
  String get baseUrl;
  String get lowercaseSlugHint;
  String providerReachable(int count);
  String modelDiscoveryCompleted(int discovered, int added);
  String get noContentSources;
  String get approvedSourcesAppearHere;
  String get noResearchJobs;
  String get operationsHealth;
  String get noOperationalComponents;
  String get componentInventoryUnavailable;
  String get auditSecurity;
  String get noAuditEvents;
  String get auditRestricted;
  String get categoryUpdate;
  String get categoryGuide;
  String get categoryDeadline;
  String get categoryEvent;
  String get categoryAnnouncement;
  String get sourceAddress;
  String get sourceSavedDisabled;
  String get sourceDuplicate;
  String get sourceSaveFailed;
  String get sourceEnable;
  String get sourceDisable;
  String get researchSourcesTitle;
  String get researchRunning;
  String get researchRunFailed;
  String get openReviewQueue;
  String get brandIntroTitle;
  String get brandIntroBody;
  String get exploreVisa;
  String get reviewQueueEmpty;
  String get sourceStateUnknown;
  String get sourceLastSuccess;
  String get sourceHttpRejected;
  String get providerSavedDiscoveryFailed;
  String get aiCredentialRejected;
  String get aiNoEligibleModel;
  String get aiRateLimited;
  String get aiRequestFailed;
  String get aiResponseNotSaved;
  String get addSource;
  String get requiredField;
  String get invalidUrl;
  String get titleLabel;
  String get sourceType;
  String get researchPipelineSummary;
  String findingsCount(int count);
  String draftsInReview(int count);
  String get feedPublishedOnly;
  String get lastResearchRun;
  String get researchNeverAutoPublishes;
  String get researchQueued;

  // Stage 2 review / feed / visa
  String get reviewQueueTitle;
  String get reviewDraftTitle;
  String get reviewFindingTitle;
  String get reject;
  String get keepPending;
  String get approve;
  String get publishExplicit;
  String get publishRequiresHuman;
  String get findingPublishNote;
  String get editTitle;
  String get editBody;
  String get category;
  String get applicationSteps;
  String get structuredSourceNote;
  String get publishedStatus;
  String get draftStatusLabel;
  String get reviewStatusLabel;
  String get scopeUser;
  String get scopeBoth;
  String get healthOffline;
  String get healthHealthy;
  String get healthDegraded;
  String get healthUnknown;
  String get modelSaveFailed;
  String get sourceQueryRejected;
  String get lastProviderCheck;

  // Stage 7/8 product surfaces
  String get consultationTitle;
  String get consultationIntro;
  String get consultationTopic;
  String get consultationMessage;
  String get consultationFieldsRequired;
  String get consultationSubmitted;
  String get consultationSubmitFailed;
  String get submitConsultation;
  String get myConsultations;
  String get noConsultations;
  String get notificationsTitle;
  String get noNotifications;
  String get markAllRead;
  String get notificationLoadFailed;
  String get requestConsultation;
  String get smsAuthUnavailable;
  String get adminConsultations;
  String get noAdminConsultations;
  String get consultationStatus;
  String get consultationAdminNote;
  String get saveConsultation;
  String get consultationUpdated;
  String get consultationUpdateFailed;
  String get openNotifications;
  String get openConsultation;
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
