import 'dart:typed_data';

import 'package:coelo_api/src/media/media_read_contract.dart';
import 'package:coelo_api/src/media/media_upload_contract.dart';
import 'package:test/test.dart';

const id = '9b400000-0000-4000-8000-000000000001';
const requestId = '9b400000-0000-4000-8000-000000000002';
final target = MediaUploadTarget(
  institutionId: id,
  resourceId: id,
  domain: 'forms',
  purpose: 'answer-image',
);
final hash = 'a' * 64;
Map<String, Object?> payload() => {
  'request_id': requestId,
  'target': target.toJson(),
  'asset_id': id,
  'state': 'uploadRequired',
  'ticket': {
    'url': 'https://media.invalid/opaque?signature=synthetic',
    'expires_at': '2026-09-08T20:00:00Z',
    'headers': {'Content-Type': 'image/png'},
  },
};

void main() {
  test('source owns stable bytes and exposes declared metadata only', () {
    final input = Uint8List.fromList([1, 2, 3]);
    final source = MediaUploadSource(bytes: input, mimeType: 'image/png', checksumSha256: hash);
    input[0] = 9;
    expect(source.copyBytes(), [1, 2, 3]);
    final copy = source.copyBytes()..[1] = 8;
    expect(copy, [1, 8, 3]);
    expect(source.copyBytes(), [1, 2, 3]);
    expect(source.metadata.toJson(), {
      'mime_type': 'image/png',
      'byte_length': 3,
      'checksum_sha256': hash,
    });
  });

  test('rejects empty source, MIME parameters and invalid declared checksum', () {
    for (final value in [
      (Uint8List(0), 'image/png', hash),
      (Uint8List(1), 'image/png; private=value', hash),
      (Uint8List(1), 'image/png', 'bad'),
    ]) {
      expect(
        () => MediaUploadSource(bytes: value.$1, mimeType: value.$2, checksumSha256: value.$3),
        throwsA(isA<MediaProtocolException>()),
      );
    }
  });

  test('ticket is immutable and does not print the bearer capability', () {
    final parsed = MediaUploadPreparation.fromJson(payload());
    expect(parsed.target, target);
    expect(parsed.requestId, requestId);
    expect(parsed.ticket!.headers, {'Content-Type': 'image/png'});
    expect(() => parsed.ticket!.headers['Cookie'] = 'secret', throwsUnsupportedError);
    expect(parsed.ticket.toString(), isNot(contains('synthetic')));
  });

  for (final headers in [
    {'Authorization': 'Bearer synthetic'},
    {'Cookie': 'session=synthetic'},
    {'Proxy-Authorization': 'synthetic'},
    {'X-Api-Key': 'synthetic'},
    {'apikey': 'synthetic'},
    {'Host': 'different.invalid'},
    {'Content-Type': 'image/png', 'content-type': 'image/jpeg'},
    {'X-Test': 'value\r\nCookie: synthetic'},
  ]) {
    test('rejects credentials, browser-controlled or ambiguous PUT headers $headers', () {
      final raw = payload();
      (raw['ticket']! as Map<String, Object?>)['headers'] = headers;
      expect(() => MediaUploadPreparation.fromJson(raw), throwsA(isA<MediaProtocolException>()));
    });
  }

  for (final url in [
    'http://media.invalid',
    'https://user:secret@media.invalid',
    'https://media.invalid/#',
    '/relative',
  ]) {
    test('rejects invalid upload URL', () {
      final raw = payload();
      (raw['ticket']! as Map<String, Object?>)['url'] = url;
      expect(() => MediaUploadPreparation.fromJson(raw), throwsA(isA<MediaProtocolException>()));
    });
  }

  test('READY requires a measured server receipt and forbids a PUT ticket', () {
    final raw = payload()..remove('ticket');
    raw['state'] = 'ready';
    expect(() => MediaUploadPreparation.fromJson(raw), throwsA(isA<MediaProtocolException>()));
    raw['receipt'] = {'mime_type': 'image/webp', 'byte_length': 2, 'checksum_sha256': hash};
    final result = MediaUploadPreparation.fromJson(raw);
    expect(result.result.receipt!.mimeType, 'image/webp');
    expect(result.ticket, isNull);
    raw['ticket'] = payload()['ticket'];
    expect(() => MediaUploadPreparation.fromJson(raw), throwsA(isA<MediaProtocolException>()));
  });

  for (final state in ['processing', 'expired', 'unavailable']) {
    test('$state never fabricates a ready receipt or ticket', () {
      final raw = payload()..remove('ticket');
      raw['state'] = state;
      expect(MediaUploadPreparation.fromJson(raw).result.state.name, state);
      raw['receipt'] = {'mime_type': 'image/png', 'byte_length': 1, 'checksum_sha256': hash};
      expect(() => MediaUploadPreparation.fromJson(raw), throwsA(isA<MediaProtocolException>()));
    });
  }

  test('legacy already_uploaded and malformed correlations fail closed', () {
    for (final patch in <Map<String, Object?>>[
      {'state': 'already_uploaded'},
      {'request_id': 'bad'},
      {'asset_id': null},
      {
        'target': {...target.toJson(), 'institution_id': 'bad'},
      },
    ]) {
      expect(
        () => MediaUploadPreparation.fromJson({...payload(), ...patch}),
        throwsA(isA<MediaProtocolException>()),
      );
    }
  });
}
