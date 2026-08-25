import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/attendance/data/supabase_attendance_repository.dart';
import 'package:coelo_superadmin/features/audit/data/supabase_audit_repository.dart';
import 'package:coelo_superadmin/features/audit/domain/audit.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:coelo_superadmin/features/invites/data/supabase_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/people/data/supabase_person_directory_repository.dart';
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
    final recoveryResult = await scope.requestPasswordRecovery('owner@coelo.me');

    expect(didInitialize, isFalse);
    expect(scope.session.isAuthenticated, isFalse);
    expect(result.isSuccess, isFalse);
    expect(result.message, UnavailableCoeloAuthGateway.defaultMessage);
    expect(recoveryResult.isSuccess, isFalse);
    expect(recoveryResult.message, UnavailableCoeloAuthGateway.defaultMessage);
    expect(scope.personDirectoryRepository, isA<UnavailablePersonDirectoryRepository>());
    expect(scope.inviteRepository, isA<UnavailableInviteRepository>());
    expect(scope.attendanceRepository, isA<UnavailableAttendanceRepository>());
    expect(scope.attendancePermissions.canManage, isFalse);
    expect(scope.auditRepository, isA<UnavailableAuditRepository>());
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
    expect(scope.personDirectoryRepository, isA<SupabasePersonDirectoryRepository>());
    expect(scope.inviteRepository, isA<SupabaseInviteRepository>());
    expect(scope.attendanceRepository, isA<SupabaseAttendanceRepository>());
    expect(scope.attendancePermissions.canManage, isFalse);
    expect(scope.attendancePermissions.backendResolved, isTrue);
    expect(scope.auditRepository, isA<SupabaseAuditRepository>());
    expect(scope.medicationPlanRepository, isA<UnavailableMedicationPlanRepository>());
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

  test('exposes password recovery through the configured auth gateway', () async {
    final auth = _FakeCoeloAuthGateway(
      isAuthenticated: false,
      authStateChanges: const Stream<bool>.empty(),
    );

    final scope = await createSuperadminAuthScope(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async {
        return SupabaseClient(url, publishableKey);
      },
      createAuthGateway: ({required client, required sessionPersistence}) => auth,
    );
    addTearDown(scope.session.dispose);

    final result = await scope.requestPasswordRecovery('owner@coelo.me');

    expect(result.isSuccess, isTrue);
    expect(auth.lastRecoveryEmail, 'owner@coelo.me');
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
  String? lastRecoveryEmail;

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecovery({required String email}) async {
    lastRecoveryEmail = email;
    return const CoeloAuthPasswordRecoveryResult.success();
  }

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
