import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/record_labels.dart';
import '../../../../core/widgets/premium_visuals.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/rpc_compat.dart';
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
      List<dynamic> rows;
      try {
        final rpcRes = await client.rpc('list_admin_consultations');
        if (rpcRes is List<dynamic>) {
          rows = rpcRes;
        } else {
          throw const FormatException(
            'Unexpected response from list_admin_consultations',
          );
        }
      } catch (e) {
        if (isRpcMissingException(e)) {
          rows =
              await client
                      .from('consultation_requests')
                      .select(
                        'id, topic, message, status, admin_note, created_at, user_id',
                      )
                      .order('created_at', ascending: false)
                      .limit(100)
                  as List<dynamic>;
        } else {
          // Strictly fail closed on 42501 (forbidden), network, timeouts, format errors
          rethrow;
        }
      }
      if (mounted) {
        setState(() {
          _rows = List<Map<String, dynamic>>.from(rows);
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
      try {
        await client.rpc(
          'update_admin_consultation',
          params: {
            'p_consultation_id': id,
            'p_status': status,
            'p_admin_note': (note != null && note.trim().isNotEmpty)
                ? note.trim()
                : null,
          },
        );
      } catch (e) {
        if (isRpcMissingException(e)) {
          await client
              .from('consultation_requests')
              .update({
                'status': status,
                'admin_note': note,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id);
        } else {
          // Strictly fail closed on 42501 (forbidden), 22023 (validation), network drops
          rethrow;
        }
      }
      if (mounted) {
        setState(() => _notice = l10n.consultationUpdated);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.consultationUpdated)));
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.consultationUpdateFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/admin'),
          title: Text(l10n.adminConsultations),
        ),
        body: PremiumCanvas(
          child: LoadingState.section(message: l10n.loadingOperational),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          leading: const AppBackButton(fallback: '/admin'),
          title: Text(l10n.adminConsultations),
        ),
        body: PremiumCanvas(
          child: ErrorState(message: _error!, onRetry: _load),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/admin'),
        title: Text(l10n.adminConsultations),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PremiumCanvas(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_notice != null) Text(_notice!),
            if (_rows.isEmpty) Text(l10n.noAdminConsultations),
            for (final r in _rows)
              Card(
                child: ExpansionTile(
                  title: Text('${r['topic'] ?? ''}'),
                  subtitle: Text(
                    '${consultationStatusLabel(r['status'], l10n)} · ${recordDateLabel(r['created_at'], context)}',
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
                            items: [
                              DropdownMenuItem(
                                value: 'submitted',
                                child: Text(
                                  consultationStatusLabel('submitted', l10n),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'in_review',
                                child: Text(
                                  consultationStatusLabel('in_review', l10n),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'contacted',
                                child: Text(
                                  consultationStatusLabel('contacted', l10n),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'closed',
                                child: Text(
                                  consultationStatusLabel('closed', l10n),
                                ),
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
      ),
    );
  }
}
