import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/app/tour/superadmin_menu_tour_steps.dart';
import 'package:coelo_superadmin/app/tour/superadmin_screen_tours.dart';
import 'package:coelo_superadmin/app/tour/superadmin_tour_store.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _balloon = Key('coelo-tour-balloon');
const _next = Key('coelo-tour-next');
const _back = Key('coelo-tour-back');
const _skip = Key('coelo-tour-skip');
const _counter = Key('coelo-tour-counter');

Widget _shellApp({
  SuperadminTourStore? tourStore,
  List<CoeloTourStep> steps = superadminMenuTourSteps,
  List<SuperadminScreenTour> screenTours = superadminScreenTourList,
  String currentDestination = 'institutions',
  Widget child = const SizedBox.expand(),
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
          screenTours: screenTours,
          child: child,
        ),
      ),
    ),
  );
}

// Dois passos do menu e duas telas com uma âncora cada: o hospedeiro troca
// a página quando o shell navega, como o router faz.
const _menuSteps = <CoeloTourStep>[
  CoeloTourStep(anchorId: 'tour-button', title: 'Menu 1', text: 'x'),
  CoeloTourStep(anchorId: 'home', title: 'Menu 2', text: 'x'),
];
const _screenA = SuperadminScreenTour(
  destinationId: 'institutions',
  steps: [
    CoeloTourStep(anchorId: 'a.one', title: 'Tela A', text: 'x'),
    CoeloTourStep(anchorId: 'a.missing', title: 'Tela A ausente', text: 'x'),
  ],
);
const _screenB = SuperadminScreenTour(
  destinationId: 'units',
  steps: [CoeloTourStep(anchorId: 'b.one', title: 'Tela B', text: 'x')],
);

class _NavigatingHost extends StatefulWidget {
  const _NavigatingHost({required this.store, this.initial = 'institutions', super.key});

  final SuperadminTourStore store;
  final String initial;

  @override
  State<_NavigatingHost> createState() => _NavigatingHostState();
}

class _NavigatingHostState extends State<_NavigatingHost> {
  late String destination = widget.initial;
  final visited = <String>[];

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: CoeloTheme.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: SuperadminShell.host(
          logout: () async => const LogoutResult.success(),
          currentDestination: destination,
          onDestinationSelected: (value) => setState(() {
            destination = value;
            visited.add(value);
          }),
          tourStore: widget.store,
          menuTourSteps: _menuSteps,
          screenTours: const [_screenA, _screenB],
          child: switch (destination) {
            'institutions' => const Center(
              child: CoeloTourAnchor(id: 'a.one', child: Text('Página A')),
            ),
            'units' => const Center(
              child: CoeloTourAnchor(id: 'b.one', child: Text('Página B')),
            ),
            _ => const Center(child: Text('Outra página')),
          },
        ),
      ),
    ),
  );
}

Future<void> _pumpFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

