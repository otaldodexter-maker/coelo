import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders an empty or error state with title, message, and icon', (tester) async {
    await tester.pumpWidget(
      const _TestApp(
        child: CoeloStatePanel(
          title: 'Nenhuma instituição',
          message: 'Ainda não há instituições cadastradas.',
          icon: Icons.apartment_outlined,
        ),
      ),
    );

    expect(find.text('Nenhuma instituição'), findsOneWidget);
    expect(find.text('Ainda não há instituições cadastradas.'), findsOneWidget);
    expect(find.byIcon(Icons.apartment_outlined), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('invokes its optional action', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _TestApp(
        child: CoeloStatePanel(
          title: 'Não foi possível carregar',
          message: 'Tente novamente.',
          actionLabel: 'Tentar novamente',
          onAction: () => calls++,
        ),
      ),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Tentar novamente'));
    expect(calls, 1);
  });

  testWidgets('renders only progress feedback while loading', (tester) async {
    await tester.pumpWidget(
      const _TestApp(
        child: CoeloStatePanel(title: 'Carregando', message: 'Aguarde.', loading: true),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Carregando'), findsNothing);
    expect(find.text('Aguarde.'), findsNothing);
  });

  testWidgets('supports 200 percent text at 375 logical pixels', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const _TestApp(
        textScaler: TextScaler.linear(2),
        child: CoeloStatePanel(
          title: 'Nenhuma instituição encontrada',
          message: 'Revise os filtros selecionados e tente novamente.',
          actionLabel: 'Limpar filtros',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Nenhuma instituição encontrada'), findsOneWidget);
  });

  testWidgets('scrolls long feedback inside a short 200 percent viewport', (tester) async {
    await tester.pumpWidget(
      const _TestApp(
        textScaler: TextScaler.linear(2),
        child: SizedBox(
          width: 375,
          height: 391,
          child: CoeloStatePanel(
            title: 'Carregando opções',
            message: 'Buscando contextos, perfis e Pessoas autorizadas.',
            icon: Icons.hourglass_top_rounded,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Carregando opções'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child, this.textScaler = TextScaler.noScaling});

  final Widget child;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        );
      },
      home: Scaffold(
        body: Center(
          child: Padding(padding: const EdgeInsets.all(CoeloSpacing.space4), child: child),
        ),
      ),
    );
  }
}
