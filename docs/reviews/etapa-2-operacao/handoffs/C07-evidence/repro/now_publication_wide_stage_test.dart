import 'package:coelo_superadmin/features/principal_now_publication/domain/now_publication.dart';
import 'package:coelo_superadmin/features/principal_now_publication/presentation/principal_now_publication_page.dart';
import 'package:coelo_superadmin/features/principal_shared/presentation/principal_publication_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato da spec 036 (Publicar no Agora, desktop 1440): "mídia vertical
/// ampla, ferramentas adjacentes e coluna editorial enxuta". Um desktop amplo
/// deve entregar ao palco de mídia mais largura do que um desktop estreito.
void main() {
  const narrowDesktop = Size(1024, 1100);
  const wideDesktop = Size(1440, 1100);
  final stage = find.byKey(const Key('now-media-stage'));
  final zones = find.byKey(const Key('now-publication-zones'));

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalNowPublicationPage.demo(repository: InMemoryNowPublicationRepository()),
      ),
    );
    await tester.pumpAndSettle();
    expect(stage, findsOneWidget);
    expect(zones, findsOneWidget);
  }

  testWidgets('wide desktop gives the media stage more width than a narrow desktop', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpAt(tester, narrowDesktop);
    final narrowStageWidth = tester.getSize(stage).width;

    await pumpAt(tester, wideDesktop);
    final wideStageWidth = tester.getSize(stage).width;

    expect(
      wideStageWidth,
      greaterThan(narrowStageWidth),
      reason:
          'Palco em ${wideDesktop.width.toInt()}px mede $wideStageWidth, '
          'em ${narrowDesktop.width.toInt()}px mede $narrowStageWidth.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('composer body on a wide desktop reaches the large breakpoint', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpAt(tester, wideDesktop);
    final frameBox = find.descendant(
      of: find.byType(PrincipalPublicationFrame),
      matching: find.byWidgetPredicate(
        (widget) => widget is ConstrainedBox && widget.constraints.maxWidth.isFinite,
      ),
    );
    final frameBoxWidth = tester.getSize(frameBox.first).width;
    final bodyWidth = tester.getSize(zones).width;

    expect(
      bodyWidth,
      greaterThanOrEqualTo(CoeloBreakpoints.large.minWidth),
      reason:
          'Corpo do compositor mede $bodyWidth (ConstrainedBox do frame: $frameBoxWidth) '
          'em ${wideDesktop.width.toInt()}px; large.minWidth = '
          '${CoeloBreakpoints.large.minWidth}.',
    );
    expect(tester.takeException(), isNull);
  });
}
