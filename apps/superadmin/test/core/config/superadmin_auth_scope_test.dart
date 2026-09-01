import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/config/superadmin_auth_scope.dart';
import 'package:coelo_superadmin/features/access_profiles/data/supabase_access_profile_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/attendance/data/supabase_attendance_repository.dart';
import 'package:coelo_superadmin/features/audit/data/supabase_audit_repository.dart';
import 'package:coelo_superadmin/features/audit/domain/audit.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/domain/superadmin_auth_context.dart';
import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:coelo_superadmin/features/health_care/domain/medication_plan_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/people/data/supabase_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_identity.dart';
import 'package:coelo_superadmin/features/student_tracking/domain/student_tracking.dart';
import 'package:coelo_superadmin/features/units/data/unavailable_unit_composition.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('builds a clean same-origin password recovery redirect', () {
    final redirect = buildSuperadminPasswordRecoveryRedirect(
      Uri.parse('http://attacker@127.0.0.1:8766/login?unsafe=value#fragment'),
    );

    expect(redirect, Uri.parse('http://127.0.0.1:8766/reset-password'));
  });

  test('recognizes only a recovery callback on the reset route', () {
    expect(
      isSuperadminPasswordRecoveryRedirect(
        Uri.parse(
          'http://127.0.0.1:8766/reset-password'
          '#type=recovery&access_token=access&refresh_token=refresh',
        ),
      ),
      isTrue,
    );
    expect(
      isSuperadminPasswordRecoveryRedirect(
        Uri.parse('http://127.0.0.1:8766/reset-password#type=recovery'),
      ),
      isFalse,
    );
    expect(
      isSuperadminPasswordRecoveryRedirect(
        Uri.parse(
          'http://127.0.0.1:8766/reset-password'
          '?type=recovery&access_token=access&refresh_token=refresh',
        ),
      ),
      isFalse,
    );
    expect(
      isSuperadminPasswordRecoveryRedirect(
        Uri.parse('http://127.0.0.1:8766/reset-password#type=signup'),
      ),
      isFalse,
    );
    expect(
      isSuperadminPasswordRecoveryRedirect(Uri.parse('http://127.0.0.1:8766/?type=recovery')),
      isFalse,
    );
  });

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
    expect(scope.activityDirectoryRepository, isA<UnavailableActivityDirectoryRepository>());
    expect(scope.activityCommandRepository, isA<UnavailableActivityCommandRepository>());
    expect(scope.personIdentityRepository, isA<UnavailablePersonIdentityRepository>());
    expect(scope.accessProfileRepository, isA<UnavailableAccessProfileRepository>());
    expect(scope.inviteRepository, isA<UnavailableInviteRepository>());
    expect(scope.attendanceRepository, isA<UnavailableAttendanceRepository>());
    expect(scope.studentTrackingRepository, isA<UnavailableStudentTrackingRepository>());
    expect(scope.routineRepository, isA<UnavailableRoutineRepository>());
    expect(scope.groupDirectoryRepository, isA<UnavailableGroupDirectoryRepository>());
    expect(scope.unitDirectoryRepository, isA<UnavailableUnitDirectoryRepository>());
    expect(scope.unitBackendCommands, isA<UnavailableUnitBackendCommandsGateway>());
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
    expect(scope.activityDirectoryRepository, isA<UnavailableActivityDirectoryRepository>());
    expect(scope.activityCommandRepository, isA<UnavailableActivityCommandRepository>());
    expect(scope.personIdentityRepository, isA<UnavailablePersonIdentityRepository>());
    expect(scope.accessProfileRepository, isA<UnavailableAccessProfileRepository>());
    expect(scope.inviteRepository, isA<UnavailableInviteRepository>());
    expect(scope.attendanceRepository, isA<SupabaseAttendanceRepository>());
    expect(scope.studentTrackingRepository, isA<UnavailableStudentTrackingRepository>());
    expect(scope.routineRepository, isA<UnavailableRoutineRepository>());
    expect(scope.groupDirectoryRepository, isA<UnavailableGroupDirectoryRepository>());
    expect(scope.activityDirectoryRepository, isA<UnavailableActivityDirectoryRepository>());
    expect(scope.activityCommandRepository, isA<UnavailableActivityCommandRepository>());
    expect(scope.unitDirectoryRepository, isA<UnavailableUnitDirectoryRepository>());
    expect(scope.unitBackendCommands, isA<UnavailableUnitBackendCommandsGateway>());
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
      createAuthGateway:
          ({required client, required sessionPersistence, required initialRecoveryAccessToken}) =>
              auth,
      createAuthContextGateway: (_) => _FakeSuperadminAuthContextGateway(),
    );
    addTearDown(scope.session.dispose);

    expect(scope.session.isAuthenticated, isTrue);
    expect(scope.session.authContext?.platformRoleCode, 'operations');

    authStates.add(false);
    await Future<void>.delayed(Duration.zero);

    expect(scope.session.isAuthenticated, isFalse);
  });

  test('keeps a restored recovery session out of internal context bootstrap', () async {
    final authContext = _FakeSuperadminAuthContextGateway();
    final auth = _FakeCoeloAuthGateway(
      isAuthenticated: false,
      authStateChanges: const Stream<bool>.empty(),
      initialSessionState: const CoeloAuthSessionState.passwordRecovery(),
    );

    final scope = await createSuperadminAuthScope(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async =>
          SupabaseClient(url, publishableKey),
      createAuthGateway:
          ({required client, required sessionPersistence, required initialRecoveryAccessToken}) =>
              auth,
      createAuthContextGateway: (_) => authContext,
    );
    addTearDown(scope.session.dispose);

    expect(scope.session.isPasswordRecovery, isTrue);
    expect(scope.session.isAuthenticated, isFalse);
    expect(scope.session.authContext, isNull);
    expect(authContext.bootstrapCalls, 0);
  });

  test('rejects and revokes a restored credential without internal context', () async {
    final auth = _FakeCoeloAuthGateway(
      isAuthenticated: true,
      authStateChanges: const Stream<bool>.empty(),
    );
    final scope = await createSuperadminAuthScope(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async =>
          SupabaseClient(url, publishableKey),
      createAuthGateway:
          ({required client, required sessionPersistence, required initialRecoveryAccessToken}) =>
              auth,
      createAuthContextGateway: (_) => _FakeSuperadminAuthContextGateway(isAuthorized: false),
    );
    addTearDown(scope.session.dispose);

    expect(scope.session.isAuthenticated, isFalse);
    expect(scope.session.authContext, isNull);
    expect(auth.signOutCalls, 1);
  });

  test('does not restore a session signed out while context bootstrap is pending', () async {
    final authStates = StreamController<bool>();
    final auth = _FakeCoeloAuthGateway(isAuthenticated: true, authStateChanges: authStates.stream);
    final authContext = _PendingSuperadminAuthContextGateway();
    addTearDown(authStates.close);

    final scopeFuture = createSuperadminAuthScope(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async =>
          SupabaseClient(url, publishableKey),
      createAuthGateway:
          ({required client, required sessionPersistence, required initialRecoveryAccessToken}) =>
              auth,
      createAuthContextGateway: (_) => authContext,
    );

    await authContext.started.future;
    auth.isAuthenticated = false;
    authStates.add(false);
    authContext.completeAuthorized();

    final scope = await scopeFuture;
    addTearDown(scope.session.dispose);
    expect(scope.session.isAuthenticated, isFalse);
    expect(scope.session.authContext, isNull);
  });

  test('does not attach context from one session to a replacement session', () async {
    final authStates = StreamController<bool>();
    final auth = _FakeCoeloAuthGateway(isAuthenticated: true, authStateChanges: authStates.stream);
    final authContext = _PendingSuperadminAuthContextGateway();
    addTearDown(authStates.close);

    final scopeFuture = createSuperadminAuthScope(
      supabaseUrl: 'https://project.supabase.co',
      supabasePublishableKey: 'sb_publishable_test',
      initializeSupabase: ({required localStorage, required publishableKey, required url}) async =>
          SupabaseClient(url, publishableKey),
      createAuthGateway:
          ({required client, required sessionPersistence, required initialRecoveryAccessToken}) =>
              auth,
      createAuthContextGateway: (_) => authContext,
    );

    await authContext.started.future;
    auth.sessionId = _sessionB;
    authStates.add(true);
    authContext.completeAuthorized();

    final scope = await scopeFuture;
    addTearDown(scope.session.dispose);
    expect(scope.session.isAuthenticated, isFalse);
    expect(scope.session.authContext, isNull);
    expect(auth.signOutCalls, 1);
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
      createAuthGateway:
          ({required client, required sessionPersistence, required initialRecoveryAccessToken}) =>
              auth,
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
    expect(scope.unitDirectoryRepository, isA<UnavailableUnitDirectoryRepository>());
    expect(scope.unitBackendCommands, isA<UnavailableUnitBackendCommandsGateway>());
    expect(scope.personIdentityRepository, isA<UnavailablePersonIdentityRepository>());
    expect(scope.accessProfileRepository, isA<UnavailableAccessProfileRepository>());
    expect(scope.routineRepository, isA<UnavailableRoutineRepository>());
    expect(scope.groupDirectoryRepository, isA<UnavailableGroupDirectoryRepository>());
    expect(result.isSuccess, isFalse);
    expect(result.message, 'Não foi possível inicializar a autenticação deste ambiente.');
  });
}

