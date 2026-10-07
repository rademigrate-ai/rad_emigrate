import '../../../l10n/app_localizations.dart';

String adminRuntimeScopeLabel(String scope, AppLocalizations l10n) =>
    switch (scope) {
      'user' => l10n.scopeUser,
      'admin' => l10n.admin,
      'both' => l10n.scopeBoth,
      _ => l10n.healthUnknown,
    };

String adminHealthLabel(String status, AppLocalizations l10n) =>
    switch (status) {
      'healthy' => l10n.healthHealthy,
      'degraded' => l10n.healthDegraded,
      'offline' => l10n.healthOffline,
      _ => l10n.healthUnknown,
    };

/// Display only known error categories, never arbitrary database/provider text.
String adminAiErrorLabel(String? code, AppLocalizations l10n) => switch (code) {
  'provider_unauthorized' || 'credential_rejected' => l10n.aiCredentialRejected,
  'no_eligible_model' => l10n.aiNoEligibleModel,
  'quota_exhausted' => l10n.aiQuotaExhausted,
  'rate_limited' || 'provider_rate_limited' => l10n.aiRateLimited,
  _ => l10n.aiRequestFailed,
};
