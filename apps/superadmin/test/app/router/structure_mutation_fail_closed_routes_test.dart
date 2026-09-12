import 'package:coelo_superadmin/app/router/superadmin_router.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_form_page.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Instituições e Unidades eram as duas únicas famílias de Estrutura sem prova
/// de que suas rotas de mutação caem na página honesta de indisponível quando a
/// capacidade está desligada. Turmas e Atividades já tinham a sua.
///
/// Isso importa agora: existe proposta de separar `structureMutationsEnabled`
/// por realm, porque o CRUD de Instituições e Atividades já fala com o realm
/// interno v2 enquanto Unidades continua no people-based com a OQ-032 aberta.
/// Se essa separação for aceita, este arquivo é o que impede Unidades de abrir
/// junto por descuido.
void main() {
  testWidgets('rotas de mutação de Instituições e Unidades caem na página honesta', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    for (final route in [
      SuperadminRoutes.institutionCreate,
      '/institutions/11111111-1111-4111-8111-111111111111/edit',
      SuperadminRoutes.unitCreate,
      '/units/22222222-2222-4222-8222-222222222222/edit',
    ]) {
      router.go(route);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('production-mutation-capability-unavailable')),
        findsOneWidget,
        reason: '$route deveria cair na pagina de mutacao indisponivel',
      );
      expect(find.byType(InstitutionFormPage), findsNothing, reason: route);
      expect(find.byType(UnitFormPage), findsNothing, reason: route);
    }
  });

  testWidgets('com a capacidade ligada, o redirect deixa de acontecer', (tester) async {
    // Sem este caso, o anterior passaria mesmo que a pagina de indisponivel
    // aparecesse por outro motivo, e nao provaria nada sobre a capacidade.
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = SuperadminSession()..signInForTesting();
    final router = createSuperadminRouter(
      session: session,
      login: unavailableSuperadminLogin,
      logout: unavailableSuperadminLogout,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      enableStructureMutations: true,
      onThemeModeChanged: (_) {},
    );
    addTearDown(router.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));

    router.go(SuperadminRoutes.institutionCreate);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('production-mutation-capability-unavailable')), findsNothing);
  });
}
