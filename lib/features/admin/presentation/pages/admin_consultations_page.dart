import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../l10n/app_localizations.dart';

/// Minimal admin consultation queue (Stage 8).
class AdminConsultationsPage extends ConsumerStatefulWidget {
  const AdminConsultationsPage({super.key});

  @override
  ConsumerState<AdminConsultationsPage> createState() =>
      _AdminConsultationsPageState();
}

class _AdminConsultationsPageState
    extends ConsumerState<AdminConsultationsPage> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientServiceProvider).client;
      final rows = await client.rpc('list_admin_consultations');
      if (mounted) {
        setState(() {
          _rows = List<Map<String, dynamic>>.from(rows as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).adminLoadFailed;
          _loading = false;
        });
      }
    }
  }

  Future<void> _update(String id, String status, String? note) async {
    final l10n = AppLocalizations.of(context);
    try {
      final client = ref.read(supabaseClientServiceProvider).client;
      await client.rpc(
        'update_admin_consultation',
        params: {
          'p_consultation_id': id,
          'p_status': status,
          'p_admin_note': note,
        },
      );
      if (mounted) {
        setState(() => _notice = l10n.consultationUpdated);
        await _load();
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.consultationUpdateFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.adminConsultations)),
        body: LoadingState.section(message: l10n.loadingOperational),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.adminConsultations)),
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminConsultations),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_notice != null) Text(_notice!),
          if (_rows.isEmpty) Text(l10n.noAdminConsultations),
          for (final r in _rows)
            Card(
              child: ExpansionTile(
                title: Text('${r['topic'] ?? ''}'),
                subtitle: Text(
                  '${r['status'] ?? ''} · ${r['created_at'] ?? ''}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('${r['message'] ?? ''}'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: '${r['status'] ?? 'submitted'}',
                          decoration: InputDecoration(
                            labelText: l10n.consultationStatus,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'submitted',
                              child: Text('submitted'),
                            ),
                            DropdownMenuItem(
                              value: 'in_review',
                              child: Text('in_review'),
                            ),
                            DropdownMenuItem(
                              value: 'contacted',
                              child: Text('contacted'),
                            ),
                            DropdownMenuItem(
                              value: 'closed',
                              child: Text('closed'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              _update(
                                r['id'] as String,
                                v,
                                r['admin_note'] as String?,
                              );
                            }
                          },
                        ),
                        TextFormField(
                          initialValue: r['admin_note'] as String? ?? '',
                          decoration: InputDecoration(
                            labelText: l10n.consultationAdminNote,
                          ),
                          minLines: 2,
                          maxLines: 4,
                          onFieldSubmitted: (note) => _update(
                            r['id'] as String,
                            '${r['status']}',
                            note,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
