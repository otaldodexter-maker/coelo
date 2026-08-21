import 'package:coelo_superadmin/features/principal_happens/presentation/principal_happens_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpHappens(
    WidgetTester tester, {
    required Size size,
    VoidCallback? onOpenMoments,
    VoidCallback? onOpenProfile,
    VoidCallback? onOpenAgenda,
    VoidCallback? onOpenNow,
    VoidCallback? onOpenForYou,
    VoidCallback? onCreatePost,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPreviewPage.demo(
          onOpenMoments: onOpenMoments,
          onOpenProfile: onOpenProfile,
          onOpenAgenda: onOpenAgenda,
          onOpenNow: onOpenNow,
          onOpenForYou: onOpenForYou,
          onCreatePost: onCreatePost,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the canonical mobile anatomy and local social actions', (tester) async {
    await pumpHappens(tester, size: const Size(375, 900));

    expect(find.byKey(const Key('principal-happens-logo')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-bug')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-notifications')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-context-avatar')), findsOneWidget);
    expect(find.text('Acontece'), findsWidgets);
    expect(find.text('Agora'), findsOneWidget);
    expect(find.text('Ver tudo'), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-mobile-nav')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-desktop-rail')), findsNothing);
    expect(find.byKey(const Key('principal-happens-context-column')), findsNothing);

    final like = find.byKey(const Key('principal-happens-like-post-0'));
    await tester.drag(find.byKey(const Key('principal-happens-feed')), const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(like);
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    final save = find.byKey(const Key('principal-happens-save-post-0'));
    await tester.tap(save);
    await tester.pump();
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses callbacks for the sibling surfaces', (tester) async {
    var momentsOpened = false;
    var profileOpened = false;
    var agendaOpened = false;
    var nowOpened = false;
    await pumpHappens(
      tester,
      size: const Size(1440, 1000),
      onOpenMoments: () => momentsOpened = true,
      onOpenProfile: () => profileOpened = true,
      onOpenAgenda: () => agendaOpened = true,
      onOpenNow: () => nowOpened = true,
    );

    await tester.tap(find.byKey(const Key('principal-happens-tab-momentos')));
    await tester.tap(find.byKey(const Key('principal-happens-tab-perfil')));
    expect(momentsOpened, isTrue);
    expect(profileOpened, isTrue);

    await tester.tap(find.text('Ver tudo'));
    expect(nowOpened, isTrue);

    nowOpened = false;
    await tester.tap(find.text('Beatriz L.'));
    expect(nowOpened, isTrue);

    await tester.ensureVisible(find.byKey(const Key('principal-happens-open-agenda')));
    await tester.tap(find.byKey(const Key('principal-happens-open-agenda')));
    expect(agendaOpened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Agora card hover in the orange Coelo hierarchy', (tester) async {
    await pumpHappens(tester, size: const Size(1440, 1000));

    final card = find.ancestor(of: find.text('Beatriz L.'), matching: find.byType(TextButton));
    final button = tester.widget<TextButton>(card.first);
    final scheme = CoeloTheme.light.colorScheme;

    expect(button.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    expect(button.style?.side?.resolve({WidgetState.hovered})?.color, scheme.primary);
    expect(button.style?.side?.resolve(<WidgetState>{})?.color, scheme.outlineVariant);
  });

  testWidgets('opens Para você as a sibling surface', (tester) async {
    var forYouOpened = false;
    await pumpHappens(tester, size: const Size(768, 1024), onOpenForYou: () => forYouOpened = true);

    await tester.tap(find.byKey(const Key('principal-happens-tab-for-you')));
    expect(forYouOpened, isTrue);
  });

  testWidgets('uses the optional create callback only for the central action', (tester) async {
    var created = false;
    await pumpHappens(tester, size: const Size(375, 900), onCreatePost: () => created = true);

    await tester.tap(find.byTooltip('Criar'));
    expect(created, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps tablet anatomy without desktop side columns', (tester) async {
    await pumpHappens(tester, size: const Size(768, 1024));

    expect(find.byKey(const Key('principal-happens-mobile-nav')), findsNothing);
    expect(find.byKey(const Key('principal-happens-desktop-rail')), findsNothing);
    expect(find.byKey(const Key('principal-happens-context-column')), findsNothing);
    expect(find.byKey(const Key('principal-happens-feed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders desktop rail, feed and contextual column', (tester) async {
    await pumpHappens(tester, size: const Size(1440, 1000));

    expect(find.byKey(const Key('principal-happens-desktop-rail')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-feed')), findsOneWidget);
    expect(find.byKey(const Key('principal-happens-context-column')), findsOneWidget);
    expect(find.text('Próximos eventos'), findsOneWidget);
    expect(find.text('Avisos importantes'), findsOneWidget);
    expect(find.text('Aniversariantes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [600.0, 839.0, 840.0, 1024.0]) {
    testWidgets('has no layout exception at ${width.toInt()} px', (tester) async {
      await pumpHappens(tester, size: Size(width, 1000));
      expect(find.byKey(const Key('principal-happens-feed')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('supports 200 percent text and reduced motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1000));
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
        home: const PrincipalHappensPreviewPage.demo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('principal-happens-feed')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
