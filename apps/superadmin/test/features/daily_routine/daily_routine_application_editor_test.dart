import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_form_sections.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new model save unlocks after the repository returns its created id', (tester) async {
    final repository = _RoutineRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(repository: repository, logout: unavailableSuperadminLogout),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('daily-routine-name')), 'Modelo criado');
    await tester.enterText(find.byKey(const Key('daily-routine-model-institution')), 'institution');
    await tester.tap(find.byKey(const Key('daily-routine-save')));
    await tester.pumpAndSettle();

    expect(repository.savedModel?.name, 'Modelo criado');
    final saveAgain = tester
        .widget<FilledButton>(find.byKey(const Key('daily-routine-save')))
        .onPressed;
    expect(saveAgain, isNotNull);
    expect(find.text('Salvando...'), findsNothing);
    saveAgain!();
    await tester.pumpAndSettle();
    expect(repository.savedModel?.id, 'created-model');
  });

  testWidgets('new application save unlocks after the repository returns its created id', (
    tester,
  ) async {
    final repository = _RoutineRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryKind: RoutineEntryKind.application,
          applicationFromModelId: 'source-model',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('daily-routine-application-save')));
    await tester.pumpAndSettle();

    expect(repository.savedApplication?.modelVersionId, 'source-model:v1');
    final saveAgain = tester
        .widget<FilledButton>(find.byKey(const Key('daily-routine-application-save')))
        .onPressed;
    expect(saveAgain, isNotNull);
    expect(find.text('Salvando...'), findsNothing);
    saveAgain!();
    await tester.pumpAndSettle();
    expect(repository.savedApplication?.id, 'created-application');
  });

  testWidgets('ignores a late application load after the editor context changes', (tester) async {
    final repository = _DelayedRoutineRepository();

    Future<void> pumpEditor(String entryId) => tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryId: entryId,
          entryKind: RoutineEntryKind.application,
        ),
      ),
    );

    await pumpEditor('application-a');
    await pumpEditor('application-b');

    repository.complete('application-b', startsAt: '10:00');
    await tester.pump();
    expect(
      tester
          .widget<CoeloFormTextField>(find.byKey(const Key('daily-routine-application-starts-at')))
          .controller
          .text,
      '10:00',
    );

    repository.complete('application-a', startsAt: '08:00');
    await tester.pump();
    expect(
      tester
          .widget<CoeloFormTextField>(find.byKey(const Key('daily-routine-application-starts-at')))
          .controller
          .text,
      '10:00',
    );
  });

  testWidgets('distinct equal repositories still replace the editor context', (tester) async {
    final repositoryA = _EqualDelayedRoutineRepository();
    final repositoryB = _EqualDelayedRoutineRepository();

    Widget editor(_EqualDelayedRoutineRepository repository) => MaterialApp(
      theme: CoeloTheme.light,
      home: DailyRoutineWizardPage(
        repository: repository,
        logout: unavailableSuperadminLogout,
        entryId: 'application-id',
        entryKind: RoutineEntryKind.application,
      ),
    );

    await tester.pumpWidget(editor(repositoryA));
    await tester.pumpWidget(editor(repositoryB));
    expect(repositoryB.fetchCount, 1);

    repositoryB.complete(startsAt: '10:00');
    await tester.pump();
    repositoryA.complete(startsAt: '08:00');
    await tester.pump();

    expect(
      tester
          .widget<CoeloFormTextField>(find.byKey(const Key('daily-routine-application-starts-at')))
          .controller
          .text,
      '10:00',
    );
  });

  for (final kind in [RoutineEntryKind.model, RoutineEntryKind.application]) {
    testWidgets('rejects a mismatched id returned while editing ${kind.name}', (tester) async {
      final repository = _TamperedRoutineRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: DailyRoutineWizardPage(
            repository: repository,
            logout: unavailableSuperadminLogout,
            entryId: kind == RoutineEntryKind.model ? 'model-id' : 'application-id',
            entryKind: kind,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          kind == RoutineEntryKind.model
              ? const Key('daily-routine-save')
              : const Key('daily-routine-application-save'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          kind == RoutineEntryKind.model
              ? 'O modelo salvo não corresponde ao solicitado.'
              : 'A rotina aplicada salva não corresponde à solicitada.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(kind == RoutineEntryKind.model ? 'Modelo salvo.' : 'Rotina aplicada salva.'),
        findsNothing,
      );
    });
  }

  testWidgets('fails closed when an application load returns another id', (tester) async {
    final repository = _TamperedRoutineRepository(tamperLoad: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryId: 'application-id',
          entryKind: RoutineEntryKind.application,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-application-editor')), findsNothing);
    expect(find.text('A rotina aplicada solicitada não pôde ser validada.'), findsOneWidget);
  });

  testWidgets('fails closed when applying a model returned for another id', (tester) async {
    final repository = _TamperedRoutineRepository(tamperLoad: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryKind: RoutineEntryKind.application,
          applicationFromModelId: 'source-model',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-application-editor')), findsNothing);
    expect(find.text('O modelo de origem não pôde ser validado.'), findsOneWidget);
  });

  testWidgets('does not surface application creation without an authorized context', (
    tester,
  ) async {
    final repository = _RoutineRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryKind: RoutineEntryKind.application,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-application-editor')), findsNothing);
    expect(
      find.text('Crie uma rotina aplicada a partir de um contexto autorizado.'),
      findsOneWidget,
    );
  });

  testWidgets('reverts a customized application through the repository', (tester) async {
    final repository = _RoutineRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryId: 'application-id',
          entryKind: RoutineEntryKind.application,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reset = find.byKey(const Key('daily-routine-inheritance-reset'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();

    expect(repository.revertedApplicationId, 'application-id');
  });

  testWidgets('persists the newly selected inheritance mode', (tester) async {
    final repository = _RoutineRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryId: 'application-id',
          entryKind: RoutineEntryKind.application,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('daily-routine-inheritance-toggle')));
    await tester.pumpAndSettle();

    expect(repository.savedApplication?.inheritanceMode, RoutineInheritanceMode.inherited);
  });

  testWidgets('renders scheduled fields and never exposes raw scope identifiers', (tester) async {
    final repository = _RoutineRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryId: 'application-id',
          entryKind: RoutineEntryKind.application,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-application-starts-at')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-application-ends-at')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-application-model-version')), findsNothing);
    expect(find.textContaining('00000000-0000'), findsNothing);
  });
}

class _RoutineRepository implements RoutineRepository {
  RoutineModel? savedModel;
  RoutineApplication? savedApplication;
  String? revertedApplicationId;

  @override
  Future<RoutineApplication> fetchApplication(String id) async => RoutineApplication(
    id: id,
    modelVersionId: 'model-version',
    institutionId: 'institution',
    status: RoutineApplicationStatus.active,
    inheritanceMode: RoutineInheritanceMode.customized,
    effectiveVersion: 3,
    expectedVersion: 2,
    startsAt: '08:00',
    endsAt: '12:00',
    assignees: [
      RoutineApplicationAssignee(
        membershipId: '00000000-0000-4000-8000-000000000015',
        responsibility: RoutineApplicationResponsibility.publish,
      ),
    ],
    canManage: true,
  );

  @override
  Future<String> saveApplication(
    RoutineApplication application, {
    required String requestId,
  }) async {
    savedApplication = application;
    return application.id.isEmpty ? 'created-application' : application.id;
  }

  @override
  Future<String> revertApplicationCustomization({
    required String applicationId,
    required int expectedVersion,
    required String requestId,
  }) async {
    revertedApplicationId = applicationId;
    return applicationId;
  }

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) async => RoutineDirectoryPage(
    items: const [],
    page: query.page,
    pageSize: query.pageSize,
    totalCount: 0,
    canManage: true,
  );
  @override
  Future<RoutineModel> fetchModel(String id) async => RoutineModel(
    id: id,
    name: 'Modelo de origem',
    description: '',
    version: 1,
    status: RoutineModelStatus.active,
    sections: const [],
    expectedVersion: 1,
    institutionId: 'institution',
    canManage: true,
  );
  @override
  Future<RoutineLaunch> fetchLaunch(String id) async => throw UnimplementedError();
  @override
  Future<String> saveModel(RoutineModel model, {required String requestId}) async {
    savedModel = model;
    return model.id.isEmpty ? 'created-model' : model.id;
  }

  @override
  Future<String> saveLaunchDraft(RoutineLaunch launch, {required String requestId}) async =>
      throw UnimplementedError();
  @override
  Future<void> publishLaunch({
    required String launchId,
    required int expectedVersion,
    required String requestId,
  }) async => throw UnimplementedError();
  @override
  Future<void> correctLaunch({
    required String launchId,
    required int expectedVersion,
    required String reason,
    required String requestId,
    required List<RoutineAnswerCorrection> corrections,
  }) async => throw UnimplementedError();
}

