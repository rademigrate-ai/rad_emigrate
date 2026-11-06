import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/dependencies.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../data/datasources/case_checklist_gateway.dart';
import '../../domain/case_lifecycle.dart';
import '../../domain/entities/application_status.dart';
import '../../domain/entities/case_checklist.dart';
import '../../domain/entities/visa_application.dart';
import '../../domain/repositories/application_repository.dart';
import 'application_controller.dart';

class CaseTrackerState {
  const CaseTrackerState({
    required this.case_,
    this.isLoading = false,
    this.isTransitioning = false,
    this.errorMessage,
    this.now,
  });

  final ImmigrationCase case_;
  final bool isLoading;
  final bool isTransitioning;
  final String? errorMessage;
  final DateTime? now;

  VisaApplication get application => case_.application;
  CaseChecklist get checklist => case_.checklist;
  List<CaseHistoryEntry> get history => case_.history;

  CaseChecklistProgress get progress =>
      case_.checklist.progress(now: now ?? DateTime.now().toUtc());

  List<CaseReminderMeta> get reminders =>
      const CaseLifecycleService().pendingReminders(case_, nowUtc: now);

  CaseTrackerState copyWith({
    ImmigrationCase? case_,
    bool? isLoading,
    bool? isTransitioning,
    String? errorMessage,
    bool clearError = false,
    DateTime? now,
  }) {
    return CaseTrackerState(
      case_: case_ ?? this.case_,
      isLoading: isLoading ?? this.isLoading,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      now: now ?? this.now,
    );
  }
}

/// Generates standard baseline checklist items for an application.
List<CaseChecklistItem> defaultMilestoneItems(
  VisaApplication app, {
  DateTime? clock,
}) {
  // Checklist templates are generic planning aids, not visa advice.
  // Requirements and deadlines differ by jurisdiction/program and must be
  // explicitly verified against official sources before being presented as
  // mandatory. Never create fictitious due dates or appointment obligations.
  return [
    CaseChecklistItem(
      id: '${app.id}_verify_requirements',
      title: 'Verify official program requirements',
      description:
          'Review the current official requirements for this destination and '
          'program. Add only confirmed documents and deadlines.',
      sortOrder: 1,
    ),
    CaseChecklistItem(
      id: '${app.id}_organize_documents',
      title: 'Organize case documents',
      description:
          'Create document tasks after confirming what this application '
          'actually requires; no automatic validity period is assumed.',
      sortOrder: 2,
    ),
    CaseChecklistItem(
      id: '${app.id}_track_milestones',
      title: 'Track verified case milestones',
      description:
          'Record official correspondence, dates and status updates '
          'only as they become confirmed.',
      sortOrder: 3,
    ),
  ];
}

final caseTrackerControllerProvider = StateNotifierProvider.autoDispose
    .family<CaseTrackerController, CaseTrackerState, VisaApplication>((
      ref,
      app,
    ) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final userId = ref.watch(authenticatedUserIdProvider) ?? 'guest';
      final appRepo = ref.watch(applicationRepositoryProvider);
      final backend = ref.watch(supabaseClientServiceProvider);
      final config = ref.watch(appConfigProvider);
      return CaseTrackerController(
        initialApp: app,
        userId: userId,
        prefs: prefs,
        appRepository: appRepo,
        gateway: backend.isInitialized && userId != 'guest'
            ? SupabaseCaseChecklistGateway(backend)
            : null,
        requireRemotePersistence: config.isProduction,
        isCurrent: () => ref.read(authenticatedUserIdProvider) == userId,
      );
    });

class CaseTrackerController extends StateNotifier<CaseTrackerState> {
  CaseTrackerController({
    required VisaApplication initialApp,
    required this._userId,
    required this._prefs,
    this._appRepository,
    this._gateway,
    bool requireRemotePersistence = false,
    bool Function()? isCurrent,
    this._service = const CaseLifecycleService(),
    DateTime? nowUtc,
  }) : _remoteRequired = requireRemotePersistence,
       _isCurrent = isCurrent ?? (() => true),
       super(
         CaseTrackerState(
           case_: ImmigrationCase(
             application: initialApp,
             checklist: CaseChecklist(
               caseId: initialApp.id,
               applicationStatus: initialApp.status,
               items: const [],
             ),
           ),
           isLoading: true,
           now: nowUtc,
         ),
       ) {
    load();
  }

  final String _userId;
  final SharedPreferences _prefs;
  final ApplicationRepository? _appRepository;
  final CaseChecklistGateway? _gateway;
  final bool _remoteRequired;
  final bool Function() _isCurrent;
  final CaseLifecycleService _service;
  int _revision = 0;
  bool _remoteReady = false;

