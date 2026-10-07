import 'app_localizations.dart';

mixin AppLocalizationsEnB2 on AppLocalizations {
  @override
  String get providerSaved => 'Provider saved.';

  @override
  String get providerSaveFailed => 'Could not save provider.';

  @override
  String modelDiscoveryCompleted(int discovered, int added) =>
      'Discovered $discovered models, added $added.';

  @override
  String get modelDiscoveryFailed => 'Model discovery failed.';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get category => 'Category';

  @override
  String get categoryUpdate => 'Update';

  @override
  String get categoryDeadline => 'Deadline';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryGuide => 'Guide';

  @override
  String get categoryAnnouncement => 'Announcement';

  @override
  String get brandIntroTitle => 'Your next step, with RAD';

  @override
  String get brandIntroBody =>
      'Explore visa pathways, organize your documents, and follow your case in one place.';

  @override
  String get aiCredentialRejected =>
      'The AI service needs an Admin to update or revalidate its provider credential.';

  @override
  String get aiNoEligibleModel =>
      'No eligible AI model is available. Please try later or contact RAD support.';

  @override
  String get aiRateLimited =>
      'The AI service is busy. Please try again shortly.';

  @override
  String get aiRequestFailed =>
      'The AI request could not be completed. Please try again.';

  @override
  String get aiResponseNotSaved =>
      'The answer was generated but could not be saved to your session.';

  @override
  String get applicationSteps => 'Application steps';

  @override
  String get approve => 'Approve';

  @override
  String get approvedSourcesAppearHere =>
      'Approved sources appear here after editorial review.';

  @override
  String get auditRestricted => 'Audit access is restricted.';

  @override
  String get auditSecurity => 'Security audit';

  @override
  String get componentInventoryUnavailable =>
      'Component inventory is unavailable.';

  @override
  String get critical => 'Critical';

  @override
  String get draftStatusLabel => 'Draft';

  @override
  String draftsInReview(int count) => '$count drafts in review';

  @override
  String get editBody => 'Body';

  @override
  String get editTitle => 'Title';

  @override
  String findingsCount(int count) => '$count findings';

  @override
  String get adminResearchAssistant => 'Research assistant';

  @override
  String get adminResearchSubtitle =>
      'Review candidates and publish only approved content.';

  @override
  String get addSource => 'Add source';

  @override
  String get researchSource => 'Research source';

  @override
  String get researchSourcesTitle => 'Research sources';

  @override
  String get noResearchJobs => 'No research jobs yet.';

  @override
  String get noContentSources => 'No content sources configured.';

  @override
  String get noOperationalComponents => 'No operational components.';

  @override
  String get noAuditEvents => 'No audit events.';

  @override
  String get operationsHealth => 'Operations health';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get inactive => 'Inactive';

  @override
  String get providerReachable => 'Reachable';

  @override
  String get providerTestFailed => 'Provider test failed.';

  @override
  String get untrustedResearchDisclaimer =>
      'Research findings are untrusted until reviewed.';

  @override
  String get sourceAddress => 'Source address';

  @override
  String get sourceEnable => 'Enable';

  @override
  String get sourceDisable => 'Disable';

  @override
  String get sourceSaveFailed => 'Could not save source.';

  @override
  String get sourceSavedDisabled => 'Source saved as disabled.';

  @override
  String get sourceDuplicate => 'This source already exists.';

  @override
  String get lowercaseSlugHint => 'Use a lowercase slug.';

  @override
  String get queueResearchRun => 'Queue research run';

  @override
  String get researchRunning => 'Research is running.';

  @override
  String get researchRunFailed => 'Research run failed.';

  @override
  String get openReviewQueue => 'Open human review';

  @override
  String get exploreVisa => 'Explore visa pathways';

  @override
  String get reviewQueueEmpty => 'No findings or drafts await review.';

  @override
  String get sourceStateUnknown => 'Not run yet';

  @override
  String get sourceLastSuccess => 'Last successful fetch';

  @override
  String get sourceHttpRejected =>
      'Use a public HTTPS address. HTTP sources cannot be fetched securely.';

  @override
  String get providerSavedDiscoveryFailed =>
      'Provider saved. Model discovery failed; use Discover Models to retry.';

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
  String get feedPublishedOnly => 'Feed shows published items only';

  @override
  String get lastResearchRun => 'Last run';

  @override
  String get researchNeverAutoPublishes =>
      'Research and AI never publish to Feed automatically. An Admin must review and publish explicitly.';

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
  String get publishExplicit => 'Publish';

  @override
  String get publishRequiresHuman =>
      'Publish requires explicit human approval.';

  @override
  String get findingPublishNote => 'Findings do not auto-publish.';

  @override
  String get structuredSourceNote => 'Structured source note';

  @override
  String get publishedStatus => 'Published';

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
  String get modelSaveFailed =>
      'Could not save model settings. Your changes are retained; try again.';

  @override
  String get sourceQueryRejected =>
      'Use a public HTTPS address without a query string. Query-based source addresses are not supported yet.';
}