final class _DelayedRoutineRepository extends _RoutineRepository {
  final _requests = <String, Completer<RoutineApplication>>{};

  @override
  Future<RoutineApplication> fetchApplication(String id) =>
      _requests.putIfAbsent(id, Completer<RoutineApplication>.new).future;

  void complete(String id, {required String startsAt}) {
    _requests[id]!.complete(
      RoutineApplication(
        id: id,
        modelVersionId: 'model-version-$id',
        institutionId: 'institution-$id',
        status: RoutineApplicationStatus.draft,
        inheritanceMode: RoutineInheritanceMode.inherited,
        effectiveVersion: 1,
        expectedVersion: 0,
        startsAt: startsAt,
        canManage: true,
      ),
    );
  }
}

final class _EqualDelayedRoutineRepository extends _RoutineRepository {
  final _request = Completer<RoutineApplication>();
  var fetchCount = 0;

  @override
  Future<RoutineApplication> fetchApplication(String id) {
    fetchCount += 1;
    return _request.future;
  }

  void complete({required String startsAt}) {
    _request.complete(
      RoutineApplication(
        id: 'application-id',
        modelVersionId: 'model-version',
        institutionId: 'institution',
        status: RoutineApplicationStatus.draft,
        inheritanceMode: RoutineInheritanceMode.inherited,
        effectiveVersion: 1,
        expectedVersion: 0,
        startsAt: startsAt,
        canManage: true,
      ),
    );
  }

  @override
  bool operator ==(Object other) => other is _EqualDelayedRoutineRepository;

  @override
  int get hashCode => 1;
}

final class _TamperedRoutineRepository extends _RoutineRepository {
  _TamperedRoutineRepository({this.tamperLoad = false});

  final bool tamperLoad;

  @override
  Future<RoutineApplication> fetchApplication(String id) =>
      super.fetchApplication(tamperLoad ? 'another-application' : id);

  @override
  Future<RoutineModel> fetchModel(String id) => super.fetchModel(tamperLoad ? 'another-model' : id);

  @override
  Future<String> saveApplication(
    RoutineApplication application, {
    required String requestId,
  }) async => 'another-application';

  @override
  Future<String> saveModel(RoutineModel model, {required String requestId}) async =>
      'another-model';
}
