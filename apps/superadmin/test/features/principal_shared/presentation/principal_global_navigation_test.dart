import 'package:coelo_superadmin/features/principal_shared/presentation/principal_global_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(375, 900),
    double textScale = 1,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          appBar: PrincipalGlobalHeader(
            onOpenMenu: () {},
            onOpenNotifications: () {},
            onOpenProfile: () {},
          ),
          body: Stack(
            children: [
              const SizedBox.expand(),
              PrincipalGlobalNavigation(
                selected: PrincipalDestination.home,
                onHome: () {},
                onForYou: () {},
                onPublishNow: () {},
                onMoments: () {},
                onSearch: () {},
                onMessages: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses the approved header actions with report problem and no hamburger', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('coelo'), findsOneWidget);
    expect(find.byTooltip('Abrir menu'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byTooltip('Notificações'), findsOneWidget);
    expect(find.byTooltip('Abrir perfil'), findsOneWidget);
    expect(find.byTooltip('Reportar problema'), findsOneWidget);
    expect(find.byIcon(Icons.menu_rounded), findsNothing);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('keeps the floating dock compact and away from viewport at ${width.toInt()} px', (
      tester,
    ) async {
      await pump(tester, size: Size(width, 1000));

      final dock = find.byKey(const Key('principal-global-dock'));
      final publish = find.byKey(const Key('principal-global-publish-now'));
      final dockRect = tester.getRect(dock);
      final publishRect = tester.getRect(publish);
      expect(dockRect.bottom, lessThan(1000));
      expect(dockRect.width, lessThanOrEqualTo(560));
      expect(publishRect.width, greaterThan(CoeloSize.touchMin));
      expect(publishRect.center.dy, closeTo(dockRect.top, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('supports 200 percent text without changing the dock anatomy', (tester) async {
    await pump(tester, textScale: 2);
    expect(find.byKey(const Key('principal-global-dock')), findsOneWidget);
    expect(find.byKey(const Key('principal-global-messages')), findsOneWidget);
    final searchLabel = find.text('Pesquisar');
    expect(MediaQuery.textScalerOf(tester.element(searchLabel)).scale(1), 2);
    final labelRect = tester.getRect(searchLabel);
    final actionRect = tester.getRect(find.widgetWithText(TextButton, 'Pesquisar'));
    expect(labelRect.left, greaterThanOrEqualTo(actionRect.left));
    expect(labelRect.right, lessThanOrEqualTo(actionRect.right));
    expect(labelRect.top, greaterThanOrEqualTo(actionRect.top));
    expect(labelRect.bottom, lessThanOrEqualTo(actionRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispatches every header and dock action', (tester) async {
    final calls = <String>[];
    await tester.binding.setSurfaceSize(const Size(768, 1024));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          appBar: PrincipalGlobalHeader(
            onOpenMenu: () => calls.add('menu'),
            onOpenNotifications: () => calls.add('notifications'),
            onOpenProfile: () => calls.add('profile'),
          ),
          body: Stack(
            children: [
              PrincipalGlobalNavigation(
                selected: PrincipalDestination.home,
                onHome: () => calls.add('home'),
                onForYou: () => calls.add('for-you'),
                onPublishNow: () => calls.add('now'),
                onMoments: () => calls.add('moments'),
                onSearch: () => calls.add('search'),
                onMessages: () => calls.add('messages'),
              ),
            ],
          ),
        ),
      ),
    );

    for (final tooltip in const [
      'Abrir menu',
      'Notificações',
      'Abrir perfil',
      'Home',
      'Para você',
      'Publicar no Agora',
      'Momentos',
      'Pesquisar',
      'Mensagens',
    ]) {
      await tester.tap(find.byTooltip(tooltip));
    }
    expect(calls, [
      'menu',
      'notifications',
      'profile',
      'home',
      'for-you',
      'now',
      'moments',
      'search',
      'messages',
    ]);
  });
}
