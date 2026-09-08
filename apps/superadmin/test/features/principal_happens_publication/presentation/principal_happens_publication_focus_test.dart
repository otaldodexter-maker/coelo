import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keyboard contract for the audience chips of Publicar no Acontece.
///
/// Each chip is a real button wrapped in a `FocusableActionDetector` that exists
/// only to light the focus highlight. If the detector also takes focus, Tab
/// stops twice on the same chip: the first stop looks identical to the second
/// and does nothing when activated. It is invisible to a mouse and tiring to
/// everyone else.
void main() {
  testWidgets('an audience chip is a single Tab stop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPublicationPage.demo(
          // Seeded so the audience step is reachable: the rail does not jump
          // over an empty draft.
          repository: InMemoryHappensPublicationRepository()
            ..savedDraft = HappensPostDraft(
              caption: 'Rascunho autorizado',
              media: [
                HappensMediaDraft(
                  localId: 'asset-1',
                  name: 'acontece.png',
                  mimeType: 'image/png',
                  bytes: Uint8List(0),
                  assetId: 'asset-1',
                  objectKey: 'private/acontece.png',
                  remoteUrl: 'https://signed.test/acontece.png',
                ),
              ],
            ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The chips live on the audience step. Walk there the way an operator does.
    for (var step = 0; step < 2; step++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
    }

    final chip = find
        .ancestor(of: find.byIcon(Icons.group_outlined).first, matching: find.byType(TextButton))
        .first;
    final chipRect = tester.getRect(chip);

    final stops = FocusScope.of(tester.element(chip)).traversalDescendants
        .where((node) => node.canRequestFocus && !node.skipTraversal)
        .where((node) {
          final box = node.context?.findRenderObject();
          if (box is! RenderBox || !box.hasSize) return false;
          return (box.localToGlobal(Offset.zero) & box.size) == chipRect;
        })
        .length;

    expect(
      stops,
      1,
      reason:
          'the chip must be one Tab stop. A second node over the same rect is the '
          'detector shadowing the button: it looks focused and activates nothing.',
    );
  });
}
