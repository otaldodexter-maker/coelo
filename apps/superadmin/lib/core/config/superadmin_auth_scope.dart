import 'package:coelo_auth/coelo_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/coelo_auth_login_action.dart';
import '../../features/attendance/attendance.dart';
import '../../features/attendance/data/supabase_attendance_repository.dart';
import '../../features/audit/data/supabase_audit_repository.dart';
import '../../features/audit/domain/audit.dart';
import '../../features/activities/data/supabase_activity_directory_repository.dart';
import '../../features/activities/data/supabase_activity_command_repository.dart';
import '../../features/activities/domain/activity_command.dart';
import '../../features/activities/domain/activity_directory.dart';
import '../../features/imports/data/supabase_import_repository.dart';
import '../../features/imports/domain/import_repository.dart';
import '../../features/invites/data/supabase_invite_repository.dart';
import '../../features/invites/domain/platform_invite.dart';
import '../../features/notices/data/supabase_notice_repository.dart';
import '../../features/notices/domain/notice_repository.dart';
import '../../features/auth/domain/login_request.dart';
import '../../features/auth/domain/logout_action.dart';
import '../../features/auth/domain/password_recovery.dart';
import '../../features/daily_routine/data/supabase_routine_repository.dart';
import '../../features/daily_routine/domain/routine_contract.dart';
import '../../features/health_care/data/supabase_medication_plan_repository.dart';
import '../../features/health_care/domain/medication_plan_repository.dart';
import '../../features/institutions/data/supabase_institution_directory_repository.dart';
import '../../features/groups/data/supabase_group_directory_repository.dart';
import '../../features/institutions/domain/institution_directory_repository.dart';
import '../../features/people/data/supabase_person_directory_repository.dart';
import '../../features/people/domain/person_directory.dart';
import '../../features/groups/domain/group_directory.dart';
import '../../features/access_profiles/data/supabase_access_profile_repository.dart';
import '../../features/access_profiles/data/supabase_access_profile_extended_repository.dart';
import '../../features/access_profiles/data/unavailable_access_profile_extended_repository.dart';
import '../../features/access_profiles/domain/access_profile.dart';
import '../../features/units/data/supabase_unit_backend_commands_gateway.dart';
import '../../features/units/data/supabase_unit_directory_repository.dart';
import '../../features/units/domain/unit_backend_commands.dart';
import '../../features/units/domain/unit_directory.dart';
import '../../features/safety/data/supabase_child_safety_repository.dart';
import '../../features/safety/domain/child_safety_contract.dart';
import '../guards/superadmin_session.dart';
import 'superadmin_app_config.dart';

typedef SupabaseInitializer =
    Future<SupabaseClient> Function({
      required String url,
      required String publishableKey,
      required LocalStorage localStorage,
    });

typedef CoeloAuthGatewayFactory =
    CoeloAuthGateway Function({
      required SupabaseClient client,
      required CoeloAuthSessionPersistence sessionPersistence,
    });

final class SuperadminAuthScope {
  const SuperadminAuthScope({
    required this.session,
    required this.login,
    required this.logout,
    required this.requestPasswordRecovery,
    required this.institutionDirectoryRepository,
    required this.activityDirectoryRepository,
    required this.activityCommandRepository,
    required this.personDirectoryRepository,
    required this.accessProfileRepository,
    required this.accessProfileExtendedRepository,
    required this.groupDirectoryRepository,
    required this.unitDirectoryRepository,
    this.unitBackendCommands,
    required this.importRepository,
    required this.inviteRepository,
    required this.noticeRepository,
    required this.attendanceRepository,
    required this.attendancePermissions,
    required this.routineRepository,
    required this.auditRepository,
    required this.childSafetyRepository,
    required this.medicationPlanRepository,
  });

  final SuperadminSession session;
  final LoginAction login;
  final LogoutAction logout;
  final PasswordRecoveryAction requestPasswordRecovery;
  final InstitutionDirectoryRepository institutionDirectoryRepository;
  final ActivityDirectoryRepository activityDirectoryRepository;
  final ActivityCommandRepository activityCommandRepository;
  final PersonDirectoryRepository personDirectoryRepository;
  final AccessProfileRepository accessProfileRepository;
  final AccessProfileExtendedRepository accessProfileExtendedRepository;
  final GroupDirectoryRepository groupDirectoryRepository;
  final UnitDirectoryRepository unitDirectoryRepository;
  final UnitBackendCommandsGateway? unitBackendCommands;
  final ImportRepository importRepository;
  final InviteRepository inviteRepository;
  final NoticeRepository noticeRepository;
  final AttendanceRepository attendanceRepository;
  final AttendancePermissions attendancePermissions;
  final RoutineRepository routineRepository;
  final AuditRepository auditRepository;
  final ChildSafetyRepository childSafetyRepository;
  final MedicationPlanRepository medicationPlanRepository;
}

