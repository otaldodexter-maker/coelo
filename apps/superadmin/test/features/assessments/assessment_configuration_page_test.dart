import 'dart:async';

import 'package:coelo_superadmin/features/assessments/assessment.dart';
import 'package:coelo_superadmin/features/assessments/assessment_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('periodicity has capsule trigger and empty periods have a token gap', (tester) async {
    final repository = _DelayedSaveConfigurationRepository();
    await tester.pumpWidget(_app(repository, 'activity-a'));
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (w) => w is CoeloAdminSingleSelectField<String> && w.label == 'Periodicidade',
    );
    expect(tester.widget<CoeloAdminSingleSelectField<String>>(field).isFilter, isTrue);
    final add = find.widgetWithText(OutlinedButton, 'Adicionar período');
    final empty = find.byWidgetPredicate(
      (w) => w is CoeloStatePanel && w.title == 'Nenhum período avaliativo',
    );
    expect(tester.getTopLeft(empty).dy - tester.getBottomLeft(add).dy, CoeloSpacing.space4);
    expect(tester.takeException(), isNull);
  });
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

  testWidgets('configuration recovers when saving throws an Error', (tester) async {
    final repository = _DelayedSaveConfigurationRepository();

    await tester.pumpWidget(_app(repository, 'activity-a'));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(OutlinedButton, 'Salvar rascunho');
    await tester.tap(saveButton);
    await tester.pump();
    repository.pendingSave.completeError(AssertionError('invalid response'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível salvar. Tente novamente.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(saveButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(AssessmentRepository repository, String activityId) => MaterialApp(
  theme: CoeloTheme.light,
  home: AssessmentConfigurationPage(
    repository: repository,
    logout: unavailableSuperadminLogout,
    activityId: activityId,
    institutionId: 'institution-1',
    onCancel: () {},
  ),
);

AssessmentConfiguration _configuration(String activityId, {int version = 1}) =>
    AssessmentConfiguration(
      id: 'configuration-$activityId',
      activityId: activityId,
      institutionId: 'institution-1',
      periodicity: 'bimonthly',
      scaleKind: AssessmentScaleKind.numeric0To10,
      version: version,
      status: 'draft',
      instruments: const [],
      competencies: const [],
    );

final class _DelayedConfigurationRepository implements AssessmentRepository {
  final requests = <String, Completer<AssessmentConfiguration?>>{};

  void complete(String activityId) {
    requests[activityId]!.complete(_configuration(activityId));
  }

  @override
  Future<AssessmentConfiguration?> fetchConfiguration(String activityId, {String? unitId}) =>
      (requests[activityId] ??= Completer<AssessmentConfiguration?>()).future;

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
