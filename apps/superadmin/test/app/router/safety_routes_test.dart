import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('declares complete development safety routes', () {
    expect(SuperadminRoutes.devSafety, '/dev/safety');
    expect(SuperadminRoutes.devSafetyCreate, '/dev/safety/new');
    expect(SuperadminRoutes.devSafetyChild, '/dev/safety/children/:childId');
    expect(
      SuperadminRoutes.devSafetyEdit,
      '/dev/safety/children/:childId/authorizations/:authorizationId/edit',
    );
  });

  testWidgets('development safety directory, create, detail and edit are locally navigable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = SuperadminSession()..signIn();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
      allowDevelopmentPreview: true,
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go(SuperadminRoutes.devSafety);
    await tester.pumpAndSettle();
    expect(find.text('Ana Criança'), findsOneWidget);
    expect(find.text('Todos (3)'), findsOneWidget);

    await tester.tap(find.text('Criar segurança'));
    await tester.pumpAndSettle();
    expect(find.text('Criança'), findsWidgets);
    await tester.enterText(find.byType(TextFormField).first, 'Ana');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Criança'), findsWidgets);

    router.go('/dev/safety/children/child-1');
    await tester.pumpAndSettle();
    expect(find.text('Maria Martins'), findsWidgets);
    expect(find.text('Cadastrar pessoa'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Maria Martins, Pendente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(find.text('Editar segurança'), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-wizard-primary')));
    await tester.pumpAndSettle();
    expect(find.text('Solicitação familiar'), findsOneWidget);
  });
}
