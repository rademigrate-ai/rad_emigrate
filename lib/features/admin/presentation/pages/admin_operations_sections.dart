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
