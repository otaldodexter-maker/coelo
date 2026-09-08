import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the width contract of the Agora composer.
///
/// The frame caps the body at 1120, which is below `CoeloBreakpoints.large`
/// (1200). What this pins is the precondition, not the absence of a branch: the
/// composer never reaches `large`, so anything keyed to it inside would be dead
/// code that reads as a third layout and never renders. Stated as an assertion,
/// it contradicts such a branch out loud instead of leaving the arithmetic for
/// a reader to redo. Widening the stage is a decision about the frame's cap,
/// with its own nominal visual review, not a branch added here.
void main() {
  Future<void> pumpComposer(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: InMemoryNowPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [1024.0, 1440.0, 1920.0]) {
    testWidgets('the composer stays below the large breakpoint at ${width.toInt()} px', (
      tester,
    ) async {
      await pumpComposer(tester, Size(width, 1000));

      final composition = find.byKey(const Key('now-publication-zones'));
      expect(
        composition,
        findsOneWidget,
        reason: 'a desktop width puts the preview beside the editorial column',
      );
      expect(
        tester.getSize(composition).width,
        lessThan(CoeloBreakpoints.large.minWidth),
        reason:
            'the frame caps the composer body below the large breakpoint, so a layout '
            'branch keyed to large inside it could never run',
      );
    });
  }

  testWidgets('the composer stops growing once the cap binds', (tester) async {
    // Both widths are past the 1120 cap, so the frame — not the viewport —
    // decides the composer size and the two must agree. 1024 is deliberately
    // excluded: there the viewport is the smaller constraint and a narrower
    // column is correct, not a regression.
    await pumpComposer(tester, const Size(1440, 1000));
    final atFourteenForty = tester
        .getSize(find.byKey(const Key('now-publication-editorial-column')))
        .width;

    await pumpComposer(tester, const Size(1920, 1000));
    final atNineteenTwenty = tester
        .getSize(find.byKey(const Key('now-publication-editorial-column')))
        .width;

    // If this ever diverges, the frame's width contract changed and the goldens
    // need a nominal visual review before anything keyed to `large` comes back.
    expect(atNineteenTwenty, atFourteenForty);
  });
}
