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

  Future<void> _addSource(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    var sourceType = 'external';
    var trustClass = 'admin_defined';
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(l10n.addSource),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.titleLabel,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? l10n.requiredField
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: urlCtrl,
                          decoration: const InputDecoration(labelText: 'URL'),
                          keyboardType: TextInputType.url,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return l10n.requiredField;
                            final uri = Uri.tryParse(value);
                            if (uri == null ||
                                !uri.hasScheme ||
                                (uri.scheme != 'https' &&
                                    uri.scheme != 'http')) {
                              return l10n.invalidUrl;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: sourceType,
                          decoration: InputDecoration(
                            labelText: l10n.sourceType,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'government',
                              child: Text('government'),
                            ),
                            DropdownMenuItem(
                              value: 'embassy',
                              child: Text('embassy'),
                            ),
                            DropdownMenuItem(
                              value: 'institution',
                              child: Text('institution'),
                            ),
                            DropdownMenuItem(
                              value: 'external',
                              child: Text('external'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setLocal(() => sourceType = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: trustClass,
                          decoration: InputDecoration(
                            labelText: l10n.trustClass,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'official',
                              child: Text('official'),
                            ),
                            DropdownMenuItem(
                              value: 'admin_defined',
                              child: Text('admin_defined'),
                            ),
                            DropdownMenuItem(
                              value: 'partner',
                              child: Text('partner'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setLocal(() => trustClass = v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(ctx).pop(true);
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !context.mounted) {
      nameCtrl.dispose();
      urlCtrl.dispose();
      return;
    }

    try {
      await ref.read(adminOperationsRepositoryProvider).createResearchSource(
            displayName: nameCtrl.text.trim(),
            baseUrl: urlCtrl.text.trim(),
            sourceType: sourceType,
            trustClass: trustClass,
            runtimeScope: 'both',
          );
      ref.invalidate(adminConsoleProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.changesSaved)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorGeneric)),
        );
      }
    } finally {
      nameCtrl.dispose();
      urlCtrl.dispose();
    }
  }

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
            onPressed: () => _addSource(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.addSource),
          ),
        ),
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

class _Research extends ConsumerWidget {
  const _Research({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final findingsPending =
        data.reviews.where((r) => r.kind == 'finding').length;
    final draftsInReview =
        data.reviews.where((r) => r.kind == 'draft').length;
    final lastJob =
        data.researchJobs.isEmpty ? null : data.researchJobs.first;

    return _SectionList(
      title: l10n.researchJobs,
      emptyTitle: l10n.noResearchJobs,
      emptySubtitle: l10n.untrustedResearchDisclaimer,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.researchPipelineSummary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(l10n.findingsCount(findingsPending)),
                Text(l10n.draftsInReview(draftsInReview)),
                Text(l10n.feedPublishedOnly),
                if (lastJob != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${l10n.lastResearchRun}: ${lastJob.status}'
                    '${lastJob.safeError == null ? '' : ' · ${lastJob.safeError}'}',
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  l10n.researchNeverAutoPublishes,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(adminOperationsRepositoryProvider)
                    .queueResearch();
                ref.invalidate(adminConsoleProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.researchQueued)),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.errorGeneric)),
                  );
                }
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.queueResearchRun),
          ),
        ),
        for (final job in data.researchJobs)
          Card(
            child: ListTile(
              leading: const Icon(Icons.travel_explore_outlined),
              title: Text(job.jobType),
              subtitle: Text(
                '${job.triggerType}${job.safeError == null ? '' : ' · ${job.safeError}'}',
              ),
              trailing: _StatusBadge(job.status),
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
