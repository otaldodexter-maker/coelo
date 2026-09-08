import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_media_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _asset = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _provider = NetworkImage('https://media.invalid/forms-ticket', headers: {});

void main() {
  for (final dark in [false, true]) {
    for (final state in ['loading', 'processing', 'expired', 'unavailable', 'available']) {
      testWidgets('$state at 200 percent in ${dark ? 'dark' : 'light'}', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(375, 1200);
        addTearDown(tester.view.reset);
        if (state == 'available') await _cacheImage(tester);
        final reader = _Reader();
        await _pump(tester, reader, MediaSession(), dark: dark, scale: 2);
        expect(reader.requests.single.toJson(), {'asset_id': _asset, 'rendition': 'preview'});
        if (state != 'loading') reader.pending.single.complete(_result(state));
        await tester.pumpAndSettle();
        expect(
          find.byKey(Key('forms-media-${state == 'available' ? 'preview' : state}')),
          findsOneWidget,
        );
        if (state == 'available') {
          expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        }
        await tester.scrollUntilVisible(
          find.text('Preparar cópia temporária'),
          200,
          scrollable: find
              .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
              .first,
        );
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Preparar cópia temporária'))
              .onPressed,
          isNull,
        );
        expect(find.text('Comprovante da atividade'), findsNothing);
        expect(find.textContaining('https://'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        if (state == 'loading') reader.pending.single.complete(_result('unavailable'));
        await tester.pump();
      });
    }
  }

  for (final change in ['asset', 'reader', 'session']) {
    testWidgets('$change replacement ignores late result and old retry', (tester) async {
      final reader = _Reader();
      final session = MediaSession();
      await _pump(tester, reader, session);
      reader.pending.single.complete(_result('processing'));
      await tester.pumpAndSettle();
      final retry = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Tentar novamente'))
          .onPressed!;
      retry();
      await tester.pump();
      final replacement = change == 'reader' ? _Reader() : reader;
      final nextSession = change == 'session' ? MediaSession() : session;
      await _pump(tester, replacement, nextSession, asset: change == 'asset' ? _other : _asset);
      final count = replacement.requests.length;
      retry();
      reader.pending[1].complete(_result('available'));
      await tester.pump();
      expect(replacement.requests, hasLength(count));
      expect(find.byKey(const Key('forms-media-loading')), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      replacement.pending.last.complete(
        _result('processing', asset: change == 'asset' ? _other : _asset),
      );
      await tester.pumpAndSettle();
      if (change == 'session') await session.invalidate();
      await tester.pump();
      expect(find.byKey(const Key('forms-media-processing')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('session purge removes decoded image and blocks retries', (tester) async {
    await _cacheImage(tester);
    final reader = _Reader();
    final session = MediaSession();
    await _pump(tester, reader, session);
    reader.pending.single.complete(_result('available'));
    await tester.pumpAndSettle();
    expect(PaintingBinding.instance.imageCache.containsKey(_provider), isTrue);
    await session.invalidate();
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Tentar novamente'), findsNothing);
    final cached = PaintingBinding.instance.imageCache.statusForKey(_provider);
    expect(cached.pending || cached.keepAlive || cached.live, isFalse);
    expect(reader.requests, hasLength(1));
  });

  testWidgets('invalid session rejects new and pending reads', (tester) async {
    final reader = _Reader();
    final invalid = MediaSession();
    await invalid.invalidate();
    await _pump(tester, reader, invalid);
    expect(reader.requests, isEmpty);
    final active = MediaSession();
    await _pump(tester, reader, active);
    await active.invalidate();
    reader.pending.single.complete(_result('available'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('forms-media-unavailable')), findsOneWidget);
  });

  testWidgets('TTL evicts image without implicit refresh', (tester) async {
    await _cacheImage(tester);
    final reader = _Reader();
    await _pump(tester, reader, MediaSession());
    reader.pending.single.complete(_result('available'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 3));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('forms-media-expired')), findsOneWidget);
    expect(PaintingBinding.instance.imageCache.containsKey(_provider), isFalse);
    expect(reader.requests, hasLength(1));
  });

  testWidgets('resume checks wall clock expiry while the timer has not fired', (tester) async {
    await _cacheImage(tester);
    final reader = _Reader();
    await _pump(tester, reader, MediaSession());
    reader.pending.single.complete(
      _result(
        'available',
        expiresAt: DateTime.now().toUtc().add(const Duration(milliseconds: 500)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('forms-media-expired')), findsOneWidget);
    expect(PaintingBinding.instance.imageCache.containsKey(_provider), isFalse);
    expect(reader.requests, hasLength(1));
  });

  testWidgets('removing the reader clears an active image and keeps download disabled', (
    tester,
  ) async {
    await _cacheImage(tester);
    final reader = _Reader();
    final session = MediaSession();
    await _pump(tester, reader, session);
    reader.pending.single.complete(_result('available'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: FormsMediaPage(assetId: _asset, session: session),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('forms-media-unavailable')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(PaintingBinding.instance.imageCache.containsKey(_provider), isFalse);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Preparar cópia temporária'))
          .onPressed,
      isNull,
    );
    await session.invalidate();
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed page ignores pending results and captured retry cannot double-read', (
    tester,
  ) async {
    final reader = _Reader();
    final session = MediaSession();
    await _pump(tester, reader, session);
    reader.pending.single.complete(_result('processing'));
    await tester.pumpAndSettle();
    final retry = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Tentar novamente'))
        .onPressed!;
    retry();
    retry();
    expect(reader.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    retry();
    reader.pending.last.complete(_result('available'));
    await tester.pump();
    await session.invalidate();
    expect(reader.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mismatched ID and private errors fail safely with explicit retry', (tester) async {
    final reader = _Reader();
    await _pump(tester, reader, MediaSession());
    reader.pending.single.complete(_result('available', asset: _other));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('forms-media-unavailable')), findsOneWidget);
    await tester.pump(const Duration(minutes: 1));
    expect(reader.requests, hasLength(1));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    reader.pending.last.completeError(Exception('private-ticket-secret'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private-ticket-secret'), findsNothing);
    expect(find.byKey(const Key('forms-media-unavailable')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('image error and disposal evict decoded cache', (tester) async {
    for (final dispose in [false, true]) {
      await _cacheImage(tester);
      final reader = _Reader();
      final session = MediaSession();
      await _pump(tester, reader, session);
      reader.pending.single.complete(_result('available'));
      await tester.pumpAndSettle();
      if (dispose) {
        await tester.pumpWidget(const SizedBox.shrink());
      } else {
        final finder = find.byKey(const Key('forms-media-preview'));
        tester.widget<Image>(finder).errorBuilder!(
          tester.element(finder),
          Exception('private'),
          StackTrace.current,
        );
        tester.binding.scheduleFrame();
      }
      await tester.pump();
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(PaintingBinding.instance.imageCache.containsKey(_provider), isFalse);
      await session.invalidate();
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  _Reader reader,
  MediaSession session, {
  String asset = _asset,
  bool dark = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? CoeloTheme.dark : CoeloTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: FormsMediaPage(assetId: asset, reader: reader, session: session),
    ),
  );
  await tester.pump();
}

Future<void> _cacheImage(WidgetTester tester) async {
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
    _provider,
    () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: decoded!))),
  );
}

MediaReadResult _result(String state, {String asset = _asset, DateTime? expiresAt}) =>
    MediaReadResult.fromJson({
      'asset_id': asset,
      'state': state,
      if (state == 'available')
        'ticket': {
          'url': _provider.url,
          'headers': <String, String>{},
          'expires_at': (expiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 2)))
              .toIso8601String(),
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
