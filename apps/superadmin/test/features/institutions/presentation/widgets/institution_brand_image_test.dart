import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_brand_image.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetId = '70000000-0000-4000-8000-000000000001';

final class _ControlledReader implements MediaReader {
  final requests = <MediaReadRequest>[];
  final results = <Completer<MediaReadResult>>[];

  @override
  Future<MediaReadResult> read(MediaReadRequest request) {
    requests.add(request);
    final result = Completer<MediaReadResult>();
    results.add(result);
    return result.future;
  }
}

MediaReadResult _decode(Map<String, Object?> json) =>
    MediaReadResult.fromJson({'asset_id': _assetId, ...json});

String _soon() => DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String();

String _past() => DateTime.now().toUtc().subtract(const Duration(minutes: 1)).toIso8601String();

void main() {
  Widget host({
    MediaReader? reader,
    int contextRevision = 0,
    void Function(Uri, Map<String, String>)? onRender,
  }) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: InstitutionBrandImage(
        assetId: _assetId,
        reader: reader,
        contextRevision: contextRevision,
        placeholder: const Icon(Icons.apartment_rounded, key: Key('fallback-icon')),
        imageBuilder: (url, headers) {
          onRender?.call(url, headers);
          return const SizedBox(key: Key('rendered-image'));
        },
      ),
    ),
  );

  testWidgets('without a composed gateway nothing is read and the fallback shows', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fallback-icon')), findsOneWidget);
    expect(find.byKey(const Key('institution-brand-image-placeholder')), findsOneWidget);
  });

  testWidgets('an authorized ticket is rendered with its own headers', (tester) async {
    final reader = _ControlledReader();
    Uri? renderedUrl;
    Map<String, String>? renderedHeaders;
    await tester.pumpWidget(
      host(
        reader: reader,
        onRender: (url, headers) {
          renderedUrl = url;
          renderedHeaders = headers;
        },
      ),
    );
    await tester.pump();
    expect(reader.requests.single.assetId, _assetId);
    expect(reader.requests.single.rendition, MediaReadRendition.preview);

    reader.results.single.complete(
      _decode({
        'state': 'available',
        'ticket': {
          'url': 'https://media.example/ticket',
          'expires_at': _soon(),
          'headers': {'authorization': 'Bearer sintetico'},
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rendered-image')), findsOneWidget);
    expect(renderedUrl.toString(), 'https://media.example/ticket');
    expect(renderedHeaders?['authorization'], 'Bearer sintetico');
  });

  testWidgets('an expired ticket offers a retry instead of a broken image', (tester) async {
    final reader = _ControlledReader();
    await tester.pumpWidget(host(reader: reader));
    await tester.pump();
    reader.results.single.complete(_decode({'state': 'expired', 'ticket': null}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-brand-image-expired')), findsOneWidget);

    await tester.tap(find.byKey(const Key('institution-brand-image-retry')));
    await tester.pump();
    expect(reader.requests, hasLength(2));
  });

  testWidgets('an available state without a usable ticket is not rendered', (tester) async {
    final reader = _ControlledReader();
    await tester.pumpWidget(host(reader: reader));
    await tester.pump();
    reader.results.single.complete(
      _decode({
        'state': 'available',
        'ticket': {
          'url': 'https://media.example/ticket',
          'expires_at': _past(),
          'headers': <String, String>{},
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rendered-image')), findsNothing);
    expect(find.byKey(const Key('institution-brand-image-expired')), findsOneWidget);
  });

  testWidgets('processing says so and unavailable falls back', (tester) async {
    final reader = _ControlledReader();
    await tester.pumpWidget(host(reader: reader));
    await tester.pump();
    reader.results.single.complete(_decode({'state': 'processing', 'ticket': null}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-brand-image-processing')), findsOneWidget);

    await tester.pumpWidget(host(reader: reader, contextRevision: 1));
    await tester.pump();
    reader.results.last.complete(_decode({'state': 'unavailable', 'ticket': null}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-brand-image-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('fallback-icon')), findsOneWidget);
  });

  testWidgets('a new context re-reads and never keeps the previous image', (tester) async {
    final reader = _ControlledReader();
    await tester.pumpWidget(host(reader: reader));
    await tester.pump();
    reader.results.single.complete(
      _decode({
        'state': 'available',
        'ticket': {
          'url': 'https://media.example/first',
          'expires_at': _soon(),
          'headers': <String, String>{},
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rendered-image')), findsOneWidget);

    await tester.pumpWidget(host(reader: reader, contextRevision: 1));
    await tester.pump();
    expect(find.byKey(const Key('rendered-image')), findsNothing);
    expect(reader.requests, hasLength(2));
  });

  testWidgets('an invalidated session shows the fallback, not a server message', (tester) async {
    final reader = _ControlledReader();
    await tester.pumpWidget(host(reader: reader));
    await tester.pump();
    reader.results.single.completeError(const MediaSessionInvalidatedException());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fallback-icon')), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}
