import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
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
  final now = clock ?? DateTime.now().toUtc();
  return [
    CaseChecklistItem(
      id: '${app.id}_doc_passport',
      title: 'Valid Passport & Identity Documents',
      description: 'Original biometric passport valid for at least 6 months beyond travel.',
      status: ChecklistItemStatus.inProgress,
      sortOrder: 1,
      dueDate: now.add(const Duration(days: 7)),
    ),
    CaseChecklistItem(
      id: '${app.id}_doc_language',
      title: 'Language Proficiency Certificate',
      description: 'Official test score (IELTS, TOEFL, TEF, or TestDaF) meeting requirements.',
      status: ChecklistItemStatus.notStarted,
      sortOrder: 2,
      dueDate: now.add(const Duration(days: 14)),
    ),
    CaseChecklistItem(
      id: '${app.id}_doc_evaluation',
      title: 'Educational Credential Assessment (ECA)',
      description: 'Verified equivalency of academic degrees from certified credential evaluation service.',
      status: ChecklistItemStatus.notStarted,
      sortOrder: 3,
      dueDate: now.add(const Duration(days: 21)),
    ),
    CaseChecklistItem(
      id: '${app.id}_doc_funds',
      title: 'Proof of Financial Sufficiency & Bank Statement',
      description:
          'Official bank statements showing sufficient funds for settlement.',
      status: ChecklistItemStatus.notStarted,
      sortOrder: 4,
      dueDate: now.add(const Duration(days: 30)),
    ),
    CaseChecklistItem(
      id: '${app.id}_stage_biometrics',
      title: 'Biometrics & Visa Application Center Appointment',
      description:
          'Schedule fingerprinting and photograph at designated VAC center.',
      status: ChecklistItemStatus.notStarted,
      sortOrder: 5,
      dueDate: now.add(const Duration(days: 45)),
    ),
  ];
}

final caseTrackerControllerProvider = StateNotifierProvider.autoDispose
    .family<CaseTrackerController, CaseTrackerState, VisaApplication>((
      ref,
      app,
    ) {
      final prefs = ref.watch(sharedPreferencesProvider);
      final session = ref.watch(authControllerProvider).valueOrNull;
      // Storage isolation: only an authenticated session may select a user
      // scoped checklist key. Never trust a stale unauthenticated userId or
      // fall back to the application owner after logout (cross-session leak).
      final sessionUser = session?.userId?.trim();
      final userId =
          (session?.isAuthenticated == true &&
              sessionUser != null &&
              sessionUser.isNotEmpty)
          ? sessionUser
          : 'guest';
      final appRepo = ref.watch(applicationRepositoryProvider);
      return CaseTrackerController(
        initialApp: app,
        userId: userId,
        prefs: prefs,
        appRepository: appRepo,
      );
    });

class CaseTrackerController extends StateNotifier<CaseTrackerState> {
  CaseTrackerController({
    required VisaApplication initialApp,
    required this._userId,
    required this._prefs,
    this._appRepository,
    this._service = const CaseLifecycleService(),
    DateTime? nowUtc,
  }) : super(
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
  final CaseLifecycleService _service;

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
            _persistChecklist(loadedChecklist);
            _prefs.remove(_legacyStorageKey);
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
        _persistChecklist(checklist);
      }

      state = state.copyWith(
        case_: state.case_.copyWith(
          checklist: checklist,
          application: state.case_.application.copyWith(
            status: checklist.applicationStatus,
          ),
        ),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load case checklist: $e',
      );
    }
  }

  Future<void> _persistChecklist(CaseChecklist checklist) async {
    final payload = checklist.toJson();
    payload['userId'] = _effectiveUserId;
    final encoded = jsonEncode(payload);
    await _prefs.setString(_scopedStorageKey, encoded);
  }

  void setCustomChecklist(List<CaseChecklistItem> items) {
    final nextChecklist = state.case_.checklist.copyWith(items: items);
    _persistChecklist(nextChecklist);
    state = state.copyWith(
      case_: state.case_.copyWith(checklist: nextChecklist),
      clearError: true,
    );
  }

  void clearChecklist() {
    setCustomChecklist(const []);
  }

  Future<bool> transitionChecklistItem(
    String itemId,
    ChecklistItemStatus next, {
    DateTime? nowUtc,
  }) async {
    if (state.isTransitioning) return false;
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
      state = state.copyWith(case_: updatedCase, isTransitioning: false);
      return true;
    } on CaseLifecycleException catch (e) {
      state = state.copyWith(errorMessage: e.message, isTransitioning: false);
      return false;
    } catch (e) {
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
    if (state.isTransitioning) return false;
    state = state.copyWith(isTransitioning: true, clearError: true);
    try {
      final updatedCase = _service.transitionApplicationStatus(
        case_: state.case_,
        actorUserId: _userId,
        next: next,
        nowUtc: nowUtc ?? state.now,
      );
      await _persistChecklist(updatedCase.checklist);
      if (_appRepository != null) {
        await _appRepository.updateApplication(updatedCase.application);
      }
      state = state.copyWith(case_: updatedCase, isTransitioning: false);
      return true;
    } on CaseLifecycleException catch (e) {
      state = state.copyWith(errorMessage: e.message, isTransitioning: false);
      return false;
    } catch (e) {
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
