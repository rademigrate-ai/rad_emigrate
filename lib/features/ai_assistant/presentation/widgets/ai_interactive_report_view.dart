import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';

enum RequirementTier { mandatory, recommended, missing }

class ChecklistItemData {
  ChecklistItemData({
    required this.title,
    this.description = '',
    this.tier = RequirementTier.mandatory,
    this.isCompleted = false,
  });

  final String title;
  final String description;
  final RequirementTier tier;
  bool isCompleted;
}

/// Interactive checklist and report presentation card for visa requirements and pathway comparisons.
class AiInteractiveReportView extends StatefulWidget {
  const AiInteractiveReportView({
    super.key,
    required this.title,
    required this.items,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<ChecklistItemData> items;

  @override
  State<AiInteractiveReportView> createState() =>
      _AiInteractiveReportViewState();
}

class _AiInteractiveReportViewState extends State<AiInteractiveReportView> {
  late List<ChecklistItemData> _items;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }

  void _copyChecklist() {
    final buffer = StringBuffer();
    buffer.writeln('📋 ${widget.title}');
    if (widget.subtitle != null) buffer.writeln(widget.subtitle);
    buffer.writeln('---------------------------');
    for (final item in _items) {
      final status = item.isCompleted ? '[x]' : '[ ]';
      buffer.writeln('$status ${item.title}');
      if (item.description.isNotEmpty) {
        buffer.writeln('   - ${item.description}');
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _items.where((i) => i.isCompleted).length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.premium.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: context.premium.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.premium.surfaceElevated,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.lg),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.checklist_rtl_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Progress Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    '$completedCount از ${_items.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _items[index];
              return InkWell(
                onTap: () {
                  setState(() => item.isCompleted = !item.isCompleted);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox.adaptive(
                        value: item.isCompleted,
                        activeColor: AppColors.teal,
                        onChanged: (val) {
                          setState(() => item.isCompleted = val ?? false);
                        },
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: item.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: item.isCompleted
                                          ? context.premium.mutedText
                                          : context.premium.text,
                                    ),
                                  ),
                                ),
                                _buildTierBadge(item.tier),
                              ],
                            ),
                            if (item.description.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.premium.mutedText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _copyChecklist,
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy,
                    size: 14,
                    color: _copied ? AppColors.teal : AppColors.navy,
                  ),
                  label: Text(
                    _copied ? 'کپی شد' : 'کپی چک‌لیست',
                    style: TextStyle(
                      fontSize: 11,
                      color: _copied ? AppColors.teal : AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierBadge(RequirementTier tier) {
    Color color;
    String label;
    switch (tier) {
      case RequirementTier.mandatory:
        color = AppColors.primaryRed;
        label = 'الزامی';
        break;
      case RequirementTier.recommended:
        color = AppColors.teal;
        label = 'پیشنهادی';
        break;
      case RequirementTier.missing:
        color = AppColors.warning;
        label = 'نقص مدرک';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