Future<SuperadminAuthScope> createSuperadminAuthScope({
  String supabaseUrl = SuperadminAppConfig.supabaseUrl,
  String supabasePublishableKey = SuperadminAppConfig.supabasePublishableKey,
  SupabaseInitializer initializeSupabase = _initializeSupabase,
  CoeloAuthGatewayFactory createAuthGateway = _createAuthGateway,
}) async {
  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    return _createUnavailableScope(const UnavailableCoeloAuthGateway());
  }

  try {
    final storage = ConditionalSupabaseLocalStorage(
      delegate: SharedPreferencesLocalStorage(persistSessionKey: 'coelo.superadmin.auth.session'),
    );
    final client = await initializeSupabase(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      localStorage: storage,
    );
    final auth = createAuthGateway(client: client, sessionPersistence: storage);
    final session = SuperadminSession(
      isAuthenticated: auth.isAuthenticated,
      authStateChanges: auth.authStateChanges,
    );
    return SuperadminAuthScope(
      session: session,
      login: createCoeloAuthLoginAction(auth: auth, session: session),
      logout: createCoeloAuthLogoutAction(auth: auth, session: session),
      requestPasswordRecovery: createCoeloAuthPasswordRecoveryAction(auth: auth),
      institutionDirectoryRepository: SupabaseInstitutionDirectoryRepository(client),
      activityDirectoryRepository: SupabaseActivityDirectoryRepository(client),
      activityCommandRepository: SupabaseActivityCommandRepository(client),
      personDirectoryRepository: SupabasePersonDirectoryRepository(client),
      accessProfileRepository: SupabaseAccessProfileRepository(client),
      accessProfileExtendedRepository: SupabaseAccessProfileExtendedRepository(client),
      groupDirectoryRepository: SupabaseGroupDirectoryRepository(client),
      unitDirectoryRepository: SupabaseUnitDirectoryRepository(client),
      unitBackendCommands: SupabaseUnitBackendCommandsGateway(client),
      importRepository: SupabaseImportRepository(client),
      inviteRepository: SupabaseInviteRepository(client),
      noticeRepository: SupabaseNoticeRepository(client),
      attendanceRepository: SupabaseAttendanceRepository(client),
      attendancePermissions: const AttendancePermissions.manager(),
      routineRepository: SupabaseRoutineRepository(client),
      auditRepository: SupabaseAuditRepository(client),
      childSafetyRepository: SupabaseChildSafetyRepository(client),
      medicationPlanRepository: SupabaseMedicationPlanRepository(client),
    );
  } on Exception catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'superadmin_auth_scope',
        context: ErrorDescription('while initializing Supabase auth for Superadmin'),
      ),
    );
    return _createUnavailableScope(
      const UnavailableCoeloAuthGateway(
        message: 'Não foi possível inicializar a autenticação deste ambiente.',
      ),
    );
  }
}

SuperadminAuthScope _createUnavailableScope(CoeloAuthGateway auth) {
  final session = SuperadminSession();
  return SuperadminAuthScope(
    session: session,
    login: createCoeloAuthLoginAction(auth: auth, session: session),
    logout: createCoeloAuthLogoutAction(auth: auth, session: session),
    requestPasswordRecovery: createCoeloAuthPasswordRecoveryAction(auth: auth),
    institutionDirectoryRepository: const UnavailableInstitutionDirectoryRepository(),
    activityDirectoryRepository: const UnavailableActivityDirectoryRepository(),
    activityCommandRepository: const UnavailableActivityCommandRepository(),
    personDirectoryRepository: const UnavailablePersonDirectoryRepository(),
    accessProfileRepository: const UnavailableAccessProfileRepository(),
    accessProfileExtendedRepository: const UnavailableAccessProfileExtendedRepository(),
    groupDirectoryRepository: const UnavailableGroupDirectoryRepository(),
    unitDirectoryRepository: const UnavailableUnitDirectoryRepository(),
    importRepository: const UnavailableImportRepository(),
    inviteRepository: const UnavailableInviteRepository(),
    noticeRepository: const UnavailableNoticeRepository(),
    attendanceRepository: const UnavailableAttendanceRepository(),
    attendancePermissions: const AttendancePermissions.readOnly(),
    routineRepository: const UnavailableRoutineRepository(),
    auditRepository: const UnavailableAuditRepository(),
    childSafetyRepository: const UnavailableChildSafetyRepository(),
    medicationPlanRepository: const UnavailableMedicationPlanRepository(),
  );
}

CoeloAuthGateway _createAuthGateway({
  required SupabaseClient client,
  required CoeloAuthSessionPersistence sessionPersistence,
}) {
  return SupabaseCoeloAuthGateway(client, sessionPersistence: sessionPersistence);
}

Future<SupabaseClient> _initializeSupabase({
  required String url,
  required String publishableKey,
  required LocalStorage localStorage,
}) async {
  await Supabase.initialize(
    url: url,
    publishableKey: publishableKey,
    authOptions: FlutterAuthClientOptions(localStorage: localStorage),
  );
  return Supabase.instance.client;
}