final class _FakeCoeloAuthGateway extends CoeloAuthLifecycleGateway {
  _FakeCoeloAuthGateway({
    required this.isAuthenticated,
    required Stream<bool> authStateChanges,
    this.initialSessionState,
  }) : _authStateChanges = authStateChanges;

  @override
  bool isAuthenticated;
  String sessionId = _sessionA;
  final CoeloAuthSessionState? initialSessionState;

  final Stream<bool> _authStateChanges;
  String? lastRecoveryEmail;
  int signOutCalls = 0;

  @override
  CoeloAuthSessionState get currentSessionState =>
      initialSessionState ??
      (isAuthenticated
          ? CoeloAuthSessionState.authenticated(sessionId: sessionId)
          : const CoeloAuthSessionState.signedOut());

  @override
  Stream<CoeloAuthSessionState> get authSessionStateChanges => _authStateChanges.map(
    (authenticated) => authenticated
        ? CoeloAuthSessionState.authenticated(sessionId: sessionId)
        : const CoeloAuthSessionState.signedOut(),
  );

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecoveryWithRedirect({
    required String email,
    required Uri redirectTo,
  }) async {
    lastRecoveryEmail = email;
    return const CoeloAuthPasswordRecoveryResult.success();
  }

  @override
  Future<CoeloAuthPasswordUpdateResult> updatePassword({required String password}) async =>
      const CoeloAuthPasswordUpdateResult.success();

