import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/rad_loading.dart';
import '../../domain/entities/fx_rate.dart';
import '../providers/fx_rate_controller.dart';

class CurrencyConverterModal extends ConsumerStatefulWidget {
  final double initialAmount;
  final String initialCurrency;

  const CurrencyConverterModal({
    super.key,
    this.initialAmount = 1000.0,
    this.initialCurrency = 'EUR',
  });

  static Future<void> show(
    BuildContext context, {
    double initialAmount = 1000.0,
    String initialCurrency = 'EUR',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CurrencyConverterModal(
        initialAmount: initialAmount,
        initialCurrency: initialCurrency,
      ),
    );
  }

  @override
  ConsumerState<CurrencyConverterModal> createState() =>
      _CurrencyConverterModalState();
}

class _CurrencyConverterModalState
    extends ConsumerState<CurrencyConverterModal> {
  late final TextEditingController _amountController;
  late String _selectedCurrency;

  final List<String> _supportedCurrencies = ['EUR', 'USD', 'CAD', 'GBP'];

  @override
  void initState() {
    super.initState();
    _selectedCurrency = widget.initialCurrency;
    _amountController = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _formatNumber(num value) {
    final parts = value.toStringAsFixed(0).split('');
    final buffer = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(parts[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(fxRateQuoteProvider(_selectedCurrency));
    final isToman = ref.watch(isTomanDisplayProvider);
    final theme = Theme.of(context);
    final isFa = Localizations.localeOf(context).languageCode == 'fa';

    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.premium.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: context.premium.border)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isFa
                      ? 'محاسبه‌گر تبدیل ارز ویزا'
                      : 'Visa Currency Calculator',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: isFa ? 'مبلغ ارز مقصد' : 'Foreign Amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCurrency,
                    decoration: InputDecoration(
                      labelText: isFa ? 'واحد ارز' : 'Currency',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _supportedCurrencies.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCurrency = val);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            quoteAsync.when(
              data: (quote) {
                final conversion = quote.convert(enteredAmount);
                final targetAmount = isToman
                    ? conversion.amountToman
                    : conversion.amountIrr;
                final unitLabel = isToman
                    ? (isFa ? 'تومان' : 'Toman')
                    : (isFa ? 'ریال' : 'IRR');

                return AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isFa ? 'معادل محاسبه‌شده:' : 'Equivalent Amount:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: context.premium.mutedText,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              ref.read(isTomanDisplayProvider.notifier).state =
                                  !isToman;
                            },
                            icon: const Icon(Icons.swap_horiz, size: 16),
                            label: Text(
                              isToman
                                  ? (isFa ? 'نمایش به ریال' : 'Show in IRR')
                                  : (isFa ? 'نمایش به تومان' : 'Show in Toman'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_formatNumber(targetAmount)} $unitLabel',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.warning,
                        ),
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_outlined,
                            size: 16,
                            color: context.premium.mutedText,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isFa
                                  ? 'منبع نرخ: مرجع رسمی ${quote.provider == FxProvider.frankfurter ? "Frankfurter (بانک مرکزی اروپا)" : "Fawazahmed0"}'
                                  : 'Provider: Official Reference (${quote.provider.name})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: context.premium.mutedText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (quote.isStale) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isFa
                                    ? 'نرخ مرجع مربوط به بیش از ۲۴ ساعت گذشته است.'
                                    : 'Reference rate is older than 24 hours.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: RadPending(),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  isFa
                      ? 'خطا در دریافت نرخ ارز مرجع'
                      : 'Error loading reference exchange rate',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: isFa ? 'بستن' : 'Close',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
