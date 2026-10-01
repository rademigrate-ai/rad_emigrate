import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../applications/presentation/providers/application_controller.dart';
import '../../../documents/presentation/providers/document_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../applications/domain/entities/application_status.dart';
import '../../../documents/domain/entities/document.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final name = session?.fullName ?? 'Traveler';
    final apps = ref.watch(applicationControllerProvider).valueOrNull ?? [];
    final docs = ref.watch(documentControllerProvider).valueOrNull ?? [];
    final activeApps = apps.where((a) => a.status != ApplicationStatus.completed).length;
    final missingDocs = docs
        .where((d) => d.status == DocumentVerificationStatus.missing)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'AI Assistant',
            onPressed: () => context.go('/ai-assistant'),
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
          Text('Case overview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Active applications',
                  value: '$activeApps',
                  onTap: () => context.go('/applications'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Documents missing',
                  value: '$missingDocs',
                  onTap: () => context.go('/documents'),
                ),
              ),
            ],
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
                onTap: () => context.go('/ai-assistant'),
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
              session?.profileComplete == true
                  ? Icons.check_circle
                  : Icons.warning_amber,
              color: session?.profileComplete == true
                  ? Colors.green
                  : Colors.orange,
            ),
            onTap: () => context.go(
              session?.profileComplete == true ? '/profile' : '/profile-completion',
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Application status',
            subtitle: apps.isEmpty
                ? 'No applications yet'
                : '${apps.length} application(s) · $activeApps active',
            icon: Icons.assignment_outlined,
            onTap: () => context.go('/applications'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'Documents',
            subtitle: missingDocs > 0
                ? '$missingDocs document(s) still missing'
                : 'Document checklist ready',
            icon: Icons.folder_outlined,
            onTap: () => context.go('/documents'),
            trailing: const Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 8),
          SectionCard(
            title: 'AI Assistant',
            subtitle: 'Ask questions about visas, requirements and process',
            icon: Icons.smart_toy_outlined,
            onTap: () => context.go('/ai-assistant'),
            trailing: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
