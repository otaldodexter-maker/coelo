import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dispose runs cleanup once without notifying or signing out', () {
    var cleanups = 0;
    var notifications = 0;
    final session = SuperadminSession(onDispose: () => cleanups++);
    session.authorize(_context({'platform.read'}), sessionId: 'session-a');
    session.addListener(() => notifications++);
    session.dispose();
    session.dispose();
    expect(cleanups, 1);
    expect(notifications, 0);
    expect(() => session.addListener(() {}), throwsFlutterError);
  });

  test('cleanup failure still disposes listeners and is not repeated', () {
    var cleanups = 0;
    final session = SuperadminSession(
      onDispose: () {
        cleanups++;
        throw StateError('cleanup failed');
      },
    );
    session.addListener(() {});
    expect(session.dispose, throwsStateError);
    expect(() => session.addListener(() {}), throwsFlutterError);
    session.dispose();
    expect(cleanups, 1);
  });

  test('first completed bootstrap invalidates another pending result', () {
    final session = SuperadminSession();
    addTearDown(session.dispose);
    final revision = session.authorizationInvalidationRevision;
    expect(
      session.authorizeIfCurrent(
        _context({'platform.read'}),
        sessionId: 'session-a',
        expectedInvalidationRevision: revision,
      ),
      isTrue,
    );
    expect(
      session.authorizeIfCurrent(
        _context({'platform.read', 'platform.member.read'}),
        sessionId: 'session-a',
        expectedInvalidationRevision: revision,
      ),
      isFalse,
    );
    expect(session.authContext!.permissionCodes, {'platform.read'});
  });

  test('initial authorization notifies once and identical reauthorization is stable', () {
    final session = SuperadminSession();
    addTearDown(session.dispose);
    var notifications = 0;
    session.addListener(() => notifications++);
    final context = _context({'platform.read', 'platform.member.read'});
    session.authorize(context, sessionId: 'session-a');
    expect(notifications, 1);
    final revision = session.authorizationInvalidationRevision;
    session.authorize(_context({'platform.member.read', 'platform.read'}), sessionId: 'session-a');
    expect(notifications, 1);
    expect(session.authContext, same(context));
    expect(session.authorizationInvalidationRevision, revision);
  });

  test('context A to B notifies while authenticated remains true', () {
    final session = SuperadminSession();
    addTearDown(session.dispose);
    session.authorize(_context({'platform.read', 'platform.member.read'}), sessionId: 'session-a');
    final revision = session.authorizationInvalidationRevision;
    var notifications = 0;
    session.addListener(() => notifications++);
    session.authorize(_context({'platform.read'}), sessionId: 'session-a');
    expect(session.isAuthenticated, isTrue);
    expect(session.authContext!.permissionCodes, {'platform.read'});
    expect(notifications, 1);
    expect(session.authorizationInvalidationRevision, greaterThan(revision));
    expect(
      session.authorizeIfCurrent(
        _context({'platform.read', 'platform.member.read'}),
        sessionId: 'session-a',
        expectedInvalidationRevision: revision,
      ),
      isFalse,
    );
    expect(notifications, 1);
  });

  test('replacement session with equal context notifies once', () {
    final session = SuperadminSession();
    addTearDown(session.dispose);
    final context = _context({'platform.read'});
    session.authorize(context, sessionId: 'session-a');
    final revision = session.authorizationInvalidationRevision;
    var notifications = 0;
    session.addListener(() => notifications++);
    session.authorize(context, sessionId: 'session-b');
    expect(notifications, 1);
    expect(session.isAuthenticated, isTrue);
    expect(session.authorizationInvalidationRevision, greaterThan(revision));
    expect(
      session.authorizeIfCurrent(
        context,
        sessionId: 'session-a',
        expectedInvalidationRevision: revision,
      ),
      isFalse,
    );
  });

  for (final changed in [
    const SuperadminAuthContext(
      platformRoleCode: 'auditor',
      scopeKind: SuperadminAuthScopeKind.platform,
      permissionCodes: {'platform.read'},
      aal: 'aal1',
    ),
    const SuperadminAuthContext(
      platformRoleCode: 'operations',
      scopeKind: SuperadminAuthScopeKind.institution,
      scopeInstitutionId: 'institution-b',
      permissionCodes: {'platform.read'},
      aal: 'aal1',
    ),
    const SuperadminAuthContext(
      platformRoleCode: 'operations',
      scopeKind: SuperadminAuthScopeKind.platform,
      permissionCodes: {'platform.read'},
      aal: 'aal2',
    ),
  ]) {
    test(
      'notifies on field change: ${changed.platformRoleCode}/${changed.scopeKind}/${changed.aal}',
      () {
        final session = SuperadminSession();
        addTearDown(session.dispose);
        session.authorize(_context({'platform.read'}), sessionId: 'session-a');
        var notifications = 0;
        session.addListener(() => notifications++);
        session.authorize(changed, sessionId: 'session-a');
        expect(notifications, 1);
        expect(session.authContext, same(changed));
      },
    );
  }

  test('logout clears context and does not duplicate signed-out notifications', () {
    final session = SuperadminSession();
    addTearDown(session.dispose);
    session.authorize(_context({'platform.read'}), sessionId: 'session-a');
    var notifications = 0;
    session.addListener(() => notifications++);
    session.signOut();
    session.signOut();
    expect(notifications, 1);
    expect(session.authContext, isNull);
    expect(session.isAuthenticated, isFalse);
  });

  test('recovery invalidates context and disposal cancels the stream', () async {
    final states = StreamController<CoeloAuthSessionState>(sync: true);
    final session = SuperadminSession(authSessionStateChanges: states.stream);
    session.authorize(_context({'platform.read'}), sessionId: 'session-a');
    var notifications = 0;
    session.addListener(() => notifications++);
    states.add(const CoeloAuthSessionState.passwordRecovery());
    expect(session.authContext, isNull);
    expect(session.isAuthenticated, isFalse);
    expect(session.isPasswordRecovery, isTrue);
    expect(notifications, 1);
    session.dispose();
    states.add(const CoeloAuthSessionState.signedOut());
    expect(notifications, 1);
    await states.close();
  });

  test('unexpected session event fails closed instead of replacing context', () async {
    final states = StreamController<CoeloAuthSessionState>(sync: true);
    final session = SuperadminSession(authSessionStateChanges: states.stream);
    addTearDown(session.dispose);
    addTearDown(states.close);
    session.authorize(_context({'platform.read'}), sessionId: 'session-a');
    var notifications = 0;
    session.addListener(() => notifications++);
    states.add(const CoeloAuthSessionState.authenticated(sessionId: 'session-b'));
    expect(session.authContext, isNull);
    expect(session.isAuthenticated, isFalse);
    expect(notifications, 1);
  });
}

SuperadminAuthContext _context(Set<String> permissions) => SuperadminAuthContext(
  platformRoleCode: 'operations',
  scopeKind: SuperadminAuthScopeKind.platform,
  permissionCodes: permissions,
  aal: 'aal1',
);
