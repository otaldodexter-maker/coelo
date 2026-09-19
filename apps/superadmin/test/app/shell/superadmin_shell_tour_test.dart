import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/app/tour/superadmin_menu_tour_steps.dart';
import 'package:coelo_superadmin/app/tour/superadmin_tour_store.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _balloon = Key('coelo-tour-balloon');
const _next = Key('coelo-tour-next');
const _skip = Key('coelo-tour-skip');

Widget _shellApp({
  SuperadminTourStore? tourStore,
  List<CoeloTourStep> steps = superadminMenuTourSteps,
  String currentDestination = 'institutions',
}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: SuperadminShell(
          logout: () async => const LogoutResult.success(),
          currentDestination: currentDestination,
          tourStore: tourStore,
          menuTourSteps: steps,
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

Future<void> _resize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _openMenuTour(WidgetTester tester, {String option = 'Tour do menu'}) async {
  await tester.tap(find.byKey(const Key('superadmin-onboarding-tour')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('o flyout "Tour do menu" abre o tour no primeiro passo', (tester) async {
    await _resize(tester, const Size(1440, 900));
    await tester.pumpWidget(_shellApp());
    await _openMenuTour(tester);

    expect(find.byKey(_balloon), findsOneWidget);
    expect(find.text('Bem-vindo ao Coelo'), findsOneWidget);
    // Só Planos (dev-only) fica sem passo; fora do /dev todos os passos
    // estão disponíveis.
    expect(find.text('1 de ${superadminMenuTourSteps.length}'), findsOneWidget);
  });

  testWidgets('"Tour completo" abre, nesta versão, o mesmo tour do menu e avisa', (tester) async {
    await _resize(tester, const Size(1440, 900));
    await tester.pumpWidget(_shellApp());
    await _openMenuTour(tester, option: 'Tour completo');

    expect(find.byKey(_balloon), findsOneWidget);
    expect(find.text('Bem-vindo ao Coelo'), findsOneWidget);
    expect(find.textContaining('O tour completo (menu e todas as telas) chega em breve'), findsOneWidget);
  });

  testWidgets('passos do menu da conta abrem o menu, apontam cada item e fecham ao sair', (
    tester,
  ) async {
    await _resize(tester, const Size(1440, 900));
    const steps = <CoeloTourStep>[
      CoeloTourStep(anchorId: 'account', title: 'Sua conta', text: 'x'),
      CoeloTourStep(anchorId: 'account-profile', title: 'Perfil do tour', text: 'x'),
      CoeloTourStep(anchorId: 'account-logout', title: 'Sair do tour', text: 'x'),
      CoeloTourStep(anchorId: 'report-bug', title: 'Bug do tour', text: 'x'),
    ];
    await tester.pumpWidget(_shellApp(steps: steps));
    await _openMenuTour(tester);
    expect(find.text('Sua conta'), findsOneWidget);
    expect(find.text('Configurações'), findsNothing);

    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    expect(find.text('Perfil do tour'), findsOneWidget);
    expect(find.text('Configurações'), findsOneWidget);
    // O balão não cobre o menu aberto (o menu fica acima do overlay).
    final menuItem = tester.getRect(find.text('Configurações'));
    final balloon = tester.getRect(find.byKey(_balloon));
    expect(balloon.overlaps(menuItem), isFalse);

    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    expect(find.text('Sair do tour'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);

    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    expect(find.text('Bug do tour'), findsOneWidget);
    expect(find.text('Configurações'), findsNothing);
    expect(find.byKey(const Key('superadmin-logout-dialog')), findsNothing);
  });

  testWidgets('passo de nó oculto por ambiente é pulado e grupo colapsado abre no passo', (
    tester,
  ) async {
    await _resize(tester, const Size(1440, 900));
    const steps = <CoeloTourStep>[
      CoeloTourStep(anchorId: 'home', title: 'Home', text: 'x'),
      CoeloTourStep(anchorId: 'plans', title: 'Planos (dev)', text: 'x'),
      CoeloTourStep(anchorId: 'meal-plans', title: 'Cardápios', text: 'x'),
    ];
    await tester.pumpWidget(_shellApp(steps: steps, currentDestination: 'home'));
    // Operação começa colapsado: Cardápios não está na árvore.
    expect(find.byKey(const Key('superadmin-navigation-meal-plans')), findsNothing);

    await _openMenuTour(tester);
    expect(find.text('1 de 2'), findsOneWidget);
    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    expect(find.text('Planos (dev)'), findsNothing);
    expect(find.text('Cardápios'), findsWidgets);
    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-navigation-meal-plans')), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);
  });

  testWidgets('primeiro acesso mostra o tour uma vez e grava o desfecho', (tester) async {
    await _resize(tester, const Size(1440, 900));
    final store = InMemorySuperadminTourStore();
    await tester.pumpWidget(_shellApp(tourStore: store));
    await tester.pumpAndSettle();
    expect(find.byKey(_balloon), findsOneWidget);

    await tester.tap(find.byKey(_skip));
    await tester.pumpAndSettle();
    expect(find.byKey(_balloon), findsNothing);
    expect(store.lastOutcome, 'skipped');

    // Nova montagem com o mesmo store: não abre sozinho.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_shellApp(tourStore: store));
    await tester.pumpAndSettle();
    expect(find.byKey(_balloon), findsNothing);

    // Refazer pelo botão continua funcionando e grava "done" ao concluir.
    await _openMenuTour(tester);
    expect(find.byKey(_balloon), findsOneWidget);
  });

  testWidgets('com tour já visto o shell não abre o tour sozinho', (tester) async {
    await _resize(tester, const Size(1440, 900));
    await tester.pumpWidget(_shellApp(tourStore: InMemorySuperadminTourStore(seen: true)));
    await tester.pumpAndSettle();
    expect(find.byKey(_balloon), findsNothing);
  });

  testWidgets('concluir grava done', (tester) async {
    await _resize(tester, const Size(1440, 900));
    final store = InMemorySuperadminTourStore(seen: true);
    const steps = <CoeloTourStep>[CoeloTourStep(anchorId: 'home', title: 'Home', text: 'x')];
    await tester.pumpWidget(_shellApp(tourStore: store, steps: steps));
    await _openMenuTour(tester);
    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    expect(find.byKey(_balloon), findsNothing);
    expect(store.lastOutcome, 'done');
  });

  testWidgets('em tela estreita o drawer abre no passo do menu e o balão é folha inferior', (
    tester,
  ) async {
    await _resize(tester, const Size(600, 900));
    const steps = <CoeloTourStep>[
      CoeloTourStep(anchorId: 'home', title: 'Home', text: 'x'),
      CoeloTourStep(anchorId: 'notifications', title: 'Sino', text: 'x'),
    ];
    await tester.pumpWidget(_shellApp(steps: steps));
    // O botão "Fazer tour" vive no drawer em tela estreita.
    expect(find.byKey(const Key('superadmin-onboarding-tour')), findsNothing);
    await tester.tap(find.byTooltip('Abrir menu'));
    await tester.pumpAndSettle();
    await _openMenuTour(tester);

    expect(find.byKey(_balloon), findsOneWidget);
    final balloon = tester.getRect(find.byKey(_balloon));
    expect(balloon.bottom, 900);
    expect(balloon.width, 600);
    expect(find.byKey(const Key('superadmin-navigation-home')), findsOneWidget);

    // Passo do cabeçalho fecha o drawer para apontar o sino.
    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    expect(find.text('Sino'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-navigation-home')), findsNothing);
    expect(find.byKey(const Key('superadmin-notifications')), findsOneWidget);
  });
}
