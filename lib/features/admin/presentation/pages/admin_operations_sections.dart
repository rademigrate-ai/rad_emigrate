part of 'admin_operations_page.dart';

class _Providers extends StatelessWidget {
  const _Providers({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionList(
      title: '${l10n.adminAiConfig} · ${l10n.providerModelConnection}',
      emptyTitle: l10n.noProviderConfigured,
      emptySubtitle: l10n.credentialsServerOnly,
      children: [
        for (final provider in data.providers)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          provider.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _StatusBadge(
                        '${provider.healthStatus} · ${provider.enabled ? l10n.enabled : l10n.disabled}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _LtrValue('${provider.adapter} · ${provider.baseUrl}'),
                  const SizedBox(height: 8),
                  Text(
                    '${provider.credentialConfigured ? l10n.credentialConfigured : l10n.credentialMissing} · ${l10n.priority} ${provider.priority}',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Sources extends ConsumerWidget {
  const _Sources({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _SectionList(
      title: l10n.source,
      emptyTitle: l10n.noContentSources,
      emptySubtitle: l10n.approvedSourcesAppearHere,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            onPressed: () => showAdminSourceDialog(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.addSource),
          ),
        ),
        const SizedBox(height: 12),
        for (final source in data.sources)
          Card(
            child: ListTile(
              leading: Icon(
                source.active
                    ? Icons.verified_outlined
                    : Icons.pause_circle_outline,
              ),
              title: Text(source.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${source.publisher} · ${source.sourceType} · ${source.languageCode.toUpperCase()}',
                  ),
                  _LtrValue(source.url),
                ],
              ),
              trailing: _StatusBadge(
                source.active ? l10n.active : l10n.inactive,
              ),
            ),
          ),
        for (final source in data.researchSources)
          Card(
            child: ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: Text(source.displayName),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LtrValue(source.baseUrl),
                  Text(
                    '${source.sourceType} · ${source.trustClass} · ${source.runtimeScope.toUpperCase()}',
                  ),
                ],
              ),
              trailing: _StatusBadge(
                source.enabled ? source.authority : l10n.disabled,
              ),
            ),
          ),
      ],
    );
  }
}

class _Research extends ConsumerStatefulWidget {
  const _Research({required this.data, required this.onReview});
  final AdminConsoleData data;
  final VoidCallback onReview;
  @override
  ConsumerState<_Research> createState() => _ResearchState();
}

