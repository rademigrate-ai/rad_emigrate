import 'app_localizations.dart';

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([super.localeName = 'en']);

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
  String get consultationIntro => 'Submit a request and a RAD advisor will follow up. This does not create a visa application automatically.';
  @override
  String get consultationTopic => 'Topic';
  @override
  String get consultationMessage => 'Message';
  @override
  String get consultationFieldsRequired => 'Topic and message are required.';
  @override
  String get consultationSubmitted => 'Your consultation request was submitted.';
  @override
  String get consultationSubmitFailed => 'Could not submit the consultation request.';
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
  String get smsAuthUnavailable => 'Phone verification is not available right now. Use email or password instead.';
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
  String get signUpSubtitle => 'Create an account to organize your documents and follow your immigration case.';
  @override
  String get passwordResetSubtitle => 'Enter your account email to request a password reset link.';
  @override
  String get passwordResetFailed => "We couldn't request a reset link. Please try again.";
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
  String get profileCompletionSubtitle => 'A few details help us personalize your experience';
  @override
  String get saveAndContinue => 'Save and continue';
  @override
  String get errorNetwork => 'Network error. Check your connection and try again.';
  @override
  String get errorAuthInvalid => 'Invalid email or password.';
  @override
  String get errorAuthSession => 'Your session has expired. Please sign in again.';
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
  String get passwordResetSent => 'If an account exists for that email, we sent a reset link.';
  @override
  String get passwordUpdated => 'Password updated successfully. You can now sign in.';
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
  String get needsActionSubtitle => 'Complete these items to keep your case moving';
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
  String get nextStepDescription => 'A few items need your attention before your case can move forward.';
  @override
  String get onTrackDescription => 'Your current case information is up to date. Review your progress or ask for guidance.';
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
  String get updateStatusHint => 'Use this only to reflect the latest confirmed case state.';
  @override
  String get newDraft => 'New draft';
  @override
  String get creating => 'Creating…';
  @override
  String get loadingApplications => 'Loading applications…';
  @override
  String get noApplicationsSubtitle => 'Start a draft or explore visa programs.';
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
  String get missingSectionSubtitle => 'Upload these to continue your application';
  @override
  String get allDocuments => 'All documents';
  @override
  String get submittedSection => 'Submitted';
  @override
  String get noDocumentsSubtitle => 'Add required document types for your case.';
  @override
  String get chooseFileUpload => 'Choose file and upload';
  @override
  String get deleteDocument => 'Delete document';
  @override
  String get deleteDocumentTitle => 'Delete document?';
  @override
  String get deleteDocumentBody => 'This removes the document record and its private file.';
  @override
  String get close => 'Close';
  @override
  String get acceptedFormats => 'Accepted formats: PDF, JPG, JPEG, and PNG. Maximum size: 10 MB.';
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
  String get aiDisclaimer => 'Sourced answers are unavailable until the RAD Knowledge Base is configured. Nothing here is an official immigration decision.';
  @override
  String get howCanWeHelp => 'How can we help?';
  @override
  String get askAboutVisas => 'Ask about visas, documents, or process. Try a suggestion:';
  @override
  String get askQuestionHint => 'Ask a question…';
  @override
  String freeQuota(int used, int limit) => '$used / $limit free';
  @override
  String get aiQuotaExhausted => 'Free AI questions used for this session.';
  @override
  String get couldNotSaveQuestion => 'Could not save this question. Please try again.';
  @override
  String get sourceLabel => 'Source';
  @override
  String get adminOperations => 'Admin operations';
  @override
  String get loadingOperational => 'Loading operational data…';
  @override
  String get adminLoadFailed => 'Admin operations could not be loaded.';
  @override
  String get adminRestricted => 'This route is restricted to verified RAD administrators.';
  @override
  String get superAdmin => 'Super Admin';
  @override
  String get operationalOverview => 'Operational overview';
  @override
  String get researchJobs => 'Research jobs';
  @override
  String get aiRequests => 'AI requests';
  @override
  String get documentJobs => 'Document jobs';
  @override
  String get openTasks => 'Open tasks';
  @override
  String get auditEvents => 'Audit events';
  @override
  String get serverEnforcedAccess => 'Server-enforced access';
  @override
  String get serverEnforcedAccessBody => 'Case notes, tasks, status history, provider health, and role changes are protected by RLS and audit events.';
  @override
  String get visaPathways => 'Visa and migration pathways';
  @override
  String get loadingCatalogue => 'Loading verified catalogue…';
  @override
  String get catalogueUnavailable => 'Catalogue unavailable. Please try again.';
  @override
  String get findPathway => 'Find a relevant pathway';
  @override
  String get catalogueDisclaimer => 'Only published, sourced RAD content is shown. Always verify current rules with the official authority.';
  @override
  String get searchProgrammes => 'Search programmes';
  @override
  String get allDestinations => 'All destinations';
  @override
  String get allServices => 'All services';
  @override
  String get noProgrammeFound => 'No programme found';
  @override
  String get tryChangingFilters => 'Try changing the search or filters.';
  @override
  String get publishedTimeline => 'Published timeline';
  @override
  String get publishedFee => 'Published fee';
  @override
  String get publishedRequirements => 'Published requirements';
  @override
  String get structuredDetailsPending => 'Structured details are awaiting review';
  @override
  String get structuredDetailsPendingBody => 'No verified requirements or application steps have been published for this programme yet. Use the cited source and confirm current rules with the official authority.';
  @override
  String get source => 'Source';
  @override
  String get visaDisclaimer => 'This information does not guarantee an outcome and does not replace current official rules or professional review.';
  @override
  String get feedTitle => 'RAD updates';
  @override
  String get loadingUpdates => 'Loading RAD updates…';
  @override
  String get updatesLoadFailed => 'Updates could not be loaded.';
  @override
  String get noReviewedUpdates => 'No reviewed updates have been published yet.';
  @override
  String get bookmark => 'Bookmark';
  @override
  String get removeBookmark => 'Remove bookmark';
  @override
  String get backToApplications => 'Back to applications';
  @override
  String get couldNotCreateDraft => 'Could not create draft. Please try again.';
  @override
  String get couldNotUpdateStatus => 'Could not update status. Please try again.';
  @override
  String get newApplicationDraft => 'New application draft';
  @override
  String get toBeSelected => 'To be selected';
  @override
  String get pageNotFound => 'Page not found';
  @override
  String get nationality => 'Nationality';
  @override
  String get firstName => 'First name';
  @override
  String get lastName => 'Last name';
  @override
  String get aboutYou => 'About you';
  @override
  String get nationalityOptional => 'Nationality (optional)';
  @override
  String get changesSaved => 'Changes saved.';
  @override
  String get accountAlreadyExists => 'An account already exists for this email. Sign in instead.';
  @override
  String get otpInvalidOrExpired => 'That verification code is invalid or has expired.';
  @override
  String get otpResent => 'A new verification code was sent.';
  @override
  String get more => 'More';
  @override
  String get sendMessage => 'Send message';
  @override
  String get suggestionStudyPermitDocuments => 'What documents are typically needed for a study permit?';
  @override
  String get suggestionVisaProcessingTime => 'How long can a visa process take?';
  @override
  String get suggestionGteStatement => 'What is a GTE statement?';
  @override
  String aiUnavailableResponse(String question) => 'The RAD Knowledge Base is not configured for this build.\n\nYour question: "$question"\n\nSourced answers will be available after the approved provider is configured. No immigration requirements are inferred here.';
  @override
  String get newDocument => 'New document';
  @override
  String get documentTypePassport => 'Passport';
  @override
  String get documentTypeIdentity => 'Identity document';
  @override
  String get documentTypeEducation => 'Education document';
  @override
  String get documentTypeFinancial => 'Financial document';
  @override
  String get documentTypeVisa => 'Visa document';
  @override
  String get documentTypeOther => 'Other';
  @override
  String get documentStatusMissing => 'Missing';
  @override
  String get documentStatusUploaded => 'Uploaded';
  @override
  String get documentStatusUnderReview => 'Under review';
  @override
  String get documentStatusVerified => 'Verified';
  @override
  String get documentStatusRejected => 'Rejected';
  @override
  String get adminAiConfig => 'AI configuration';
  @override
  String get providerModelConnection => 'Providers, models & API connection';
  @override
  String get credentialsServerOnly => 'Credentials are server-side only and stored values are never returned to the browser.';
  @override
  String get configurationUnavailable => 'Configuration is unavailable.';
  @override
  String get noProviderConfigured => 'No provider is configured yet. Use the form below for initial setup.';
  @override
  String get addOrUpdateProvider => 'Add or update provider';
  @override
  String get slugLabel => 'Slug';
  @override
  String get displayName => 'Display name';
  @override
  String get adapterType => 'Adapter';
  @override
  String get publicHttpsOnly => 'Must be a valid public HTTPS URL';
  @override
  String get apiKeyWriteOnly => 'API key (write-only)';
  @override
  String get keyMinimumEight => 'Key must be at least 8 characters';
  @override
  String get keepCurrentCredential => 'Leave blank to keep the current credential.';
  @override
  String get enabled => 'Enabled';
  @override
  String get priority => 'Priority';
  @override
  String get saveProvider => 'Save provider';
  @override
  String get credentialConfigured => 'Credential configured';
  @override
  String get credentialMissing => 'Credential missing';
  @override
  String get testProvider => 'Test provider';
  @override
  String get discoverModels => 'Discover models';
  @override
  String get runtimeScope => 'Runtime scope';
  @override
  String get trustClass => 'Trust class';
  @override
  String get researchSource => 'Research source';
  @override
  String get queueResearchRun => 'Queue research run';
  @override
  String get adminResearchAssistant => 'Admin research assistant';
  @override
  String get adminResearchSubtitle => 'Broader research with evidence, provenance and conflicts preserved; no automatic publishing.';
  @override
  String get untrustedResearchDisclaimer => 'Retrieved content is untrusted; conflicts are preserved and nothing is published automatically.';
  @override
  String get providerSaved => 'Provider saved. The credential is stored server-side and will not be shown again.';
  @override
  String get providerSaveFailed => 'Could not save configuration. Confirm Super Admin role and input validity.';
  @override
  String get providerTestFailed => 'Provider test failed with a sanitized provider error.';
  @override
  String get modelDiscoveryFailed => 'Model discovery failed with a sanitized provider error.';
  @override
  String get disabled => 'Disabled';
  @override
  String get active => 'Active';
  @override
  String get inactive => 'Inactive';
  @override
  String get critical => 'Critical';
  @override
  String get unavailable => 'Unavailable';
  @override
  String get baseUrl => 'Base URL';
  @override
  String get lowercaseSlugHint => 'Use lowercase letters, digits, and underscores only';
  @override
  String providerReachable(int count) => 'Provider is reachable ($count models visible).';
  @override
  String modelDiscoveryCompleted(int discovered, int added) => 'Model discovery completed: $discovered found, $added added.';
  @override
  String get noContentSources => 'No content sources are configured.';
  @override
  String get approvedSourcesAppearHere => 'RAD official sources and approved authoritative sources appear here.';
  @override
  String get noResearchJobs => 'No research jobs yet.';
  @override
  String get operationsHealth => 'Operations / Health';
  @override
  String get noOperationalComponents => 'No operational components are registered.';
  @override
  String get componentInventoryUnavailable => 'Component inventory is unavailable.';
  @override
  String get auditSecurity => 'Audit / Security';
  @override
  String get noAuditEvents => 'No audit events are visible.';
  @override
  String get auditRestricted => 'Audit history is restricted to Super Admin.';
  @override
  String get categoryUpdate => 'Update';
  @override
  String get categoryGuide => 'Guide';
  @override
  String get categoryDeadline => 'Deadline';
  @override
  String get categoryEvent => 'Event';
  @override
  String get categoryAnnouncement => 'Announcement';
  @override
  String get sourceAddress => 'Source address';
  @override
  String get sourceSavedDisabled => 'Source saved. Enable it after checking its attribution and scope.';
  @override
  String get sourceDuplicate => 'This source address is already registered.';
  @override
  String get sourceSaveFailed => 'Could not save the source. Check the address and your Admin access, then try again.';
  @override
  String get sourceEnable => 'Enable source';
  @override
  String get sourceDisable => 'Disable source';
  @override
  String get researchSourcesTitle => 'Research sources';
  @override
  String get researchRunning => 'Research is running. Job results appear below.';
  @override
  String get researchRunFailed => 'Research did not finish. Review source and job errors below before retrying.';
  @override
  String get openReviewQueue => 'Open human review';
  @override
  String get brandIntroTitle => 'Your next step, with RAD';
  @override
  String get brandIntroBody => 'Explore visa pathways, organize your documents, and follow your case in one place.';
  @override
  String get exploreVisa => 'Explore visa pathways';
  @override
  String get reviewQueueEmpty => 'No findings or drafts await review.';
  @override
  String get sourceStateUnknown => 'Not run yet';
  @override
  String get sourceLastSuccess => 'Last successful fetch';
  @override
  String get sourceHttpRejected => 'Use a public HTTPS address. HTTP sources cannot be fetched securely.';
  @override
  String get providerSavedDiscoveryFailed => 'Provider saved. Model discovery failed; use Discover Models to retry.';
  @override
  String get aiCredentialRejected => 'The AI service needs an Admin to update or revalidate its provider credential.';
  @override
  String get aiNoEligibleModel => 'No eligible AI model is available. Please try later or contact RAD support.';
  @override
  String get aiRateLimited => 'The AI service is busy. Please try again shortly.';
  @override
  String get aiRequestFailed => 'Your AI request could not be completed. Please try again.';
  @override
  String get aiResponseNotSaved => 'This response could not be saved. It may not appear after reloading.';
  @override
  String get addSource => 'Add source';
  @override
  String get requiredField => 'This field is required';
  @override
  String get invalidUrl => 'Enter a valid public HTTPS address';
  @override
  String get titleLabel => 'Title';
  @override
  String get sourceType => 'Source type';
  @override
  String get researchPipelineSummary => 'Research pipeline';
  @override
  String findingsCount(int count) => '$count findings awaiting review';
  @override
  String draftsInReview(int count) => '$count drafts in review';
  @override
  String get feedPublishedOnly => 'Feed shows published items only';
  @override
  String get lastResearchRun => 'Last run';
  @override
  String get researchNeverAutoPublishes => 'Research and AI never publish to Feed automatically. An Admin must review and publish explicitly.';
  @override
  String get researchQueued => 'Research run queued';
  @override
  String get reviewQueueTitle => 'Human review queue';
  @override
  String get reviewDraftTitle => 'Draft review';
  @override
  String get reviewFindingTitle => 'Finding review';
  @override
  String get reject => 'Reject';
  @override
  String get keepPending => 'Keep pending';
  @override
  String get approve => 'Approve';
  @override
  String get publishExplicit => 'Publish';
  @override
  String get publishRequiresHuman => 'Publish requires explicit human approval.';
  @override
  String get findingPublishNote => 'Findings do not auto-publish.';
  @override
  String get editTitle => 'Edit title';
  @override
  String get editBody => 'Edit body';
  @override
  String get category => 'Category';
  @override
  String get applicationSteps => 'Application steps';
  @override
  String get structuredSourceNote => 'Structured source note';
  @override
  String get publishedStatus => 'Published';
  @override
  String get draftStatusLabel => 'Draft';
  @override
  String get reviewStatusLabel => 'In review';
  @override
  String get scopeUser => 'User';
  @override
  String get scopeBoth => 'User and Admin';
  @override
  String get healthOffline => 'Offline';
  @override
  String get healthHealthy => 'Healthy';
  @override
  String get healthDegraded => 'Degraded';
  @override
  String get healthUnknown => 'Not checked';
  @override
  String get modelSaveFailed => 'Could not save model settings. Your changes are retained; try again.';
  @override
  String get sourceQueryRejected => 'Use a public HTTPS page without a query string. Query-based source addresses are not supported yet.';
}
