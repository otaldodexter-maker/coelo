import 'package:coelo_superadmin/features/principal_now/presentation/principal_now_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner decision of 2026-09-09: hosted in the Superadmin the Agora viewer
/// stays inside the shell content container instead of taking over the window.
/// These tests exercise the container contract of the page itself; the route
/// placement that actually keeps the host shell mounted lives in the router.
void main() {
  const hostChrome = Key('host-chrome');
  const hostInsets = EdgeInsets.only(top: 48, bottom: 24);

  Future<void> pumpHosted(
    WidgetTester tester, {
    required Size size,
    required bool embedded,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, padding: hostInsets, viewPadding: hostInsets),
          child: child!,
        ),
        home: Column(
          children: [
            const SizedBox(key: hostChrome, height: 56, width: double.infinity),
            Expanded(child: PrincipalNowPreviewPage(embedded: embedded)),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('keeps the host chrome mounted while hosted in a wide container', (tester) async {
    await pumpHosted(tester, size: const Size(1440, 900), embedded: true);

    expect(find.byKey(hostChrome), findsOneWidget);
    expect(find.byType(PrincipalNowPreviewPage), findsOneWidget);
    expect(find.byKey(const Key('principal-now-desktop-shell')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-story')), findsOneWidget);
    expect(find.byKey(const Key('principal-global-dock')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the host chrome mounted while hosted in a compact container', (tester) async {
    await pumpHosted(tester, size: const Size(375, 900), embedded: true);

    expect(find.byKey(hostChrome), findsOneWidget);
    expect(find.byKey(const Key('principal-now-story')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-reply-field')), findsOneWidget);
    expect(find.byKey(const Key('principal-now-back')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not repeat the host system insets when hosted', (tester) async {
    await pumpHosted(tester, size: const Size(1440, 900), embedded: false);
    final standalone = tester.getTopLeft(find.byKey(const Key('principal-now-close'))).dy;

    await pumpHosted(tester, size: const Size(1440, 900), embedded: true);
    final hosted = tester.getTopLeft(find.byKey(const Key('principal-now-close'))).dy;

    expect(standalone - hosted, hostInsets.top);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone viewer keeps applying its own safe insets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, padding: hostInsets, viewPadding: hostInsets),
          child: child!,
        ),
        home: const PrincipalNowPreviewPage(),
      ),
    );
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(const Key('principal-now-close'))).dy,
      greaterThanOrEqualTo(hostInsets.top),
    );
    expect(tester.takeException(), isNull);
  });
}
