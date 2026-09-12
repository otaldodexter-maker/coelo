import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:coelo_superadmin/features/forms/data/forms_media_reader.dart';
import 'package:flutter_test/flutter_test.dart';

const _asset = '11111111-1111-4111-8111-111111111111';
const _otherAsset = '22222222-2222-4222-8222-222222222222';
final _now = DateTime.utc(2026, 9, 8, 12);

void main() {
  test(
    'question images resolve through their separate purpose and expire within five minutes',
    () async {
      final gateway = _Gateway();
      final reader = FormsQuestionImageReader(gateway: gateway, now: () => _now);
      final pending = reader.read(_request());
      expect(gateway.envelopes.single, {
        'action': 'resolve',
        'payload': {'purpose': 'question-image', 'asset_id': _asset},
      });
      gateway.pending.single.complete({
        'asset_id': _asset,
        'signed_url': 'https://synthetic.r2.cloudflarestorage.com/question',
        'expires_at': _now.add(const Duration(minutes: 5)).toIso8601String(),
      });
      final result = await pending;
      expect(result.state, MediaReadState.available);
      expect(result.ticket!.headers, isEmpty);
    },
  );

  test('question resolve rejects an asset crossed with another question receipt', () async {
    final gateway = _Gateway();
    final pending = FormsQuestionImageReader(gateway: gateway, now: () => _now).read(_request());
    gateway.pending.single.complete({
      'asset_id': _otherAsset,
      'signed_url': 'https://synthetic.r2.cloudflarestorage.com/question',
      'expires_at': _now.add(const Duration(minutes: 5)).toIso8601String(),
    });
    await expectLater(pending, throwsA(isA<MediaProtocolException>()));
  });

  for (final state in MediaReadState.values) {
    test('decodes $state using only the candidate read envelope', () async {
      final gateway = _Gateway();
      final reader = FormsMediaReader(gateway: gateway, now: () => _now);
      final pending = reader.read(_request());
      expect(gateway.envelopes.single, {
        'action': 'read',
        'payload': {'asset_id': _asset, 'rendition': 'preview'},
      });
      gateway.pending.single.complete(_result(state: state));
      final result = await pending;
      expect(result.assetId, _asset);
      expect(result.state, state);
      expect(result.ticket != null, state == MediaReadState.available);
      if (result.ticket case final ticket?) {
        expect(ticket.expiresAt, _now.add(const Duration(seconds: 300)));
        expect(ticket.headers, {'x-media-proof': 'synthetic'});
      }
    });
  }

  test('independent concurrent reads are not cached and never fall back to original', () async {
    final gateway = _Gateway();
    final reader = FormsMediaReader(gateway: gateway, now: () => _now);
    final first = reader.read(_request());
    final second = reader.read(_request());
    expect(gateway.envelopes, hasLength(2));
    gateway.pending[1].complete(_result(state: MediaReadState.processing));
    gateway.pending[0].complete(_result(state: MediaReadState.unavailable));
    expect((await first).state, MediaReadState.unavailable);
    expect((await second).state, MediaReadState.processing);
    expect(gateway.envelopes, hasLength(2));
    final original = reader.read(
      MediaReadRequest(assetId: _asset, rendition: MediaReadRendition.original),
    );
    expect((gateway.envelopes.last['payload'] as Map)['rendition'], 'original');
    gateway.pending.last.complete(_result(state: MediaReadState.unavailable));
    await original;
    expect(gateway.envelopes, hasLength(3));
  });

  for (final raw in [
    null,
    <Object?>[],
    'not-a-response',
    <String, Object?>{},
    {'asset_id': _otherAsset, 'state': 'unavailable'},
    {'asset_id': 'catalog-lookup-key', 'state': 'available'},
    {'asset_id': _asset, 'state': 'unknown'},
    {'asset_id': _asset, 'state': 'available', 'ticket': null},
    {
      'asset_id': _asset,
      'state': 'processing',
      'ticket': {'url': 'private'},
    },
  ]) {
    test('rejects malformed or crossed receipt $raw', () async {
      await _reject(raw);
    });
  }

  for (final url in [
    'http://media.invalid/x',
    'https:///missing',
    'https://name:secret@media.invalid/x',
    'https://media.invalid/x#fragment',
    'https://media.invalid/x?two words',
    'https://media.invalid/x\n',
  ]) {
    test('rejects malformed URL without exposing it', () async {
      await _reject(_result(ticket: {..._ticket(), 'url': url}));
    });
  }

  for (final expiry in [
    '2026-09-08T12:05:00.001Z',
    '2026-09-08T12:05:01Z',
    '2026-09-08T12:04:00',
    '2026-02-30T12:04:00Z',
    '2026-09-08T12:04:00Z\n',
  ]) {
    test('rejects invalid expiry or TTL over 300 seconds', () async {
      await _reject(_result(ticket: {..._ticket(), 'expires_at': expiry}));
    });
  }

  for (final expiry in ['2026-09-08T12:00:00Z', '2026-09-08T11:59:59Z']) {
    test('expired receipt keeps the safe expired exception', () async {
      await _reject(_result(ticket: {..._ticket(), 'expires_at': expiry}), expired: true);
    });
  }

  test('absolute offset expiry is checked at receipt time', () async {
    var now = _now;
    final gateway = _Gateway();
    final reader = FormsMediaReader(gateway: gateway, now: () => now);
    final pending = reader.read(_request());
    now = now.add(const Duration(minutes: 5));
    gateway.pending.single.complete(
      _result(ticket: {..._ticket(), 'expires_at': '2026-09-08T09:05:00-03:00'}),
    );
    await expectLater(pending, throwsA(isA<MediaTicketExpiredException>()));
  });

  test('invalid headers are rejected through the shared ticket contract', () async {
    await _reject(
      _result(
        ticket: {
          ..._ticket(),
          'headers': {'authorization': 'secret\r\nInjected: yes'},
        },
      ),
    );
  });

  for (final error in [
    Exception('private-url?secret=token'),
    StateError('private-url?secret=token'),
    const FormsBackendFailure(code: 'secret-token', message: 'private signed URL'),
  ]) {
    test('backend failure is sanitized without implicit retry', () async {
      final gateway = _Gateway();
      final reader = FormsMediaReader(gateway: gateway, now: () => _now);
      final pending = reader.read(_request());
      gateway.pending.single.completeError(error);
      await expectLater(
        pending,
        throwsA(
          isA<MediaProtocolException>().having(
            (error) => error.toString(),
            'safe error',
            'Invalid media response.',
          ),
        ),
      );
      expect(gateway.envelopes, hasLength(1));
    });
  }

  test('consumer SessionMediaReader still rejects late invalidated results', () async {
    final gateway = _Gateway();
    final session = MediaSession();
    final reader = SessionMediaReader(
      delegate: FormsMediaReader(gateway: gateway, now: () => _now),
      session: session,
      now: () => _now,
    );
    final pending = reader.read(_request());
    await session.invalidate();
    gateway.pending.single.complete(_result());
    await expectLater(pending, throwsA(isA<MediaSessionInvalidatedException>()));
  });
}

