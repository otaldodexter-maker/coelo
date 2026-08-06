import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
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

  testWidgets('protects production and exposes the development group directory', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      institutionDirectoryRepository: FakeInstitutionDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.groups);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    router.go(SuperadminRoutes.devGroups);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devGroups);
    expect(find.text('Gerencie as turmas da plataforma.'), findsOneWidget);
    expect(find.text('Criar turma'), findsWidgets);
  });
}
