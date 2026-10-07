import 'app_localizations.dart';

mixin AppLocalizationsEnB1 on AppLocalizations {
  @override
  String get adminRestricted =>
      'This route is restricted to verified RAD administrators.';

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
  String get serverEnforcedAccessBody =>
      'Case notes, tasks, status history, provider health, and role changes are protected by RLS and audit events.';

  @override
  String get visaPathways => 'Visa and migration pathways';

  @override
  String get loadingCatalogue => 'Loading verified catalogue…';

  @override
  String get catalogueUnavailable => 'Catalogue unavailable. Please try again.';

  @override
  String get findPathway => 'Find a relevant pathway';

  @override
  String get catalogueDisclaimer =>
      'Only published, sourced RAD content is shown. Always verify current rules with the official authority.';

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
  String get structuredDetailsPending =>
      'Structured details are awaiting review';

  @override
  String get structuredDetailsPendingBody =>
      'No verified requirements or application steps have been published for this programme yet. Use the cited source and confirm current rules with the official authority.';

  @override
  String get source => 'Source';

  @override
  String get visaDisclaimer =>
      'This information does not guarantee an outcome and does not replace current official rules or professional review.';

  @override
  String get feedTitle => 'RAD updates';

  @override
  String get loadingUpdates => 'Loading RAD updates…';

  @override
  String get updatesLoadFailed => 'Updates could not be loaded.';

  @override
  String get noReviewedUpdates =>
      'No reviewed updates have been published yet.';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String get backToApplications => 'Back to applications';

  @override
  String get couldNotCreateDraft =>
      'Could not create draft. Please try again.';

  @override
  String get couldNotUpdateStatus =>
      'Could not update status. Please try again.';

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
  String get accountAlreadyExists =>
      'An account already exists for this email. Sign in instead.';

  @override
  String get otpInvalidOrExpired =>
      'That verification code is invalid or has expired.';

  @override
  String get otpResent => 'A new verification code was sent.';

  @override
  String get more => 'More';

  @override
  String get sendMessage => 'Send message';

  @override
  String get suggestionStudyPermitDocuments =>
      'What documents are typically needed for a study permit?';

  @override
  String get suggestionVisaProcessingTime =>
      'How long can a visa process take?';

  @override
  String get suggestionGteStatement => 'What is a GTE statement?';

  @override
  String aiUnavailableResponse(String question) =>
      'The RAD Knowledge Base is not configured for this build.\n\nYour question: "$question"\n\nSourced answers will be available after the approved provider is configured. No immigration requirements are inferred here.';

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
  String get credentialsServerOnly =>
      'Credentials are server-side only and stored values are never returned to the browser.';

  @override
  String get configurationUnavailable => 'Configuration is unavailable.';

  @override
  String get noProviderConfigured =>
      'No provider is configured yet. Use the form below for initial setup.';

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
  String get keepCurrentCredential =>
      'Leave blank to keep the current credential.';

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
  String get active => 'Active';

  @override
  String get disabled => 'Disabled';
}
