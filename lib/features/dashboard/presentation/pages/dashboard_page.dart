import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../app/dependencies.dart';
import '../../../../core/widgets/section_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final name = session?.fullName ?? 'Traveler';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'AI Assistant',
            onPressed: () => _openAiSheet(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppColors.navy,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome, $name',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your immigration journey starts here.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickAction(
                icon: Icons.public,
                label: 'Visa Programs',
                onTap: () => context.go('/visa'),
              ),
              _QuickAction(
                icon: Icons.assignment_outlined,
                label: 'Applications',
                onTap: () => context.go('/applications'),
              ),
              _QuickAction(
                icon: Icons.folder_outlined,
                label: 'Documents',
                onTap: () => context.go('/documents'),
              ),
              _QuickAction(
                icon: Icons.person_outline,
                label: 'Profile',
                onTap: () => context.go('/profile'),
              ),
              _QuickAction(
                icon: Icons.smart_toy_outlined,
                label: 'AI Assistant',
                onTap: () => _openAiSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Profile completion',
            subtitle: session?.profileComplete == true
                ? 'Your basic profile is complete'
                : 'Complete your immigration profile',
            icon: Icons.task_alt,
            trailing: Icon(
              session?.profileComplete == true ? Icons.check_circle : Icons.warning_amber,
              color: session?.profileComplete == true ? Colors.green : Colors.orange,
            ),
            onTap: () => context.go('/profile'),
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Updates & News',
            subtitle: 'Immigration news and RAD announcements will appear here',
            icon: Icons.newspaper_outlined,
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'AI Assistant',
            subtitle: 'Ask questions about visas, requirements and process',
            icon: Icons.smart_toy_outlined,
            onTap: () => _openAiSheet(context, ref),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Future<void> _openAiSheet(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    String? answer;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('AI Assistant', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                    'Foundation ready. Responses are placeholders until the knowledge base is connected.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask about visas, documents, timelines…',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primaryRed),
                    onPressed: () async {
                      final ai = ref.read(aiServiceProvider);
                      final result = await ai.ask(controller.text);
                      setModalState(() => answer = result);
                    },
                    child: const Text('Ask'),
                  ),
                  if (answer != null) ...[
                    const SizedBox(height: 16),
                    Text(answer!),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
