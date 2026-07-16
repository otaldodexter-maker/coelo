import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'maps a successful password sign-in to a reusable success result',
    () async {
      final persistence = _FakeSessionPersistence();
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(isAuthenticated: false, signInSucceeds: true),
        sessionPersistence: persistence,
      );

      final result = await gateway.signInWithPassword(
        email: 'owner@coelo.me',
        password: 'secret-password',
        persistSession: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.message, isNull);
      expect(persistence.isEnabled, isTrue);
    },
  );

  test(
    'disables persistence before a non-persistent password sign-in',
    () async {
      final events = <String>[];
      final persistence = _FakeSessionPersistence(events: events);
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(
          isAuthenticated: false,
          signInSucceeds: true,
          events: events,
        ),
        sessionPersistence: persistence,
      );

      final result = await gateway.signInWithPassword(
        email: 'owner@coelo.me',
        password: 'secret-password',
        persistSession: false,
      );

      expect(result.isSuccess, isTrue);
      expect(persistence.isEnabled, isFalse);
      expect(events, <String>['persistence:false', 'sign-in']);
    },
  );

  test('converts auth failures into a safe generic login message', () async {
    final gateway = SupabaseCoeloAuthGateway.test(
      _FakeSupabaseAuthApi(
        isAuthenticated: false,
        signInException: Exception('bad credentials'),
      ),
      sessionPersistence: _FakeSessionPersistence(),
    );

    final result = await gateway.signInWithPassword(
      email: 'owner@coelo.me',
      password: 'wrong-password',
      persistSession: false,
    );

    expect(result.isSuccess, isFalse);
    expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
    expect(result.message, isNot(contains('wrong-password')));
  });

  test(
    'rejects a password response without an authenticated session',
    () async {
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(isAuthenticated: false, signInSucceeds: false),
        sessionPersistence: _FakeSessionPersistence(),
      );

      final result = await gateway.signInWithPassword(
        email: 'owner@coelo.me',
        password: 'secret-password',
        persistSession: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
    },
  );

  test(
    'exposes auth state changes as an authentication boolean stream',
    () async {
      final controller = StreamController<bool>();
      addTearDown(controller.close);
      final gateway = SupabaseCoeloAuthGateway.test(
        _FakeSupabaseAuthApi(
          isAuthenticated: false,
          authStateChanges: controller.stream,
        ),
        sessionPersistence: _FakeSessionPersistence(),
      );

      expect(gateway.isAuthenticated, isFalse);
      expectLater(gateway.authStateChanges, emitsInOrder(<bool>[true, false]));

      controller.add(true);
      controller.add(false);
    },
  );

  test('keeps an unavailable environment safe and explicit', () async {
    const gateway = UnavailableCoeloAuthGateway();

    final result = await gateway.signInWithPassword(
      email: 'owner@coelo.me',
      password: 'secret-password',
      persistSession: false,
    );

    expect(gateway.isAuthenticated, isFalse);
    expect(result.isSuccess, isFalse);
    expect(result.message, UnavailableCoeloAuthGateway.defaultMessage);
  });

  test('delegates sign-out to the Supabase auth API', () async {
    final api = _FakeSupabaseAuthApi(isAuthenticated: true);
    final gateway = SupabaseCoeloAuthGateway.test(
      api,
      sessionPersistence: _FakeSessionPersistence(),
    );

    await gateway.signOut();

    expect(api.didSignOut, isTrue);
  });
}

final class _FakeSupabaseAuthApi implements CoeloSupabaseAuthApi {
  _FakeSupabaseAuthApi({
    required this.isAuthenticated,
    this.signInSucceeds = false,
    this.signInException,
    Stream<bool>? authStateChanges,
    this.events,
  }) : authStateChanges = authStateChanges ?? const Stream<bool>.empty();

  @override
  final Stream<bool> authStateChanges;

  @override
  final bool isAuthenticated;

  final bool signInSucceeds;
  final Exception? signInException;
  final List<String>? events;
  bool didSignOut = false;

  @override
  Future<bool> signInWithPassword({
    required String email,
    required String password,
  }) async {
    events?.add('sign-in');
    if (signInException case final exception?) {
      throw exception;
    }
    return signInSucceeds;
  }

  @override
  Future<void> signOut() async {
    didSignOut = true;
  }
}

final class _FakeSessionPersistence implements CoeloAuthSessionPersistence {
  _FakeSessionPersistence({this.events});

  final List<String>? events;
  bool? isEnabled;

  @override
  Future<void> setPersistenceEnabled({required bool value}) async {
    isEnabled = value;
    events?.add('persistence:$value');
  }
}
