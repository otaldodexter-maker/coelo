import 'package:coelo_superadmin/features/principal_for_you/domain/principal_for_you_preview_data.dart';
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
    expect(find.byKey(const Key('principal-global-dock')), findsOneWidget);
    expect(find.byKey(const Key('principal-for-you-mobile-nav')), findsNothing);
    expect(find.byKey(const Key('principal-for-you-desktop-rail')), findsNothing);
    expect(find.text('Bom dia, Fernanda!'), findsOneWidget);
    expect(find.text('Feira Cultural hoje!'), findsOneWidget);
    expect(find.text('Atalhos essenciais'), findsOneWidget);
    expect(find.text('Resumo do dia'), findsOneWidget);
    expect(find.text('Seu contexto atual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves editorial media without stretching', (tester) async {
    await pumpPage(tester, const Size(768, 1024));

    final fixtureImages = tester
        .widgetList<Image>(find.byType(Image))
        .where((image) => image.image is AssetImage);
    expect(fixtureImages, isNotEmpty);
    expect(fixtureImages.every((image) => image.fit == BoxFit.cover), isTrue);
  });

  testWidgets('keeps protagonist copy complete at 200 percent text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const PrincipalForYouPreviewPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('Feira Cultural hoje!')).maxLines, isNull);
    expect(
      tester
          .widget<Text>(
            find.text('A partir das 16h, no pátio da unidade. Participe com sua família!'),
          )
          .maxLines,
      isNull,
    );
    expect(
      tester
          .getSize(find.text('A partir das 16h, no pátio da unidade. Participe com sua família!'))
          .height,
      greaterThanOrEqualTo(140),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('adapts tablet and desktop without overflow', (tester) async {
    await pumpPage(tester, const Size(768, 1024));
    expect(find.byKey(const Key('principal-global-dock')), findsOneWidget);
    expect(find.byKey(const Key('principal-for-you-desktop-rail')), findsNothing);
    expect(find.byKey(const Key('principal-for-you-summary-aside')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-global-dock')), findsOneWidget);
    expect(find.byKey(const Key('principal-for-you-desktop-rail')), findsNothing);
    expect(find.byKey(const Key('principal-for-you-summary-aside')), findsNothing);
    expect(
      tester.getTopLeft(find.text('Resumo do dia')).dy,
      greaterThan(tester.getTopLeft(find.text('Para você').first).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded web preview omits its own application chrome', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const PrincipalForYouPreviewPage(embedded: true)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-for-you-desktop-rail')), findsNothing);
    expect(find.byKey(const Key('principal-for-you-mobile-nav')), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('principal-for-you-summary-aside')), findsNothing);
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

  testWidgets('resets the active context when data changes', (tester) async {
    final dataA = _dataWithContexts(const [
      PrincipalForYouContext(id: 'a1', label: 'Família A1', family: 'Família A1', childCount: 1),
      PrincipalForYouContext(id: 'a2', label: 'Família A2', family: 'Família A2', childCount: 1),
    ]);
    final dataB = _dataWithContexts(const [
      PrincipalForYouContext(id: 'b1', label: 'Família B', family: 'Família B', childCount: 1),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouPreviewPage(data: dataA),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-for-you-context-trigger')).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Família A2'));
    await tester.pumpAndSettle();
    expect(find.text('Família A2'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouPreviewPage(data: dataB),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Família B'), findsWidgets);
    expect(find.text('Família A1'), findsNothing);
    expect(find.text('Família A2'), findsNothing);
  });

  testWidgets('dismisses an owned context sheet before data B is shown', (tester) async {
    final dataA = _dataWithContexts(const [
      PrincipalForYouContext(id: 'a1', label: 'Contexto A1', family: 'Contexto A1', childCount: 1),
      PrincipalForYouContext(id: 'a2', label: 'Contexto A2', family: 'Contexto A2', childCount: 1),
    ]);
    final dataB = _dataWithContexts(const [
      PrincipalForYouContext(id: 'b1', label: 'Contexto B', family: 'Família B', childCount: 1),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouPreviewPage(data: dataA),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('principal-for-you-context-trigger')).first);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouPreviewPage(data: dataB),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-for-you-context-sheet')), findsNothing);
    expect(find.text('Contexto A1'), findsNothing);
    expect(find.text('Contexto A2'), findsNothing);
    expect(find.text('Família B'), findsWidgets);
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

  testWidgets('keeps the hero action above the floating dock at 200 percent text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const PrincipalForYouPreviewPage(),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(const Key('principal-for-you-hero-action'));
    final dock = find.byKey(const Key('principal-global-dock'));
    expect(action, findsOneWidget);
    await tester.drag(find.byKey(const Key('principal-for-you-scroll')), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.getRect(action).bottom, lessThan(tester.getRect(dock).top));
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the reading order linear at 200 percent on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
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

    expect(find.byKey(const Key('principal-for-you-summary-aside')), findsNothing);
    expect(find.text('Resumo do dia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes every global destination callback', (tester) async {
    final invoked = <String>[];
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalForYouPreviewPage(
          onOpenMenu: () => invoked.add('menu'),
          onOpenNotifications: () => invoked.add('notifications'),
          onOpenHome: () => invoked.add('home'),
          onOpenForYou: () => invoked.add('for-you'),
          onPublishNow: () => invoked.add('publish-now'),
          onOpenMoments: () => invoked.add('moments'),
          onOpenSearch: () => invoked.add('search'),
          onOpenMessages: () => invoked.add('messages'),
          onOpenProfile: () => invoked.add('profile'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final tooltip in [
      'Abrir menu',
      'Notificações',
      'Home',
      'Para você',
      'Publicar no Agora',
      'Momentos',
      'Pesquisar',
      'Mensagens',
      'Abrir perfil',
    ]) {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
    }

    expect(
      invoked,
      containsAll(<String>[
        'menu',
        'notifications',
        'home',
        'for-you',
        'publish-now',
        'moments',
        'search',
        'messages',
        'profile',
      ]),
    );
  });
}

PrincipalForYouPreviewData _dataWithContexts(List<PrincipalForYouContext> contexts) =>
    PrincipalForYouPreviewData(
      highlights: PrincipalForYouPreviewData.demo.highlights,
      shortcuts: PrincipalForYouPreviewData.demo.shortcuts,
      editorialItems: PrincipalForYouPreviewData.demo.editorialItems,
      dayItems: PrincipalForYouPreviewData.demo.dayItems,
      contexts: contexts,
    );
