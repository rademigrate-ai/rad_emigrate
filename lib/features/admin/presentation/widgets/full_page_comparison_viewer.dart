import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../domain/entities/admin_cms_entities.dart';
import 'source_provenance_badge.dart';

/// Presentation mode for the full-page comparison.
enum FullPageComparisonViewMode {
  /// Full-page proposed-content reading view with inline accessible highlights.
  inlineReading,

  /// Side-by-side or tabbed before-and-after comparison.
  splitComparison,
}

/// Action callback when an individual section change is accepted, rejected, or edited.
typedef SectionActionCallback = void Function(String sectionId, String action);

/// Action callback when an individual section text is manually edited in-place.
typedef SectionEditCallback = void Function(String sectionId, String newText);

/// A comprehensive full-page comparison viewer that renders the entire
/// Visa content page in context, displaying unchanged sections alongside
/// precisely highlighted added, removed, and modified passages with source provenance.
class FullPageComparisonViewer extends StatefulWidget {
  final String articleTitle;
  final String? countryFlag;
  final String? countryName;
  final String? category;
  final int baseRevision;
  final int proposedRevision;
  final DateTime? lastVerifiedAt;
  final bool hasConflicts;
  final List<ArticleSectionInput> baseSections;
  final List<SectionChange> changes;
  final List<EvidenceRef> evidence;
  final String? reviewerNotes;
  final Map<String, String>
  sectionReviewDecisions; // sectionId -> 'accepted' | 'rejected'
  final Map<String, String> sectionEdits;
  final SectionActionCallback? onSectionAction;
  final SectionEditCallback? onSectionEdit;
  final bool isPersian;

  const FullPageComparisonViewer({
    super.key,
    required this.articleTitle,
    this.countryFlag,
    this.countryName,
    this.category,
    required this.baseRevision,
    required this.proposedRevision,
    this.lastVerifiedAt,
    this.hasConflicts = false,
    required this.baseSections,
    required this.changes,
    required this.evidence,
    this.reviewerNotes,
    this.sectionReviewDecisions = const {},
    this.sectionEdits = const {},
    this.onSectionAction,
    this.onSectionEdit,
    this.isPersian = true,
  });

  @override
  State<FullPageComparisonViewer> createState() =>
      _FullPageComparisonViewerState();
}

class _FullPageComparisonViewerState extends State<FullPageComparisonViewer> {
  FullPageComparisonViewMode _viewMode =
      FullPageComparisonViewMode.inlineReading;
  String _sectionFilter = 'all'; // 'all', 'changed', 'unchanged'
  int _splitActiveTab = 1; // 0: baseline, 1: proposed (for narrow screens)
  final Set<String> _editingSectionIds = {};
  final Map<String, TextEditingController> _editControllers = {};

