// Country and pathway comparison page.
//
// A responsive grid lays pathways side by side. RTL (FA) and LTR (EN) both
// flow naturally via Directionality. Missing or prose-only attributes render
// explicit indicators instead of fabricated values.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/constrained_content.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/inline_alert.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/motion_primitives.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/pathway_comparison.dart';
import '../comparison_labels.dart';
import '../providers/comparison_controller.dart';

/// Comparison entry page.
class ComparisonPage extends ConsumerWidget {
  const ComparisonPage({super.key});

  static const List<ComparisonField> _fields = [
    ComparisonField.country,
    ComparisonField.pathway,
    ComparisonField.category,
    ComparisonField.processingTime,
    ComparisonField.fees,
    ComparisonField.requirements,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode;
    final labels = ComparisonLabels(locale);
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final isAuthed = auth?.isAuthenticated ?? false;
    final entries = ref.watch(comparisonEntriesProvider(locale));
    final selectedIds = ref.watch(selectedComparisonIdsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/dashboard'),
        title: Text(labels.title),
      ),
      body: PremiumCanvas(
        accent: theme.colorScheme.secondary,
        child: ConstrainedContent(
          maxWidth: 1000,
          alignment: Alignment.topCenter,
          child: MotionReveal(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    labels.intro,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                entries.when(
                  loading: () => const LoadingState.section(),
                  error: (_, _) => isAuthed
                      ? ErrorState(
                          message: labels.genericError,
                          onRetry: () =>
                              ref.invalidate(comparisonEntriesProvider(locale)),
                        )
                      : AppCard(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.lock_outline),
                            title: Text(labels.signInPrompt),
                          ),
                        ),
                  data: (list) {
                    if (list.isEmpty) {
                      return EmptyState(
                        title: labels.emptyCatalog,
                        icon: Icons.compare_arrows_outlined,
                      );
                    }
                    final selected = [
                      for (final entry in list)
                        if (selectedIds.contains(entry.id)) entry,
                    ];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _pickerCard(
                          context,
                          ref,
                          labels,
                          theme,
                          list,
                          selectedIds,
                        ),
                        const SizedBox(height: 16),
                        if (selected.length < 2)
                          InlineAlert(
                            message: labels.selectPrompt,
                            error: false,
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              labels.disclaimer,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          _comparisonCard(
                            context,
                            labels,
                            theme,
                            locale,
                            selected,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickerCard(
    BuildContext context,
    WidgetRef ref,
    ComparisonLabels labels,
    ThemeData theme,
    List<ComparisonEntry> list,
    List<String> selectedIds,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final entry in list)
                FilterChip(
                  label: Text('${entry.flagEmoji} ${entry.countryName}'),
                  selected: selectedIds.contains(entry.id),
                  onSelected: (_) => toggleComparison(ref, entry.id),
                ),
            ],
          ),
          if (selectedIds.length >= kMaxCompare) ...[
            const SizedBox(height: 8),
            Text(
              labels.selectionFull,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              label: labels.clearAction,
              icon: Icons.clear_all_outlined,
              variant: AppButtonVariant.ghost,
              expanded: false,
              onPressed: selectedIds.isEmpty
                  ? null
                  : () =>
                        ref.read(selectedComparisonIdsProvider.notifier).state =
                            const [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonCard(
    BuildContext context,
    ComparisonLabels labels,
    ThemeData theme,
    String locale,
    List<ComparisonEntry> selected,
  ) {
    final width = MediaQuery.sizeOf(context).width;
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: width.clamp(0, 960) - 40),
          child: DataTable(
            headingRowHeight: 56,
            columnSpacing: 28,
            columns: [
              const DataColumn(label: SizedBox.shrink()),
              for (final entry in selected)
                DataColumn(
                  label: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.flagEmoji} ${entry.countryName}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        entry.pathwayTitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            rows: [
              for (final field in _fields)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        _fieldLabel(field, labels),
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    for (final entry in selected)
                      DataCell(_cellWidget(field, entry, labels, theme)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _fieldLabel(ComparisonField field, ComparisonLabels labels) =>
      switch (field) {
        ComparisonField.country => labels.countryLabel,
        ComparisonField.pathway => labels.pathwayLabel,
        ComparisonField.category => labels.categoryLabel,
        ComparisonField.processingTime => labels.processingTimeLabel,
        ComparisonField.fees => labels.feesLabel,
        ComparisonField.requirements => labels.requirementsLabel,
      };

  Widget _cellWidget(
    ComparisonField field,
    ComparisonEntry entry,
    ComparisonLabels labels,
    ThemeData theme,
  ) {
    final cell = entry.cellFor(field);
    if (cell.isMissing) {
      return StatusBadge(label: labels.notPublished, tone: StatusTone.warning);
    }
    final bodyStyle = theme.textTheme.bodySmall;
    if (cell.items != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in cell.items!)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• $item', style: bodyStyle),
            ),
        ],
      );
    }
    final text = cell.text ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(text, style: bodyStyle),
        ),
        if (cell.status == CellStatus.prose)
          Text(
            labels.proseHint,
            style: theme.textTheme.labelSmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
