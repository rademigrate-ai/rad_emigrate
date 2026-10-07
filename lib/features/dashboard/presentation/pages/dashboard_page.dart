import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_entrance.dart';
import '../../../feed/data/feed_repository.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/rad_brand.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../applications/domain/entities/application_status.dart';
import '../../../applications/presentation/providers/application_controller.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/document_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final name = session?.fullName ?? l10n.travelerFallback;
    final appsState = ref.watch(applicationControllerProvider);
    final docsState = ref.watch(documentControllerProvider);
    final apps = appsState.valueOrNull ?? [];
    final locale = Localizations.localeOf(context).languageCode;
    final updates = ref.watch(feedProvider(locale));
    final docs = docsState.valueOrNull ?? [];
    final activeApps = apps
        .where((a) => a.status != ApplicationStatus.completed)
        .length;
    final missingDocs = docs
        .where((d) => d.status == DocumentVerificationStatus.missing)
        .length;
    final profileDone = session?.profileComplete == true;
    final needsAction = !profileDone || missingDocs > 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.yourJourney),
        actions: [
          IconButton(
            tooltip: l10n.aiAssistant,
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
              AppEntrance(
                child: _JourneyHero(
                  name: name,
                  needsAction: needsAction,
                  onPrimaryAction: () => context.go(
                    !profileDone
                        ? '/profile-completion'
                        : needsAction
                        ? '/documents'
                        : '/applications',
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (needsAction) ...[
                SectionHeader(
                  title: l10n.needsYourAction,
                  subtitle: l10n.needsActionSubtitle,
                ),
                if (!profileDone)
                  _ActionRow(
                    icon: Icons.badge_outlined,
                    title: l10n.completeProfileTitle,
                    subtitle: l10n.completeProfileSubtitle,
                    tone: AppColors.warning,
                    onTap: () => context.go('/profile-completion'),
                  ),
                if (missingDocs > 0)
                  _ActionRow(
                    icon: Icons.folder_outlined,
                    title: missingDocs == 1
                        ? l10n.documentMissingOne
                        : l10n.documentsMissingCount(missingDocs),
                    subtitle: l10n.reviewRequiredFiles,
                    tone: AppColors.warning,
                    badge: StatusBadge(
                      label: l10n.actionBadge,
                      tone: StatusTone.warning,
                    ),
                    onTap: () => context.go('/documents'),
                  ),
                const SizedBox(height: 16),
              ],
              SectionHeader(
                title: l10n.caseOverview,
                subtitle: l10n.caseOverviewSubtitle,
                actionLabel: l10n.allCases,
                onAction: () => context.go('/applications'),
              ),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      value: appsState.hasValue ? '$activeApps' : '—',
                      label: l10n.activeCases,
                      icon: Icons.assignment_outlined,
                      onTap: () => context.go('/applications'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      value: docsState.hasValue ? '$missingDocs' : '—',
                      label: l10n.documentsMissing,
                      icon: Icons.folder_outlined,
                      onTap: () => context.go('/documents'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SectionHeader(
                title: l10n.quickActions,
                subtitle: l10n.quickActionsSubtitle,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionChip(
                    icon: Icons.public_outlined,
                    label: l10n.visaPrograms,
                    onTap: () => context.go('/visa'),
                  ),
                  _ActionChip(
                    icon: Icons.article_outlined,
                    label: l10n.radUpdates,
                    onTap: () => context.go('/feed'),
                  ),
                  _ActionChip(
                    icon: Icons.assignment_outlined,
                    label: l10n.applications,
                    onTap: () => context.go('/applications'),
                  ),
                  _ActionChip(
                    icon: Icons.folder_outlined,
                    label: l10n.documents,
                    onTap: () => context.go('/documents'),
                  ),
                  _ActionChip(
                    icon: Icons.smart_toy_outlined,
                    label: l10n.aiAssistant,
                    onTap: () => context.go('/ai-assistant'),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SectionHeader(
                title: l10n.radUpdates,
                actionLabel: l10n.feed,
                onAction: () => context.go('/feed'),
              ),
              updates.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => _ShortcutRow(
                  icon: Icons.refresh,
                  title: l10n.updatesLoadFailed,
                  subtitle: l10n.retry,
                  onTap: () => ref.invalidate(feedProvider(locale)),
                ),
                data: (items) => items.isEmpty
                    ? AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.noReviewedUpdates,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(l10n.catalogueDisclaimer),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in items.take(3))
                            _ShortcutRow(
                              icon: Icons.article_outlined,
                              title: item.title,
                              subtitle: item.summary,
                              onTap: () => context.go('/feed'),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 28),
              SectionHeader(title: l10n.shortcuts),
              _ShortcutRow(
                icon: Icons.person_outline,
                title: l10n.profile,
                subtitle: l10n.profileShortcutSubtitle,
                onTap: () => context.go('/profile'),
              ),
              _ShortcutRow(
                icon: Icons.smart_toy_outlined,
                title: l10n.askAssistant,
                subtitle: l10n.askAssistantSubtitle,
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
    final l10n = AppLocalizations.of(context);
    final title = l10n.brandIntroTitle;
    final description = l10n.brandIntroBody;
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
                    const RadBrand(
                      size: RadBrandSize.small,
                      showInstituteName: false,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.helloName(name),
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AppButton(
                label: l10n.exploreVisa,
                icon: Icons.public_outlined,
                expanded: false,
                onPressed: () => context.go('/visa'),
              ),
              AppButton(
                label: needsAction
                    ? l10n.reviewNextStep
                    : l10n.viewApplications,
                icon: needsAction
                    ? directionalForward(context)
                    : Icons.assignment_outlined,
                expanded: false,
                variant: AppButtonVariant.secondary,
                onPressed: onPrimaryAction,
              ),
            ],
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
              Icon(
                directionalChevron(context),
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: colorScheme.primary,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: Theme.of(context).dividerColor),
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
          Icon(icon, color: Theme.of(context).colorScheme.primary),
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
          Icon(
            directionalChevron(context),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
