import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cases = [
    (
      kind: SuperadminErrorKind.forbidden,
      code: '403',
      message: 'Você não tem permissão para acessar esta área.',
      action: 'Voltar ao início',
    ),
    (
      kind: SuperadminErrorKind.notFound,
      code: '404',
      message: 'Não encontramos a página que você procura.',
      action: 'Voltar ao início',
    ),
    (
      kind: SuperadminErrorKind.internal,
      code: '500',
      message: 'Não foi possível concluir esta ação.',
      action: 'Tentar novamente',
    ),
    (
      kind: SuperadminErrorKind.unavailable,
      code: '503',
      message: 'O Coelo está temporariamente indisponível.',
      action: 'Tentar novamente',
    ),
  ];

  for (final errorCase in cases) {
    testWidgets('renders ${errorCase.code} content and delegates its action', (tester) async {
      var actionCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: SuperadminErrorScreen(kind: errorCase.kind, onAction: () => actionCount += 1),
        ),
      );

      expect(find.text(errorCase.code), findsOneWidget);
      expect(find.text(errorCase.message), findsOneWidget);
      expect(find.text(errorCase.action), findsOneWidget);
      expect(find.bySemanticsLabel('Erro ${errorCase.code}. ${errorCase.message}'), findsOneWidget);

      await tester.tap(find.text(errorCase.action));
      expect(actionCount, 1);
    });
  }

  for (final size in const [Size(375, 844), Size(768, 900), Size(1024, 900), Size(1440, 900)]) {
    testWidgets('renders without overflow at ${size.width.toInt()} pixels', (tester) async {
      await _pumpError(tester, size: size);

      expect(tester.takeException(), isNull);
      expect(find.byType(SuperadminErrorScreen), findsOneWidget);
    });
  }

  testWidgets('renders compact layout with text at 200 percent', (tester) async {
    await _pumpError(tester, size: const Size(375, 844), textScaler: const TextScaler.linear(2));

    expect(tester.takeException(), isNull);
    expect(find.byType(SuperadminErrorScreen), findsOneWidget);
  });
}

Future<void> _pumpError(
  WidgetTester tester, {
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: textScaler),
        child: SuperadminErrorScreen(kind: SuperadminErrorKind.notFound, onAction: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
