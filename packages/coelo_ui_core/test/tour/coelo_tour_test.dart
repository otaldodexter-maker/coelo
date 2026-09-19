import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _steps = <CoeloTourStep>[
  CoeloTourStep(anchorId: 'a', title: 'Primeiro', text: 'Texto do primeiro passo.'),
  CoeloTourStep(anchorId: 'hidden', title: 'Oculto', text: 'Nunca aparece.'),
  CoeloTourStep(anchorId: 'b', title: 'Segundo', text: 'Texto do segundo passo.'),
  CoeloTourStep(anchorId: 'c', title: 'Terceiro', text: 'Texto do terceiro passo.'),
];

void _resize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host({required CoeloTourAnchorRegistry registry, List<String>? prepared}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    home: CoeloTourScope(
      registry: registry,
      child: Scaffold(
        body: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoeloTourAnchor(id: 'a', child: const Text('Item A')),
              CoeloTourAnchor(id: 'b', child: const Text('Item B')),
              CoeloTourAnchor(id: 'c', child: const Text('Item C')),
              FilledButton(
                key: const Key('start'),
                onPressed: () => showCoeloTour(
                  context,
                  steps: _steps,
                  registry: registry,
                  onPrepareStep: (step) async => prepared?.add(step.anchorId),
                ),
                child: const Text('Iniciar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('start')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('navega pelos passos, pula âncora ausente e conclui no último', (tester) async {
    final registry = CoeloTourAnchorRegistry();
    final prepared = <String>[];
    _resize(tester, const Size(1200, 800));
    await tester.pumpWidget(_host(registry: registry, prepared: prepared));
    await _start(tester);

    expect(find.byKey(const Key('coelo-tour-balloon')), findsOneWidget);
    expect(find.text('Primeiro'), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);
    final back = tester.widget<OutlinedButton>(find.byKey(const Key('coelo-tour-back')));
    expect(back.onPressed, isNull);

    await tester.tap(find.byKey(const Key('coelo-tour-next')));
    await tester.pumpAndSettle();
    expect(find.text('Segundo'), findsOneWidget);
    expect(find.text('2 de 3'), findsOneWidget);
    expect(prepared, ['a', 'b']);

    await tester.tap(find.byKey(const Key('coelo-tour-back')));
    await tester.pumpAndSettle();
    expect(find.text('Primeiro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coelo-tour-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-tour-next')));
    await tester.pumpAndSettle();
    expect(find.text('Terceiro'), findsOneWidget);
    expect(find.text('3 de 3'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);
    expect(find.text('Próximo'), findsNothing);

    await tester.tap(find.byKey(const Key('coelo-tour-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-tour-balloon')), findsNothing);
  });

  testWidgets('Pular tour fecha o overlay e devolve skipped', (tester) async {
    final registry = CoeloTourAnchorRegistry();
    CoeloTourOutcome? outcome;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: CoeloTourScope(
          registry: registry,
          child: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  CoeloTourAnchor(id: 'a', child: const Text('Item A')),
                  FilledButton(
                    key: const Key('start'),
                    onPressed: () async {
                      outcome = await showCoeloTour(context, steps: _steps, registry: registry);
                    },
                    child: const Text('Iniciar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _start(tester);
    await tester.tap(find.byKey(const Key('coelo-tour-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-tour-balloon')), findsNothing);
    expect(outcome, CoeloTourOutcome.skipped);
  });

  testWidgets('teclado: → e Enter avançam, ← volta, Esc pula', (tester) async {
    final registry = CoeloTourAnchorRegistry();
    _resize(tester, const Size(1200, 800));
    await tester.pumpWidget(_host(registry: registry));
    await _start(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Segundo'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Terceiro'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Segundo'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-tour-balloon')), findsNothing);
  });

  testWidgets('sem nenhuma âncora visível o tour termina sem abrir balão', (tester) async {
    final registry = CoeloTourAnchorRegistry();
    CoeloTourOutcome? outcome;
    await tester.pumpWidget(
      MaterialApp(
        home: CoeloTourScope(
          registry: registry,
          child: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                key: const Key('start'),
                onPressed: () async {
                  outcome = await showCoeloTour(context, steps: _steps, registry: registry);
                },
                child: const Text('Iniciar'),
              ),
            ),
          ),
        ),
      ),
    );
    await _start(tester);
    expect(find.byKey(const Key('coelo-tour-balloon')), findsNothing);
    expect(outcome, CoeloTourOutcome.unavailable);
  });

  testWidgets('em tela estreita o balão vira folha inferior', (tester) async {
    final registry = CoeloTourAnchorRegistry();
    _resize(tester, const Size(600, 900));
    await tester.pumpWidget(_host(registry: registry));
    await _start(tester);

    final balloon = tester.getRect(find.byKey(const Key('coelo-tour-balloon')));
    expect(balloon.bottom, 900);
    expect(balloon.left, 0);
    expect(balloon.width, 600);
  });

  testWidgets('em tela estreita, âncora na metade de baixo leva a folha ao topo', (tester) async {
    final registry = CoeloTourAnchorRegistry();
    _resize(tester, const Size(600, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: CoeloTourScope(
          registry: registry,
          child: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  FilledButton(
                    key: const Key('start'),
                    onPressed: () => showCoeloTour(
                      context,
                      steps: const [CoeloTourStep(anchorId: 'low', title: 'Baixo', text: 'x')],
                      registry: registry,
                    ),
                    child: const Text('Iniciar'),
                  ),
                  const Spacer(),
                  CoeloTourAnchor(id: 'low', child: const Text('Item baixo')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _start(tester);
    final balloon = tester.getRect(find.byKey(const Key('coelo-tour-balloon')));
    expect(balloon.top, 0);
    expect(balloon.overlaps(tester.getRect(find.text('Item baixo'))), isFalse);
  });

  testWidgets('em tela larga o balão fica ao lado da âncora sem cobri-la', (tester) async {
    final registry = CoeloTourAnchorRegistry();
    _resize(tester, const Size(1200, 800));
    await tester.pumpWidget(_host(registry: registry));
    await _start(tester);

    final anchor = tester.getRect(find.text('Item A'));
    final balloon = tester.getRect(find.byKey(const Key('coelo-tour-balloon')));
    expect(balloon.overlaps(anchor), isFalse);
    expect(balloon.left, greaterThan(anchor.right));
  });

  testWidgets('os botões do balão são nós de semântica próprios (não fundidos no rótulo)', (
    tester,
  ) async {
    final registry = CoeloTourAnchorRegistry();
    _resize(tester, const Size(1200, 800));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(registry: registry));
    await _start(tester);

    final next = tester.getSemantics(find.byKey(const Key('coelo-tour-next')));
    expect(next.label, 'Próximo');
    expect(next.flagsCollection.isButton, isTrue);
    final skip = tester.getSemantics(find.byKey(const Key('coelo-tour-skip')));
    expect(skip.label, 'Pular tour');
    expect(skip.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('segmento: contador com deslocamento, Próximo no último passo e Voltar no primeiro', (
    tester,
  ) async {
    final registry = CoeloTourAnchorRegistry();
    _resize(tester, const Size(1200, 800));
    CoeloTourOutcome? outcome;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: CoeloTourScope(
          registry: registry,
          child: Scaffold(
            body: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoeloTourAnchor(id: 'a', child: const Text('Item A')),
                  CoeloTourAnchor(id: 'b', child: const Text('Item B')),
                  FilledButton(
                    key: const Key('start'),
                    onPressed: () async {
                      outcome = await showCoeloTour(
                        context,
                        steps: const [
                          CoeloTourStep(anchorId: 'a', title: 'A', text: 'x'),
                          CoeloTourStep(anchorId: 'b', title: 'B', text: 'x'),
                        ],
                        registry: registry,
                        segment: const CoeloTourSegment(
                          counterOffset: 10,
                          counterTotal: 20,
                          continuesAfter: true,
                          allowBackFromFirst: true,
                        ),
                      );
                    },
                    child: const Text('Iniciar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await _start(tester);
    expect(find.text('11 de 20'), findsOneWidget);
    await tester.tap(find.byKey(const Key('coelo-tour-next')));
    await tester.pumpAndSettle();
    expect(find.text('12 de 20'), findsOneWidget);
    // Último passo de um segmento intermediário continua com "Próximo".
    expect(find.text('Próximo'), findsOneWidget);
    expect(find.text('Concluir'), findsNothing);
    await tester.tap(find.byKey(const Key('coelo-tour-back')));
    await tester.pumpAndSettle();
    // "Voltar" no primeiro passo devolve `back`.
    await tester.tap(find.byKey(const Key('coelo-tour-back')));
    await tester.pumpAndSettle();
    expect(outcome, CoeloTourOutcome.back);
    expect(find.byKey(const Key('coelo-tour-balloon')), findsNothing);
  });
}