  @override
  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) async {
    return const CoeloAuthSignInResult.success();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

const _sessionA = '11111111-1111-4111-8111-111111111111';
const _sessionB = '22222222-2222-4222-8222-222222222222';

final class _PendingSuperadminAuthContextGateway implements SuperadminAuthContextGateway {
  final started = Completer<void>();
  final _result = Completer<SuperadminAuthContext?>();

  void completeAuthorized() => _result.complete(
    const SuperadminAuthContext(
      platformRoleCode: 'operations',
      scopeKind: SuperadminAuthScopeKind.platform,
      permissionCodes: {'platform.read'},
      aal: 'aal1',
    ),
  );

  @override
  Future<SuperadminAuthContext?> bootstrap() {
    started.complete();
    return _result.future;
  }
}

final class _FakeSuperadminAuthContextGateway implements SuperadminAuthContextGateway {
  _FakeSuperadminAuthContextGateway({this.isAuthorized = true});

  final bool isAuthorized;
  int bootstrapCalls = 0;

  @override
  Future<SuperadminAuthContext?> bootstrap() async {
    bootstrapCalls++;
    return isAuthorized
        ? const SuperadminAuthContext(
            platformRoleCode: 'operations',
            scopeKind: SuperadminAuthScopeKind.platform,
            permissionCodes: {'platform.read'},
            aal: 'aal1',
          )
        : null;
  }
}
