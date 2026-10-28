import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../domain/entities/admin_research_models.dart';
import 'source_provenance_badge.dart';

/// Screen 2 — Official Sources & Authorities Management View.
class SourceManagementView extends StatefulWidget {
  final List<ManagedResearchSource> sources;
  final ValueChanged<String>? onToggleSource;
  final void Function(String id, MonitoringInterval interval)? onUpdateInterval;
  final Future<void> Function(String id)? onRefreshSource;
  final VoidCallback? onAddNewSource;

  const SourceManagementView({
    super.key,
    required this.sources,
    this.onToggleSource,
    this.onUpdateInterval,
    this.onRefreshSource,
    this.onAddNewSource,
  });

  @override
  State<SourceManagementView> createState() => _SourceManagementViewState();
}

class _SourceManagementViewState extends State<SourceManagementView> {
  String _countryFilter = 'all';
  String _typeFilter = 'all';
  String _searchQuery = '';
  final Set<String> _refreshingSourceIds = {};

  Future<void> _handleRefresh(String id) async {
    if (_refreshingSourceIds.contains(id)) return;
    setState(() => _refreshingSourceIds.add(id));
    try {
      if (widget.onRefreshSource != null) {
        await widget.onRefreshSource!(id);
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'بررسی مجدد منبع با موفقیت انجام شد و وضعیت اتصال به‌روزرسانی گردید.',
            ),
            backgroundColor: AppColors.teal,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingSourceIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter sources
    final filtered = widget.sources.where((s) {
      if (_countryFilter != 'all' &&
          s.countryCode.toUpperCase() != _countryFilter.toUpperCase()) {
        return false;
      }
      if (_typeFilter != 'all') {
        if (_typeFilter == 'official' &&
            s.verificationTier != SourceVerificationTier.officialAuthority)
          return false;
        if (_typeFilter == 'university' &&
            s.verificationTier != SourceVerificationTier.accreditedUniversity)
          return false;
        if (_typeFilter == 'employer' &&
            s.verificationTier !=
                SourceVerificationTier.employerDefinedUnverified)
          return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            s.name.toLowerCase().contains(q) ||
            s.baseUrl.toLowerCase().contains(q) ||
            s.topic.toLowerCase().contains(q) ||
            (s.universityName?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        // 1. Filter & Search Controls Bar
        _buildFilterBar(),

        const Divider(height: 1),

        // 2. Sources List or Empty State
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return _buildSourceCard(filtered[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'جستجوی نام سازمان، پورتال دانشگاه یا دامنه...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onPressed: widget.onAddNewSource,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('افزودن منبع'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Country Filter Chips
                const Text(
                  'کشور: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('همه'),
                      selected: _countryFilter == 'all',
                      onSelected: (_) => setState(() => _countryFilter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('🇨🇦 کانادا'),
                      selected: _countryFilter == 'CA',
                      onSelected: (_) => setState(() => _countryFilter = 'CA'),
                    ),
                    ChoiceChip(
                      label: const Text('🇩🇪 آلمان'),
                      selected: _countryFilter == 'DE',
                      onSelected: (_) => setState(() => _countryFilter = 'DE'),
                    ),
                    ChoiceChip(
                      label: const Text('🇦🇺 استرالیا'),
                      selected: _countryFilter == 'AU',
                      onSelected: (_) => setState(() => _countryFilter = 'AU'),
                    ),
                    ChoiceChip(
                      label: const Text('🇬🇧 انگلستان'),
                      selected: _countryFilter == 'UK',
                      onSelected: (_) => setState(() => _countryFilter = 'UK'),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Type Filter Chips
                const Text(
                  'نوع: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('همه انواع'),
                      selected: _typeFilter == 'all',
                      onSelected: (_) => setState(() => _typeFilter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('مراجع دولتی'),
                      selected: _typeFilter == 'official',
                      onSelected: (_) =>
                          setState(() => _typeFilter = 'official'),
                    ),
                    ChoiceChip(
                      label: const Text('دانشگاه‌ها'),
                      selected: _typeFilter == 'university',
                      onSelected: (_) =>
                          setState(() => _typeFilter = 'university'),
                    ),
                    ChoiceChip(
                      label: const Text('افزوده‌شده کارفرما'),
                      selected: _typeFilter == 'employer',
                      onSelected: (_) =>
                          setState(() => _typeFilter = 'employer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(ManagedResearchSource source) {
    final isRefreshing = _refreshingSourceIds.contains(source.id);

    Color tierColor;
    switch (source.verificationTier) {
      case SourceVerificationTier.officialAuthority:
        tierColor = AppColors.teal;
        break;
      case SourceVerificationTier.accreditedUniversity:
        tierColor = AppColors.navy;
        break;
      case SourceVerificationTier.employerDefinedUnverified:
        tierColor = AppColors.warning;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: source.hasFailure
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
          width: source.hasFailure ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Name, Verification Badge & Active Switch
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _flagForCountry(source.countryCode),
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              source.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch.adaptive(
                            value: source.isEnabled,
                            activeTrackColor: AppColors.teal,
                            onChanged: (val) =>
                                widget.onToggleSource?.call(source.id),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        source.baseUrl,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          SourceProvenanceBadge(
                            trustLevel:
                                source.verificationTier ==
                                        SourceVerificationTier
                                            .officialAuthority ||
                                    source.verificationTier ==
                                        SourceVerificationTier
                                            .accreditedUniversity
                                ? SourceTrustLevel.officiallyVerified
                                : SourceTrustLevel.adminDefined,
                            fontSize: 10,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                              border: Border.all(
                                color: tierColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              source.verificationTier.toPersian(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: tierColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Metadata Chips: University, Topic, Relevant Articles
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (source.universityName != null)
                  _buildTagChip(
                    icon: Icons.school,
                    label: source.universityName!,
                    color: AppColors.navy,
                  ),
                _buildTagChip(
                  icon: Icons.category,
                  label: 'موضوع: ${source.topic}',
                  color: AppColors.textSecondary,
                ),
                ...source.relevantArticles.map(
                  (art) => _buildTagChip(
                    icon: Icons.article_outlined,
                    label: art,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Monitoring Details & Timestamps Bar
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                // Monitoring Interval Selector
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'دوره پایش:',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    DropdownButton<MonitoringInterval>(
                      value: source.interval,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      items: MonitoringInterval.values.map((interval) {
                        return DropdownMenuItem(
                          value: interval,
                          child: Text(
                            interval.toPersian(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newInterval) {
                        if (newInterval != null) {
                          widget.onUpdateInterval?.call(source.id, newInterval);
                        }
                      },
                    ),
                  ],
                ),
                // Status and Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Connection Status Chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: source.hasFailure
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            source.hasFailure
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            size: 12,
                            color: source.hasFailure
                                ? AppColors.error
                                : AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            source.hasFailure
                                ? 'خطای اتصال (${source.connectionStatus})'
                                : 'اتصال معتبر (۲۰۰ OK)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: source.hasFailure
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Manual Refresh Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: isRefreshing
                          ? null
                          : () => _handleRefresh(source.id),
                      icon: isRefreshing
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 14),
                      label: Text(
                        isRefreshing ? 'در حال ارسال…' : 'واکشی تغییرات منبع',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Connection Error Detail (if any)
            if (source.lastErrorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'پیام خطا: ${source.lastErrorMessage!} (تعداد تلاش‌های مجدد: ${source.retryAttempts})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'هیچ مرجع یا منبعی با فیلترهای انتخابی یافت نشد.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _countryFilter = 'all';
                  _typeFilter = 'all';
                  _searchQuery = '';
                });
              },
              child: const Text('پاک کردن فیلترها'),
            ),
          ],
        ),
      ),
    );
  }

  String _flagForCountry(String code) {
    switch (code.toUpperCase()) {
      case 'CA':
        return '🇨🇦';
      case 'DE':
        return '🇩🇪';
      case 'AU':
        return '🇦🇺';
      case 'UK':
      case 'GB':
        return '🇬🇧';
      case 'US':
        return '🇺🇸';
      case 'IT':
        return '🇮🇹';
      default:
        return '🌍';
    }
  }
}
