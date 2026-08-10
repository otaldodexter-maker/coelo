import 'dart:ui';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart' as domain;
import 'package:coelo_superadmin/features/groups/presentation/group_directory_page.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders confirmed group fields and switches to the canonical table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
    final first = repository.records.first;
    String? editedId;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onEdit: (id) => editedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Turmas'), findsWidgets);
    expect(find.text('Gerencie as turmas da plataforma.'), findsOneWidget);
    expect(find.textContaining('Instituição:'), findsWidgets);
    expect(find.textContaining('Unidade:'), findsWidgets);
    expect(find.text('Tipos'), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) => widget is SuperadminDirectoryViewToggle),
      findsOneWidget,
    );
    expect(find.text('Equipe institucional'), findsWidgets);
    expect(find.text('Atividades'), findsWidgets);
    expect(find.text('Responsáveis'), findsWidgets);
    expect(find.text('Crianças'), findsWidgets);

    expect(
      tester.getSize(find.byType(CoeloAdminCreateAction)).height,
      closeTo(tester.getSize(find.byKey(Key('group-card-${first.id}'))).height, 0.5),
    );

    await tester.tap(find.byKey(Key('group-card-${first.id}')));
    expect(editedId, first.id);

    await tester.tap(find.byKey(const Key('group-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-directory-table')), findsOneWidget);
    expect(find.text('Turma'), findsWidgets);

    await tester.longPress(find.byKey(const Key('group-view-table')));
    await tester.pumpAndSettle();
    expect(find.text('Agrupado'), findsOneWidget);
    expect(find.text('Detalhado por Atividades'), findsOneWidget);
    await tester.tap(find.text('Detalhado por Atividades'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-activity-directory-table')), findsOneWidget);
    expect(find.text('Atividade'), findsWidgets);
    expect(find.text('Equipe institucional'), findsWidgets);
    expect(find.byKey(const Key('coelo-admin-table-header-status')), findsOneWidget);
  });

  testWidgets('uses the canonical expandable status indicator on group cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());
    final first = repository.records.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final indicator = find.byKey(Key('group-status-${first.id}'));
    final card = find.byKey(Key('group-card-${first.id}'));
    final name = find.descendant(of: card, matching: find.text(first.name));
    final cardSizeBefore = tester.getSize(card);
    final cardTopLeftBefore = tester.getTopLeft(card);
    final nameTopLeftBefore = tester.getTopLeft(name);
    expect(indicator, findsOneWidget);
    expect(tester.getSize(indicator), const Size.square(24));
    expect(find.text(first.status.label), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(indicator));
    await tester.pumpAndSettle();

    expect(find.text(first.status.label), findsOneWidget);
    expect(tester.getSize(indicator).width, greaterThan(24));
    expect(tester.getSize(card), cardSizeBefore);
    expect(tester.getTopLeft(card), cardTopLeftBefore);
    expect((tester.getTopLeft(name) - nameTopLeftBefore).distance, lessThanOrEqualTo(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps sticky pagination usable at 200 percent text on compact width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: GroupDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-directory-pagination-footer')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses only dependent units after selecting an institution', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-institution-filter')), findsOneWidget);
    expect(find.byKey(const Key('group-unit-filter')), findsOneWidget);
    expect(find.byKey(const Key('group-type-filter')), findsOneWidget);
    expect(find.byKey(const Key('group-status-tabs')), findsOneWidget);
    expect(find.text('Ativos'), findsOneWidget);
  });

  testWidgets('offers explicit local import and export demonstrations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupDirectoryPage(
          repository: FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository()),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Importar turmas'), findsOneWidget);
    expect(find.text('Exportar turmas'), findsOneWidget);

    await tester.tap(find.text('Exportar turmas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('visão: Cards'), findsOneWidget);

    final toggle = tester.widget<SuperadminDirectoryViewToggle<GroupDirectoryTableView>>(
      find.byType(SuperadminDirectoryViewToggle<GroupDirectoryTableView>),
    );
    toggle.onTableViewSelected(GroupDirectoryTableView.activities);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar turmas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('visão: Detalhado por Atividades'), findsOneWidget);
  });

  testWidgets('inherits the approved Bug, profile and tour overlays from the shell', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final submittedReports = <Object>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: GroupDirectoryPage(
          repository: FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository()),
          logout: () async => const LogoutResult.success(),
          onBugReportSubmitted: submittedReports.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-bug-report-dialog')), findsOneWidget);
    expect(find.text('Bug? O Coelo resolve!'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('superadmin-bug-screen')),
        matching: find.text('Turmas'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('superadmin-bug-report-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-onboarding-tour')));
    await tester.pumpAndSettle();
    expect(find.text('Tour desta tela'), findsOneWidget);
    expect(find.text('Tour do menu'), findsOneWidget);
    expect(find.text('Tour completo'), findsOneWidget);
  });

  for (final scenario in [
    (name: 'empty', repository: _ScenarioRepository.empty(), expected: 'Nenhuma turma cadastrada'),
    (
      name: 'failure',
      repository: _ScenarioRepository.failure(),
      expected: 'Não foi possível carregar as turmas',
    ),
    (
      name: 'unauthorized',
      repository: _ScenarioRepository.unauthorized(),
      expected: 'Acesso não autorizado',
    ),
  ]) {
    testWidgets('renders the ${scenario.name} directory state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: GroupDirectoryPage(
            repository: scenario.repository,
            logout: () async => const LogoutResult.success(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(scenario.expected), findsOneWidget);
    });
  }
}

enum _Scenario { empty, failure, unauthorized }

final class _ScenarioRepository implements domain.GroupDirectoryRepository {
  _ScenarioRepository.empty() : scenario = _Scenario.empty;
  _ScenarioRepository.failure() : scenario = _Scenario.failure;
  _ScenarioRepository.unauthorized() : scenario = _Scenario.unauthorized;

  final _Scenario scenario;

  @override
  List<domain.GroupRecord> get records => const [];

  @override
  String createId(String institutionId, String unitId, String name) => 'unused';

  @override
  Future<domain.GroupDirectoryFilterOptions> fetchFilterOptions({
    Set<String> institutionIds = const {},
  }) async => const domain.GroupDirectoryFilterOptions();

  @override
  Future<domain.GroupDirectoryPage> fetchPage(domain.GroupDirectoryQuery query) async {
    if (scenario == _Scenario.failure) throw Exception('failure');
    if (scenario == _Scenario.unauthorized) {
      throw const domain.GroupDirectoryUnauthorizedException();
    }
    return domain.GroupDirectoryPage(
      items: const [],
      totalCount: 0,
      page: 0,
      pageSize: query.pageSize,
    );
  }

  @override
  domain.GroupRecord? findById(String id) => null;

  @override
  Future<void> upsert(domain.GroupRecord record) async {}
}
