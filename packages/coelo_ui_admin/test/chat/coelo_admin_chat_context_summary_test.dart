import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires between two and six metrics', () {
    expect(
      () => CoeloAdminChatContextSummary(
        title: 'Centro Horizonte',
        subtitle: 'Fortaleza · CE',
        metrics: const [CoeloAdminChatMetric('Unidades', 3)],
        collapsed: false,
        onToggle: _noop,
      ),
      throwsAssertionError,
    );
    expect(
      () => CoeloAdminChatContextSummary(
        title: 'Centro Horizonte',
        subtitle: 'Fortaleza · CE',
        metrics: List.generate(7, (index) => CoeloAdminChatMetric('Métrica $index', index)),
        collapsed: false,
        onToggle: _noop,
      ),
      throwsAssertionError,
    );
  });

  for (final metricCount in [2, 6]) {
    testWidgets('renders $metricCount textual metrics with semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      final metrics = List.generate(
        metricCount,
        (index) => CoeloAdminChatMetric('Métrica ${index + 1}', index + 1),
      );

      await tester.pumpWidget(_app(metrics: metrics));

      expect(find.byKey(const Key('coelo-admin-chat-context-metric')), findsNWidgets(metricCount));
      for (final metric in metrics) {
        expect(find.text(metric.label), findsOne);
        expect(find.text('${metric.value}'), findsOne);
        expect(
          tester.getSemantics(find.text(metric.label)),
          matchesSemantics(label: '${metric.label}: ${metric.value}'),
        );
      }
      semantics.dispose();
    });
  }

  testWidgets('keeps the optional context image square and capped at avatarXl', (tester) async {
    await tester.pumpWidget(_app(image: const ColoredBox(color: Colors.blue)));

    final size = tester.getSize(find.byKey(const Key('coelo-admin-chat-context-image')));
    expect(size, const Size.square(CoeloSize.avatarXl));
  });

  testWidgets('exposes a focusable toggle and the collapsed state', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    var toggles = 0;

    await tester.pumpWidget(_app(toggleFocusNode: focusNode, onToggle: () => toggles++));
    focusNode.requestFocus();
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    await tester.tap(find.byTooltip('Recolher painel contextual'));
    expect(toggles, 1);

    await tester.pumpWidget(
      _app(collapsed: true, toggleFocusNode: focusNode, onToggle: () => toggles++),
    );
    expect(find.byKey(const Key('coelo-admin-chat-context-summary-collapsed')), findsOne);
    await tester.tap(find.byTooltip('Mostrar detalhes do contexto'));
    expect(toggles, 2);
  });

  for (final themeCase in [
    (name: 'light', theme: CoeloTheme.light),
    (name: 'dark', theme: CoeloTheme.dark),
  ]) {
    testWidgets('supports ${themeCase.name} theme and 200 percent text', (tester) async {
      await tester.pumpWidget(
        _app(theme: themeCase.theme, textScaler: const TextScaler.linear(2), width: 320),
      );

      expect(find.byKey(const Key('coelo-admin-chat-context-summary')), findsOne);
      expect(find.text('Centro Horizonte'), findsOne);
      expect(find.text('Dados simulados'), findsOne);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _app({
  List<CoeloAdminChatMetric> metrics = const [
    CoeloAdminChatMetric('Unidades', 3),
    CoeloAdminChatMetric('Grupos', 14),
    CoeloAdminChatMetric('Atividades', 21),
    CoeloAdminChatMetric('Pessoas', 284),
  ],
  Widget? image,
  FocusNode? toggleFocusNode,
  VoidCallback onToggle = _noop,
  bool collapsed = false,
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
  double width = 288,
}) {
  return MaterialApp(
    theme: theme ?? CoeloTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: 720,
        child: CoeloAdminChatContextSummary(
          title: 'Centro Horizonte',
          subtitle: 'Fortaleza · CE',
          metrics: metrics,
          image: image,
          collapsed: collapsed,
          toggleFocusNode: toggleFocusNode,
          onToggle: onToggle,
          footer: const Text('Dados simulados'),
        ),
      ),
    ),
  );
}

void _noop() {}
