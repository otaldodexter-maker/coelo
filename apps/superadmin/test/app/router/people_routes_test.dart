import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/people/fake_person_directory_repository.dart';

void main() {
  test('declares production and development people routes', () {
    expect(SuperadminRoutes.people, '/people');
    expect(SuperadminRoutes.personCreate, '/people/new');
    expect(SuperadminRoutes.personEdit, '/people/:personId/edit');
    expect(SuperadminRoutes.devPeople, '/dev/people');
    expect(SuperadminRoutes.devPersonCreate, '/dev/people/new');
    expect(SuperadminRoutes.devPersonEdit, '/dev/people/:personId/edit');
  });

  testWidgets('exposes People as an active navigation destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? selectedDestination;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminShell.host(
          logout: unavailableSuperadminLogout,
          currentDestination: 'people',
          onDestinationSelected: (destination) {
            selectedDestination = destination;
          },
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final peopleDestination = find.byKey(const Key('superadmin-navigation-people'));
    expect(peopleDestination, findsOneWidget);

    await tester.tap(peopleDestination);
    await tester.pump();
    expect(selectedDestination, 'people');
  });

  testWidgets('protects production and exposes the development people directory', (tester) async {
    final session = SuperadminSession();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      personDirectoryRepository: FakePersonDirectoryRepository(),
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    router.go(SuperadminRoutes.people);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.login);

    router.go(SuperadminRoutes.devPeople);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, SuperadminRoutes.devPeople);
    expect(find.text('Gerencie identidades globais e vínculos contextuais.'), findsOneWidget);
    expect(find.text('Criar pessoa'), findsWidgets);
  });
}
