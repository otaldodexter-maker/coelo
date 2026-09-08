import 'dart:async';

import 'package:coelo_superadmin/features/assessments/assessment.dart';
import 'package:coelo_superadmin/features/assessments/assessment_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('configuration reloads and ignores an older A response after swapping to B', (
    tester,
  ) async {
    final repository = _DelayedConfigurationRepository();

    await tester.pumpWidget(_app(repository, 'activity-a'));
    await tester.pump();
    await tester.pumpWidget(_app(repository, 'activity-b'));
    await tester.pump();

    expect(repository.requests, contains('activity-b'));
    repository.complete('activity-b');
    await tester.pump();
    expect(find.text('activity-b'), findsOneWidget);

    repository.complete('activity-a');
    await tester.pumpAndSettle();
    expect(find.text('activity-b'), findsOneWidget);
    expect(find.text('activity-a'), findsNothing);
  });

  testWidgets('configuration ignores an older save response after swapping from A to B', (
    tester,
  ) async {
    final repository = _DelayedSaveConfigurationRepository();

    await tester.pumpWidget(_app(repository, 'activity-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pump();

    await tester.pumpWidget(_app(repository, 'activity-b'));
    await tester.pumpAndSettle();
    expect(find.text('activity-b'), findsOneWidget);

    repository.pendingSave.complete(_configuration('activity-a', version: 2));
    await tester.pumpAndSettle();
    expect(find.text('activity-b'), findsOneWidget);
    expect(find.text('activity-a'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configuration reenables actions after a successful save', (tester) async {
    final repository = _DelayedSaveConfigurationRepository();

    await tester.pumpWidget(_app(repository, 'activity-a'));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.tap(saveButton);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(saveButton).onPressed, isNull);

    repository.pendingSave.complete(_configuration('activity-a', version: 2));
    await tester.pumpAndSettle();

    expect(tester.widget<OutlinedButton>(saveButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configuration rejects a load outside the requested scope', (tester) async {
    final repository = _DelayedConfigurationRepository();

    await tester.pumpWidget(
      _app(repository, 'activity-a', institutionId: 'institution-a', unitId: 'unit-a'),
    );
    repository.complete(
      'activity-a',
      value: _configuration('activity-b', institutionId: 'institution-b', unitId: 'unit-b'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesso negado'), findsOneWidget);
    expect(find.text('activity-b'), findsNothing);
  });

  testWidgets('configuration rejects a save response outside its scope', (tester) async {
    final repository = _DelayedSaveConfigurationRepository();

    await tester.pumpWidget(_app(repository, 'activity-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar rascunho'));
    await tester.pump();
    repository.pendingSave.complete(_configuration('activity-b', institutionId: 'institution-b'));
    await tester.pumpAndSettle();

    expect(find.text('Você não tem permissão para configurar avaliações.'), findsOneWidget);
    expect(find.text('activity-a'), findsOneWidget);
    expect(find.text('activity-b'), findsNothing);
  });

  testWidgets('configuration rejects an activation response outside its scope', (tester) async {
    final repository = _DelayedActivationConfigurationRepository();

    await tester.pumpWidget(_app(repository, 'activity-a'));
    await tester.pumpAndSettle();
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Ativar configuração'));
    await tester.pump();
    repository.pendingActivation.complete(
      _configuration('activity-b', institutionId: 'institution-b', valid: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Você não tem permissão para configurar avaliações.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(
  AssessmentRepository repository,
  String activityId, {
  String institutionId = 'institution-1',
  String? unitId,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: AssessmentConfigurationPage(
    repository: repository,
    logout: unavailableSuperadminLogout,
    activityId: activityId,
    institutionId: institutionId,
    unitId: unitId,
    onCancel: () {},
  ),
);

AssessmentConfiguration _configuration(
  String activityId, {
  int version = 1,
  String institutionId = 'institution-1',
  String? unitId,
  bool valid = false,
}) => AssessmentConfiguration(
  id: 'configuration-$activityId',
  activityId: activityId,
  institutionId: institutionId,
  unitId: unitId,
  periodicity: 'bimonthly',
  scaleKind: AssessmentScaleKind.numeric0To10,
  version: version,
  status: 'draft',
  instruments: valid
      ? const [AssessmentInstrument(id: 'instrument-1', name: 'Prova', weight: 100, sortOrder: 0)]
      : const [],
  competencies: const [],
  periods: valid
      ? [
          AssessmentConfiguredPeriod(
            id: 'period-1',
            name: '1º bimestre',
            ordinal: 1,
            academicYear: 2027,
            startsOn: DateTime(2027, 1, 1),
            endsOn: DateTime(2027, 3, 31),
            entryClosesAt: DateTime(2027, 4, 1),
            familyReleaseAt: DateTime(2027, 4, 2),
          ),
        ]
      : const [],
);

final class _DelayedConfigurationRepository implements AssessmentRepository {
  final requests = <String, Completer<AssessmentConfiguration?>>{};

  void complete(String activityId, {AssessmentConfiguration? value}) {
    requests[activityId]!.complete(value ?? _configuration(activityId));
  }

  @override
  Future<AssessmentConfiguration?> fetchConfiguration(String activityId, {String? unitId}) =>
      (requests[activityId] ??= Completer<AssessmentConfiguration?>()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DelayedActivationConfigurationRepository implements AssessmentRepository {
  final pendingActivation = Completer<AssessmentConfiguration>();

  @override
  Future<AssessmentConfiguration?> fetchConfiguration(String activityId, {String? unitId}) async =>
      _configuration(activityId, valid: true);

  @override
  Future<AssessmentConfiguration> saveConfiguration(AssessmentConfiguration value) async => value;

  @override
  Future<AssessmentConfiguration> activateConfiguration(AssessmentConfiguration value) =>
      pendingActivation.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DelayedSaveConfigurationRepository implements AssessmentRepository {
  final pendingSave = Completer<AssessmentConfiguration>();

  @override
  Future<AssessmentConfiguration?> fetchConfiguration(String activityId, {String? unitId}) async =>
      _configuration(activityId);

  @override
  Future<AssessmentConfiguration> saveConfiguration(AssessmentConfiguration value) =>
      pendingSave.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
