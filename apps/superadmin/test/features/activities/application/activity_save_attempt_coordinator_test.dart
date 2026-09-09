import 'package:coelo_superadmin/features/activities/application/activity_save_attempt_coordinator.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_profile_about_repository.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_draft.dart';
import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_domain/locations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalogued create rejects About before aggregate even when About is available', () async {
    final commands = _ReceiptActivityCommands();
    final about = _FailOnceAboutRepository();
    await expectLater(
      ActivitySaveAttemptRunner(readAuthorizationRevision: () => 7).save(
        _locationDraft(withAbout: true),
        intent: ActivityCommandIntent.saveDraft,
        activityId: null,
        commandRepository: commands,
        aboutRepository: about,
        buildCommand: _command,
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    expect(commands.saveCalls, 0);
    expect(about.activityIds, isEmpty);
  });
  test('legacy location ID cannot be silently discarded by aggregate save', () async {
    final commands = _ReceiptActivityCommands();
    await expectLater(
      ActivitySaveAttemptRunner(readAuthorizationRevision: () => 7).save(
        _locationDraft(legacy: true),
        intent: ActivityCommandIntent.saveDraft,
        activityId: null,
        commandRepository: commands,
        aboutRepository: const UnavailableActivityProfileAboutRepository(),
        buildCommand: _command,
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    expect(commands.saveCalls, 0);
  });
  for (final unsupported in [
    (ActivityCommandIntent.publish, null),
    (ActivityCommandIntent.saveDraft, 'existing'),
  ]) {
    test(
      'catalogued create rejects unsupported intent or edit $unsupported before write',
      () async {
        final commands = _ReceiptActivityCommands();
        await expectLater(
          ActivitySaveAttemptRunner(readAuthorizationRevision: () => 7).save(
            _locationDraft(),
            intent: unsupported.$1,
            activityId: unsupported.$2,
            commandRepository: commands,
            aboutRepository: const UnavailableActivityProfileAboutRepository(),
            buildCommand: _command,
          ),
          throwsA(isA<ActivityCommandUnavailableException>()),
        );
        expect(commands.saveCalls, 0);
      },
    );
  }
  test('builder cannot drop a catalog selection', () async {
    final commands = _ReceiptActivityCommands();
    await expectLater(
      ActivitySaveAttemptRunner(readAuthorizationRevision: () => 7).save(
        _locationDraft(),
        intent: ActivityCommandIntent.saveDraft,
        activityId: null,
        commandRepository: commands,
        aboutRepository: const UnavailableActivityProfileAboutRepository(),
        buildCommand: (draft, {required requestId, required intent, required activityId}) =>
            _command(_draft, requestId: requestId, intent: intent, activityId: activityId),
      ),
      throwsA(isA<ActivityCommandUnavailableException>()),
    );
    expect(commands.saveCalls, 0);
  });
  test('catalogued create retries the same aggregate request without About followup', () async {
    final commands = _ReceiptActivityCommands(throwAfterFirstCommit: true);
    final runner = ActivitySaveAttemptRunner(readAuthorizationRevision: () => 7);
    Future<void> save() => runner.save(
      _locationDraft(),
      intent: ActivityCommandIntent.saveDraft,
      activityId: null,
      commandRepository: commands,
      aboutRepository: const UnavailableActivityProfileAboutRepository(),
      buildCommand: _command,
    );
    await expectLater(save(), throwsA(isA<_AmbiguousResponse>()));
    await save();
    expect(commands.requestIds, ['request-form-1', 'request-form-1']);
    expect(commands.createdActivityIds, {'activity-1'});
  });

  test('retries an ambiguous primary save under the same server request', () async {
    final coordinator = ActivitySaveAttemptCoordinator();
    var calls = 0;
    final storedIds = <String>{};

    Future<String> primary() async {
      calls++;
      storedIds.add('activity-1');
      if (calls == 1) throw const _AmbiguousResponse();
      return 'activity-1';
    }

    await expectLater(
      coordinator.run(
        requestId: 'request-1',
        fingerprint: 'draft-1',
        intent: ActivityCommandIntent.saveDraft,
        readAuthorizationRevision: () => 3,
        saveActivity: primary,
        saveFollowUp: (_) async {},
      ),
      throwsA(isA<_AmbiguousResponse>()),
    );
    final result = await coordinator.run(
      requestId: 'request-1',
      fingerprint: 'draft-1',
      intent: ActivityCommandIntent.saveDraft,
      readAuthorizationRevision: () => 3,
      saveActivity: primary,
      saveFollowUp: (_) async {},
    );

    expect(result, 'activity-1');
    expect(calls, 2);
    expect(storedIds, {'activity-1'});
  });

  test('keeps the primary result while retrying a failed follow-up', () async {
    final coordinator = ActivitySaveAttemptCoordinator();
    var primaryCalls = 0;
    var followUpCalls = 0;

    Future<String> primary() async {
      primaryCalls++;
      return 'activity-1';
    }

    Future<void> followUp(String activityId) async {
      followUpCalls++;
      expect(activityId, 'activity-1');
      if (followUpCalls == 1) throw const _FollowUpFailure();
    }

    await expectLater(
      coordinator.run(
        requestId: 'request-2',
        fingerprint: 'draft-2',
        intent: ActivityCommandIntent.saveDraft,
        readAuthorizationRevision: () => 3,
        saveActivity: primary,
        saveFollowUp: followUp,
      ),
      throwsA(isA<_FollowUpFailure>()),
    );
    final result = await coordinator.run(
      requestId: 'request-2',
      fingerprint: 'draft-2',
      intent: ActivityCommandIntent.saveDraft,
      readAuthorizationRevision: () => 3,
      saveActivity: primary,
      saveFollowUp: followUp,
    );

    expect(result, 'activity-1');
    expect(primaryCalls, 1);
    expect(followUpCalls, 2);
  });

  test('never carries a pending attempt into another authorization revision', () async {
    final coordinator = ActivitySaveAttemptCoordinator();
    var primaryCalls = 0;

    await expectLater(
      coordinator.run(
        requestId: 'request-3',
        fingerprint: 'draft-3',
        intent: ActivityCommandIntent.saveDraft,
        readAuthorizationRevision: () => 3,
        saveActivity: () async {
          primaryCalls++;
          return 'activity-1';
        },
        saveFollowUp: (_) async => throw const _FollowUpFailure(),
      ),
      throwsA(isA<_FollowUpFailure>()),
    );
    await expectLater(
      coordinator.run(
        requestId: 'request-3',
        fingerprint: 'draft-3',
        intent: ActivityCommandIntent.saveDraft,
        readAuthorizationRevision: () => 4,
        saveActivity: () async {
          primaryCalls++;
          return 'activity-2';
        },
        saveFollowUp: (_) async {},
      ),
      throwsA(isA<ActivitySaveAttemptInvalidatedException>()),
    );
    expect(primaryCalls, 1);
  });

  test('revalidates current authorization after the primary await', () async {
    final coordinator = ActivitySaveAttemptCoordinator();
    var revision = 3;
    var followUpCalls = 0;

    await expectLater(
      coordinator.run(
        requestId: 'request-4',
        fingerprint: 'draft-4',
        intent: ActivityCommandIntent.saveDraft,
        readAuthorizationRevision: () => revision,
        saveActivity: () async {
          revision = 4;
          return 'activity-1';
        },
        saveFollowUp: (_) async => followUpCalls++,
      ),
      throwsA(isA<ActivitySaveAttemptInvalidatedException>()),
    );
    expect(followUpCalls, 0);
  });

  test('revalidates current authorization after the follow-up await', () async {
    final coordinator = ActivitySaveAttemptCoordinator();
    var revision = 3;

    await expectLater(
      coordinator.run(
        requestId: 'request-5',
        fingerprint: 'draft-5',
        intent: ActivityCommandIntent.saveDraft,
        readAuthorizationRevision: () => revision,
        saveActivity: () async => 'activity-1',
        saveFollowUp: (_) async => revision = 4,
      ),
      throwsA(isA<ActivitySaveAttemptInvalidatedException>()),
    );
  });

  test('real activity callback replays one request after an ambiguous response', () async {
    final commands = _ReceiptActivityCommands(throwAfterFirstCommit: true);
    final runner = ActivitySaveAttemptRunner(readAuthorizationRevision: () => 7);

    await expectLater(
      runner.save(
        _draft,
        intent: ActivityCommandIntent.saveDraft,
        activityId: null,
        commandRepository: commands,
        aboutRepository: const UnavailableActivityProfileAboutRepository(),
        buildCommand: _command,
      ),
      throwsA(isA<_AmbiguousResponse>()),
    );
    await runner.save(
      _draft,
      intent: ActivityCommandIntent.saveDraft,
      activityId: null,
      commandRepository: commands,
      aboutRepository: const UnavailableActivityProfileAboutRepository(),
      buildCommand: _command,
    );

    expect(commands.requestIds, ['request-form-1', 'request-form-1']);
    expect(commands.createdActivityIds, {'activity-1'});
  });

  test('real activity callback keeps the aggregate id while About retries', () async {
    final commands = _ReceiptActivityCommands();
    final about = _FailOnceAboutRepository();
    final runner = ActivitySaveAttemptRunner(readAuthorizationRevision: () => 7);
    final draft = _draftWithAbout();

    await expectLater(
      runner.save(
        draft,
        intent: ActivityCommandIntent.saveDraft,
        activityId: null,
        commandRepository: commands,
        aboutRepository: about,
        buildCommand: _command,
      ),
      throwsA(isA<_FollowUpFailure>()),
    );
    await runner.save(
      draft,
      intent: ActivityCommandIntent.saveDraft,
      activityId: null,
      commandRepository: commands,
      aboutRepository: about,
      buildCommand: _command,
    );

    expect(commands.saveCalls, 1);
    expect(commands.createdActivityIds, {'activity-1'});
    expect(about.activityIds, ['activity-1', 'activity-1']);
    expect(about.requestIds, ['request-form-1', 'request-form-1']);
  });

  test('real activity callback rejects a changed draft after the aggregate completed', () async {
    final commands = _ReceiptActivityCommands();
    final about = _FailOnceAboutRepository();
    final runner = ActivitySaveAttemptRunner(readAuthorizationRevision: () => 7);

    await expectLater(
      runner.save(
        _draftWithAbout(),
        intent: ActivityCommandIntent.saveDraft,
        activityId: null,
        commandRepository: commands,
        aboutRepository: about,
        buildCommand: _command,
      ),
      throwsA(isA<_FollowUpFailure>()),
    );
    await expectLater(
      runner.save(
        _draftWithAbout(name: 'Outro nome', signature: 'draft-form-changed'),
        intent: ActivityCommandIntent.saveDraft,
        activityId: null,
        commandRepository: commands,
        aboutRepository: about,
        buildCommand: _command,
      ),
      throwsA(isA<ActivitySaveAttemptInvalidatedException>()),
    );

    expect(commands.saveCalls, 1);
    expect(about.activityIds, ['activity-1']);
  });
}

final class _AmbiguousResponse implements Exception {
  const _AmbiguousResponse();
}

final class _FollowUpFailure implements Exception {
  const _FollowUpFailure();
}

const _draft = ActivityFormDraft(
  requestId: 'request-form-1',
  commandSignature: 'draft-form-1',
  name: 'Robótica',
  description: '',
  taxonomy: null,
  subtype: null,
  template: null,
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: 'institution-1',
  unitIds: {'unit-1'},
  groupIds: {},
  assignments: [],
);

ActivityFormDraft _draftWithAbout({String? name, String? signature}) => ActivityFormDraft(
  requestId: _draft.requestId,
  commandSignature: signature ?? _draft.commandSignature,
  name: name ?? _draft.name,
  description: _draft.description,
  taxonomy: null,
  subtype: null,
  template: null,
  taxonomyOtherDescription: '',
  governance: ActivityGovernance.optional,
  institutionId: _draft.institutionId,
  unitIds: _draft.unitIds,
  groupIds: const {},
  assignments: const [],
  aboutPage: ProfileAboutPage.empty(
    const ProfileAboutSubjectRef(
      type: ProfileAboutSubjectType.activity,
      institutionId: 'institution-1',
      activityId: 'activity-1',
    ),
  ),
);

ActivitySaveCommand _command(
  ActivityFormDraft draft, {
  required String requestId,
  required ActivityCommandIntent intent,
  required String? activityId,
}) => ActivitySaveCommand(
  requestId: requestId,
  intent: intent,
  activityId: activityId,
  name: draft.name,
  description: draft.description,
  taxonomyId: 'taxonomy-1',
  taxonomyOtherDescription: '',
  governance: draft.governance,
  institutionId: draft.institutionId,
  unitIds: draft.unitIds,
  groupIds: draft.groupIds,
  locationSelection: draft.locationSelection,
  reservation: draft.reservation,
  assignments: const [],
  identity: const ActivityCommandIdentity(
    kind: ActivityIdentityKind.initials,
    initials: 'RO',
    color: '#D63C00',
    icon: 'activity',
  ),
);

final class _ReceiptActivityCommands implements ActivityCommandRepository {
  _ReceiptActivityCommands({this.throwAfterFirstCommit = false});

  final bool throwAfterFirstCommit;
  final Map<String, ActivitySaveResult> _receipts = {};
  final List<String> requestIds = [];
  int saveCalls = 0;

  Set<String> get createdActivityIds => _receipts.values.map((value) => value.activityId).toSet();

  @override
  Future<ActivitySaveResult> save(ActivitySaveCommand command) async {
    saveCalls++;
    requestIds.add(command.requestId);
    final existed = _receipts.containsKey(command.requestId);
    final result = _receipts.putIfAbsent(
      command.requestId,
      () => const ActivitySaveResult(
        activityId: 'activity-1',
        managementVersion: 1,
        status: ActivityStatus.draft,
      ),
    );
    if (!existed && throwAfterFirstCommit) throw const _AmbiguousResponse();
    return result;
  }

  Future<T> _unavailable<T>() => Future.error(const ActivityCommandUnavailableException());

  @override
  Future<ActivityTemplateCopyResult> copyTemplate(ActivityTemplateCopyCommand command) =>
      _unavailable();

  @override
  Future<List<ActivityLocationResult>> createLocations(ActivityLocationCommand command) =>
      _unavailable();

  @override
  Future<ActivityTemplateCreateResult> createTemplate(ActivityTemplateCreateCommand command) =>
      _unavailable();

  @override
  Future<ActivityExportResult> requestExport(
    ActivityDirectoryQuery query, {
    required ActivityCommandExportFormat format,
  }) => _unavailable();
}

final class _FailOnceAboutRepository implements ActivityProfileAboutRepository {
  final List<String> activityIds = [];
  final List<String> requestIds = [];

  @override
  bool get isAvailable => true;

  @override
  Future<ProfileAboutPage> load({required String institutionId, String? activityId}) =>
      throw UnimplementedError();

  @override
  Future<ProfileAboutPage> save({
    required ProfileAboutPage page,
    required String institutionId,
    required String activityId,
    required String requestId,
  }) async {
    activityIds.add(activityId);
    requestIds.add(requestId);
    if (activityIds.length == 1) throw const _FollowUpFailure();
    return page;
  }
}

ActivityFormDraft _locationDraft({bool withAbout = false, bool legacy = false}) =>
    ActivityFormDraft(
      requestId: _draft.requestId,
      commandSignature: _draft.commandSignature,
      name: _draft.name,
      description: _draft.description,
      taxonomy: null,
      subtype: null,
      template: null,
      taxonomyOtherDescription: '',
      governance: _draft.governance,
      institutionId: _draft.institutionId,
      unitIds: _draft.unitIds,
      groupIds: const {},
      assignments: const [],
      locationId: 'location-1',
      locationSelection: legacy
          ? null
          : const CataloguedLocationSelection(
              LocationReferenceSnapshot(
                id: 'location-1',
                scope: LocationScope.institution(institutionId: 'institution-1'),
                kind: LocationKind.internal,
                label: 'Local',
              ),
            ),
      aboutPage: withAbout ? _draftWithAbout().aboutPage : null,
    );
