import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('uses a safe unavailable scope when Supabase config is missing', () async {
    var didInitialize = false;

    final scope = await createSuperadminAuthScope(
      supabaseUrl: '',
      supabasePublishableKey: '',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async {
        didInitialize = true;
        return SupabaseClient(url, publishableKey);
      },
    );
    addTearDown(scope.session.dispose);

    final result = await scope.login(
      const LoginRequest(
        email: 'owner@coelo.me',
        password: 'secret-password',
        keepSessionOpen: false,
      ),
    );

    expect(didInitialize, isFalse);
    expect(scope.session.isAuthenticated, isFalse);
    expect(result.isSuccess, isFalse);
    expect(result.message, UnavailableCoeloAuthGateway.defaultMessage);
  });

  test('initializes Supabase with public config and conditional local storage', () async {
    String? initializedUrl;
    String? initializedKey;
    LocalStorage? initializedStorage;

    final scope = await createSuperadminAuthScope(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async {
        initializedUrl = url;
        initializedKey = publishableKey;
        initializedStorage = localStorage;
        return SupabaseClient(url, publishableKey);
      },
    );
    addTearDown(scope.session.dispose);

    expect(initializedUrl, 'https://project.supabase.co');
    expect(initializedKey, 'sb_publishable_test');
    expect(initializedStorage, isA<ConditionalSupabaseLocalStorage>());
    expect(scope.session.isAuthenticated, isFalse);
  });

  test('starts authenticated from a restored session and mirrors later auth changes', () async {
    final authStates = StreamController<bool>();
    addTearDown(authStates.close);
    final auth = _FakeCoeloAuthGateway(isAuthenticated: true, authStateChanges: authStates.stream);

    final scope = await createSuperadminAuthScope(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async {
        return SupabaseClient(url, publishableKey);
      },
      createAuthGateway: ({required client, required sessionPersistence}) => auth,
    );
    addTearDown(scope.session.dispose);

    expect(scope.session.isAuthenticated, isTrue);

    authStates.add(false);
    await Future<void>.delayed(Duration.zero);

    expect(scope.session.isAuthenticated, isFalse);
  });

  test('falls back safely when Supabase initialization fails', () async {
    final previousErrorHandler = FlutterError.onError;
    final reportedErrors = <FlutterErrorDetails>[];
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousErrorHandler);

    final scope = await createSuperadminAuthScope(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async {
        throw Exception('initialization failed');
      },
    );
    addTearDown(scope.session.dispose);

    final result = await scope.login(
      const LoginRequest(
        email: 'owner@coelo.me',
        password: 'secret-password',
        keepSessionOpen: false,
      ),
    );

    expect(reportedErrors, hasLength(1));
    expect(result.isSuccess, isFalse);
    expect(result.message, 'Não foi possível inicializar a autenticação deste ambiente.');
  });
}

final class _FakeCoeloAuthGateway implements CoeloAuthGateway {
  _FakeCoeloAuthGateway({required this.isAuthenticated, required this.authStateChanges});

  @override
  final bool isAuthenticated;

  @override
  final Stream<bool> authStateChanges;

  @override
  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) async {
    return const CoeloAuthSignInResult.success();
  }

  @override
  Future<void> signOut() async {}
}
