import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import '../support/health_care_fixture_repository.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_medication_plan_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rejects a medication detail returned for another child', (tester) async {
    final repository = _DelayedDirectoryRepository(delayChild: true);
    final controller = _controllerFor('b', repository: repository);
    addTearDown(controller.dispose);
    final fixture = FixtureHealthCareRepository();
    final page = await fixture.fetchDirectory(
      const HealthCareDirectoryQuery(),
      actor: controller.actor,
    );
    final otherChild = await fixture.findChild('child-demo-a', actor: fixture.defaultActor);
    await tester.pumpWidget(_directory(controller));
    repository.directory.complete(page);
    await tester.pump();
    expect(repository.childRequests, ['child-demo-b']);
    repository.child.complete(otherChild);
    await tester.pumpAndSettle();
    expect(find.text('Criança Demo A'), findsNothing);
    expect(find.text('Medicamento Demo'), findsNothing);
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clears medication cards when the authorized controller changes', (tester) async {
    final a = _controllerFor('a');
    final b = _controllerFor('b');
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await tester.pumpWidget(_directory(a));
    await tester.pumpAndSettle();
    expect(find.text('Criança Demo A'), findsOneWidget);

    await tester.pumpWidget(_directory(b));
    expect(find.text('Criança Demo A'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum plano'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('never forwards old directory child IDs to the replacement controller', (
    tester,
  ) async {
    final repositoryA = _DelayedDirectoryRepository();
    final repositoryB = _DelayedDirectoryRepository();
    final a = _controllerFor('a', repository: repositoryA);
    final b = _controllerFor('b', repository: repositoryB);
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final fixture = FixtureHealthCareRepository();
    final oldPage = await fixture.fetchDirectory(const HealthCareDirectoryQuery(), actor: a.actor);
    final newPage = await fixture.fetchDirectory(const HealthCareDirectoryQuery(), actor: b.actor);

    await tester.pumpWidget(_directory(a));
    await tester.pump();
    await tester.pumpWidget(_directory(b));
    repositoryB.directory.complete(newPage);
    await tester.pump(const Duration(milliseconds: 200));
    repositoryA.directory.complete(oldPage);
    await tester.pumpAndSettle();
    expect(repositoryA.childRequests, isEmpty);
    expect(repositoryB.childRequests, ['child-demo-b']);
    expect(find.text('Criança Demo A'), findsNothing);
    expect(find.text('Não foi possível carregar'), findsNothing);
  });

  for (final failOldChild in [false, true]) {
    testWidgets(
      'ignores late child ${failOldChild ? 'failure' : 'success'} after controller replacement',
      (tester) async {
        final repositoryA = _DelayedDirectoryRepository(delayChild: true);
        final a = _controllerFor('a', repository: repositoryA);
        final b = _controllerFor('b');
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        final fixture = FixtureHealthCareRepository();
        final oldPage = await fixture.fetchDirectory(
          const HealthCareDirectoryQuery(),
          actor: a.actor,
        );
        final oldChild = await fixture.findChild('child-demo-a', actor: a.actor);
        await tester.pumpWidget(_directory(a));
        repositoryA.directory.complete(oldPage);
        await tester.pump();
        expect(repositoryA.childRequests, ['child-demo-a']);
        await tester.pumpWidget(_directory(b));
        await tester.pump(const Duration(milliseconds: 200));
        if (failOldChild) {
          repositoryA.child.completeError(StateError('old context failure'));
        } else {
          repositoryA.child.complete(oldChild);
        }
        await tester.pumpAndSettle();
        expect(find.text('Criança Demo A'), findsNothing);
        expect(find.text('Nenhum plano'), findsOneWidget);
        expect(find.text('Não foi possível carregar'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('switching to minimized context starts no sensitive queries', (tester) async {
    final repositoryA = _DelayedDirectoryRepository();
    final repositoryB = _DelayedDirectoryRepository();
    final a = _controllerFor('a', repository: repositoryA);
    final b = HealthCareController(
      repositoryB,
      actor: HealthCareActor(
        id: 'minimized-b',
        profile: HealthCareAccessProfile.minimized,
        authorizedChildIds: const {'child-demo-b'},
      ),
    );
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    final oldPage = await FixtureHealthCareRepository().fetchDirectory(
      const HealthCareDirectoryQuery(),
      actor: a.actor,
    );
    await tester.pumpWidget(_directory(a));
    await tester.pumpWidget(_directory(b));
    repositoryA.directory.complete(oldPage);
    await tester.pumpAndSettle();
    expect(repositoryB.directoryRequests, 0);
    expect(repositoryA.childRequests, isEmpty);
    expect(repositoryB.childRequests, isEmpty);
    expect(find.text('Resumo minimizado'), findsOneWidget);
    expect(find.text('Criança Demo A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmounted directory does not start child reads after its first await', (
    tester,
  ) async {
    final repository = _DelayedDirectoryRepository();
    final controller = _controllerFor('a', repository: repository);
    addTearDown(controller.dispose);
    final oldPage = await FixtureHealthCareRepository().fetchDirectory(
      const HealthCareDirectoryQuery(),
      actor: controller.actor,
    );
    await tester.pumpWidget(_directory(controller));
    await tester.pumpWidget(const SizedBox.shrink());
    repository.directory.complete(oldPage);
    await tester.pumpAndSettle();
    expect(repository.childRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lists medication plans as a sibling directory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = HealthCareController(FixtureHealthCareRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.byType(CoeloAdminInteractiveCard), findsWidgets);
    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsWidgets);
    expect(find.text('Status do plano'), findsOneWidget);
    expect(find.text('Situação da dose'), findsOneWidget);
    expect(find.byType(CoeloAdminPagination), findsOneWidget);
    expect(find.text('Vigência'), findsWidgets);
    expect(find.text('Horários'), findsWidgets);
    expect(find.text('Contexto responsável'), findsWidgets);
    expect(find.textContaining('Responsável indisponível'), findsWidgets);

    final statusFilter = tester.widget<CoeloAdminMultiSelectFilter<HealthMedicationReviewStatus>>(
      find.byType(CoeloAdminMultiSelectFilter<HealthMedicationReviewStatus>),
    );
    statusFilter.onChanged({HealthMedicationReviewStatus.ended});
    await tester.pumpAndSettle();
    expect(find.text('Nenhum plano'), findsOneWidget);
    statusFilter.onChanged({});
    await tester.pumpAndSettle();

    final doseFilter = tester.widget<CoeloAdminMultiSelectFilter<HealthMedicationDoseSituation>>(
      find.byType(CoeloAdminMultiSelectFilter<HealthMedicationDoseSituation>),
    );
    doseFilter.onChanged({HealthMedicationDoseSituation.notAdministered});
    await tester.pumpAndSettle();
    expect(find.text('Nenhum plano'), findsOneWidget);
    doseFilter.onChanged({});
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('health-medication-plans-view-table')));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminResizableTable<HealthMedicationPlanListItem>), findsOneWidget);
    expect(find.text('Contexto responsável'), findsOneWidget);
  });

  testWidgets('shows the minimized permission state without leaking plan data', (tester) async {
    final controller = HealthCareController(
      FixtureHealthCareRepository(),
      actor: HealthCareActor(
        id: 'minimized-demo',
        profile: HealthCareAccessProfile.minimized,
        authorizedChildIds: const {'child-demo-a', 'child-demo-b'},
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Resumo minimizado'), findsOneWidget);
    expect(find.byType(CoeloAdminListingToolbar), findsNothing);
    expect(find.text('Medicamento Demo'), findsNothing);
  });

  testWidgets('medication directory requires capability and real callbacks for actions', (
    tester,
  ) async {
    final controller = HealthCareController(
      FixtureHealthCareRepository(),
      actor: HealthCareActor(
        id: 'reader-demo',
        profile: HealthCareAccessProfile.sensitiveReader,
        authorizedChildIds: const {'child-demo-a'},
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    for (final card in tester.widgetList<CoeloAdminInteractiveCard>(
      find.byType(CoeloAdminInteractiveCard),
    )) {
      expect(card.onPressed, isNull);
    }

    await tester.tap(find.byKey(const Key('health-medication-plans-view-table')));
    await tester.pumpAndSettle();
    final table = tester.widget<CoeloAdminResizableTable<HealthMedicationPlanListItem>>(
      find.byType(CoeloAdminResizableTable<HealthMedicationPlanListItem>),
    );
    expect(table.onRowPressed, isNull);
  });

  testWidgets('loads only medication plans authorized for the active context', (tester) async {
    final controller = HealthCareController(
      FixtureHealthCareRepository(),
      actor: HealthCareActor(
        id: 'reader-demo',
        profile: HealthCareAccessProfile.sensitiveReader,
        institutionId: 'institution-demo-a',
        authorizedChildIds: const {'child-demo-a'},
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthMedicationPlanDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Medicamento Demo'), findsOneWidget);
    expect(find.text('Não foi possível carregar'), findsNothing);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('medication directory has no overflow at $width with 200% text', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = HealthCareController(FixtureHealthCareRepository());
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: HealthMedicationPlanDirectoryPage(
            controller: controller,
            logout: unavailableSuperadminLogout,
            onCreate: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}

Widget _directory(HealthCareController controller) => MaterialApp(
  theme: CoeloTheme.light,
  home: HealthMedicationPlanDirectoryPage(
    controller: controller,
    logout: unavailableSuperadminLogout,
  ),
);

HealthCareController _controllerFor(String suffix, {HealthCareRepository? repository}) =>
    HealthCareController(
      repository ?? FixtureHealthCareRepository(),
      actor: HealthCareActor(
        id: 'reader-$suffix',
        profile: HealthCareAccessProfile.sensitiveReader,
        authorizedChildIds: {'child-demo-$suffix'},
      ),
    );

final class _DelayedDirectoryRepository implements HealthCareRepository {
  _DelayedDirectoryRepository({this.delayChild = false});
  final bool delayChild;
  final directory = Completer<HealthCareDirectoryPage>();
  final child = Completer<HealthCareChild?>();
  final childRequests = <String>[];
  var directoryRequests = 0;
  final _fixture = FixtureHealthCareRepository();

  @override
  HealthCareActor? get defaultActor => null;

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) {
    directoryRequests++;
    return directory.future;
  }

  @override
  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor}) {
    childRequests.add(childId);
    return delayChild ? child.future : _fixture.findChild(childId, actor: actor);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
