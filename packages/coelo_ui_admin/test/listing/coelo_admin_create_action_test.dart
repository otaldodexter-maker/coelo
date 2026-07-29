import 'dart:ui' show PointerDeviceKind, SemanticsAction;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('activates by pointer, Enter and Space and disables with null callback', (
    tester,
  ) async {
    var calls = 0;
    await _pumpAction(tester, onPressed: () => calls += 1);

    await tester.tap(find.text('Criar instituição'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(calls, 3);

    await _pumpAction(tester, onPressed: null);
    expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
  });

  testWidgets('uses semantic label, hover state and reduced motion', (tester) async {
    await _pumpAction(tester, disableAnimations: true);

    final semantics = tester.getSemantics(find.text('Criar instituição'));
    expect(semantics.label, contains('Criar instituição'));
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(InkWell)));
    await tester.pump();

    var animation = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>).first,
    );
    expect(animation.tween.end, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    animation = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>).first,
    );
    expect(animation.duration, Duration.zero);
  });

  testWidgets('uses the supplied icon', (tester) async {
    await _pumpAction(tester, icon: Icons.add_business_outlined);
    expect(find.byIcon(Icons.add_business_outlined), findsOneWidget);
  });

  testWidgets('keeps tile as default and offers a horizontal banner', (tester) async {
    await _pumpAction(tester);
    expect(
      find.descendant(of: find.byType(CoeloAdminCreateAction), matching: find.byType(Column)),
      findsOneWidget,
    );

    await _pumpAction(tester, variant: CoeloAdminCreateActionVariant.banner);
    expect(
      find.descendant(of: find.byType(CoeloAdminCreateAction), matching: find.byType(Row)),
      findsOneWidget,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).size, CoeloSize.iconSm);
    expect(tester.widget<Row>(find.byType(Row)).mainAxisAlignment, MainAxisAlignment.center);
  });

  testWidgets('shows optional supporting description only in the banner', (tester) async {
    await _pumpAction(
      tester,
      variant: CoeloAdminCreateActionVariant.banner,
      description: 'Cadastre identidade e vínculos contextuais.',
    );
    expect(find.text('Cadastre identidade e vínculos contextuais.'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Criar instituição')).label,
      contains('Cadastre identidade e vínculos contextuais.'),
    );

    await _pumpAction(tester, description: 'Não pertence ao tile.');
    expect(find.text('Não pertence ao tile.'), findsNothing);
  });

  testWidgets('banner grows without overflow in light and dark at 200%', (tester) async {
    const description =
        'Cadastre uma pessoa e revise cuidadosamente os vínculos contextuais antes de continuar.';
    await _pumpNaturalBanner(tester, theme: CoeloTheme.light, description: description);
    final baseHeight = tester.getSize(find.byType(CoeloAdminCreateAction)).height;

    for (final theme in [CoeloTheme.light, CoeloTheme.dark]) {
      await _pumpNaturalBanner(
        tester,
        theme: theme,
        description: description,
        textScaler: const TextScaler.linear(2),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CoeloAdminCreateAction)).height, greaterThan(baseHeight));
      expect(tester.getSemantics(find.text('Criar instituição')).label, contains(description));
    }
  });

  testWidgets('removes semantic activation when disabled', (tester) async {
    await _pumpAction(tester, onPressed: null);

    final semantics = tester.getSemantics(find.text('Criar instituição'));
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
  });

  testWidgets('keeps the approved public widget stateless', (tester) async {
    await _pumpAction(tester);

    expect(
      tester.widget<CoeloAdminCreateAction>(find.byType(CoeloAdminCreateAction)),
      isA<StatelessWidget>(),
    );
  });
}

Future<void> _pumpAction(
  WidgetTester tester, {
  VoidCallback? onPressed = _noop,
  IconData icon = Icons.add,
  bool disableAnimations = false,
  CoeloAdminCreateActionVariant variant = CoeloAdminCreateActionVariant.tile,
  String? description,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 216,
          child: CoeloAdminCreateAction(
            label: 'Criar instituição',
            onPressed: onPressed,
            icon: icon,
            variant: variant,
            description: description,
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpNaturalBanner(
  WidgetTester tester, {
  required ThemeData theme,
  required String description,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: CoeloAdminCreateAction(
                label: 'Criar instituição',
                description: description,
                onPressed: _noop,
                variant: CoeloAdminCreateActionVariant.banner,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void _noop() {}
