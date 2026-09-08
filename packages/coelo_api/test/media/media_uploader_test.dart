import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:test/test.dart';

const asset = '9b400000-0000-4000-8000-000000000001';
const request = '9b400000-0000-4000-8000-000000000002';
const finish = '9b400000-0000-4000-8000-000000000003';
const other = '9b400000-0000-4000-8000-000000000004';
final now = DateTime.utc(2026, 9, 8, 19);
final target = MediaUploadTarget(
  institutionId: asset,
  resourceId: asset,
  domain: 'forms',
  purpose: 'answer-image',
);
final hash = 'a' * 64;
Map<String, Object?> response([String state = 'ready']) => {
  'target': target.toJson(),
  'asset_id': asset,
  'state': state,
  if (state == 'ready')
    'receipt': {'mime_type': 'image/webp', 'byte_length': 2, 'checksum_sha256': hash},
};
MediaUploadPreparation preparation({String? id, String? expiry, MediaUploadTarget? scope}) =>
    MediaUploadPreparation.fromJson({
      ...response('uploadRequired'),
      'request_id': id ?? request,
      if (scope != null) 'target': scope.toJson(),
      'ticket': {
        'url': 'https://media.invalid/opaque?signature=synthetic',
        'expires_at': expiry ?? '2026-09-08T19:02:00Z',
        'headers': {'Content-Type': 'image/png'},
      },
    });

