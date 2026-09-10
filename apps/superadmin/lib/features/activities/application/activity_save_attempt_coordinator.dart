import 'dart:convert';

import '../domain/activity_command.dart';
import '../domain/activity_profile_about_repository.dart';
import '../presentation/activity_form_draft.dart';

typedef ActivitySaveCommandBuilder =
    ActivitySaveCommand Function(
      ActivityFormDraft draft, {
      required String requestId,
      required ActivityCommandIntent intent,
      required String? activityId,
    });

final class ActivitySaveAttemptRunner {
  ActivitySaveAttemptRunner({required int Function() readAuthorizationRevision})
    : _readAuthorizationRevision = readAuthorizationRevision;

  final int Function() _readAuthorizationRevision;
  final ActivitySaveAttemptCoordinator _coordinator = ActivitySaveAttemptCoordinator();

  Future<void> save(
    ActivityFormDraft draft, {
    required ActivityCommandIntent intent,
    required String? activityId,
    required ActivityCommandRepository commandRepository,
    required ActivityProfileAboutRepository aboutRepository,
    required ActivitySaveCommandBuilder buildCommand,
  }) async {
    final aboutPage = draft.aboutPage;
    final selection = draft.locationSelection;
    if ((draft.locationId != null && selection == null) ||
        (draft.reservation != null && selection == null) ||
        (selection != null &&
            (aboutPage != null ||
                activityId != null ||
                intent != ActivityCommandIntent.saveDraft ||
                draft.locationId != null && draft.locationId != selection.snapshot.id))) {
      throw const ActivityCommandUnavailableException();
    }
    if (aboutPage != null && !aboutRepository.isAvailable) {
      throw const ActivityProfileAboutUnavailableException();
    }
    final requestId = draft.requestId;
    final fingerprint = draft.commandSignature;
    if (requestId == null || fingerprint == null) {
      throw const ActivityCommandUnavailableException();
    }
    final command = buildCommand(
      draft,
      requestId: requestId,
      intent: intent,
      activityId: activityId,
    );
    if (command.locationSelection?.snapshot.id != selection?.snapshot.id ||
        jsonEncode(command.reservation?.toJson()) != jsonEncode(draft.reservation?.toJson())) {
      throw const ActivityCommandUnavailableException();
    }
    await _coordinator.run<ActivitySaveResult>(
      requestId: requestId,
      fingerprint: fingerprint,
      intent: intent,
      readAuthorizationRevision: _readAuthorizationRevision,
      saveActivity: () => commandRepository.save(command),
      saveFollowUp: (result) async {
        if (aboutPage == null) return;
        await aboutRepository.save(
          page: aboutPage,
          institutionId: draft.institutionId,
          activityId: result.activityId,
          requestId: requestId,
        );
      },
    );
  }
}

/// Keeps one activity form attempt stable across ambiguous transport and
/// post-save failures. The coordinator is scoped to one router instance.
final class ActivitySaveAttemptCoordinator {
  final Map<String, _PendingActivitySave> _pending = {};

  Future<T> run<T>({
    required String requestId,
    required String fingerprint,
    required ActivityCommandIntent intent,
    required int Function() readAuthorizationRevision,
    required Future<T> Function() saveActivity,
    required Future<void> Function(T result) saveFollowUp,
  }) async {
    final authorizationRevision = readAuthorizationRevision();
    final pending = _pending.putIfAbsent(
      requestId,
      () => _PendingActivitySave(authorizationRevision, fingerprint, intent),
    );
    if (pending.authorizationRevision != authorizationRevision ||
        pending.fingerprint != fingerprint ||
        pending.intent != intent) {
      throw const ActivitySaveAttemptInvalidatedException();
    }

    var result = pending.result;
    if (result == null) {
      result = await saveActivity();
      pending.result = result;
    }
    _requireCurrentAuthorization(pending, readAuthorizationRevision());
    final typedResult = result as T;
    await saveFollowUp(typedResult);
    _requireCurrentAuthorization(pending, readAuthorizationRevision());
    _pending.remove(requestId);
    return typedResult;
  }

  void _requireCurrentAuthorization(_PendingActivitySave pending, int currentRevision) {
    if (pending.authorizationRevision != currentRevision) {
      throw const ActivitySaveAttemptInvalidatedException();
    }
  }
}

final class ActivitySaveAttemptInvalidatedException implements Exception {
  const ActivitySaveAttemptInvalidatedException();
}

final class _PendingActivitySave {
  _PendingActivitySave(this.authorizationRevision, this.fingerprint, this.intent);

  final int authorizationRevision;
  final String fingerprint;
  final ActivityCommandIntent intent;
  Object? result;
}