  @override
  void dispose() {
    for (final c in _editControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getEditController(
    String sectionId,
    String initialText,
  ) {
    return _editControllers.putIfAbsent(
      sectionId,
      () => TextEditingController(text: initialText),
    );
  }

  ArticleSectionInput? _reviewedReplacement(SectionChange change) {
    final original = change.replacement;
    final edit = widget.sectionEdits[change.sectionId];
    if (edit == null ||
        original == null ||
        original.blocks.length != 1 ||
        original.blocks.first.type != 'paragraph') {
      return original;
    }
    final json = original.toJson();
    final blocks = (json['blocks'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    blocks.first['text'] = edit;
    return ArticleSectionInput.fromJson({...json, 'blocks': blocks});
  }

  // Map changes by sectionId for quick lookup
  Map<String, SectionChange> get _changesBySectionId {
    final map = <String, SectionChange>{};
    for (final c in widget.changes) {
      map[c.sectionId] = c;
    }
    return map;
  }

  // Map evidence by sectionId or claimId
  Map<String, List<EvidenceRef>> get _evidenceBySectionId {
    final map = <String, List<EvidenceRef>>{};
    for (final ev in widget.evidence) {
      if (ev.sectionId != null) {
        map.putIfAbsent(ev.sectionId!, () => []).add(ev);
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final changesMap = _changesBySectionId;

    // Collect all unified sections in order
    final unifiedSections = <_UnifiedSection>[];

    // Track added sectionIds that are not in base
    final seenSectionIds = <String>{};

    for (final baseSec in widget.baseSections) {
      seenSectionIds.add(baseSec.id);
      final change = changesMap[baseSec.id];
      if (change == null) {
        unifiedSections.add(
          _UnifiedSection(
            id: baseSec.id,
            heading: baseSec.heading,
            anchor: baseSec.anchor,
            status: _SectionDiffStatus.unchanged,
            baseContent: baseSec,
            proposedContent: baseSec,
            change: null,
          ),
        );
      } else if (change.operation == 'remove') {
        unifiedSections.add(
          _UnifiedSection(
            id: baseSec.id,
            heading: baseSec.heading,
            anchor: baseSec.anchor,
            status: _SectionDiffStatus.removed,
            baseContent: baseSec,
            proposedContent: null,
            change: change,
          ),
        );
      } else {
        // replace / modify
        unifiedSections.add(
          _UnifiedSection(
            id: baseSec.id,
            heading: change.replacement?.heading ?? baseSec.heading,
            anchor: change.replacement?.anchor ?? baseSec.anchor,
            status: _SectionDiffStatus.modified,
            baseContent: baseSec,
            proposedContent: _reviewedReplacement(change) ?? baseSec,
            change: change,
          ),
        );
      }
    }

    // Add newly added sections from changes that were not in base
    for (final change in widget.changes) {
      if (change.operation == 'add' &&
          !seenSectionIds.contains(change.sectionId)) {
        unifiedSections.add(
          _UnifiedSection(
            id: change.sectionId,
            heading: change.replacement?.heading ?? 'بخش جدید',
            anchor: change.replacement?.anchor ?? 'new-section',
            status: _SectionDiffStatus.added,
            baseContent: null,
            proposedContent: _reviewedReplacement(change),
            change: change,
          ),
        );
      }
    }

    // Apply section filter
    final filteredSections = unifiedSections.where((s) {
      if (_sectionFilter == 'changed') {
        return s.status != _SectionDiffStatus.unchanged;
      }
      if (_sectionFilter == 'unchanged') {
        return s.status == _SectionDiffStatus.unchanged;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Header Toolbar
        _buildHeaderToolbar(unifiedSections),

        // 2. Unresolved Conflict Warning Banner (if any)
        if (widget.hasConflicts) _buildConflictWarningBanner(),

        const SizedBox(height: 12),

        // 3. View Switcher & Filters
        _buildViewSwitcherAndFilters(unifiedSections),

        const SizedBox(height: 16),

        // 4. Main Body: Inline Reading or Split Comparison
        if (_viewMode == FullPageComparisonViewMode.inlineReading)
          _buildInlineReadingView(filteredSections)
        else
          _buildSplitComparisonView(filteredSections),
      ],
    );
  }

  Widget _buildHeaderToolbar(List<_UnifiedSection> allSections) {
    final changedCount = allSections
        .where((s) => s.status != _SectionDiffStatus.unchanged)
        .length;
    final isFa = widget.isPersian;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.countryFlag != null) ...[
                Text(widget.countryFlag!, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.articleTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (widget.countryName != null)
                          Text(
                            widget.countryName!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (widget.category != null) ...[
                          const Text(
                            '•',
                            style: TextStyle(color: AppColors.border),
                          ),
                          Text(
                            widget.category!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const Text(
                          '•',
                          style: TextStyle(color: AppColors.border),
                        ),
                        Text(
                          isFa
                              ? 'نسخه مبنا: v${widget.baseRevision} ← پیش‌نویس پیشنهادی: v${widget.proposedRevision}'
                              : 'Base: v${widget.baseRevision} → Proposed: v${widget.proposedRevision}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: changedCount > 0
                      ? AppColors.primaryRed.withValues(alpha: 0.08)
                      : AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: changedCount > 0
                        ? AppColors.primaryRed.withValues(alpha: 0.3)
                        : AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isFa
                      ? '$changedCount تغییر محتوایی'
                      : '$changedCount Content Changes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: changedCount > 0
                        ? AppColors.primaryRed
                        : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          if (widget.lastVerifiedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              isFa
                  ? 'آخرین تطبیق رسمی: ${widget.lastVerifiedAt!.toLocal().toString().split('.').first}'
                  : 'Last verified: ${widget.lastVerifiedAt!.toLocal().toString().split('.').first}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConflictWarningBanner() {
    final isFa = widget.isPersian;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isFa
                  ? 'هشدار مغایرت: میان منابع رسمی استناد تناقض اطلاعاتی مشاهده شده است. بازبینی دقیق انسانی پیش از تأیید الزامی است.'
                  : 'Conflict Warning: Divergent evidence detected across sources. Careful human verification required.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewSwitcherAndFilters(List<_UnifiedSection> allSections) {
    final isFa = widget.isPersian;
    final changedCount = allSections
        .where((s) => s.status != _SectionDiffStatus.unchanged)
        .length;
    final unchangedCount = allSections.length - changedCount;

    return Column(
      children: [
        // View Mode Switcher
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<FullPageComparisonViewMode>(
            segments: [
              ButtonSegment(
                value: FullPageComparisonViewMode.inlineReading,
                icon: const Icon(Icons.menu_book_outlined, size: 16),
                label: Text(
                  isFa ? 'نمای خوانش تمام‌صفحه' : 'Full Page Reading',
                ),
              ),
              ButtonSegment(
                value: FullPageComparisonViewMode.splitComparison,
                icon: const Icon(Icons.compare_arrows_outlined, size: 16),
                label: Text(isFa ? 'مقایسه قبل و بعد' : 'Before / After'),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) setState(() => _viewMode = set.first);
            },
          ),
        ),
        const SizedBox(width: 12),

        // Section Filter Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(
              label: Text(
                isFa
                    ? 'همه (${allSections.length})'
                    : 'All (${allSections.length})',
              ),
              selected: _sectionFilter == 'all',
              onSelected: (_) => setState(() => _sectionFilter = 'all'),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: Text(
                isFa ? 'تغییرات ($changedCount)' : 'Changed ($changedCount)',
              ),
              selected: _sectionFilter == 'changed',
              onSelected: (_) => setState(() => _sectionFilter = 'changed'),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: Text(
                isFa
                    ? 'بدون تغییر ($unchangedCount)'
                    : 'Unchanged ($unchangedCount)',
              ),
              selected: _sectionFilter == 'unchanged',
              onSelected: (_) => setState(() => _sectionFilter = 'unchanged'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInlineReadingView(List<_UnifiedSection> sections) {
    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            widget.isPersian
                ? 'بخشی با فیلتر انتخابی یافت نشد.'
                : 'No sections match the current filter.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sections.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildSectionInlineCard(sections[index]);
      },
    );
  }

  Widget _buildSectionInlineCard(_UnifiedSection sec) {
    final isFa = widget.isPersian;
    final isEditing = _editingSectionIds.contains(sec.id);
    final decision = widget.sectionReviewDecisions[sec.id];

    Color cardBorder;
    Color headerBg;
    Widget statusBadge;

    switch (sec.status) {
      case _SectionDiffStatus.unchanged:
        cardBorder = AppColors.border;
        headerBg = AppColors.surfaceMuted;
        statusBadge = _buildStatusPill(
          icon: Icons.check_circle_outline,
          label: isFa ? '[بدون تغییر]' : '[Unchanged]',
          color: AppColors.teal,
        );
        break;
      case _SectionDiffStatus.added:
        cardBorder = AppColors.success.withValues(alpha: 0.4);
        headerBg = AppColors.success.withValues(alpha: 0.08);
        statusBadge = _buildStatusPill(
          icon: Icons.add_circle_outline,
          label: isFa ? '[+] بخش جدید افزوده شده' : '[+] Added Section',
          color: AppColors.success,
        );
        break;
      case _SectionDiffStatus.removed:
        cardBorder = AppColors.error.withValues(alpha: 0.4);
        headerBg = AppColors.error.withValues(alpha: 0.08);
        statusBadge = _buildStatusPill(
          icon: Icons.remove_circle_outline,
          label: isFa ? '[-] بخش حذف شده' : '[-] Removed Section',
          color: AppColors.error,
        );
        break;
      case _SectionDiffStatus.modified:
        cardBorder = AppColors.primaryRed.withValues(alpha: 0.4);
        headerBg = AppColors.primaryRed.withValues(alpha: 0.08);
        statusBadge = _buildStatusPill(
          icon: Icons.change_circle_outlined,
          label: isFa ? '[~] بخش اصلاح شده' : '[~] Modified Section',
          color: AppColors.primaryRed,
        );
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: cardBorder,
          width: sec.status == _SectionDiffStatus.unchanged ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.md - 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sec.heading,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                statusBadge,
                if (decision != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: decision == 'accepted'
                          ? AppColors.success
                          : AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      decision == 'accepted'
                          ? (isFa ? 'تأیید شده' : 'Accepted')
                          : (isFa ? 'رد شده' : 'Rejected'),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Section Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sec.status == _SectionDiffStatus.unchanged) ...[
                  // Unchanged reading content
                  _renderBlocks(sec.baseContent?.blocks ?? []),
                ] else if (sec.status == _SectionDiffStatus.added) ...[
                  // Added section: full proposed blocks
                  _renderBlocks(sec.proposedContent?.blocks ?? []),
                  const SizedBox(height: 12),
                  _buildSourceAttributionBox(sec.id),
                ] else if (sec.status == _SectionDiffStatus.removed) ...[
                  // Removed section: strikethrough original content
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFa
                              ? 'حذف پیشنهادی محتوای مبنا:'
                              : 'Proposed removal of baseline content:',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _renderBlocks(
                          sec.baseContent?.blocks ?? [],
                          strikethrough: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSourceAttributionBox(sec.id),
                ] else if (sec.status == _SectionDiffStatus.modified) ...[
                  // Modified section: Show both Original and Proposed with text difference
                  if (!isEditing) ...[
                    // Before Box (Original approved)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.history,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isFa ? 'متن نسخه مبنا:' : 'Baseline Content:',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _renderBlocks(sec.baseContent?.blocks ?? []),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Proposed Updated Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(
                          color: AppColors.teal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 14,
                                color: AppColors.teal,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isFa
                                      ? 'متن پیشنهادی؛ وضعیت اعتبار در منابع مشخص است:'
                                      : 'Proposed content (check source verification):',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.teal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _renderBlocks(sec.proposedContent?.blocks ?? []),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Inline Editor Box
                    Text(
                      isFa
                          ? 'ویرایش دستی متن پیشنهادی:'
                          : 'Manual Edit of Proposed Text:',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _getEditController(
                        sec.id,
                        sec.proposedContent?.blocks
                                .map((b) => b.text)
                                .join('\n\n') ??
                            '',
                      ),
                      maxLines: 6,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'متن نهایی بند را وارد کنید...',
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  _buildSourceAttributionBox(sec.id),
                ],

                // Granular Action Buttons (for changed sections)
                if (sec.status != _SectionDiffStatus.unchanged) ...[
                  const Divider(height: 24),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (isEditing) ...[
                        TextButton(
                          onPressed: () {
                            setState(() => _editingSectionIds.remove(sec.id));
                          },
                          child: Text(isFa ? 'انصراف' : 'Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final text = _getEditController(sec.id, '').text;
                            widget.onSectionEdit?.call(sec.id, text);
                            setState(() => _editingSectionIds.remove(sec.id));
                          },
                          child: Text(isFa ? 'ثبت ویرایش' : 'Save Text'),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.error),
                            foregroundColor: AppColors.error,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              widget.onSectionAction?.call(sec.id, 'reject'),
                          icon: const Icon(Icons.close, size: 14),
                          label: Text(isFa ? 'رد این بند' : 'Reject Change'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.navy),
                            foregroundColor: AppColors.navy,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed:
                              sec.proposedContent?.blocks.length == 1 &&
                                  sec.proposedContent?.blocks.first.type ==
                                      'paragraph'
                              ? () => setState(
                                  () => _editingSectionIds.add(sec.id),
                                )
                              : null,
                          icon: const Icon(Icons.edit, size: 14),
                          label: Text(isFa ? 'ویرایش متن' : 'Edit Text'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              widget.onSectionAction?.call(sec.id, 'accept'),
                          icon: const Icon(Icons.check, size: 14),
                          label: Text(isFa ? 'تأیید این بند' : 'Accept Change'),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitComparisonView(List<_UnifiedSection> sections) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          // Desktop: True Side-by-Side Split View
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Pane: Baseline (Approved)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSplitPaneHeader(
                      title: widget.isPersian
                          ? 'نسخه فعلی (مبنا v${widget.baseRevision})'
                          : 'Baseline (v${widget.baseRevision})',
                      color: AppColors.navy,
                      icon: Icons.history,
                    ),
                    const SizedBox(height: 12),
                    ...sections.map(
                      (s) => _buildSplitSectionCard(s, isProposed: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right Pane: Proposed Updated
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSplitPaneHeader(
                      title: widget.isPersian
                          ? 'نسخه پیشنهادی جدید (v${widget.proposedRevision})'
                          : 'Proposed Updates (v${widget.proposedRevision})',
                      color: AppColors.teal,
                      icon: Icons.auto_awesome,
                    ),
                    const SizedBox(height: 12),
                    ...sections.map(
                      (s) => _buildSplitSectionCard(s, isProposed: true),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          // Mobile / Tablet: Tabbed Split View
          final isFa = widget.isPersian;
          return Column(
            children: [
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      isFa
                          ? 'نسخه مبنا v${widget.baseRevision}'
                          : 'Baseline v${widget.baseRevision}',
                    ),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text(
                      isFa
                          ? 'پیشنهادی v${widget.proposedRevision}'
                          : 'Proposed v${widget.proposedRevision}',
                    ),
                  ),
                ],
                selected: {_splitActiveTab},
                onSelectionChanged: (set) {
                  if (set.isNotEmpty) {
                    setState(() => _splitActiveTab = set.first);
                  }
                },
              ),
              const SizedBox(height: 12),
              ...sections.map(
                (s) =>
                    _buildSplitSectionCard(s, isProposed: _splitActiveTab == 1),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSplitPaneHeader({
    required String title,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitSectionCard(
    _UnifiedSection sec, {
    required bool isProposed,
  }) {
    final content = isProposed ? sec.proposedContent : sec.baseContent;
    final isFa = widget.isPersian;

    if (content == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: Center(
          child: Text(
            isProposed
                ? (isFa
                      ? 'این بخش طبق پیشنهاد حذف می‌شود.'
                      : 'Section removed in proposed update.')
                : (isFa
                      ? 'بخش جدید (در نسخه مبنا وجود ندارد).'
                      : 'New section (absent in baseline).'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    Color border;
    if (sec.status == _SectionDiffStatus.unchanged) {
      border = AppColors.border;
    } else if (isProposed) {
      border = sec.status == _SectionDiffStatus.added
          ? AppColors.success
          : AppColors.teal;
    } else {
      border = sec.status == _SectionDiffStatus.removed
          ? AppColors.error
          : AppColors.primaryRed;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: border.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.md - 1),
              ),
            ),
            child: Text(
              content.heading,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _renderBlocks(content.blocks),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceAttributionBox(String sectionId) {
    final evList = _evidenceBySectionId[sectionId] ?? widget.evidence;
    if (evList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final evidence in evList) _buildEvidence(evidence)],
    );
  }

  Widget _buildEvidence(EvidenceRef ev) {
    final uri = Uri.tryParse(ev.url);
    final safe =
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    final isFa = widget.isPersian;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.policy_outlined,
                size: 14,
                color: AppColors.teal,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${isFa ? 'شواهد پیشنهادی' : 'Proposed Evidence'}: ${ev.publisher}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal,
                  ),
                ),
              ),
              SourceProvenanceBadge(
                trustLevel: ev.verificationState == FactualStatus.conflicting
                    ? SourceTrustLevel.conflicting
                    : ev.verificationState == FactualStatus.verified &&
                          ev.authorityId != null &&
                          ev.verifiedAt != null &&
                          ev.freshUntil != null &&
                          ev.freshUntil!.isAfter(DateTime.now())
                    ? SourceTrustLevel.officiallyVerified
                    : SourceTrustLevel.fromString(ev.sourceClass),
                isPersian: isFa,
                fontSize: 10,
              ),
            ],
          ),
          if (ev.url.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: safe
                  ? () => launchUrl(uri, mode: LaunchMode.externalApplication)
                  : null,
              child: Text(
                ev.url,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.primaryRed,
                  decoration: TextDecoration.underline,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (ev.excerpt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: const Border(
                  right: BorderSide(color: AppColors.teal, width: 3),
                ),
              ),
              child: Text(
                '«${ev.excerpt}»',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _renderBlocks(
    List<ContentBlock> blocks, {
    bool strikethrough = false,
  }) {
    if (blocks.isEmpty) {
      return Text(
        widget.isPersian ? 'فاقد محتوای متنی.' : 'No text content.',
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((b) {
        final textStyle = TextStyle(
          fontSize: 13,
          height: 1.5,
          color: strikethrough
              ? AppColors.textSecondary
              : AppColors.textPrimary,
          decoration: strikethrough ? TextDecoration.lineThrough : null,
        );

        if (b.type == 'bullet_list' || b.type == 'numbered_list') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: b.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: textStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Expanded(child: Text(item, style: textStyle)),
                  ],
                ),
              );
            }).toList(),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(b.text, style: textStyle),
        );
      }).toList(),
    );
  }

  Widget _buildStatusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

enum _SectionDiffStatus { unchanged, added, removed, modified }

class _UnifiedSection {
  final String id;
  final String heading;
  final String anchor;
  final _SectionDiffStatus status;
  final ArticleSectionInput? baseContent;
  final ArticleSectionInput? proposedContent;
  final SectionChange? change;

  const _UnifiedSection({
    required this.id,
    required this.heading,
    required this.anchor,
    required this.status,
    required this.baseContent,
    required this.proposedContent,
    required this.change,
  });
}
