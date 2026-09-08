import 'dart:ui';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('measurement style honors accessibility bold text', (tester) async {
    await _pumpStatus(tester, label: 'Suspenso', textScale: 2, boldText: true);
    await tester.tap(find.byKey(const Key('expandable-status-surface')));
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('Suspenso'));
    expect(text.style!.fontWeight, FontWeight.bold);
  });
  testWidgets('screen reader tap toggles the expanded label', (tester) async {
    await _pumpStatus(tester);
    final node = tester.getSemantics(find.bySemanticsLabel('Status: Ativa'));
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ativa'), findsOneWidget);
  });
  testWidgets('keyboard status activation does not activate ancestor card', (tester) async {
    var cardOpens = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Center(
            child: CoeloAdminInteractiveCard(
              onPressed: () => cardOpens++,
              child: const CoeloAdminExpandableStatusIndicator(
                label: 'Ativa',
                backgroundColor: Color(0xFFE8F5EE),
                foregroundColor: Color(0xFF166534),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Ativa'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(cardOpens, 0);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Ativa'), findsOneWidget);
  });
  testWidgets('touch outside visual dot activates the minimum semantic target', (tester) async {
    await _pumpStatus(tester);
    final target = find.byType(CoeloAdminExpandableStatusIndicator);
    final rect = tester.getRect(target);
    final semantics = tester.getSemantics(find.bySemanticsLabel('Status: Ativa'));
    expect(semantics.rect.height, greaterThanOrEqualTo(CoeloSize.touchMin));
    await tester.tapAt(rect.topRight + const Offset(-2, 2));
    await tester.pumpAndSettle();
    expect(find.text('Ativa'), findsOneWidget);
  });
  for (final dark in [false, true]) {
    testWidgets('error status preserves contrast colors and visible keyboard focus dark=$dark', (
      tester,
    ) async {
      final tokens = dark ? CoeloStatusColors.dark : CoeloStatusColors.light;
      final foreground = tokens.onErrorContainer;
      final background = tokens.errorContainer;
      final luminances = [foreground.computeLuminance(), background.computeLuminance()]..sort();
      expect((luminances.last + .05) / (luminances.first + .05), greaterThanOrEqualTo(4.5));
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? CoeloTheme.dark : CoeloTheme.light,
          home: Scaffold(
            body: Center(
              child: CoeloAdminExpandableStatusIndicator(
                label: 'Suspenso',
                backgroundColor: background,
                foregroundColor: foreground,
                surfaceKey: const Key('contrast-status'),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final decoration =
          tester.widget<Container>(find.byKey(const Key('contrast-status'))).decoration!
              as BoxDecoration;
      expect(decoration.color, background);
      expect((decoration.border! as Border).top.width, 2);
      expect(tester.widget<Text>(find.text('Suspenso')).style!.color, foreground);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('long label wraps without clipping in compact text200 surface', (tester) async {
    await _pumpStatus(tester, label: 'Aguardando confirmação', textScale: 2, maxWidth: 240);
    await tester.tap(find.byKey(const Key('expandable-status-surface')));
    await tester.pumpAndSettle();
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text('Aguardando confirmação'), matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: TextDirection.ltr,
      textScaler: paragraph.textScaler,
    )..layout(maxWidth: paragraph.size.width);
    expect(paragraph.size.height, greaterThanOrEqualTo(painter.height));
    painter.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('interactive target is at least touchMin while visual dot stays 24', (tester) async {
    await _pumpStatus(tester);
    final target = tester.getSize(find.byType(CoeloAdminExpandableStatusIndicator));
    expect(target.width, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(target.height, greaterThanOrEqualTo(CoeloSize.touchMin));
    expect(
      tester.getSize(find.byKey(const Key('expandable-status-surface'))),
      const Size.square(24),
    );
  });
  for (final label in ['Suspenso', 'Arquivado', 'Aguardando confirmação']) {
    testWidgets('whole label $label fits at text200', (tester) async {
      await _pumpStatus(tester, label: label, textScale: 2);
      await tester.tap(find.byKey(const Key('expandable-status-surface')));
      await tester.pumpAndSettle();
      final text = find.text(label);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout();
      expect(paragraph.size.width, greaterThanOrEqualTo(painter.width));
      expect(paragraph.size.height, greaterThanOrEqualTo(painter.height));
      painter.dispose();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Enter and Space persist and release expansion after focus leaves', (tester) async {
    await _pumpStatus(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.text('Ativa'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Ativa'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Ativa'), findsNothing);
  });
  testWidgets('starts as a 24 pixel dot with its label hidden', (tester) async {
    await _pumpStatus(tester);

    final surface = find.byKey(const Key('expandable-status-surface'));
    expect(tester.getSize(surface), const Size.square(24));
    expect(find.text('Ativa'), findsNothing);
    expect(find.bySemanticsLabel('Status: Ativa'), findsOneWidget);
  });

  testWidgets('reveals the status on hover without a gray overlay', (tester) async {
    await _pumpStatus(tester);
    final surface = find.byKey(const Key('expandable-status-surface'));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(surface));
    await tester.pumpAndSettle();

    expect(find.text('Ativa'), findsOneWidget);
    expect(tester.getSize(surface).width, greaterThan(CoeloSpacing.space8));
    final decoration = tester.widget<Container>(surface).decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFE8F5EE));
    expect(decoration.borderRadius, BorderRadius.circular(CoeloRadius.full));
  });

  testWidgets('tap keeps the label expanded for touch users', (tester) async {
    await _pumpStatus(tester);
    final surface = find.byKey(const Key('expandable-status-surface'));

    await tester.tap(surface);
    await tester.pumpAndSettle();

    expect(find.text('Ativa'), findsOneWidget);
  });

  testWidgets('uses instant motion when animations are disabled', (tester) async {
    await _pumpStatus(tester, disableAnimations: true);

    final animation = tester.widget<TweenAnimationBuilder<double>>(
      find.byType(TweenAnimationBuilder<double>),
    );
    expect(animation.duration, Duration.zero);
  });
}

Future<void> _pumpStatus(
  WidgetTester tester, {
  bool disableAnimations = false,
  String label = 'Ativa',
  double textScale = 1,
  double maxWidth = 800,
  bool boldText = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
            boldText: boldText,
          ),
          child: Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: CoeloAdminExpandableStatusIndicator(
                  label: label,
                  semanticLabel: 'Status: $label',
                  backgroundColor: const Color(0xFFE8F5EE),
                  foregroundColor: const Color(0xFF166534),
                  surfaceKey: const Key('expandable-status-surface'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
