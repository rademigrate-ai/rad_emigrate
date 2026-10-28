import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/premium_tokens.dart';
import '../../data/ai_session_repository.dart';

/// Conversation history drawer and desktop sidebar for multi-thread management.
class AiHistoryDrawer extends StatelessWidget {
  const AiHistoryDrawer({
    super.key,
    required this.sessions,
    required this.activeSessionId,
    required this.onSelectSession,
    required this.onNewChat,
    required this.onDeleteSession,
    required this.onRenameSession,
    this.isAuthenticated = true,
  });

  final List<AiSession> sessions;
  final String? activeSessionId;
  final ValueChanged<String> onSelectSession;
  final VoidCallback onNewChat;
  final ValueChanged<String> onDeleteSession;
  final void Function(String sessionId, String newTitle) onRenameSession;
  final bool isAuthenticated;

  void _showRenameDialog(BuildContext context, AiSession session) {
    final controller = TextEditingController(
      text: 'گفتگوی ${session.createdAt.toLocal().toString().split('.').first}',
    );

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('تغییر نام گفتگو'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'عنوان جدید',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                onRenameSession(session.id, newTitle);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AiSession session) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('حذف گفتگو'),
        content: const Text(
          'آیا از حذف این گفتگو اطمینان دارید؟ پیام‌های این گفتگو پاک خواهند شد.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              onDeleteSession(session.id);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: context.premium.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header with New Chat Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.forum_outlined,
                        color: AppColors.primaryRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'تاریخچه گفتگوها',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      onNewChat();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'گفتگوی جدید',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Sessions List
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 40,
                              color: context.premium.mutedText,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'هنوز گفتگویی ثبت نشده است.',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.premium.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isSelected = session.id == activeSessionId;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.premium.surfaceElevated
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(
                              color: isSelected
                                  ? context.premium.accent.withValues(
                                      alpha: 0.3,
                                    )
                                  : Colors.transparent,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              leading: Icon(
                                isSelected
                                    ? Icons.chat_bubble
                                    : Icons.chat_bubble_outline,
                                size: 18,
                                color: isSelected
                                    ? context.premium.accent
                                    : context.premium.mutedText,
                              ),
                              title: Text(
                                'گفتگوی ${_formatDate(session.createdAt)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: context.premium.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${session.questionCount} پیام',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.premium.mutedText,
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 16),
                                onSelected: (action) {
                                  if (action == 'rename') {
                                    _showRenameDialog(context, session);
                                  } else if (action == 'delete') {
                                    _showDeleteDialog(context, session);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 16),
                                        SizedBox(width: 8),
                                        Text('تغییر نام'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                          color: AppColors.error,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'حذف',
                                          style: TextStyle(
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).maybePop();
                                onSelectSession(session.id);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer Notice
            if (!isAuthenticated)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'در حالت مهمان، تاریخچه به صورت موقت ذخیره می‌شود. برای حفظ دائمی وارد شوید.',
                        style: TextStyle(fontSize: 11, color: AppColors.navy),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inDays == 0) {
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return 'امروز ساعت $hour:$minute';
    } else if (diff.inDays == 1) {
      return 'دیروز';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} روز پیش';
    }
    return '${local.year}/${local.month}/${local.day}';
  }
}
