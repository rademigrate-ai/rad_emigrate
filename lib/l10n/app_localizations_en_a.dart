import 'app_localizations.dart';

mixin AppLocalizationsEnA on AppLocalizations {
  @override
  String get appTitle => 'RAD International Institute';

  @override
  String get signIn => 'Sign in';

  @override
  String get adminConsultations => 'Consultations';

  @override
  String get noAdminConsultations => 'No consultation requests.';

  @override
  String get consultationTitle => 'Request consultation';

  @override
  String get consultationIntro =>
      'Submit a request and a RAD advisor will follow up. This does not create a visa application automatically.';

  @override
  String get consultationTopic => 'Topic';

  @override
  String get consultationMessage => 'Message';

  @override
  String get consultationFieldsRequired => 'Topic and message are required.';

  @override
  String get consultationSubmitted =>
      'Your consultation request was submitted.';

  @override
  String get consultationSubmitFailed =>
      'Could not submit the consultation request.';

  @override
  String get submitConsultation => 'Submit request';

  @override
  String get myConsultations => 'Your requests';

  @override
  String get noConsultations => 'No consultation requests yet.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get noNotifications => 'No notifications yet.';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get notificationLoadFailed => 'Could not load notifications.';

  @override
  String get requestConsultation => 'Request consultation';

  @override
  String get smsAuthUnavailable =>
      'Phone verification is not available right now. Use email or password instead.';

  @override
  String get consultationStatus => 'Status';

  @override
  String get consultationAdminNote => 'Internal note';

  @override
  String get saveConsultation => 'Update';

  @override
  String get consultationUpdated => 'Consultation updated.';

  @override
  String get consultationUpdateFailed => 'Could not update consultation.';

  @override
  String get openNotifications => 'Notifications';

  @override
  String get openConsultation => 'Consultation';

  @override
  String get lastProviderCheck => 'Last provider check';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get required => 'Required';

  @override
  String get loading => 'Loading…';

  @override
  String get splashLoadingStatus => 'Preparing your secure RAD workspace';

  @override
  String get retry => 'Retry';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get home => 'Home';

  @override
  String get visa => 'Visa';

  @override
  String get cases => 'Cases';

  @override
  String get docs => 'Docs';

  @override
  String get profile => 'Profile';

  @override
  String get feed => 'Feed';

  @override
  String get aiAssistant => 'AI Assistant';

  @override
  String get admin => 'Admin';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get logout => 'Log out';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get english => 'English';

  @override
  String get persian => 'Persian';

  @override
  String get signInSubtitle => 'Sign in to manage your immigration case';

  @override
  String get signUpSubtitle =>
      'Create an account to organize your documents and follow your immigration case.';

  @override
  String get passwordResetSubtitle =>
      'Enter your account email to request a password reset link.';

  @override
  String get passwordResetFailed =>
      "We couldn't request a reset link. Please try again.";

  @override
  String get passwordResetRateLimited =>
      'Too many reset requests. Please wait a minute, then try again.';

  @override
  String get passwordResetLinkInvalid =>
      'This reset link is invalid or has expired. Request a new link.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get createAccount => 'Create an account';

  @override
  String get continueWithOtp => 'Continue with OTP';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get signUp => 'Sign up';

  @override
  String get alreadyHaveAccount => 'Already have an account? Sign in';

  @override
  String get fullName => 'Full name';

  @override
  String get phone => 'Phone';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordTooShort => 'Password must be at least 8 characters';

  @override
  String get invalidEmail => 'Enter a valid email address';

  @override
  String get otpTitle => 'Enter verification code';

  @override
  String get otpSubtitle => 'We sent a 6-digit code to your email';

  @override
  String get otpCode => 'Verification code';

  @override
  String get verify => 'Verify';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendIn(int seconds) => 'Resend in ${seconds}s';

  @override
  String get profileCompletionTitle => 'Complete your profile';

  @override
  String get profileCompletionSubtitle =>
      'A few details help us personalize your experience';

  @override
  String get saveAndContinue => 'Save and continue';

  @override
  String get errorNetwork =>
      'Network error. Check your connection and try again.';

  @override
  String get errorAuthInvalid => 'Invalid email or password.';

  @override
  String get errorAuthSession =>
      'Your session has expired. Please sign in again.';

  @override
  String get emptyState => 'Nothing here yet';

  @override
  String get search => 'Search';

  @override
  String get filter => 'Filter';

  @override
  String get status => 'Status';

  @override
  String get documents => 'Documents';

  @override
  String get applications => 'Applications';

  @override
  String get noDocuments => 'No documents uploaded yet';

  @override
  String get noApplications => 'No applications yet';

  @override
  String get uploadDocument => 'Upload document';

  @override
  String get viewDetails => 'View details';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get setNewPassword => 'Set new password';

  @override
  String get newPassword => 'New password';

  @override
  String get passwordResetSent =>
      'If an account exists for that email, we sent a reset link.';

  @override
  String get passwordUpdated =>
      'Password updated successfully. You can now sign in.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get yourJourney => 'Your journey';

  @override
  String helloName(String name) => 'Hello, $name';

  @override
  String get travelerFallback => 'Traveler';

  @override
  String get needsYourAction => 'Needs your action';

  @override
  String get needsActionSubtitle =>
      'Complete these items to keep your case moving';

  @override
  String get completeProfileTitle => 'Complete your profile';

  @override
  String get completeProfileSubtitle => 'Add your name and basic details';

  @override
  String documentsMissingCount(int count) => '$count documents missing';

  @override
  String get documentMissingOne => '1 document missing';

  @override
  String get reviewRequiredFiles => 'Review the required files for your case';

  @override
  String get actionBadge => 'Action';

  @override
  String get caseOverview => 'Case overview';

  @override
  String get caseOverviewSubtitle => 'A quick view of your active work';

  @override
  String get allCases => 'All cases';

  @override
  String get activeCases => 'Active cases';

  @override
  String get documentsMissing => 'Documents missing';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get quickActionsSubtitle => 'Start where you need help today';

  @override
  String get visaPrograms => 'Visa programs';

  @override
  String get radUpdates => 'RAD updates';

  @override
  String get shortcuts => 'Shortcuts';

  @override
  String get profileShortcutSubtitle => 'Personal and immigration details';

  @override
  String get askAssistant => 'Ask the assistant';

  @override
  String get askAssistantSubtitle => 'Visas, documents, and process guidance';

  @override
  String get nextStepReady => 'Your next step is ready';

  @override
  String get onTrack => 'You are on track';

  @override
  String get nextStepDescription =>
      'A few items need your attention before your case can move forward.';

  @override
  String get onTrackDescription =>
      'Your current case information is up to date. Review your progress or ask for guidance.';

  @override
  String get reviewNextStep => 'Review next step';

  @override
  String get viewApplications => 'View applications';

  @override
  String get refresh => 'Refresh';

  @override
  String get progress => 'Progress';

  @override
  String get updateStatus => 'Update status';

  @override
  String get updateStatusHint =>
      'Use this only to reflect the latest confirmed case state.';

  @override
  String get newDraft => 'New draft';

  @override
  String get creating => 'Creating…';

  @override
  String get loadingApplications => 'Loading applications…';

  @override
  String get noApplicationsSubtitle =>
      'Start a draft or explore visa programs.';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusSubmitted => 'Submitted';

  @override
  String get statusReviewing => 'Under review';

  @override
  String get statusDocumentsRequired => 'Documents required';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get loadingDocuments => 'Loading documents…';

  @override
  String get addType => 'Add type';

  @override
  String get missingSection => 'Missing';

  @override
  String get missingSectionSubtitle =>
      'Upload these to continue your application';

  @override
  String get allDocuments => 'All documents';

  @override
  String get submittedSection => 'Submitted';

  @override
  String get noDocumentsSubtitle =>
      'Add required document types for your case.';

  @override
  String get chooseFileUpload => 'Choose file and upload';

  @override
  String get deleteDocument => 'Delete document';

  @override
  String get deleteDocumentTitle => 'Delete document?';

  @override
  String get deleteDocumentBody =>
      'This removes the document record and its private file.';

  @override
  String get close => 'Close';

  @override
  String get acceptedFormats =>
      'Accepted formats: PDF, JPG, JPEG, and PNG. Maximum size: 10 MB.';

  @override
  String get couldNotReadFile => 'Could not read that file.';

  @override
  String get fileTooLarge => 'Files must be 10 MB or smaller.';

  @override
  String get uploadFailed => 'Upload failed. Please try again.';

  @override
  String get deleteFailed => 'Delete failed. Please try again.';

  @override
  String get typeLabel => 'Type';

  @override
  String get statusLabel => 'Status';

  @override
  String get aiDisclaimer =>
      'Sourced answers are unavailable until the RAD Knowledge Base is configured. Nothing here is an official immigration decision.';

  @override
  String get howCanWeHelp => 'How can we help?';

  @override
  String get askAboutVisas =>
      'Ask about visas, documents, or process. Try a suggestion:';

  @override
  String get askQuestionHint => 'Ask a question…';

  @override
  String freeQuota(int used, int limit) => '$used / $limit free';

  @override
  String get aiQuotaExhausted => 'Free AI questions used for this session.';

  @override
  String get couldNotSaveQuestion =>
      'Could not save this question. Please try again.';

  @override
  String get sourceLabel => 'Source';

  @override
  String get adminOperations => 'Admin operations';

  @override
  String get loadingOperational => 'Loading operational data…';

  @override
  String get adminLoadFailed => 'Admin operations could not be loaded.';
}
