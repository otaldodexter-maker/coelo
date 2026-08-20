import 'package:coelo_superadmin/features/principal_for_you/presentation/principal_for_you_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalForYouPreviewPage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the approved mobile anatomy', (tester) async {
    await pumpPage(tester, const Size(375, 900));

    expect(find.byKey(const Key('principal-for-you-scroll')), findsOneWidget);
    expect(find.byKey(const Key('principal-for-you-mobile-nav')), findsOneWidget);
    expect(find.byKey(const Key('principal-for-you-desktop-rail')), findsNothing);
    expect(find.text('Bom dia, Fernanda!'), findsOneWidget);
    expect(find.text('Feira Cultural hoje!'), findsOneWidget);
    expect(find.text('Atalhos essenciais'), findsOneWidget);
    expect(find.text('Resumo do dia'), findsOneWidget);
    expect(find.text('Seu contexto atual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapts tablet and desktop without overflow', (tester) async {
    await pumpPage(tester, const Size(768, 1024));
    expect(find.byKey(const Key('principal-for-you-desktop-rail')), findsNothing);
    expect(find.byKey(const Key('principal-for-you-summary-aside')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-for-you-desktop-rail')), findsOneWidget);
    expect(find.byKey(const Key('principal-for-you-summary-aside')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the context selector and updates the active projection', (tester) async {
    await pumpPage(tester, const Size(375, 900));

    await tester.tap(find.byKey(const Key('principal-for-you-context-trigger')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-for-you-context-sheet')), findsOneWidget);

    await tester.tap(find.text('Beatriz Silva'));
    await tester.pumpAndSettle();
    expect(find.text('Beatriz Silva'), findsWidgets);
    expect(find.text('3º ano A'), findsWidgets);
  });

  testWidgets('dismisses the context selector with escape', (tester) async {
    await pumpPage(tester, const Size(768, 1024));
    final trigger = find.byKey(const Key('principal-for-you-context-trigger')).first;

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-for-you-context-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [600.0, 839.0, 840.0, 1024.0]) {
    testWidgets('has no layout exception at ${width.toInt()} px', (tester) async {
      await pumpPage(tester, Size(width, 1000));
      expect(find.byKey(const Key('principal-for-you-scroll')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('supports 200 percent text and reduced motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
          child: child!,
        ),
        home: const PrincipalForYouPreviewPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-for-you-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
