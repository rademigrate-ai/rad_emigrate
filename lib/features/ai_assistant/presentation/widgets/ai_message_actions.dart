import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Interactive message actions toolbar: copy, feedback thumbs, report inaccuracy, retry.
class AiMessageActions extends StatefulWidget {
  const AiMessageActions({
    super.key,
    required this.messageText,
    this.onRetry,
    this.showRetry = false,
  });

  final String messageText;
  final VoidCallback? onRetry;
  final bool showRetry;

  @override
  State<AiMessageActions> createState() => _AiMessageActionsState();
}

class _AiMessageActionsState extends State<AiMessageActions> {
  bool _copied = false;
  bool? _thumbsUp;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.messageText));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _showReportDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('گزارش پاسخ نادرست'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'لطفاً دلیل نادرست یا مبهم بودن پاسخ را بنویسید تا کیفیت هوش مصنوعی ارتقا یابد:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'توضیحات شما...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('گزارش شما با موفقیت ثبت شد.'),
                  backgroundColor: AppColors.teal,
                ),
              );
            },
            child: const Text('ارسال گزارش'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy Action
          _ActionButton(
            tooltip: _copied ? 'کپی شد' : 'کپی متن پاسخ',
            icon: _copied ? Icons.check : Icons.copy,
            color: _copied ? AppColors.teal : context.premium.mutedText,
            onPressed: _copy,
          ),
          const SizedBox(width: 4),

          // Thumbs Up
          _ActionButton(
            tooltip: 'پاسخ مفید بود',
            icon: _thumbsUp == true ? Icons.thumb_up : Icons.thumb_up_outlined,
            color: _thumbsUp == true ? AppColors.teal : context.premium.mutedText,
            onPressed: () {
              setState(() => _thumbsUp = _thumbsUp == true ? null : true);
            },
          ),
          const SizedBox(width: 4),

          // Thumbs Down
          _ActionButton(
            tooltip: 'پاسخ نامناسب یا ناقص بود',
            icon: _thumbsUp == false
                ? Icons.thumb_down
                : Icons.thumb_down_outlined,
            color: _thumbsUp == false
                ? AppColors.error
                : context.premium.mutedText,
            onPressed: () {
              setState(() => _thumbsUp = _thumbsUp == false ? null : false);
              if (_thumbsUp == false) {
                _showReportDialog();
              }
            },
          ),
          const SizedBox(width: 4),

          // Report
          _ActionButton(
            tooltip: 'گزارش مغایرت یا اشتباه',
            icon: Icons.flag_outlined,
            color: context.premium.mutedText,
            onPressed: _showReportDialog,
          ),

          if (widget.showRetry && widget.onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh, size: 14),
              label: Text(
                AppLocalizations.of(context).retry,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
