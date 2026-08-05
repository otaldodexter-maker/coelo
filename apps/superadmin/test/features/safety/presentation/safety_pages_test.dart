import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';

void main() {
  testWidgets('landing renders grouped children and switches to table', (tester) async {
    await _surface(tester, const Size(1440, 1000));
    final store = ChildSafetyStore.demo();
    await tester.pumpWidget(_landingApp(store));
    await tester.pumpAndSettle();

    expect(find.text('Segurança da criança'), findsNWidgets(2));
    expect(find.text('Instituição 2 · Unidade 2'), findsOneWidget);
    expect(find.text('Criança Coelo 2'), findsOneWidget);
    expect(find.text('Aguardando aprovação'), findsOneWidget);

    await tester.tap(find.byKey(const Key('safety-view-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('safety-children-table')), findsOneWidget);
    expect(find.text('Pessoas autorizadas'), findsOneWidget);
    expect(find.text('Validação'), findsOneWidget);
  });

  testWidgets('search and status filters preserve no-results feedback', (tester) async {
    await _surface(tester, const Size(1440, 1000));
    await tester.pumpWidget(_landingApp(ChildSafetyStore.demo()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'criança inexistente');
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma criança encontrada'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);
  });

  testWidgets('guardian registration starts pending and can be approved', (tester) async {
    await _surface(tester, const Size(700, 1200));
    final store = ChildSafetyStore.demo();
    await tester.pumpWidget(_detailApp(store, 'person-4'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cadastrar pessoa'));
    await tester.pumpAndSettle();

    final origin = tester.widget<CoeloAdminSingleSelectField<PickupAuthorizationOrigin>>(
      find.byType(CoeloAdminSingleSelectField<PickupAuthorizationOrigin>),
    );
    origin.onChanged(PickupAuthorizationOrigin.guardian);
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(1), 'Lúcia Teste');
    await tester.enterText(fields.at(2), 'Avó');
    await tester.tap(find.text('Salvar autorização'));
    await tester.pumpAndSettle();

    final created = store.findChild('person-4')!.authorizations.last;
    expect(created.name, 'Lúcia Teste');
    expect(created.status, PickupAuthorizationStatus.pending);
    expect(find.text('Retirada bloqueada até aprovação.'), findsOneWidget);

    await tester.ensureVisible(find.text('Aprovar'));
    await tester.tap(find.text('Aprovar'));
    await tester.pumpAndSettle();

    expect(
      store.findChild('person-4')!.authorizations.last.status,
      PickupAuthorizationStatus.approved,
    );
  });

  testWidgets('removal requires confirmation before deleting authorization', (tester) async {
    await _surface(tester, const Size(700, 1000));
    final store = ChildSafetyStore.demo();
    await tester.pumpWidget(_detailApp(store, 'person-4'));
    await tester.pumpAndSettle();

    expect(store.findChild('person-4')!.authorizations, hasLength(1));
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    expect(find.text('Remover autorização'), findsOneWidget);
    expect(store.findChild('person-4')!.authorizations, hasLength(1));

    await tester.tap(find.text('Remover').last);
    await tester.pumpAndSettle();

    expect(store.findChild('person-4')!.authorizations, isEmpty);
    expect(find.text('Nenhuma pessoa cadastrada'), findsOneWidget);
  });

  testWidgets('desktop detail exposes the complete authorized persons table', (tester) async {
    await _surface(tester, const Size(1800, 1000));
    await tester.pumpWidget(_detailApp(ChildSafetyStore.demo(), 'person-1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('authorized-persons-table')), findsOneWidget);
    for (final label in const [
      'Nome',
      'Relação / hierarquia',
      'Instituição / unidade',
      'Período de retirada',
      'Status',
      'Origem',
      'Ações',
    ]) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('child summary exposes recent authorizations and full CTA', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: ChildSecuritySummaryCard(
            childId: 'person-1',
            store: ChildSafetyStore.demo(),
            onOpen: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pessoas que podem retirar'), findsOneWidget);
    expect(find.textContaining('Marina Coelo'), findsOneWidget);
    await tester.tap(find.text('Ver completa'));
    expect(opened, isTrue);
  });

  testWidgets('directory paginates large child collections', (tester) async {
    await _surface(tester, const Size(1440, 1000));
    final records = List.generate(
      12,
      (index) => ChildSafetyRecord(
        childId: 'child-' + index.toString(),
        childName: 'Criança ' + index.toString(),
        internalId: 'RA ' + index.toString(),
        institutionName: 'Instituição teste',
        unitName: 'Unidade teste',
        authorizations: const [],
      ),
    );
    await tester.pumpWidget(_landingApp(ChildSafetyStore.seeded(records)));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminPagination), findsOneWidget);
    expect(find.text('Criança 0'), findsOneWidget);
    expect(find.text('Criança 8'), findsNothing);
  });
}

Widget _landingApp(ChildSafetyStore store) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            SafetyLandingPage(store: store, logout: _logout, onOpenChild: (_) {}),
      ),
    ],
  );
  return MaterialApp.router(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    routerConfig: router,
  );
}

Widget _detailApp(ChildSafetyStore store, String childId) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            ChildSecurityPage(childId: childId, store: store, logout: _logout, onBack: () {}),
      ),
    ],
  );
  return MaterialApp.router(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    routerConfig: router,
  );
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

Future<void> _surface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
