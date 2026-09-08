import 'dart:async';

import 'package:coelo_superadmin/core/config/superadmin_media_scope.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/forms/data/form_export_download_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SuperadminSession session;
  late SuperadminMediaScope media;
  late _Gateway gateway;

  setUp(() {
    session = SuperadminSession();
    gateway = _Gateway();
    media = SuperadminMediaScope(session: session, downloadGateway: gateway);
  });
  tearDown(() {
    media.dispose();
    session.dispose();
  });

  Future<void> authorize([
    String id = 'session-a',
    Set<String> permissions = const {'forms.read'},
  ]) async {
    session.authorize(_context(permissions), sessionId: id);
    await _settle();
  }

  test('only authorized sessions receive a cached resolver and media lifetime', () async {
    expect(media.current, isNull);
    expect(media.downloadResolver, isNull);
    await authorize();
    final first = media.current;
    final resolver = media.downloadResolver;
    expect(first, isNotNull);
    expect(resolver, isNotNull);
    await authorize();
    expect(media.current, same(first));
    expect(media.downloadResolver, same(resolver));
    expect(gateway.calls, 0);
  });

  test('prepare waits for purge and never republishes A before commit', () async {
    await authorize();
    final first = media.current!;
    final purge = Completer<void>();
    first.registerPurge(() => purge.future);
    var finished = false;
    final preparation = media.prepareAuthorization().then((value) {
      finished = true;
      return value;
    });
    expect(first.isInvalidated, isTrue);
    expect(media.current, isNull);
    expect(media.downloadResolver, isNull);
    await _settle();
    expect(finished, isFalse);
    purge.complete();
    expect(await preparation, isTrue);
    await _settle();
    expect(media.current, isNull);
    await authorize(); // Identical context does not notify SuperadminSession.
    expect(media.current, isNull);
    media.authorizationCommitted();
    await _settle();
    expect(media.current, isNotNull);
    expect(media.current, isNot(same(first)));
  });

  test('second authorization remains without media until purge and commit', () async {
    await authorize();
    final first = media.current!;
    final oldResolver = media.downloadResolver;
    final purge = Completer<void>();
    first.registerPurge(() => purge.future);
    final prepared = media.prepareAuthorization();
    await _settle();
    expect(media.current, isNull);
    purge.complete();
    expect(await prepared, isTrue);
    session.authorize(_context({'forms.responses.export'}), sessionId: 'session-b');
    await _settle();
    expect(media.current, isNull);
    media.authorizationCommitted();
    await _settle();
    expect(media.current, isNotNull);
    expect(media.current, isNot(same(first)));
    expect(media.downloadResolver, isNot(same(oldResolver)));
  });

  test('revocation during purge invalidates preparation and cannot publish', () async {
    await authorize();
    final purge = Completer<void>();
    media.current!.registerPurge(() => purge.future);
    final prepared = media.prepareAuthorization();
    session.signOut();
    purge.complete();
    expect(await prepared, isFalse);
    media.authorizationCommitted();
    await _settle();
    expect(media.current, isNull);
    expect(media.downloadResolver, isNull);
  });

  test('publication queued before preparation cannot bypass explicit commit', () async {
    session.authorize(_context({'forms.read'}), sessionId: 'session-a');
    // Do not let the authorization listener's publication microtask run first.
    expect(await media.prepareAuthorization(), isTrue);
    await _settle();
    expect(media.current, isNull);
    media.authorizationCommitted();
    await _settle();
    expect(media.current, isNotNull);
  });

  test('only the latest overlapping preparation succeeds', () async {
    await authorize();
    final purge = Completer<void>();
    media.current!.registerPurge(() => purge.future);
    final first = media.prepareAuthorization();
    final second = media.prepareAuthorization();
    purge.complete();
    expect(await first, isFalse);
    expect(await second, isTrue);
    expect(media.current, isNull);
    media.authorizationCommitted();
    await _settle();
    expect(media.current, isNotNull);
  });

  test('external A B A waits for purge and cannot revive the original lifetime', () async {
    await authorize();
    final first = media.current!;
    final initialGeneration = media.generation;
    final purge = Completer<void>();
    first.registerPurge(() => purge.future);
    session.authorize(_context({'forms.read'}), sessionId: 'session-b');
    session.authorize(_context({'forms.read'}), sessionId: 'session-a');
    await _settle();
    expect(first.isInvalidated, isTrue);
    expect(media.current, isNull);
    purge.complete();
    await _settle();
    expect(media.current, isNotNull);
    expect(media.current, isNot(same(first)));
    expect(media.generation, greaterThan(initialGeneration));
  });

  test('permissions change with same credentials renews and purges media', () async {
    await authorize();
    final first = media.current!;
    var purges = 0;
    first.registerPurge(() => purges++);
    await authorize('session-a', {'forms.responses.export'});
    expect(purges, 1);
    expect(first.isInvalidated, isTrue);
    expect(media.current, isNotNull);
    expect(media.current, isNot(same(first)));
  });

  for (final failure in [StateError('private capability'), Exception('private capability')]) {
    test('purge ${failure.runtimeType} blocks future lifetimes without leaking error', () async {
      await authorize();
      final first = media.current!;
      first.registerPurge(() => throw failure);
      expect(await media.prepareAuthorization(), isFalse);
      session.authorize(_context({'forms.read'}), sessionId: 'session-b');
      media.authorizationCommitted();
      await _settle();
      expect(media.current, isNull);
      expect(media.downloadResolver, isNull);
      expect(await media.prepareAuthorization(), isFalse);
      expect(first.isInvalidated, isTrue);
    });
  }

  test('dispose during purge cannot notify or publish after completion', () async {
    await authorize();
    final first = media.current!;
    final purge = Completer<void>();
    first.registerPurge(() => purge.future);
    final prepared = media.prepareAuthorization();
    var notificationsAfterPreparation = 0;
    media.addListener(() => notificationsAfterPreparation++);
    media.dispose();
    purge.completeError(StateError('private purge failure'));
    expect(await prepared, isFalse);
    session.authorize(_context({'forms.read'}), sessionId: 'session-b');
    media.authorizationCommitted();
    expect(await media.prepareAuthorization(), isFalse);
    await _settle();
    expect(media.current, isNull);
    expect(media.downloadResolver, isNull);
    expect(first.isInvalidated, isTrue);
    expect(notificationsAfterPreparation, 0);
  });

  test('logout purges immediately and the next external authorization waits', () async {
    await authorize();
    final first = media.current!;
    final purge = Completer<void>();
    first.registerPurge(() => purge.future);
    session.signOut();
    expect(first.isInvalidated, isTrue);
    expect(media.current, isNull);
    session.authorize(_context({'forms.read'}), sessionId: 'session-b');
    await _settle();
    expect(media.current, isNull);
    purge.complete();
    await _settle();
    expect(media.current, isNotNull);
    expect(media.current, isNot(same(first)));
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

SuperadminAuthContext _context(Set<String> permissions) => SuperadminAuthContext(
  platformRoleCode: 'superadmin',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: permissions,
  aal: 'aal2',
);

final class _Gateway implements FormExportDownloadGateway {
  int calls = 0;
  @override
  Future<Object?> resolve(String jobId) async {
    calls++;
    throw StateError('No download should be requested by lifetime composition.');
  }
}