String _counterText(WidgetTester tester) => tester.widget<Text>(find.byKey(_counter)).data!;

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

  testWidgets('"Tour desta tela" abre o tour do destino atual e pula o passo sem elemento', (
    tester,
  ) async {
    await _resize(tester, const Size(1440, 900));
    await tester.pumpWidget(
      _shellApp(
        screenTours: const [_screenA],
        child: const Center(
          child: CoeloTourAnchor(id: 'a.one', child: Text('Página A')),
        ),
      ),
    );
    await _openMenuTour(tester, option: 'Tour desta tela');

    expect(find.byKey(_balloon), findsOneWidget);
    expect(find.text('Tela A'), findsOneWidget);
    // O passo com âncora ausente não entra no contador.
    expect(_counterText(tester), '1 de 1');
    expect(find.text('Concluir'), findsOneWidget);
    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    expect(find.byKey(_balloon), findsNothing);
  });

  testWidgets('"Tour desta tela" numa tela sem tour avisa', (tester) async {
    await _resize(tester, const Size(1440, 900));
    await tester.pumpWidget(_shellApp(screenTours: const [_screenB]));
    await _openMenuTour(tester, option: 'Tour desta tela');

    expect(find.byKey(_balloon), findsNothing);
    expect(find.text('Esta tela ainda não tem tour.'), findsOneWidget);
  });

  testWidgets('tour completo: menu, telas em sequência, contador global, voltar e origem', (
    tester,
  ) async {
    await _resize(tester, const Size(1440, 900));
    final store = InMemorySuperadminTourStore(seen: true);
    final hostKey = GlobalKey<_NavigatingHostState>();
    await tester.pumpWidget(_NavigatingHost(key: hostKey, store: store));
    await _openMenuTour(tester, option: 'Tour completo');

    // Menu: 2 passos; telas: A (1 disponível de 2 declarados) e B (1). O
    // total conta os declarados.
    expect(find.text('Menu 1'), findsOneWidget);
    expect(_counterText(tester), '1 de 5');
    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    expect(find.text('Menu 2'), findsOneWidget);
    expect(_counterText(tester), '2 de 5');
    // Último passo do menu continua para as telas: "Próximo", não "Concluir".
    expect(find.text('Próximo'), findsOneWidget);
    await tester.tap(find.byKey(_next));
    await _pumpFrames(tester, 10);
    await tester.pumpAndSettle();

    expect(find.text('Tela A'), findsOneWidget);
    expect(_counterText(tester), '3 de 5');
    expect(store.completeProgress, 0);
    // "Voltar" no primeiro passo da tela volta ao último passo do menu.
    await tester.tap(find.byKey(_back));
    await _pumpFrames(tester, 10);
    await tester.pumpAndSettle();
    expect(find.text('Menu 2'), findsOneWidget);
    await tester.tap(find.byKey(_next));
    await _pumpFrames(tester, 10);
    await tester.pumpAndSettle();
    expect(find.text('Tela A'), findsOneWidget);

    // Próximo navega para a tela B e espera a página montar.
    await tester.tap(find.byKey(_next));
    await _pumpFrames(tester, 10);
    await tester.pumpAndSettle();
    expect(hostKey.currentState!.destination, 'units');
    expect(find.text('Página B'), findsOneWidget);
    expect(find.text('Tela B'), findsOneWidget);
    expect(_counterText(tester), '5 de 5');
    expect(find.text('Concluir'), findsOneWidget);
    expect(store.completeProgress, 1);

    await tester.tap(find.byKey(_next));
    await _pumpFrames(tester, 5);
    await tester.pumpAndSettle();
    expect(find.byKey(_balloon), findsNothing);
    expect(store.lastCompleteOutcome, 'done');
    expect(store.completeProgress, isNull);
    // Volta à tela de origem.
    expect(hostKey.currentState!.destination, 'institutions');
  });

  testWidgets('tour completo: "Pular tour" numa tela encerra tudo e volta à origem', (
    tester,
  ) async {
    await _resize(tester, const Size(1440, 900));
    final store = InMemorySuperadminTourStore(seen: true);
    final hostKey = GlobalKey<_NavigatingHostState>();
    await tester.pumpWidget(_NavigatingHost(key: hostKey, store: store, initial: 'units'));
    await _openMenuTour(tester, option: 'Tour completo');
    await tester.tap(find.byKey(_next));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_next));
    await _pumpFrames(tester, 10);
    await tester.pumpAndSettle();
    expect(hostKey.currentState!.destination, 'institutions');
    expect(find.text('Tela A'), findsOneWidget);

    await tester.tap(find.byKey(_skip));
    await _pumpFrames(tester, 5);
    await tester.pumpAndSettle();
    expect(find.byKey(_balloon), findsNothing);
    expect(store.lastCompleteOutcome, 'skipped');
    expect(hostKey.currentState!.destination, 'units');
  });

  testWidgets('tour completo retoma após reload na tela gravada', (tester) async {
    await _resize(tester, const Size(1440, 900));
    // Reload simulado: o store diz que parou na tela de índice 1 (B).
    final store = InMemorySuperadminTourStore(seen: true, completeProgress: 1);
    final hostKey = GlobalKey<_NavigatingHostState>();
    await tester.pumpWidget(_NavigatingHost(key: hostKey, store: store));
    await _pumpFrames(tester, 10);
    await tester.pumpAndSettle();

    expect(hostKey.currentState!.destination, 'units');
    expect(find.text('Tela B'), findsOneWidget);
    expect(_counterText(tester), '5 de 5');
    await tester.tap(find.byKey(_next));
    await _pumpFrames(tester, 5);
    await tester.pumpAndSettle();
    expect(store.lastCompleteOutcome, 'done');
    expect(hostKey.currentState!.destination, 'institutions');
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
