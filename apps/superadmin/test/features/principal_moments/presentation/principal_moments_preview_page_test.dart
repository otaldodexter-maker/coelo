import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpMoments(
    WidgetTester tester, {
    required Size size,
    VoidCallback? onOpenHappens,
    VoidCallback? onOpenProfile,
    VoidCallback? onCreateMoment,
    double textScale = 1,
    bool disableAnimations = false,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: disableAnimations,
            textScaler: TextScaler.linear(textScale),
          ),
          child: PrincipalMomentsPreviewPage(
            onOpenHappens: onOpenHappens,
            onOpenProfile: onOpenProfile,
            onCreateMoment: onCreateMoment,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the canonical immersive mobile anatomy and social states', (tester) async {
    await pumpMoments(tester, size: const Size(375, 900));

    expect(find.byKey(const Key('principal-moments-logo')), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-bug')), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-notifications')), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-context-avatar')), findsOneWidget);
    expect(find.text('Momentos'), findsWidgets);
    expect(find.byKey(const Key('principal-moments-mobile-nav')), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-desktop-aside')), findsNothing);

    await tester.tap(find.byKey(const Key('principal-moments-like')));
    await tester.tap(find.byKey(const Key('principal-moments-save')));
    await tester.tap(find.byKey(const Key('principal-moments-mute')));
    await tester.pump();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses callbacks for Acontece and Perfil', (tester) async {
    var happensOpened = false;
    var profileOpened = false;
    await pumpMoments(
      tester,
      size: const Size(768, 1024),
      onOpenHappens: () => happensOpened = true,
      onOpenProfile: () => profileOpened = true,
    );

    await tester.tap(find.byKey(const Key('principal-moments-nav-acontece')));
    await tester.tap(find.byKey(const Key('principal-moments-nav-perfil')));

    expect(happensOpened, isTrue);
    expect(profileOpened, isTrue);
  });

  testWidgets('opens the Momentos publication contract from the desktop CTA', (tester) async {
    var publicationOpened = false;
    await pumpMoments(
      tester,
      size: const Size(1440, 1000),
      onCreateMoment: () => publicationOpened = true,
    );

    await tester.tap(find.byKey(const Key('principal-moments-create')));

    expect(publicationOpened, isTrue);
  });

  testWidgets('pages vertically through moments', (tester) async {
    await pumpMoments(tester, size: const Size(375, 900));

    expect(find.text('Música que inspira, conexão que transforma. 🎻✨'), findsOneWidget);
    await tester.drag(find.byKey(const Key('principal-moments-page-view')), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(
      find.text('Ciência na prática é descoberta que fica para a vida toda. 🔬✨'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pages through moments with the keyboard', (tester) async {
    await pumpMoments(tester, size: const Size(768, 1024), disableAnimations: true);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    expect(
      find.text('Ciência na prática é descoberta que fica para a vida toda. 🔬✨'),
      findsOneWidget,
    );
  });

  testWidgets('pages through moments with the mouse wheel', (tester) async {
    await pumpMoments(tester, size: const Size(1440, 1000));

    final pager = find.byKey(const Key('principal-moments-page-view'));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: tester.getCenter(pager), scrollDelta: const Offset(0, 600)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Ciência na prática é descoberta que fica para a vida toda. 🔬✨'),
      findsOneWidget,
    );
  });

  testWidgets('uses Coelo orange hover and focus states for discrete navigation', (tester) async {
    await pumpMoments(tester, size: const Size(1440, 1000));

    final context = tester.element(find.byType(PrincipalMomentsPreviewPage));
    final colors = Theme.of(context).colorScheme;
    final button = tester.widget<TextButton>(
      find.byKey(const Key('principal-moments-nav-acontece')),
    );

    expect(button.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(button.style?.foregroundColor?.resolve({WidgetState.focused}), colors.primary);
  });

  testWidgets('expands into the desktop media and contextual aside', (tester) async {
    await pumpMoments(tester, size: const Size(1440, 1000));

    expect(find.byKey(const Key('principal-moments-mobile-nav')), findsNothing);
    expect(find.byKey(const Key('principal-moments-desktop-nav')), findsOneWidget);
    expect(find.byKey(const Key('principal-moments-desktop-aside')), findsOneWidget);
    expect(find.text('Em alta na escola'), findsOneWidget);
    expect(find.text('Compartilhe momentos que inspiram'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [600.0, 839.0, 840.0, 1024.0]) {
    testWidgets('has no overflow at ${width.toInt()} px with enlarged text', (tester) async {
      await pumpMoments(tester, size: Size(width, 1000), textScale: 2);

      expect(find.byKey(const Key('principal-moments-page-view')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
