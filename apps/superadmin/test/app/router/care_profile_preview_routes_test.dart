import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('development care profiles navigate from directory to create and edit wizards', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final session = SuperadminSession()..signInForTesting();
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

    router.go(SuperadminRoutes.devHealthCareProfiles);
    await tester.pumpAndSettle();
    expect(find.text('Criança Demo A'), findsOneWidget);
    final paths = <String>[];
    void recordPath() => paths.add(router.routeInformationProvider.value.uri.path);
    router.routeInformationProvider.addListener(recordPath);
    addTearDown(() => router.routeInformationProvider.removeListener(recordPath));
    final childCard = find.ancestor(
      of: find.text('Criança Demo A'),
      matching: find.byType(CoeloAdminInteractiveCard),
    );
    tester.widget<CoeloAdminInteractiveCard>(childCard).onPressed!();
    await tester.pumpAndSettle();
    expect(paths, contains('/dev/health-care/profiles/child-demo-a/edit'));
    expect(
      router.routeInformationProvider.value.uri.path,
      '/dev/health-care/profiles/child-demo-a/edit',
      reason: paths.toString(),
    );
    expect(find.text('Editar perfil de cuidado'), findsWidgets);
    expect(find.text('Criança Demo A'), findsWidgets);
    expect(find.text('Edema no episódio registrado.'), findsNothing);

    await tester.tap(find.text('Alergias e restrições').last);
    await tester.pumpAndSettle();
    expect(find.text('Edema no episódio registrado.'), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar perfil de cuidado').first);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      SuperadminRoutes.devHealthCareProfileCreate,
    );
    expect(find.text('Criar perfil de cuidado'), findsWidgets);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
  });
}