MediaReadRequest _request() =>
    MediaReadRequest(assetId: _asset, rendition: MediaReadRendition.preview);

Map<String, Object?> _ticket() => {
  'url': 'https://media.invalid/forms?ticket=synthetic',
  'headers': {'x-media-proof': 'synthetic'},
  'expires_at': _now.add(const Duration(seconds: 300)).toIso8601String(),
};

Map<String, Object?> _result({
  MediaReadState state = MediaReadState.available,
  Map<String, Object?>? ticket,
}) => {
  'asset_id': _asset,
  'state': state.name,
  if (state == MediaReadState.available) 'ticket': ticket ?? _ticket(),
};

Future<void> _reject(Object? raw, {bool expired = false}) async {
  final gateway = _Gateway();
  final pending = FormsMediaReader(gateway: gateway, now: () => _now).read(_request());
  gateway.pending.single.complete(raw);
  await expectLater(
    pending,
    throwsA(expired ? isA<MediaTicketExpiredException>() : isA<MediaProtocolException>()),
  );
}

final class _Gateway implements FormsBackendGateway {
  final envelopes = <Map<String, Object?>>[];
  final pending = <Completer<Object?>>[];
  @override
  Future<Object?> media(Map<String, Object?> envelope) {
    envelopes.add(envelope);
    final result = Completer<Object?>();
    pending.add(result);
    return result.future;
  }

  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) =>
      throw StateError('Unexpected RPC');
}
