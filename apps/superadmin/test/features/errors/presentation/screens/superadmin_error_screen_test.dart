import 'dart:async';

import 'package:coelo_superadmin/features/errors/presentation/screens/superadmin_error_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pending error action runs once and becomes available after completion', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _actionApp(() async {
        calls++;
        await pending.future;
      }),
    );
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(find.text('Aguarde…'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
    await tester.tap(find.byType(TextButton));
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNotNull);
  });

  testWidgets('error action failure is sanitized and keyboard retry remains available', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _actionApp(() async {
        if (++calls == 1) throw StateError('private tenant token detail');
      }),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível concluir esta ação.'), findsOneWidget);
    expect(find.textContaining('private tenant'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('replaced error callback ignores the old completion while the new one runs', (
    tester,
  ) async {
    final first = Completer<void>();
    final second = Completer<void>();
    await tester.pumpWidget(_actionApp(() => first.future));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pumpWidget(_actionApp(() => second.future));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    first.completeError(StateError('stale private detail'));
    await tester.pump();
    expect(find.text('Aguarde…'), findsOneWidget);
    expect(find.text('Não foi possível concluir esta ação.'), findsNothing);
    second.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing an error screen discards a late action failure', (tester) async {
    final pending = Completer<void>();
    await tester.pumpWidget(_actionApp(() => pending.future));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.completeError(StateError('late private detail'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('recognizes conflict without treating it as a missing page', () {
    expect(SuperadminErrorKind.fromCode('409').code, '409');
    expect(SuperadminErrorKind.fromCode('409').actionLabel, 'Voltar ao início');
    for (final unknown in [null, '401', '409 private detail', '<script>']) {
      expect(SuperadminErrorKind.fromCode(unknown), SuperadminErrorKind.notFound);
    }
  });

  testWidgets('conflict delegates safe navigation by keyboard without automatic retry', (
    tester,
  ) async {
    var actions = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: SuperadminErrorScreen(
          kind: SuperadminErrorKind.fromCode('409'),
          onAction: () => actions++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('409'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(actions, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(tester.takeException(), isNull);
  });

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
      kind: SuperadminErrorKind.conflict,
      code: '409',
      message: 'Esta ação não pode ser concluída no estado atual.',
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
    for (final brightness in Brightness.values) {
      testWidgets('conflict at 200 percent ${size.width} $brightness remains usable', (
        tester,
      ) async {
        await _pumpError(
          tester,
          size: size,
          textScaler: const TextScaler.linear(2),
          kind: SuperadminErrorKind.conflict,
          brightness: brightness,
        );
        expect(find.text('409'), findsOneWidget);
        expect(find.text('Voltar ao início'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
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

  testWidgets('switches from wide geometry to compact geometry at 200 percent', (tester) async {
    await _pumpError(tester, size: const Size(1024, 900));

    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
    expect(
      tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView)).padding,
      const EdgeInsets.symmetric(horizontal: CoeloSpacing.space10, vertical: CoeloSpacing.space8),
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ConstrainedBox && widget.constraints.maxWidth == 720,
      ),
      findsOneWidget,
    );

    await _pumpError(tester, size: const Size(1024, 900), textScaler: const TextScaler.linear(2));

    expect(find.byType(VerticalDivider), findsNothing);
    expect(find.byType(Divider), findsOneWidget);
    expect(
      tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView)).padding,
      const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4, vertical: CoeloSpacing.space8),
    );
  });
}

Future<void> _pumpError(
  WidgetTester tester, {
  required Size size,
  TextScaler textScaler = TextScaler.noScaling,
  SuperadminErrorKind kind = SuperadminErrorKind.notFound,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? CoeloTheme.dark : CoeloTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: textScaler),
        child: SuperadminErrorScreen(kind: kind, onAction: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _actionApp(Future<void> Function() action) => MaterialApp(
  theme: CoeloTheme.light,
  home: SuperadminErrorScreen(kind: SuperadminErrorKind.unavailable, onAction: action),
);
