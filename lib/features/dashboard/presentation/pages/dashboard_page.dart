import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../applications/domain/entities/application_status.dart';
import '../../../applications/presentation/providers/application_controller.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/document_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final name = session?.fullName ?? 'Traveler';
    final apps = ref.watch(applicationControllerProvider).valueOrNull ?? [];
    final docs = ref.watch(documentControllerProvider).valueOrNull ?? [];
    final activeApps = apps
        .where((a) => a.status != ApplicationStatus.completed)
        .length;
    final missingDocs = docs
        .where((d) => d.status == DocumentVerificationStatus.missing)
        .length;
    final profileDone = session?.profileComplete == true;
    final needsAction = !profileDone || missingDocs > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your journey'),
        actions: [
          IconButton(
            tooltip: 'AI Assistant',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: () => context.go('/ai-assistant'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _JourneyHero(
                name: name,
                needsAction: needsAction,
                onPrimaryAction: () => context.go(
                  !profileDone ? '/profile-completion' : '/documents',
                ),
              ),
              const SizedBox(height: 28),
              if (needsAction) ...[
                SectionHeader(
                  title: 'Needs your action',
                  subtitle: 'Complete these items to keep your case moving',
                ),
                if (!profileDone)
                  _ActionRow(
                    icon: Icons.badge_outlined,
                    title: 'Complete your profile',
                    subtitle: 'Add your name and basic details',
                    tone: AppColors.warning,
                    onTap: () => context.go('/profile-completion'),
                  ),
                if (missingDocs > 0)
                  _ActionRow(
                    icon: Icons.folder_outlined,
                    title:
                        '$missingDocs document${missingDocs == 1 ? '' : 's'} missing',
                    subtitle: 'Review the required files for your case',
                    tone: AppColors.warning,
                    badge: const StatusBadge(
                      label: 'Action',
                      tone: StatusTone.warning,
                    ),
                    onTap: () => context.go('/documents'),
                  ),
                const SizedBox(height: 16),
              ],
              SectionHeader(
                title: 'Case overview',
                subtitle: 'A quick view of your active work',
                actionLabel: 'All cases',
                onAction: () => context.go('/applications'),
              ),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      value: '$activeApps',
                      label: 'Active cases',
                      icon: Icons.assignment_outlined,
                      onTap: () => context.go('/applications'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      value: '$missingDocs',
                      label: 'Documents missing',
                      icon: Icons.folder_outlined,
                      onTap: () => context.go('/documents'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SectionHeader(
                title: 'Quick actions',
                subtitle: 'Start where you need help today',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionChip(
                    icon: Icons.public_outlined,
                    label: 'Visa programs',
                    onTap: () => context.go('/visa'),
                  ),
                  _ActionChip(
                    icon: Icons.article_outlined,
                    label: 'RAD updates',
                    onTap: () => context.go('/feed'),
                  ),
                  _ActionChip(
                    icon: Icons.assignment_outlined,
                    label: 'Applications',
                    onTap: () => context.go('/applications'),
                  ),
                  _ActionChip(
                    icon: Icons.folder_outlined,
                    label: 'Documents',
                    onTap: () => context.go('/documents'),
                  ),
                  _ActionChip(
                    icon: Icons.smart_toy_outlined,
                    label: 'AI assistant',
                    onTap: () => context.go('/ai-assistant'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SectionHeader(title: 'Shortcuts'),
              _ShortcutRow(
                icon: Icons.person_outline,
                title: 'Profile',
                subtitle: 'Personal and immigration details',
                onTap: () => context.go('/profile'),
              ),
              _ShortcutRow(
                icon: Icons.smart_toy_outlined,
                title: 'Ask the assistant',
                subtitle: 'Visas, documents, and process guidance',
                onTap: () => context.go('/ai-assistant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JourneyHero extends StatelessWidget {
  const _JourneyHero({
    required this.name,
    required this.needsAction,
    required this.onPrimaryAction,
  });

  final String name;
  final bool needsAction;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final title = needsAction ? 'Your next step is ready' : 'You are on track';
    final description = needsAction
        ? 'A few items need your attention before your case can move forward.'
        : 'Your current case information is up to date. Review your progress or ask for guidance.';
    return AppCard(
      emphasized: true,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $name',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                needsAction ? Icons.flag_outlined : Icons.check_circle_outline,
                size: 28,
                color: needsAction ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 18),
          AppButton(
            label: needsAction ? 'Review next step' : 'View applications',
            icon: needsAction ? Icons.arrow_forward : Icons.assignment_outlined,
            expanded: false,
            variant: needsAction
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            onPressed: onPrimaryAction,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          badge ??
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.navyMuted),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.navy,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.navyMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