  String get _effectiveUserId =>
      _userId.trim().isNotEmpty ? _userId.trim() : 'guest';

  String get _scopedStorageKey =>
      'rad_case_checklist_${_effectiveUserId}_${state.case_.caseId}';

  String get _legacyStorageKey => 'rad_case_checklist_${state.case_.caseId}';

  void load() {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final effectiveUser = _effectiveUserId;
      CaseChecklist? loadedChecklist;

      // 1. Authoritative per-user scoped storage check
      final scopedRaw = _prefs.getString(_scopedStorageKey);
      if (scopedRaw != null && scopedRaw.isNotEmpty) {
        final decoded = jsonDecode(scopedRaw) as Map<String, dynamic>;
        final storedOwner =
            decoded['userId'] as String? ?? decoded['ownerId'] as String?;
        if (storedOwner == null || storedOwner == effectiveUser) {
          loadedChecklist = CaseChecklist.fromJson(decoded);
        }
      }

      // 2. Legacy unscoped storage fallback ONLY with demonstrably verified ownership.
      // An unowned legacy key contains no owner identity to authorize migration and MUST fail closed.
      if (loadedChecklist == null) {
        final legacyRaw = _prefs.getString(_legacyStorageKey);
        if (legacyRaw != null && legacyRaw.isNotEmpty) {
          final decoded = jsonDecode(legacyRaw) as Map<String, dynamic>;
          final legacyOwner =
              decoded['userId'] as String? ??
              decoded['ownerId'] as String? ??
              decoded['creatorUserId'] as String? ??
              _prefs.getString(
                'rad_case_checklist_owner_${state.case_.caseId}',
              );

          if (legacyOwner != null &&
              legacyOwner.isNotEmpty &&
              legacyOwner == effectiveUser) {
            loadedChecklist = CaseChecklist.fromJson(decoded);
            // Migrate to user-scoped storage and purge legacy unscoped key
            unawaited(_persistLocalOnly(loadedChecklist));
            unawaited(_prefs.remove(_legacyStorageKey));
          }
          // Otherwise fail closed: never disclose unowned or foreign account checklist
        }
      }

      final checklist =
          loadedChecklist ??
          CaseChecklist(
            caseId: state.case_.caseId,
            applicationStatus: state.case_.application.status,
            items: defaultMilestoneItems(
              state.case_.application,
              clock: state.now,
            ),
          );

      if (loadedChecklist == null) {
        unawaited(_persistLocalOnly(checklist));
      }

      state = state.copyWith(
        case_: state.case_.copyWith(
          checklist: checklist,
          application: state.case_.application.copyWith(
            // A server-authenticated application outranks any locally cached
            // case status. The cache cannot silently undo a staff transition.
            status: _gateway == null
                ? checklist.applicationStatus
                : state.case_.application.status,
          ),
        ),
        isLoading: _gateway != null,
        errorMessage: _remoteRequired && _gateway == null
            ? 'Server checklist persistence is unavailable.'
            : null,
      );
      if (_gateway != null) unawaited(_hydrateRemote());
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load case checklist: $e',
      );
    }
  }

  Future<void> _persistLocalOnly(CaseChecklist checklist) async {
    final payload = checklist.toJson();
    payload['userId'] = _effectiveUserId;
    await _prefs.setString(_scopedStorageKey, jsonEncode(payload));
  }

  Future<void> _hydrateRemote() async {
    final gateway = _gateway;
    if (gateway == null) return;
    try {
      final snapshot = await gateway.load(state.case_.caseId);
      if (!mounted || !_isCurrent()) return;
      _revision = snapshot?.revision ?? 0;
      _remoteReady = true;
      if (snapshot != null) {
        final checklist = state.case_.checklist.copyWith(
          items: snapshot.items,
          applicationStatus: state.case_.application.status,
        );
        await _persistLocalOnly(checklist);
        if (!mounted || !_isCurrent()) return;
        state = state.copyWith(
          case_: state.case_.copyWith(checklist: checklist),
          isLoading: false,
          clearError: true,
        );
      } else {
        // Do not auto-overwrite an empty server record with local data.
        // Existing owner-scoped local edits sync on the next explicit save.
        state = state.copyWith(isLoading: false, clearError: true);
      }
    } catch (_) {
      if (!mounted || !_isCurrent()) return;
      _remoteReady = false;
      state = state.copyWith(
        isLoading: false,
        errorMessage:
            'Could not load the server checklist; changes are disabled.',
      );
    }
  }

  Future<void> _persistChecklist(CaseChecklist checklist) async {
    if (!mounted || !_isCurrent() || state.isLoading) {
      throw StateError('Checklist session is not ready.');
    }
    final gateway = _gateway;
    if (gateway != null) {
      if (!_remoteReady) throw StateError('Server checklist is unavailable.');
      final revision = await gateway.save(
        applicationId: state.case_.caseId,
        items: checklist.items,
        expectedRevision: _revision,
      );
      if (!mounted || !_isCurrent()) {
        throw StateError('Checklist session changed during save.');
      }
      _revision = revision;
    } else if (_remoteRequired) {
      throw StateError('Server checklist persistence is required.');
    }
    await _persistLocalOnly(checklist);
  }

  Future<void> setCustomChecklist(List<CaseChecklistItem> items) async {
    if (!mounted || !_isCurrent()) return;
    final nextChecklist = state.case_.checklist.copyWith(items: items);
    // Preserve synchronous local-mode behavior for offline test fixtures.
    if (_gateway == null && !_remoteRequired) {
      state = state.copyWith(
        case_: state.case_.copyWith(checklist: nextChecklist),
        clearError: true,
      );
      await _persistChecklist(nextChecklist);
      return;
    }
    await _persistChecklist(nextChecklist);
    if (!mounted || !_isCurrent()) return;
    state = state.copyWith(
      case_: state.case_.copyWith(checklist: nextChecklist),
      clearError: true,
    );
  }

  Future<void> clearChecklist() => setCustomChecklist(const []);

  Future<bool> transitionChecklistItem(
    String itemId,
    ChecklistItemStatus next, {
    DateTime? nowUtc,
  }) async {
    if (!mounted || state.isTransitioning) return false;
    state = state.copyWith(isTransitioning: true, clearError: true);
    try {
      final updatedCase = _service.transitionChecklistItem(
        case_: state.case_,
        actorUserId: _userId,
        itemId: itemId,
        next: next,
        nowUtc: nowUtc ?? state.now,
      );
      await _persistChecklist(updatedCase.checklist);
      if (!mounted) return false;
      if (!mounted) return false;
      state = state.copyWith(case_: updatedCase, isTransitioning: false);
      return true;
    } on CaseLifecycleException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(errorMessage: e.message, isTransitioning: false);
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: e.toString(),
        isTransitioning: false,
      );
      return false;
    }
  }

  Future<bool> transitionApplicationStatus(
    ApplicationStatus next, {
    DateTime? nowUtc,
  }) async {
    if (!mounted || state.isTransitioning) return false;
    state = state.copyWith(isTransitioning: true, clearError: true);
    try {
      var updatedCase = _service.transitionApplicationStatus(
        case_: state.case_,
        actorUserId: _userId,
        next: next,
        nowUtc: nowUtc ?? state.now,
      );
      await _persistChecklist(updatedCase.checklist);
      if (!mounted) return false;
      if (_appRepository != null) {
        final persisted = await _appRepository.updateApplication(
          updatedCase.application,
        );
        if (persisted.id != updatedCase.application.id ||
            persisted.userId != _userId ||
            persisted.status != next) {
          throw StateError('Application transition was not acknowledged.');
        }
        updatedCase = updatedCase.copyWith(application: persisted);
      } else if (_remoteRequired) {
        throw StateError('Server application persistence is required.');
      }
      if (!mounted || !_isCurrent()) return false;
      state = state.copyWith(case_: updatedCase, isTransitioning: false);
      return true;
    } on CaseLifecycleException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(errorMessage: e.message, isTransitioning: false);
      return false;
    } catch (e) {
      if (!mounted) return false;
      state = state.copyWith(
        errorMessage: e.toString(),
        isTransitioning: false,
      );
      return false;
    }
  }

  Future<void> addChecklistItem({
    required String title,
    String? description,
    DateTime? dueDate,
  }) async {
    final items = List<CaseChecklistItem>.from(state.case_.checklist.items);
    final newItem = CaseChecklistItem(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      description: description,
      dueDate: dueDate,
      sortOrder: items.length + 1,
    );
    items.add(newItem);
    final nextChecklist = state.case_.checklist.copyWith(items: items);
    await _persistChecklist(nextChecklist);
    state = state.copyWith(
      case_: state.case_.copyWith(checklist: nextChecklist),
      clearError: true,
    );
  }

  Future<void> updateItemNote(String itemId, String note) async {
    final items = state.case_.checklist.items.map((i) {
      if (i.id == itemId) {
        return i.copyWith(description: note);
      }
      return i;
    }).toList();
    final nextChecklist = state.case_.checklist.copyWith(items: items);
    await _persistChecklist(nextChecklist);
    state = state.copyWith(
      case_: state.case_.copyWith(checklist: nextChecklist),
      clearError: true,
    );
  }
}
