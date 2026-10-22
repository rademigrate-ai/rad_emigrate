// Immigration cost calculator page.
//
// Truthful by construction: every figure is derived from published,
// source-attributed catalog text. Missing, prose-only, or mixed-currency data
// renders explicit explanatory states instead of an invented number.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_back_button.dart';
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
import '../../domain/currencies.dart';
import '../../domain/entities/immigration_cost.dart';
import '../cost_calculator_labels.dart';
import '../providers/cost_calculator_controller.dart';

/// Cost calculator entry page.
class CostCalculatorPage extends ConsumerWidget {
  const CostCalculatorPage({super.key});

  String _currencySymbol(String? code) =>
      costCurrencyByCode(code)?.symbol ?? (code ?? '');

  String _amount(int? minor, String? code) {
    if (minor == null) return '—';
    final symbol = _currencySymbol(code);
    final value = minor / 100;
    final formatted = value.toStringAsFixed(
      value == value.roundToDouble() ? 0 : 2,
    );
    return symbol.isEmpty ? formatted : '$symbol$formatted';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context).languageCode;
    final labels = CostCalculatorLabels(locale);
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider).valueOrNull;
    final isAuthed = auth?.isAuthenticated ?? false;
    final pathways = ref.watch(costPathwaysProvider(locale));
    final selectedId = ref.watch(selectedPathwayIdProvider);
    final displayCurrency = ref.watch(displayCurrencyProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/dashboard'),
        title: Text(labels.title),
      ),
      body: PremiumCanvas(
        accent: theme.colorScheme.secondary,
        child: ConstrainedContent(
          maxWidth: 820,
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
                const SizedBox(height: 20),
                pathways.when(
                  loading: () => const LoadingState.section(),
                  error: (_, _) => isAuthed
                      ? ErrorState(
                          message: labels.genericError,
                          onRetry: () =>
                              ref.invalidate(costPathwaysProvider(locale)),
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
                        icon: Icons.calculate_outlined,
                      );
                    }
                    return _buildBody(
                      context,
                      ref,
                      labels,
                      theme,
                      locale,
                      list,
                      selectedId,
                      displayCurrency,
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

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    CostCalculatorLabels labels,
    ThemeData theme,
    String locale,
    List<CostPathway> list,
    String? selectedId,
    String displayCurrency,
  ) {
    final breakdown = breakdownFor(list, selectedId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(labels.selectPathway, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: selectedId,
                decoration: InputDecoration(
                  labelText: labels.selectPathway,
                  prefixIcon: const Icon(Icons.public_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('—'),
                  ),
                  for (final pathway in list)
                    DropdownMenuItem<String?>(
                      value: pathway.id,
                      child: Text(
                        '${pathway.flagEmoji} ${pathway.countryName} · '
                        '${pathway.categoryName}',
                      ),
                    ),
                ],
                onChanged: (value) =>
                    ref.read(selectedPathwayIdProvider.notifier).state = value,
              ),
              const SizedBox(height: 14),
              Text(labels.currencyLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final currency in kCostCurrencies)
                    ChoiceChip(
                      label: Text('${currency.code} ${currency.symbol}'),
                      selected: displayCurrency == currency.code,
                      onSelected: (_) =>
                          ref.read(displayCurrencyProvider.notifier).state =
                              currency.code,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                labels.currencyNoConvertNote,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (breakdown == null) ...[
          const SizedBox(height: 16),
          InlineAlert(message: labels.pathwayHint, error: false),
        ] else ...[
          const SizedBox(height: 16),
          ..._breakdownCards(labels, theme, locale, breakdown, displayCurrency),
        ],
      ],
    );
  }

  List<Widget> _breakdownCards(
    CostCalculatorLabels labels,
    ThemeData theme,
    String locale,
    CostBreakdown breakdown,
    String displayCurrency,
  ) {
    final dateFormat = DateFormat.yMMMd(locale);
    final pathway = breakdown.pathway;
    final mismatch =
        breakdown.total.isAvailable &&
        breakdown.total.currency != displayCurrency;

    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                '${pathway.flagEmoji} ${pathway.countryName} · '
                '${pathway.categoryName}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 6),
            Text(pathway.title, style: theme.textTheme.bodyMedium),
            const Divider(height: 22),
            Text(labels.breakdownTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            for (final line in breakdown.lines) ...[
              _lineRow(labels, theme, line),
              const SizedBox(height: 10),
            ],
            const Divider(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    labels.totalLabel,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: StatusBadge(
                    label: breakdown.total.isAvailable
                        ? _amount(
                            breakdown.total.amountMinor,
                            breakdown.total.currency,
                          )
                        : labels.noVerifiedFigure,
                    tone: breakdown.total.isAvailable
                        ? StatusTone.success
                        : StatusTone.warning,
                  ),
                ),
              ],
            ),
            if (mismatch) ...[
              const SizedBox(height: 8),
              InlineAlert(message: labels.mixedCurrencies, error: false),
            ],
            const SizedBox(height: 14),
            Text(
              '${labels.sourceLabel}: ${pathway.sourcePublisher} — '
              '${pathway.sourceTitle}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${labels.retrievedAt}: ${dateFormat.format(pathway.sourceRetrievedAt)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _lineRow(CostCalculatorLabels labels, ThemeData theme, CostLine line) {
    final value = switch (line.basis) {
      CostBasis.publishedFigure => _amount(line.amountMinor, line.currency),
      // Prose is published; only the exact figure is absent. The note below
      // carries the authoritative wording, so "Not published" would be false.
      CostBasis.publishedTextOnly => '—',
      CostBasis.notPublished => labels.notPublished,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(line.label, style: theme.textTheme.bodyMedium),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        if (line.basis == CostBasis.publishedFigure &&
            line.rawText != null) ...[
          const SizedBox(height: 2),
          Text(
            line.rawText!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            labels.figureFromSource,
            style: theme.textTheme.labelSmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else if (line.basis == CostBasis.publishedTextOnly &&
            line.rawText != null) ...[
          const SizedBox(height: 2),
          Text(
            line.rawText!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            labels.textOnlyNote,
            style: theme.textTheme.labelSmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