void main() {
  late _Gateway gateway;
  late MediaSession session;
  late SessionMediaUploader uploader;
  late Future<void> Function(MediaUploadTransfer) put;
  late List<String> calls;
  Future<MediaUploadResult> upload() => uploader.upload(
    requestId: request,
    finalizeRequestId: finish,
    source: MediaUploadSource(
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/png',
      checksumSha256: hash,
    ),
  );
  setUp(() {
    calls = [];
    gateway = _Gateway(calls, target);
    session = MediaSession();
    put = (transfer) async {
      calls.add('put');
      expect(transfer.bytes, [1, 2, 3]);
    };
    uploader = SessionMediaUploader(
      gateway: gateway,
      session: session,
      put: (value) => put(value),
      now: () => now,
    );
  });

  test('prepare PUT finalize preserves stable IDs, exact headers and measured receipt', () async {
    MediaUploadTransfer? retained;
    put = (transfer) async {
      calls.add('put');
      retained = transfer;
      expect(transfer.headers, {'Content-Type': 'image/png'});
      expect(() => transfer.bytes[0] = 7, throwsUnsupportedError);
    };
    final result = await upload();
    expect(calls, ['prepare:$request', 'put', 'finalize:$finish']);
    expect(result.receipt!.byteLength, 2);
    expect(retained!.bytes, [0, 0, 0]);
    expect(retained!.isCancelled, isTrue);
  });

  test('READY replay skips PUT and finalize', () async {
    gateway.prepareResult = () async =>
        MediaUploadPreparation.fromJson({...response(), 'request_id': request});
    expect((await upload()).state, MediaUploadState.ready);
    expect(calls, ['prepare:$request']);
  });

  for (final invalid in [
    () => preparation(id: other),
    () => preparation(expiry: '2026-09-08T19:00:00Z'),
    () => preparation(
      scope: MediaUploadTarget(
        institutionId: other,
        resourceId: asset,
        domain: 'forms',
        purpose: 'answer-image',
      ),
    ),
  ]) {
    test('invalid prepare correlation or TTL prevents PUT', () async {
      gateway.prepareResult = () async => invalid();
      await expectLater(
        upload(),
        throwsA(anyOf(isA<MediaProtocolException>(), isA<MediaTicketExpiredException>())),
      );
      expect(calls, ['prepare:$request']);
    });
  }

  test('already invalidated session never calls gateway', () async {
    await session.invalidate();
    await expectLater(upload(), throwsA(isA<MediaSessionInvalidatedException>()));
    expect(calls, isEmpty);
  });

  for (final step in ['prepare', 'put', 'finalize', 'reconcile']) {
    test('invalidation during $step rejects late completion and later stages', () async {
      final reached = Completer<void>();
      final release = Completer<void>();
      Future<void> pause() async {
        reached.complete();
        await release.future;
      }

      if (step == 'prepare') {
        gateway.prepareResult = () async {
          await pause();
          return preparation();
        };
      }
      if (step == 'put') {
        put = (transfer) async {
          calls.add('put');
          await pause();
          expect(transfer.isCancelled, isTrue);
          expect(transfer.bytes, [0, 0, 0]);
        };
      }
      if (step == 'finalize') {
        gateway.finalizeResult = () async {
          await pause();
          return MediaUploadResult.fromJson(response());
        };
      }
      if (step == 'reconcile') {
        gateway.finalizeResult = () async => throw StateError('synthetic secret');
        gateway.reconcileResult = () async {
          await pause();
          return MediaUploadResult.fromJson(response());
        };
      }
      final rejected = expectLater(upload(), throwsA(isA<MediaSessionInvalidatedException>()));
      await reached.future;
      await session.invalidate();
      release.complete();
      await rejected;
      expect(calls, isNot(contains('discard')));
      if (step == 'prepare') expect(calls, ['prepare:$request']);
      if (step == 'put') expect(calls, ['prepare:$request', 'put']);
    });
  }

  for (final step in ['put', 'finalize']) {
    for (final state in ['ready', 'processing']) {
      test('$step error reconciles $state once without deleting or retrying PUT', () async {
        if (step == 'put') {
          put = (_) async {
            calls.add('put');
            throw StateError('synthetic secret');
          };
        }
        if (step == 'finalize') {
          gateway.finalizeResult = () async => throw StateError('synthetic secret');
        }
        gateway.reconcileResult = () async => MediaUploadResult.fromJson(response(state));
        expect((await upload()).state.name, state);
        expect(calls.where((call) => call == 'reconcile'), hasLength(1));
        expect(calls.where((call) => call == 'put'), hasLength(1));
        expect(calls, isNot(contains('discard')));
        if (step == 'put') expect(calls, isNot(contains('finalize:$finish')));
      });
    }
  }

  test('ambiguous failure exposes only safe asset correlation', () async {
    gateway.finalizeResult = () async => throw StateError('https://private.invalid?token=secret');
    gateway.reconcileResult = () async => throw StateError('session=secret');
    await expectLater(
      upload(),
      throwsA(
        isA<MediaUploadUncertainException>()
            .having((error) => error.assetId, 'asset', asset)
            .having((error) => error.toString(), 'safe text', isNot(contains('secret'))),
      ),
    );
    expect(calls, isNot(contains('discard')));
  });

  test('wrong asset at finalize never releases receipt', () async {
    gateway.finalizeResult = () async =>
        MediaUploadResult.fromJson({...response(), 'asset_id': other});
    await expectLater(upload(), throwsA(isA<MediaProtocolException>()));
    expect(calls, isNot(contains('discard')));
  });

  test('explicit discard is gated, preserves request ID and does not call transport', () async {
    await uploader.discard(requestId: request, assetId: asset);
    expect(calls, ['discard:$request:$asset']);
    await session.invalidate();
    await expectLater(
      uploader.discard(requestId: request, assetId: asset),
      throwsA(isA<MediaSessionInvalidatedException>()),
    );
    expect(calls, hasLength(1));
  });

  test('source is copied before prepare even if the caller clears its source', () async {
    final input = Uint8List.fromList([1, 2, 3]);
    final source = MediaUploadSource(bytes: input, mimeType: 'image/png', checksumSha256: hash);
    final reached = Completer<void>();
    final release = Completer<void>();
    gateway.prepareResult = () async {
      reached.complete();
      await release.future;
      return preparation();
    };
    final result = uploader.upload(requestId: request, finalizeRequestId: finish, source: source);
    await reached.future;
    input.fillRange(0, input.length, 9);
    source.clear();
    release.complete();
    expect((await result).state, MediaUploadState.ready);
    expect(calls, ['prepare:$request', 'put', 'finalize:$finish']);
  });

  test('failed PUT purges transfer before reconciliation begins', () async {
    late MediaUploadTransfer retained;
    put = (value) async {
      retained = value;
      throw StateError('private');
    };
    gateway.reconcileResult = () async {
      expect(retained.isCancelled, isTrue);
      expect(retained.bytes, [0, 0, 0]);
      expect(() => retained.url, throwsA(isA<MediaUploadException>()));
      return MediaUploadResult.fromJson(response('processing'));
    };
    expect((await upload()).state, MediaUploadState.processing);
  });

  test('gateway target mutation during prepare prevents transport', () async {
    gateway.prepareResult = () async {
      gateway.targetValue = MediaUploadTarget(
        institutionId: other,
        resourceId: asset,
        domain: 'forms',
        purpose: 'answer-image',
      );
      return preparation();
    };
    await expectLater(upload(), throwsA(isA<MediaProtocolException>()));
    expect(calls, ['prepare:$request']);
  });

  test('wrong asset during reconciliation never returns a receipt', () async {
    gateway.finalizeResult = () async => throw StateError('private');
    gateway.reconcileResult = () async =>
        MediaUploadResult.fromJson({...response(), 'asset_id': other});
    await expectLater(upload(), throwsA(isA<MediaProtocolException>()));
    expect(calls, isNot(contains('discard')));
  });

  test('invalidation also rejects a late failing request without leaking its error', () async {
    final reached = Completer<void>();
    final release = Completer<void>();
    gateway.prepareResult = () async {
      reached.complete();
      await release.future;
      throw StateError('private');
    };
    final source = MediaUploadSource(
      bytes: Uint8List.fromList([1, 2, 3]),
      mimeType: 'image/png',
      checksumSha256: hash,
    );
    final result = expectLater(
      uploader.upload(requestId: request, finalizeRequestId: finish, source: source),
      throwsA(isA<MediaSessionInvalidatedException>()),
    );
    await reached.future;
    await session.invalidate();
    expect(source.copyBytes, throwsA(isA<MediaProtocolException>()));
    release.complete();
    await result;
    expect(calls, ['prepare:$request']);
  });

  test('prepare dependency error is safe and does not create a cleanup request', () async {
    gateway.prepareResult = () async => throw StateError('private token');
    await expectLater(
      upload(),
      throwsA(
        isA<MediaUploadException>().having(
          (error) => error.toString(),
          'safe message',
          'Private media upload failed.',
        ),
      ),
    );
    expect(calls, ['prepare:$request']);
  });

  test('late discard completion is rejected after invalidation', () async {
    final release = Completer<void>();
    gateway.discardResult = () => release.future;
    final result = expectLater(
      uploader.discard(requestId: request, assetId: asset),
      throwsA(isA<MediaSessionInvalidatedException>()),
    );
    await session.invalidate();
    release.complete();
    await result;
  });
}

final class _Gateway implements MediaUploadGateway {
  _Gateway(this.calls, this.targetValue);
  final List<String> calls;
  @override
  MediaUploadTarget get target => targetValue;
  MediaUploadTarget targetValue;
  Future<void> Function() discardResult = () async {};
  Future<MediaUploadPreparation> Function() prepareResult = () async => preparation();
  Future<MediaUploadResult> Function() finalizeResult = () async =>
      MediaUploadResult.fromJson(response());
  Future<MediaUploadResult> Function() reconcileResult = () async =>
      MediaUploadResult.fromJson(response());
  @override
  Future<MediaUploadPreparation> prepare({
    required String requestId,
    required MediaUploadMetadata sourceMetadata,
  }) {
    calls.add('prepare:$requestId');
    return prepareResult();
  }

  @override
  Future<MediaUploadResult> finalize({required String requestId, required String assetId}) {
    calls.add('finalize:$requestId');
    return finalizeResult();
  }

  @override
  Future<MediaUploadResult> reconcile({required String assetId}) {
    calls.add('reconcile');
    return reconcileResult();
  }

  @override
  Future<void> discard({required String requestId, required String assetId}) async {
    calls.add('discard:$requestId:$assetId');
    await discardResult();
  }
}
