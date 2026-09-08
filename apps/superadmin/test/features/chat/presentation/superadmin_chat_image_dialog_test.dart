import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_image_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _asset = '11111111-1111-4111-8111-111111111111';
const _otherAsset = '22222222-2222-4222-8222-222222222222';

void main() {
  for (final dark in [false, true]) {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final state in ['loading', 'processing', 'expired', 'unavailable', 'available']) {
        testWidgets('image state $state width=$width dark=$dark text200', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.reset);
          if (state == 'available') {
            final decoded = await tester.runAsync(() async {
              final result = Completer<ui.Image>();
              ui.decodeImageFromPixels(
                Uint8List.fromList(List.filled(64, 255)),
                4,
                4,
                ui.PixelFormat.rgba8888,
                result.complete,
              );
              return result.future;
            });
            PaintingBinding.instance.imageCache.putIfAbsent(
              const NetworkImage(
                'https://media.invalid/opaque-ticket',
                headers: <String, String>{},
              ),
              () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: decoded!))),
            );
          }
          final reader = _Reader();
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
                  assetId: _asset,
                  reader: reader,
                  session: MediaSession(),
                ),
              ),
            ),
          );
          await tester.pump();
          if (state != 'loading') reader.pending.single.complete(_result(state));
          await tester.pumpAndSettle();
          expect(
            find.byKey(Key('chat-image-${state == 'available' ? 'preview' : state}')),
            findsOneWidget,
          );
          if (state == 'available') {
            expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
          }
          expect(tester.takeException(), isNull);
          final close = find.widgetWithText(OutlinedButton, 'Fechar');
          expect(close, findsOneWidget);
          expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
          await tester.pumpWidget(const SizedBox.shrink());
          if (state == 'loading') reader.pending.single.complete(_result('unavailable'));
          await tester.pump();
        });
      }
    }
  }

  testWidgets('decoded Flutter cache entry is evicted when its session is invalidated', (
    tester,
  ) async {
    // A decoded synthetic cache fixture, not proof of HTTP or browser cleanup.
    final decoded = await tester.runAsync(() async {
      final result = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        Uint8List.fromList(List.filled(64, 255)),
        4,
        4,
        ui.PixelFormat.rgba8888,
        result.complete,
      );
      return result.future;
    });
    const provider = NetworkImage(
      'https://media.invalid/opaque-ticket',
      headers: <String, String>{},
    );
    PaintingBinding.instance.imageCache.putIfAbsent(
      provider,
      () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: decoded!))),
    );
    final session = MediaSession();
    final reader = _Reader();
    await _pump(tester, reader, session);
    reader.pending.single.complete(_result('available'));
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsOneWidget);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(PaintingBinding.instance.imageCache.containsKey(provider), isTrue);
    await session.invalidate();
    await tester.pumpAndSettle();
    expect(find.byType(RawImage), findsNothing);
    final cached = PaintingBinding.instance.imageCache.statusForKey(provider);
    expect(cached.pending, isFalse);
    expect(cached.keepAlive, isFalse);
    expect(cached.live, isFalse);
  });
  testWidgets('context replacement rejects old response and unregisters old purge', (tester) async {
    final oldReader = _Reader();
    final oldSession = MediaSession();
    await _pump(tester, oldReader, oldSession);
    final newReader = _Reader();
    final newSession = MediaSession();
    await _pump(tester, newReader, newSession);
    expect(newReader.requests, hasLength(1));
    await oldSession.invalidate();
    oldReader.pending.single.complete(_result('available'));
    await tester.pump();
    expect(find.byKey(const Key('chat-image-loading')), findsOneWidget);
    newReader.pending.single.complete(_result('processing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-image-processing')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dispose rejects pending response and leaves no session cleanup error', (
    tester,
  ) async {
    final reader = _Reader();
    final session = MediaSession();
    await _pump(tester, reader, session);
    await tester.pumpWidget(const SizedBox.shrink());
    reader.pending.single.complete(_result('available'));
    await tester.pump();
    await session.invalidate();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('active image is removed on invalidation without retry or new read', (tester) async {
    final reader = _Reader();
    final session = MediaSession();
    await _pump(tester, reader, session);
    reader.pending.single.complete(_result('available'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('chat-image-preview')), findsOneWidget);
    await session.invalidate();
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('chat-image-unavailable')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(reader.requests, hasLength(1));
    await tester.pump(const Duration(minutes: 3));
    expect(find.byKey(const Key('chat-image-unavailable')), findsOneWidget);
  });

  testWidgets('image load error clears temporary provider and enables explicit retry', (
    tester,
  ) async {
    final reader = _Reader();
    await _pump(tester, reader, MediaSession());
    reader.pending.single.complete(_result('available'));
    await tester.pump();
    await tester.pump();
    final finder = find.byKey(const Key('chat-image-preview'));
    final image = tester.widget<Image>(finder);
    image.errorBuilder!(tester.element(finder), Exception('private-ticket'), StackTrace.current);
    await tester.pump();
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('chat-image-unavailable')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.textContaining('private-ticket'), findsNothing);
    expect(reader.requests, hasLength(1));
  });

  testWidgets('requests only canonical preview and shows loading without duplicate reads', (
    tester,
  ) async {
    final reader = _Reader();
    await _pump(tester, reader, MediaSession());
    expect(reader.requests, hasLength(1));
    expect(reader.requests.single.toJson(), {'asset_id': _asset, 'rendition': 'preview'});
    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    expect(find.byKey(const Key('chat-image-loading')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(reader.requests, hasLength(1));
    reader.pending.single.complete(_result('processing'));
    await tester.pumpAndSettle();
  });

  for (final state in ['processing', 'expired', 'unavailable']) {
    testWidgets('$state has no image and retries only explicitly', (tester) async {
      final reader = _Reader();
      await _pump(tester, reader, MediaSession());
      expect(reader.pending, hasLength(1));
      reader.pending.single.complete(_result(state));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('chat-image-$state')), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.pump(const Duration(minutes: 1));
      expect(reader.requests, hasLength(1));
      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      expect(reader.requests, hasLength(2));
      reader.pending.last.complete(_result('unavailable'));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('invalidated session never requests or accepts pending media', (tester) async {
    final reader = _Reader();
    final session = MediaSession();
    await session.invalidate();
    await _pump(tester, reader, session);
    expect(reader.requests, isEmpty);
    expect(find.byKey(const Key('chat-image-unavailable')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    final active = MediaSession();
    await _pump(tester, reader, active);
    expect(reader.requests, hasLength(1));
    await active.invalidate();
    reader.pending.single.complete(_result('available'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('chat-image-unavailable')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
  });

  testWidgets('mismatched asset and private errors become safe unavailable state', (tester) async {
    final reader = _Reader();
    await _pump(tester, reader, MediaSession());
    expect(reader.pending, hasLength(1));
    reader.pending.single.complete(_result('available', assetId: _otherAsset));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-image-unavailable')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    reader.pending.last.completeError(Exception('private signed URL must not be rendered'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat-image-unavailable')), findsOneWidget);
    expect(find.textContaining('signed URL'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('available ticket is temporary and expires without another read', (tester) async {
    final reader = _Reader();
    await _pump(tester, reader, MediaSession());
    expect(reader.pending, hasLength(1));
    reader.pending.single.complete(_result('available'));
    await tester.pump();
    await tester.pump();
    final image = tester.widget<Image>(find.byKey(const Key('chat-image-preview')));
    expect((image.image as NetworkImage).url, 'https://media.invalid/opaque-ticket');
    await tester.pump(const Duration(minutes: 3));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('chat-image-expired')), findsOneWidget);
    expect(reader.requests, hasLength(1));
  });
}

Future<void> _pump(WidgetTester tester, _Reader reader, MediaSession session) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: SuperadminChatImageDialog(assetId: _asset, reader: reader, session: session),
      ),
    ),
  );
  await tester.pump();
}

MediaReadResult _result(String state, {String assetId = _asset}) => MediaReadResult.fromJson({
  'asset_id': assetId,
  'state': state,
  if (state == 'available')
    'ticket': {
      'url': 'https://media.invalid/opaque-ticket',
      'headers': <String, String>{},
      'expires_at': DateTime.now().toUtc().add(const Duration(minutes: 2)).toIso8601String(),
    },
});

final class _Reader implements MediaReader {
  final requests = <MediaReadRequest>[];
  final pending = <Completer<MediaReadResult>>[];
  @override
  Future<MediaReadResult> read(MediaReadRequest request) {
    requests.add(request);
    final result = Completer<MediaReadResult>();
    pending.add(result);
    return result.future;
  }
}
