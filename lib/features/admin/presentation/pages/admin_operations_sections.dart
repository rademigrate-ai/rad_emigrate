part of 'admin_operations_page.dart';

class _Providers extends StatelessWidget {
  const _Providers({required this.data});

  final AdminConsoleData data;

  @override
  Widget build(BuildContext context) {
    return _SectionList(
      title: 'AI Configuration · Providers & Models',
      emptyTitle: 'No AI provider is configured yet.',
      emptySubtitle:
          'Provider credentials remain server-side. Existing secrets are never displayed.',
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
                        '${provider.healthStatus} · ${provider.enabled ? 'enabled' : 'disabled'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _LtrValue('${provider.adapter} · ${provider.baseUrl}'),
                  const SizedBox(height: 8),
                  Text(
                    'Credential: ${provider.credentialConfigured ? 'Configured' : 'Not configured'} · Priority ${provider.priority}',
                  ),
                  const SizedBox(height: 12),
                  Text('Models', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  if (data.models
                      .where((item) => item.providerId == provider.id)
                      .isEmpty)
                    const Text('No models registered.')
                  else
                    ...data.models
                        .where((item) => item.providerId == provider.id)
                        .map(
                          (model) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            leading: Icon(
                              model.enabled
                                  ? Icons.check_circle_outline
                                  : Icons.pause_circle_outline,
                            ),
                            title: Text(model.displayName),
                            subtitle: _LtrValue(
                              '${model.slug} · ${model.capability}',
                            ),
                            trailing: Text('${model.maxOutputTokens}'),
                          ),
                        ),
                ],
              ),
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
    return _SectionList(
      title: 'Operations / Health',
      emptyTitle: 'No operational components are registered.',
      emptySubtitle: 'Component inventory is unavailable.',
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
                '${item.enabled ? 'enabled' : 'disabled'}${item.critical ? ' · critical' : ''}',
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
    return _SectionList(
      title: 'Audit / Security',
      emptyTitle: 'No audit events are visible.',
      emptySubtitle: 'Audit history is restricted to Super Admin.',
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