class _ResearchState extends ConsumerState<_Research> {
  var _running = false;
  String? _error;

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      await ref.read(adminOperationsRepositoryProvider).queueResearch();
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).researchRunFailed);
      }
    } finally {
      ref.invalidate(adminConsoleProvider);
      ref.invalidate(adminSnapshotProvider);
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final data = widget.data;
    final findings = data.reviews
        .where((item) => item.kind == 'finding' && item.status == 'review')
        .length;
    final drafts = data.reviews
        .where((item) => item.kind == 'draft' && item.status == 'review')
        .length;
    return _SectionList(
      title: l10n.researchPipelineSummary,
      emptyTitle: l10n.noResearchJobs,
      emptySubtitle: l10n.untrustedResearchDisclaimer,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.researchNeverAutoPublishes,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(l10n.findingsCount(findings))),
                    Chip(label: Text(l10n.draftsInReview(drafts))),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _running ? null : _run,
                      icon: _running
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(
                        _running ? l10n.researchRunning : l10n.queueResearchRun,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onReview,
                      icon: const Icon(Icons.fact_check_outlined),
                      label: Text(l10n.openReviewQueue),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          l10n.researchSourcesTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final source in data.researchSources)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  _LtrValue(source.baseUrl),
                  const SizedBox(height: 8),
                  Text(
                    '${source.enabled ? l10n.enabled : l10n.disabled} · ${source.trustClass}',
                  ),
                  Text(
                    '${l10n.lastResearchRun}: ${source.lastAttemptAt?.toLocal().toString() ?? l10n.sourceStateUnknown}',
                  ),
                  Text(
                    '${l10n.sourceLastSuccess}: ${source.lastSuccessAt?.toLocal().toString() ?? l10n.sourceStateUnknown}',
                  ),
                  if (source.lastErrorCode != null)
                    Text(
                      RegExp(r'^[a-z0-9_]{1,80}$')
                              .hasMatch(source.lastErrorCode!)
                          ? source.lastErrorCode!
                          : l10n.errorGeneric,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _running
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(adminOperationsRepositoryProvider)
                                  .configureResearchSource(
                                    sourceId: source.id,
                                    displayName: source.displayName,
                                    enabled: !source.enabled,
                                    runtimeScope: source.runtimeScope,
                                    trustClass: source.trustClass,
                                  );
                              ref.invalidate(adminConsoleProvider);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.sourceSaveFailed),
                                  ),
                                );
                              }
                            }
                          },
                    icon: Icon(source.enabled ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      source.enabled ? l10n.sourceDisable : l10n.sourceEnable,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text(l10n.researchJobs, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (data.researchJobs.isEmpty) Text(l10n.noResearchJobs),
        for (final job in data.researchJobs)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [Text(job.jobType), _StatusBadge(job.status)],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.createdAt?.toLocal().toString() ??
                        l10n.sourceStateUnknown,
                  ),
                  if (job.safeError != null)
                    Text(
                      RegExp(r'^[a-zA-Z0-9_]{1,80}$').hasMatch(job.safeError!)
                          ? job.safeError!
                          : l10n.researchRunFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        if (data.reviews.isEmpty) Text(l10n.reviewQueueEmpty),
        for (final item in data.reviews.take(12))
          Card(
            child: ListTile(
              onTap: () => showAdminReviewDetail(context, ref, item),
              leading: Icon(
                item.kind == 'finding'
                    ? Icons.find_in_page_outlined
                    : Icons.edit_note_outlined,
              ),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.kind == 'finding'
                    ? l10n.reviewFindingTitle
                    : l10n.reviewDraftTitle,
              ),
              trailing: _StatusBadge(item.status),
            ),
          ),
      ],
    );
  }
}

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _SectionList(
      title: l10n.reviewQueueTitle,
      emptyTitle: l10n.noReviewedUpdates,
      emptySubtitle: l10n.publishRequiresHuman,
      children: [
        for (final item in data.reviews)
          Card(
            child: ListTile(
              onTap: () => showAdminReviewDetail(context, ref, item),
              leading: Icon(
                item.kind == 'finding'
                    ? Icons.find_in_page_outlined
                    : Icons.edit_note_outlined,
              ),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.kind == 'finding'
                    ? l10n.reviewFindingTitle
                    : l10n.reviewDraftTitle,
              ),
              trailing: _StatusBadge(item.status),
            ),
          ),
      ],
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionList(
      title: l10n.feed,
      emptyTitle: l10n.noReviewedUpdates,
      emptySubtitle: l10n.publishRequiresHuman,
      children: [
        for (final item in data.feedItems)
          Card(
            child: ListTile(
              leading: const Icon(Icons.newspaper_outlined),
              title: _LtrValue(item.slug),
              subtitle: Text(item.category),
              trailing: _StatusBadge(item.status),
            ),
          ),
      ],
    );
  }
}

class _Health extends StatelessWidget {
  const _Health({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionList(
      title: l10n.operationsHealth,
      emptyTitle: l10n.noOperationalComponents,
      emptySubtitle: l10n.componentInventoryUnavailable,
      children: [
        for (final item in data.health)
          Card(
            child: ListTile(
              leading: Icon(
                item.enabled
                    ? Icons.monitor_heart_outlined
                    : Icons.pause_circle_outline,
              ),
              title: Text(item.displayName),
              subtitle: _LtrValue(item.slug),
              trailing: _StatusBadge(
                '${item.enabled ? l10n.enabled : l10n.disabled}${item.critical ? ' · ${l10n.critical}' : ''}',
              ),
            ),
          ),
      ],
    );
  }
}

class _Audit extends StatelessWidget {
  const _Audit({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SectionList(
      title: l10n.auditSecurity,
      emptyTitle: l10n.noAuditEvents,
      emptySubtitle: l10n.auditRestricted,
      children: [
        for (final item in data.audit)
          Card(
            child: ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: Text(item.action),
              subtitle: Text(
                '${item.resourceType}${item.resourceId == null ? '' : ' · ${item.resourceId}'}',
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({
    required this.title,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.children,
  });

  final String title;
  final String emptyTitle;
  final String emptySubtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        if (children.isEmpty)
          Card(
            child: ListTile(
              title: Text(emptyTitle),
              subtitle: Text(emptySubtitle),
            ),
          )
        else
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: child,
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(label, style: const TextStyle(fontSize: 12)));
  }
}

class _LtrValue extends StatelessWidget {
  const _LtrValue(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(value, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _KeyValue {
  const _KeyValue(this.label, this.value);
  final String label;
  final String value;
}

class _DataSummaryCard extends StatelessWidget {
  const _DataSummaryCard({
    required this.icon,
    required this.title,
    required this.rows,
  });

  final IconData icon;
  final String title;
  final List<_KeyValue> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label)),
                    Text(row.value),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
