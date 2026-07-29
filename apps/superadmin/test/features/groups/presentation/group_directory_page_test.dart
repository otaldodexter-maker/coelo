import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart' as domain;
import 'package:coelo_superadmin/features/groups/presentation/group_directory_page.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
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

    expect(find.text('Grupos'), findsWidgets);
    expect(find.text('Gerencie os grupos da plataforma.'), findsOneWidget);
    expect(find.text('Instituição'), findsWidgets);
    expect(find.text('Unidade'), findsWidgets);
    expect(find.text('Tipo'), findsWidgets);
    expect(find.text('Status'), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);

    await tester.tap(find.byKey(Key('group-card-${first.id}')));
    expect(editedId, first.id);

    await tester.tap(find.byKey(const Key('group-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-directory-table')), findsOneWidget);
    expect(find.text('Grupo'), findsWidgets);
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
    expect(find.byKey(const Key('group-status-filter')), findsOneWidget);
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
    expect(find.text('Importar grupos'), findsOneWidget);
    expect(find.text('Exportar grupos'), findsOneWidget);
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
        matching: find.text('Grupos'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('superadmin-bug-report-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-profile-action')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-settings-action')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-logout-action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('superadmin-onboarding-tour')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('superadmin-tour-screen')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-tour-menu')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-tour-complete')), findsOneWidget);
  });

  for (final scenario in [
    (name: 'empty', repository: _ScenarioRepository.empty(), expected: 'Nenhum grupo cadastrado'),
    (
      name: 'failure',
      repository: _ScenarioRepository.failure(),
      expected: 'Não foi possível carregar os grupos',
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
