import 'dart:async';
import 'dart:io';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_image_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Nunito Sans',
    )..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'))).load();
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final icons = File(
      '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons)))).load();
  });
  for (final dark in [false, true]) {
    for (final entry in [
      (375, 'processing'),
      (768, 'expired'),
      (1024, 'unavailable'),
      (1440, 'loading'),
    ]) {
      testWidgets(
        'candidate private image ${entry.$2} ${entry.$1} dark=$dark text200 reduced-motion',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(entry.$1.toDouble(), 900);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          final reader = _Reader(entry.$2);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? CoeloTheme.dark : CoeloTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2), disableAnimations: true),
                child: child!,
              ),
              home: Scaffold(
                body: SuperadminChatImageDialog(
                  assetId: '11111111-1111-4111-8111-111111111111',
                  reader: reader,
                  session: MediaSession(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(Key('chat-image-${entry.$2}')), findsOneWidget);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'goldens/chat_image_candidate_${entry.$2}_${dark ? 'dark' : 'light'}_${entry.$1}_text200.png',
            ),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          reader.pending?.complete(
            MediaReadResult.fromJson({
              'asset_id': '11111111-1111-4111-8111-111111111111',
              'state': 'unavailable',
            }),
          );
          await tester.pump();
        },
      );
    }
  }
}

final class _Reader implements MediaReader {
  _Reader(this.state);
  final String state;
  Completer<MediaReadResult>? pending;
  @override
  Future<MediaReadResult> read(MediaReadRequest request) async {
    if (state == 'loading') return (pending = Completer<MediaReadResult>()).future;
    return MediaReadResult.fromJson({'asset_id': request.assetId, 'state': state});
  }
}
