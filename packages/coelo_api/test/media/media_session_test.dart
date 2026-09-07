import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:test/test.dart';

void main() {
  test('returns a gateway result while its session is active', () async {
    final session = MediaSession();
    expect(await session.run(() async => 'asset-result'), 'asset-result');
    expect(session.isInvalidated, isFalse);
  });

  test('logout invalidates immediately and blocks new requests during purge', () async {
    final session = MediaSession();
    final purged = Completer<void>();
    session.registerPurge(() => purged.future);
    final invalidating = session.invalidate();
    expect(session.isInvalidated, isTrue);
    var requested = false;
    await expectLater(
      session.run(() async {
        requested = true;
        return 'private';
      }),
      throwsA(isA<MediaSessionInvalidatedException>()),
    );
    expect(requested, isFalse);
    purged.complete();
    await invalidating;
  });

  test('does not release a late gateway result after context revocation', () async {
    final session = MediaSession();
    final response = Completer<String>();
    final pending = session.run(() => response.future);
    final rejected = expectLater(pending, throwsA(isA<MediaSessionInvalidatedException>()));
    await session.invalidate();
    response.complete('private-ticket');
    await rejected;
  });

  test('old context stays invalid even after another session is created', () async {
    final old = MediaSession();
    await old.invalidate();
    final next = MediaSession();
    expect(await next.run(() async => 'new-context'), 'new-context');
    await expectLater(
      old.run(() async => 'old-context'),
      throwsA(isA<MediaSessionInvalidatedException>()),
    );
  });

  test('purges every registered resource once and shares concurrent invalidation', () async {
    final session = MediaSession();
    final release = Completer<void>();
    final calls = <String>[];
    session.registerPurge(() {
      calls.add('tickets');
    });
    session.registerPurge(() async {
      calls.add('bytes');
      await release.future;
    });
    final first = session.invalidate();
    final second = session.invalidate();
    expect(identical(first, second), isTrue);
    release.complete();
    await first;
    await session.invalidate();
    expect(calls, ['tickets', 'bytes']);
  });

  test('a disposed consumer can unregister its purge callback', () async {
    final session = MediaSession();
    var called = false;
    final unregister = session.registerPurge(() {
      called = true;
    });
    unregister();
    unregister();
    await session.invalidate();
    expect(called, isFalse);
  });

  test('purge failure does not skip other resources or reopen the session', () async {
    final session = MediaSession();
    var cleared = false;
    session.registerPurge(() {
      throw StateError('private diagnostic');
    });
    session.registerPurge(() async {
      cleared = true;
    });
    await expectLater(session.invalidate(), throwsA(isA<MediaSessionPurgeException>()));
    expect(cleared, isTrue);
    expect(session.isInvalidated, isTrue);
    await expectLater(
      session.run(() async => 'secret'),
      throwsA(isA<MediaSessionInvalidatedException>()),
    );
  });

  test('cannot register a new consumer on an invalidated session', () async {
    final session = MediaSession();
    await session.invalidate();
    expect(() => session.registerPurge(() {}), throwsA(isA<MediaSessionInvalidatedException>()));
  });

  test('preserves active transport failures for the gateway to classify', () async {
    final session = MediaSession();
    final failure = Exception('offline');
    await expectLater(session.run<String>(() => Future.error(failure)), throwsA(same(failure)));
  });
}
