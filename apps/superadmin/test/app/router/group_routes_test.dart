import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_directory_page.dart'
    as presentation;
import 'package:coelo_superadmin/features/groups/presentation/group_form_page.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares production and development group routes', () {
    expect(SuperadminRoutes.groups, '/groups');
    expect(SuperadminRoutes.groupCreate, '/groups/new');
    expect(SuperadminRoutes.groupEdit, '/groups/:groupId/edit');
    expect(SuperadminRoutes.devGroups, '/dev/groups');
    expect(SuperadminRoutes.devGroupCreate, '/dev/groups/new');
    expect(SuperadminRoutes.devGroupEdit, '/dev/groups/:groupId/edit');
  });

  testWidgets('exposes Groups as an active navigation destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selectedDestination;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'groups',
          onDestinationSelected: (destination) {
            selectedDestination = destination;
          },
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final groupsDestination = find.byKey(const Key('superadmin-navigation-groups'));
    expect(groupsDestination, findsOneWidget);

    await tester.tap(groupsDestination);
    await tester.pump();
    expect(selectedDestination, 'groups');
  });

  testWidgets('development routes share one local fake and never call production', (tester) async {
    final session = SuperadminSession()..signIn();
    final production = _TrackingGroupDirectoryRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      groupDirectoryRepository: production,
      allowDevelopmentPreview: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go(SuperadminRoutes.devGroups);
    await tester.pumpAndSettle();
    final directory = tester.widget<presentation.GroupDirectoryPage>(
      find.byType(presentation.GroupDirectoryPage),
    );
    expect(directory.repository, isA<FakeGroupDirectoryRepository>());
    expect(production.calls, isEmpty);

    router.go(SuperadminRoutes.devGroupCreate);
    await tester.pumpAndSettle();
    final create = tester.widget<GroupFormPage>(find.byType(GroupFormPage));
    expect(create.repository, same(directory.repository));
    expect(production.calls, isEmpty);

    final preview = directory.repository as FakeGroupDirectoryRepository;
    router.go('/dev/groups/${preview.records.first.id}/edit');
    await tester.pumpAndSettle();
    final edit = tester.widget<GroupFormPage>(find.byType(GroupFormPage));
    expect(edit.repository, same(directory.repository));
    expect(production.calls, isEmpty);
  });

  testWidgets('production list uses its repository while mutations fail closed', (tester) async {
    final session = SuperadminSession()..signIn();
    final repository = _TrackingGroupDirectoryRepository();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      groupDirectoryRepository: repository,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go(SuperadminRoutes.groups);
    await tester.pumpAndSettle();
    final directory = tester.widget<presentation.GroupDirectoryPage>(
      find.byType(presentation.GroupDirectoryPage),
    );
    expect(directory.repository, same(repository));
    expect(repository.calls, containsAll(['fetchPage', 'fetchFilterOptions']));

    repository.calls.clear();
    router.go(SuperadminRoutes.groupCreate);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(find.byType(GroupFormPage), findsNothing);
    expect(repository.calls, isEmpty);

    repository.calls.clear();
    router.go('/groups/${repository.firstId}/edit');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsOneWidget);
    expect(find.byType(GroupFormPage), findsNothing);
    expect(repository.calls, isEmpty);
  });
}

final class _TrackingGroupDirectoryRepository implements GroupDirectoryRepository {
  _TrackingGroupDirectoryRepository()
    : _delegate = FakeGroupDirectoryRepository(FakeInstitutionDirectoryRepository());

  final FakeGroupDirectoryRepository _delegate;
  final calls = <String>[];

  String get firstId => _delegate.records.first.id;

  @override
  Future<GroupRecord?> findById(String id) {
    calls.add('findById:$id');
    return _delegate.findById(id);
  }

  @override
  String createId(String institutionId, String unitId, String name) {
    calls.add('createId');
    return _delegate.createId(institutionId, unitId, name);
  }

  @override
  Future<void> upsert(GroupRecord record) {
    calls.add('upsert');
    return _delegate.upsert(record);
  }

  @override
  Future<GroupDirectorySaveResult> saveComposition(GroupDirectorySaveRequest request) {
    calls.add('saveComposition');
    return _delegate.saveComposition(request);
  }

  @override
  Future<GroupDirectoryPage> fetchPage(GroupDirectoryQuery query) {
    calls.add('fetchPage');
    return _delegate.fetchPage(query);
  }

  @override
  Future<GroupDirectoryFilterOptions> fetchFilterOptions({Set<String> institutionIds = const {}}) {
    calls.add('fetchFilterOptions');
    return _delegate.fetchFilterOptions(institutionIds: institutionIds);
  }

  @override
  Future<GroupDirectoryFormContext> fetchFormContext({String? institutionId}) {
    calls.add('fetchFormContext');
    return _delegate.fetchFormContext(institutionId: institutionId);
  }

  @override
  Future<GroupDirectoryExportResult> requestExport(GroupDirectoryQuery query) {
    calls.add('requestExport');
    return _delegate.requestExport(query);
  }
}
