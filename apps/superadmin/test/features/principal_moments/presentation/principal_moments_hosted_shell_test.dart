import 'package:coelo_superadmin/features/principal_moments/presentation/principal_moments_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner decision of 2026-09-09: hosted in the Superadmin the Momentos viewer
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
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, padding: hostInsets, viewPadding: hostInsets),
          child: child!,
        ),
        home: Column(
          children: [
            const SizedBox(key: hostChrome, height: 56, width: double.infinity),
            Expanded(child: PrincipalMomentsPreviewPage(embedded: embedded)),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  for (final size in const [Size(375, 812), Size(1440, 900)]) {
    testWidgets('keeps the host chrome mounted at ${size.width.toInt()}', (tester) async {
      await pumpHosted(tester, size: size, embedded: true);

      expect(find.byKey(hostChrome), findsOneWidget);
      expect(find.byType(PrincipalMomentsPreviewPage), findsOneWidget);
      expect(find.byKey(const Key('principal-moments-page-view')), findsOneWidget);
      expect(find.byKey(const Key('principal-moments-back')), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const Key('principal-global-dock')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('does not repeat the host system insets when hosted', (tester) async {
    await pumpHosted(tester, size: const Size(375, 812), embedded: false);
    final standalone = tester.getTopLeft(find.byKey(const Key('principal-moments-back'))).dy;

    await pumpHosted(tester, size: const Size(375, 812), embedded: true);
    final hosted = tester.getTopLeft(find.byKey(const Key('principal-moments-back'))).dy;

    expect(standalone - hosted, hostInsets.top);
    expect(tester.takeException(), isNull);
  });
}
