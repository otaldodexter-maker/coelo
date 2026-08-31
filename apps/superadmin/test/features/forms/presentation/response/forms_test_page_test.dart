import 'package:coelo_superadmin/features/forms/presentation/response/forms_test_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(Widget child, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
    theme: CoeloTheme.light,
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: child,
    ),
  );

  testWidgets('is a static unavailable surface without API or success state', (tester) async {
    await tester.pumpWidget(app(const FormsTestPage()));

    expect(find.text('Teste de formulário indisponível'), findsOneWidget);
    expect(find.textContaining('temporariamente indisponível'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('development validates, navigates, preserves answer and finishes only locally', (
    tester,
  ) async {
    await tester.pumpWidget(app(const FormsTestPage.development()));

    expect(find.text('Teste do formulário'), findsOneWidget);
    expect(find.text('Pesquisa das famílias'), findsOneWidget);
    expect(find.text('Resposta identificada'), findsOneWidget);
    expect(find.text('Fixture local · nenhuma resposta será persistida'), findsOneWidget);
    expect(find.text('Etapa 1 de 2'), findsOneWidget);

    await tester.drag(find.byKey(const Key('forms-test-scroll')), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-test-next')));
    await tester.pump();
    expect(find.text('Selecione uma opção para continuar.'), findsOneWidget);
    expect(find.text('Etapa 1 de 2'), findsOneWidget);

    await tester.tap(find.text('Muito boa'));
    await tester.enterText(
      find.byKey(const Key('forms-test-comment')),
      'A comunicação está clara.',
    );
    await tester.tap(find.byKey(const Key('forms-test-next')));
    await tester.pumpAndSettle();
    expect(find.text('Etapa 2 de 2'), findsOneWidget);
    expect(find.text('Revise sua resposta'), findsOneWidget);
    expect(find.text('Muito boa'), findsWidgets);
    expect(find.text('A comunicação está clara.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('forms-test-back')));
    await tester.pumpAndSettle();
    expect(find.text('Etapa 1 de 2'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('forms-test-comment'))).controller!.text,
      'A comunicação está clara.',
    );

    await tester.tap(find.byKey(const Key('forms-test-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-test-finish')));
    await tester.pumpAndSettle();
    expect(find.text('Teste concluído nesta demonstração'), findsOneWidget);
    expect(find.textContaining('Nenhuma persistência remota'), findsOneWidget);
    await tester.tap(find.text('Recomeçar teste'));
    await tester.pumpAndSettle();
    expect(find.text('Etapa 1 de 2'), findsOneWidget);
    expect(find.text('Teste concluído nesta demonstração'), findsNothing);
  });

  testWidgets('development alterna preview e modo anônimo sem capturar identidade', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1100);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(app(const FormsTestPage.development(anonymous: true)));

    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.textContaining('não registra identidade'), findsOneWidget);
    expect(find.textContaining('Respondendo como'), findsNothing);
    expect(find.byKey(const Key('forms-test-preview')), findsOneWidget);

    await tester.tap(find.byKey(const Key('forms-test-preview-mobile')));
    await tester.pumpAndSettle();
    final mobile = tester.getSize(find.byKey(const Key('forms-test-preview')));
    expect(mobile.width, lessThanOrEqualTo(375));

    await tester.tap(find.text('Identificada'));
    await tester.pumpAndSettle();
    expect(find.text('Resposta identificada'), findsOneWidget);
    expect(find.textContaining('Respondendo como'), findsOneWidget);
  });

  testWidgets('development remains overflow-free at responsive widths and 200% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1200);
      await tester.pumpWidget(
        app(const FormsTestPage.development(), textScaler: const TextScaler.linear(2)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $width px');
    }
  });
}
