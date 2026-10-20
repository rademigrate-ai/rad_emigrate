import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/premium_tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/premium_visuals.dart';
import '../../../../core/widgets/reference_widgets.dart';
import '../../../../l10n/app_localizations.dart';
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
    final isAuthed = session != null && session.isAuthenticated;
    final name = isAuthed
        ? (session.fullName ?? l10n.travelerFallback)
        : l10n.travelerFallback;
    final apps = ref.watch(applicationControllerProvider).valueOrNull ?? [];
    final docs = ref.watch(documentControllerProvider).valueOrNull ?? [];
    final missing = docs
        .where((d) => d.status == DocumentVerificationStatus.missing)
        .length;
    final profileDone = isAuthed && session.profileComplete;
    final quick = [
      (
        Icons.chat_bubble_outline,
        const Color(0xFF345CFF),
        l10n.consultationShortLabel,
        '/consultation',
      ),
      (
        Icons.schedule_outlined,
        const Color(0xFF345CFF),
        l10n.worldTimeTitle,
        '/world-clock',
      ),
      (
        Icons.description_outlined,
        const Color(0xFF00A986),
        l10n.documents,
        '/documents',
      ),
      (Icons.article_outlined, const Color(0xFFD91F2B), l10n.feed, '/feed'),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: InkWell(
          onTap: () => context.go('/profile'),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: context.premium.surfaceElevated,
                child: Text(
                  name.trim().isEmpty ? 'R' : name.trim()[0],
                  style: TextStyle(color: context.premium.text),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.helloName(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.yourJourney,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.notificationsTitle,
            icon: const Icon(Icons.notifications_outlined, size: 22),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            tooltip: l10n.aiAssistant,
            icon: const Icon(Icons.smart_toy_outlined, size: 22),
            onPressed: () => context.go('/ai-assistant'),
          ),
        ],
      ),
      body: PremiumCanvas(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                ReferenceJourneyHero(
                  title: l10n.migrationHeroTitle,
                  body: l10n.brandIntroBody,
                  action: l10n.exploreVisa,
                  onAction: () => context.go('/visa'),
                ),
                ReferenceSection(
                  title: l10n.quickActions,
                  action: l10n.shortcuts,
                  onAction: () => context.go('/profile'),
                ),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    runSpacing: 8,
                    children: [
                      for (final item in quick)
                        SizedBox(
                          width:
                              constraints.maxWidth /
                              (MediaQuery.textScalerOf(context).scale(14) > 20
                                  ? 2
                                  : 4),
                          child: ReferenceQuickAction(
                            icon: item.$1,
                            color: item.$2,
                            label: item.$3,
                            onTap: () => context.go(item.$4),
                          ),
                        ),
                    ],
                  ),
                ),
                ReferenceSection(
                  title: l10n.recentActivity,
                  action: l10n.allCases,
                  onAction: () => context.push('/profile/cases'),
                ),
                if (!isAuthed)
                  _ActivityRow(
                    icon: Icons.login_outlined,
                    title: l10n.signIn,
                    subtitle: l10n.caseOverviewSubtitle,
                    onTap: () => context.go('/login?from=%2Fdashboard'),
                  ),
                for (final app in apps.take(1))
                  _ActivityRow(
                    country: app.country,
                    icon: Icons.assignment_outlined,
                    title: app.title,
                    subtitle: app.programName,
                    onTap: () => context.push('/profile/cases'),
                  ),
                if (missing > 0)
                  _ActivityRow(
                    icon: Icons.description_outlined,
                    title: missing == 1
                        ? l10n.documentMissingOne
                        : l10n.documentsMissingCount(missing),
                    subtitle: l10n.reviewRequiredFiles,
                    onTap: () => context.push('/documents'),
                  ),
                if (isAuthed && !profileDone)
                  _ActivityRow(
                    icon: Icons.badge_outlined,
                    title: l10n.completeProfileTitle,
                    subtitle: l10n.completeProfileSubtitle,
                    onTap: () => context.go('/profile-completion'),
                  ),
                if (isAuthed && apps.isEmpty && missing == 0 && profileDone)
                  _ActivityRow(
                    icon: Icons.assignment_outlined,
                    title: l10n.noApplications,
                    subtitle: l10n.noApplicationsSubtitle,
                    onTap: () => context.push('/profile/cases'),
                  ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tiles = [
                      _InformationCard(
                        image: 'assets/images/destinations/gb.jpg',
                        title: l10n.worldTimeTitle,
                        subtitle: l10n.searchWorldClocks,
                        onTap: () => context.push('/world-clock'),
                      ),
                      _InformationCard(
                        image: 'assets/images/destinations/ca.jpg',
                        title: l10n.openConsultation,
                        subtitle: l10n.consultationIntro,
                        onTap: () => context.push('/consultation'),
                      ),
                    ];
                    if (MediaQuery.textScalerOf(context).scale(14) > 21) {
                      return Column(
                        children: [
                          for (final tile in tiles)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: tile,
                            ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 12),
                        Expanded(child: tiles[1]),
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
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.country,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? country;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        if (country != null)
          ReferenceFlag(country: country!)
        else
          ReferenceIcon(icon: icon, color: context.premium.information),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(
          directionalChevron(context),
          size: 18,
          color: context.premium.mutedText,
        ),
      ],
    ),
  );
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Material(
      color: const Color(0xFF101A2B),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                image,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x100B1220), Color(0xF00B1220)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFEDF3FF),
                      fontSize: 11,
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Icon(
                      directionalChevron(context),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
