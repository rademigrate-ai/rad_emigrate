import 'package:flutter/foundation.dart';

/// Monitoring interval frequencies for official sources.
enum MonitoringInterval {
  every6Hours,
  every12Hours,
  daily,
  weekly;

  String toPersian() {
    switch (this) {
      case MonitoringInterval.every6Hours:
        return 'هر ۶ ساعت';
      case MonitoringInterval.every12Hours:
        return 'هر ۱۲ ساعت';
      case MonitoringInterval.daily:
        return 'روزانه (۲۴ ساعت)';
      case MonitoringInterval.weekly:
        return 'هفتگی';
    }
  }

  String toEnglish() {
    switch (this) {
      case MonitoringInterval.every6Hours:
        return 'Every 6 Hours';
      case MonitoringInterval.every12Hours:
        return 'Every 12 Hours';
      case MonitoringInterval.daily:
        return 'Daily (24h)';
      case MonitoringInterval.weekly:
        return 'Weekly';
    }
  }
}

/// Verification tier and authority class for monitored sources.
enum SourceVerificationTier {
  officialAuthority,
  accreditedUniversity,
  employerDefinedUnverified;

  String toPersian() {
    switch (this) {
      case SourceVerificationTier.officialAuthority:
        return 'مرجع دولتی رسمی';
      case SourceVerificationTier.accreditedUniversity:
        return 'دانشگاه معتبر بین‌المللی';
      case SourceVerificationTier.employerDefinedUnverified:
        return 'منبع افزوده‌شده کارفرما (تأییدنشده)';
    }
  }

  String toEnglish() {
    switch (this) {
      case SourceVerificationTier.officialAuthority:
        return 'Official Government Authority';
      case SourceVerificationTier.accreditedUniversity:
        return 'Accredited University Portal';
      case SourceVerificationTier.employerDefinedUnverified:
        return 'Employer-Added (Unverified)';
    }
  }
}

/// Comprehensive metrics for the Research Assistant Dashboard (Screen 1).
@immutable
class ResearchDashboardMetrics {
  final int monitoredCountriesCount;
  final int activeOfficialSourcesCount;
  final int employerAddedSourcesCount;
  final int monitoredUniversitiesCount;
  final int detectedChangesCount;
  final int pendingAdminReviewsCount;
  final int monitoringFailuresCount;
  final int overdueSourceChecksCount;
  final DateTime lastCrawlCompletedAt;

  const ResearchDashboardMetrics({
    required this.monitoredCountriesCount,
    required this.activeOfficialSourcesCount,
    required this.employerAddedSourcesCount,
    required this.monitoredUniversitiesCount,
    required this.detectedChangesCount,
    required this.pendingAdminReviewsCount,
    required this.monitoringFailuresCount,
    required this.overdueSourceChecksCount,
    required this.lastCrawlCompletedAt,
  });
}

/// Detailed managed source model (Screen 2).
@immutable
class ManagedResearchSource {
  final String id;
  final String name;
  final String baseUrl;
  final String countryCode;
  final String? universityName;
  final String topic;
  final List<String> relevantArticles;
  final SourceVerificationTier verificationTier;
  final bool isEnabled;
  final MonitoringInterval interval;
  final DateTime lastCheckedAt;
  final DateTime nextScheduledCheckAt;
  final String connectionStatus; // 'ok_200', 'timeout', 'http_503', etc.
  final int retryAttempts;
  final String? lastErrorMessage;

  const ManagedResearchSource({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.countryCode,
    this.universityName,
    required this.topic,
    required this.relevantArticles,
    required this.verificationTier,
    required this.isEnabled,
    required this.interval,
    required this.lastCheckedAt,
    required this.nextScheduledCheckAt,
    required this.connectionStatus,
    this.retryAttempts = 0,
    this.lastErrorMessage,
  });

  bool get isOverdue => DateTime.now().isAfter(nextScheduledCheckAt);
  bool get hasFailure => connectionStatus != 'ok_200';
}

/// Individual crawl run record (Screen 5).
@immutable
class CrawlRunHistoryItem {
  final String runId;
  final DateTime startedAt;
  final Duration duration;
  final int sourcesScanned;
  final int changesFound;
  final int failuresCount;
  final String status; // 'completed', 'partial_failure', 'running'

  const CrawlRunHistoryItem({
    required this.runId,
    required this.startedAt,
    required this.duration,
    required this.sourcesScanned,
    required this.changesFound,
    required this.failuresCount,
    required this.status,
  });
}

/// Raw source snapshot record (Screen 5).
@immutable
class SourceSnapshotItem {
  final String snapshotId;
  final String authorityName;
  final String url;
  final DateTime fetchedAt;
  final String contentHash;
  final String excerpt;
  final int byteSize;
  final int httpStatusCode;

  const SourceSnapshotItem({
    required this.snapshotId,
    required this.authorityName,
    required this.url,
    required this.fetchedAt,
    required this.contentHash,
    required this.excerpt,
    required this.byteSize,
    required this.httpStatusCode,
  });
}

/// Recorded administrative review decision (Screen 5).
@immutable
class AdminDecisionHistoryItem {
  final String id;
  final String proposalId;
  final String articleTitle;
  final String decision; // 'approved', 'rejected', 'edited_and_approved'
  final String reviewerName;
  final DateTime reviewedAt;
  final String reviewerNotes;
  final String resultingRevisionHash;

  const AdminDecisionHistoryItem({
    required this.id,
    required this.proposalId,
    required this.articleTitle,
    required this.decision,
    required this.reviewerName,
    required this.reviewedAt,
    required this.reviewerNotes,
    required this.resultingRevisionHash,
  });
}

/// Related article impacted by a regulatory or policy change (Screen 4).
@immutable
class ArticleRelatedImpact {
  final String articleId;
  final String title;
  final String countryCode;
  final String category;
  final String impactReason;

  const ArticleRelatedImpact({
    required this.articleId,
    required this.title,
    required this.countryCode,
    required this.category,
    required this.impactReason,
  });
}
