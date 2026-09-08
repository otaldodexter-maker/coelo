import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:test/test.dart';

const assetId = '9b400000-0000-4000-8000-000000000001';
const otherAssetId = '9b400000-0000-4000-8000-000000000002';
final now = DateTime.utc(2026, 9, 7, 12);

Map<String, Object?> available() => {
  'asset_id': assetId,
  'state': 'available',
  'ticket': <String, Object?>{
    'url': 'https://media.invalid/read/opaque?ticket=synthetic',
    'expires_at': '2026-09-07T12:02:00Z',
    'headers': <String, String>{'Accept': 'image/webp'},
  },
};

void main() {
  test('request carries only the asset and explicit rendition', () {
    final request = MediaReadRequest(assetId: assetId, rendition: MediaReadRendition.preview);
    expect(request.toJson(), {'asset_id': assetId, 'rendition': 'preview'});
  });

  test('request normalizes UUID casing and rejects malformed identifiers', () {
    final request = MediaReadRequest(
      assetId: assetId.toUpperCase(),
      rendition: MediaReadRendition.original,
    );
    expect(request.toJson(), {'asset_id': assetId, 'rendition': 'original'});
    for (final invalid in ['', ' $assetId', '$assetId/preview', 'not-an-id']) {
      expect(
        () => MediaReadRequest(assetId: invalid, rendition: MediaReadRendition.original),
        throwsA(isA<MediaProtocolException>()),
      );
    }
  });

  test('valid timestamp offset and fraction normalize to UTC', () {
    final payload = available();
    (payload['ticket']! as Map<String, Object?>)['expires_at'] = '2026-09-07T09:02:00.123456-03:00';
    expect(
      MediaReadResult.fromJson(payload).ticket!.expiresAt,
      DateTime.utc(2026, 9, 7, 12, 2, 0, 123, 456),
    );
  });

  test('available response preserves an immutable temporary capability', () {
    final payload = available();
    final result = MediaReadResult.fromJson(payload);
    final ticket = result.ticket!;
    expect(result.assetId, assetId);
    expect(result.state, MediaReadState.available);
    expect(ticket.url.scheme, 'https');
    expect(ticket.expiresAt, now.add(const Duration(minutes: 2)));
    expect(() => ticket.headers['Authorization'] = 'changed', throwsUnsupportedError);
    expect(ticket.toString(), isNot(contains('synthetic')));
  });

  for (final state in ['processing', 'expired', 'unavailable']) {
    test('$state is not an available ticket', () {
      final result = MediaReadResult.fromJson({'asset_id': assetId, 'state': state});
      expect(result.ticket, isNull);
      expect(result.state.name, state);
      expect(
        () => MediaReadResult.fromJson({...available(), 'state': state}),
        throwsA(isA<MediaProtocolException>()),
      );
    });
  }

  for (final payload in <Object?>[
    null,
    <String, Object?>{},
    {'asset_id': assetId, 'state': 'ready'},
    {'asset_id': 'private-invalid-id', 'state': 'unavailable'},
    {'asset_id': assetId, 'state': 'available'},
    {'asset_id': assetId, 'state': 'available', 'ticket': <String, Object?>{}},
  ]) {
    test('malformed response fails without leaking its payload: ${payload.runtimeType}', () {
      expect(
        () => MediaReadResult.fromJson(payload),
        throwsA(
          isA<MediaProtocolException>().having(
            (error) => error.toString(),
            'safe error',
            'Invalid media response.',
          ),
        ),
      );
    });
  }

  for (final url in [
    'http://media.invalid/read',
    'https://user:password@media.invalid/read',
    'https://media.invalid/read#fragment',
    'https://media.invalid/read#',
    'javascript:alert(1)',
    '/relative',
    ' https://media.invalid/read',
  ]) {
    test('rejects unsafe ticket URL', () {
      final payload = available();
      (payload['ticket']! as Map<String, Object?>)['url'] = url;
      expect(() => MediaReadResult.fromJson(payload), throwsA(isA<MediaProtocolException>()));
    });
  }

  for (final invalid in [
    null,
    'tomorrow',
    '2026-09-07T12:02:00',
    123,
    '2026-02-30T12:02:00Z',
    '2026-09-07T25:02:00Z',
    '2026-09-07T12:02:00+25:00',
  ]) {
    test('ticket expiry must be an absolute timestamp', () {
      final payload = available();
      (payload['ticket']! as Map<String, Object?>)['expires_at'] = invalid;
      expect(() => MediaReadResult.fromJson(payload), throwsA(isA<MediaProtocolException>()));
    });
  }

  test('rejects non-string or newline-bearing headers', () {
    for (final headers in [
      {'X-Test': 123},
      {'X-Test': 'line\r\nbreak'},
      {'Bad\nName': 'value'},
    ]) {
      final payload = available();
      (payload['ticket']! as Map<String, Object?>)['headers'] = headers;
      expect(() => MediaReadResult.fromJson(payload), throwsA(isA<MediaProtocolException>()));
    }
  });

  test('active reader returns the corresponding unexpired asset', () async {
    final delegate = _Reader()..result.complete(MediaReadResult.fromJson(available()));
    final reader = SessionMediaReader(delegate: delegate, session: MediaSession(), now: () => now);
    expect((await reader.read(_request())).assetId, assetId);
    expect(delegate.calls, 1);
  });

  test('invalidated session never invokes the delegate', () async {
    final session = MediaSession();
    await session.invalidate();
    final delegate = _Reader();
    final reader = SessionMediaReader(delegate: delegate, session: session, now: () => now);
    await expectLater(reader.read(_request()), throwsA(isA<MediaSessionInvalidatedException>()));
    expect(delegate.calls, 0);
  });

  test('revocation rejects a late response', () async {
    final session = MediaSession();
    final delegate = _Reader();
    final reader = SessionMediaReader(delegate: delegate, session: session, now: () => now);
    final result = reader.read(_request());
    final rejected = expectLater(result, throwsA(isA<MediaSessionInvalidatedException>()));
    await session.invalidate();
    delegate.result.complete(MediaReadResult.fromJson(available()));
    await rejected;
  });

  test('does not release a response for another asset', () async {
    final delegate = _Reader()
      ..result.complete(MediaReadResult.fromJson({...available(), 'asset_id': otherAssetId}));
    final reader = SessionMediaReader(delegate: delegate, session: MediaSession(), now: () => now);
    await expectLater(reader.read(_request()), throwsA(isA<MediaProtocolException>()));
  });

  test('does not release an expired ticket', () async {
    final delegate = _Reader()..result.complete(MediaReadResult.fromJson(available()));
    final reader = SessionMediaReader(
      delegate: delegate,
      session: MediaSession(),
      now: () => now.add(const Duration(minutes: 2)),
    );
    await expectLater(reader.read(_request()), throwsA(isA<MediaTicketExpiredException>()));
  });

  test('processing response remains processing without a fabricated URL', () async {
    final delegate = _Reader()
      ..result.complete(MediaReadResult.fromJson({'asset_id': assetId, 'state': 'processing'}));
    final reader = SessionMediaReader(delegate: delegate, session: MediaSession(), now: () => now);
    final result = await reader.read(_request());
    expect(result.state, MediaReadState.processing);
    expect(result.ticket, isNull);
    expect(delegate.calls, 1);
  });

  test('delegate failure is propagated without an implicit retry', () async {
    final delegate = _Reader();
    final reader = SessionMediaReader(delegate: delegate, session: MediaSession(), now: () => now);
    const failure = MediaProtocolException();
    final rejected = expectLater(reader.read(_request()), throwsA(same(failure)));
    delegate.result.completeError(failure);
    await rejected;
    expect(delegate.calls, 1);
  });

  test('ticket headers are copied rather than borrowed from the wire map', () {
    final payload = available();
    final result = MediaReadResult.fromJson(payload);
    final headers = (payload['ticket']! as Map)['headers']! as Map;
    headers['Accept'] = 'changed';
    expect(result.ticket!.headers['Accept'], 'image/webp');
  });
}

MediaReadRequest _request() =>
    MediaReadRequest(assetId: assetId, rendition: MediaReadRendition.preview);

final class _Reader implements MediaReader {
  final result = Completer<MediaReadResult>();
  var calls = 0;
  @override
  Future<MediaReadResult> read(MediaReadRequest request) {
    calls++;
    return result.future;
  }
}
