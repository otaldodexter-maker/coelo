import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import '../../features/groups/domain/group_detail.dart';
import '../../features/groups/data/supabase_group_detail_repository.dart';
import '../../features/units/domain/unit_detail.dart';
import '../../features/units/data/supabase_unit_detail_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/coelo_auth_login_action.dart';
import '../../features/chat/data/supabase_chat_repository.dart';
import '../../features/chat/domain/chat_repository.dart';
import '../../features/children/data/supabase_child_directory_reader.dart';
import '../../features/children/presentation/child_directory_controller.dart';
import '../../features/circulars/data/supabase_superadmin_circular_repository.dart';
import '../../features/circulars/domain/superadmin_circular_repository.dart';
import '../../features/attendance/attendance.dart';
import '../../features/attendance/data/supabase_attendance_repository.dart';
import '../../features/audit/data/supabase_audit_repository.dart';
import '../../features/audit/domain/audit.dart';
import '../../features/activities/domain/activity_command.dart';
import '../../features/activities/domain/activity_directory.dart';
import '../../features/activities/data/supabase_activity_command_repository.dart';
import '../../features/activities/data/supabase_activity_directory_repository.dart';
import '../../features/assessments/assessment.dart';
import '../../features/assessments/data/supabase_assessment_repository.dart';
import '../../features/imports/domain/import_repository.dart';
import '../../features/agenda/data/supabase_agenda_repository.dart';
import '../../features/agenda/domain/agenda_repository.dart';
import '../../features/plans/data/supabase_plan_catalog_repository.dart';
import '../../features/plans/domain/plan_catalog_repository.dart';
import '../../features/invites/data/supabase_invite_repository.dart';
import '../../features/invites/domain/platform_invite.dart';
import '../../features/notices/data/supabase_notice_repository.dart';
import '../../features/notices/domain/notice_repository.dart';
import '../../features/principal_moments/data/supabase_principal_moments_feed_repository.dart';
import '../../features/principal_moments/domain/principal_moments_feed_repository.dart';
import '../../features/principal_circulars/data/supabase_circular_auxiliary_repositories.dart';
import '../../features/principal_circulars/data/supabase_circular_repository.dart';
import '../../features/principal_circulars/domain/circular_repository.dart'
    show CircularMediaRepository, CircularRepository, CircularResponseRepository;
import '../../features/principal_circulars/data/supabase_principal_mixed_feed_repository.dart';
import '../../features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import '../../features/principal_happens/data/supabase_principal_happens_feed_repository.dart';
import '../../features/principal_happens/domain/principal_happens_feed_repository.dart';
import '../../features/principal_happens_publication/data/supabase_happens_publication_repository.dart';
import '../../features/principal_happens_publication/domain/happens_publication.dart';
import '../../features/principal_moments_publication/data/supabase_moments_publication_repository.dart';
import '../../features/principal_moments_publication/domain/moments_publication.dart';
import '../../features/principal_now/data/supabase_principal_now_feed_repository.dart';
import '../../features/principal_now/domain/principal_now_feed_repository.dart';
import '../../features/principal_now_publication/data/supabase_now_publication_repository.dart';
import '../../features/principal_now_publication/domain/now_publication.dart';
import '../../features/principal_shared/data/supabase_principal_runtime_context_repository.dart';
import '../../features/profile_about/data/supabase_profile_about_repository.dart';
import '../../features/profile_about/domain/profile_about_repository.dart';
import '../../features/principal_shared/domain/principal_runtime_context.dart';
import '../../features/auth/domain/login_request.dart';
import '../../features/auth/domain/logout_action.dart';
import '../../features/auth/domain/password_recovery.dart';
import '../../features/auth/domain/reset_password_action.dart';
import '../../features/auth/data/supabase_superadmin_auth_context_gateway.dart';
import '../../features/auth/domain/superadmin_auth_context.dart';
import '../../features/daily_routine/data/supabase_routine_repository.dart';
import '../../features/daily_routine/domain/routine_contract.dart';
import '../../features/health_care/data/supabase_health_care_repository.dart';
import '../../features/health_care/data/supabase_medication_plan_repository.dart';
import '../../features/health_care/domain/health_care_repository.dart';
import '../../features/health_care/domain/medication_plan_repository.dart';
import '../../features/meal_plans/data/supabase_meal_plan_repository.dart';
import '../../features/meal_plans/data/supabase_meal_plan_image_repository.dart';
import '../../features/meal_plans/domain/meal_plan_image_repository.dart';
import '../../features/meal_plans/domain/meal_plan_repository.dart';
import '../../features/forms/data/forms_backend_gateway.dart';
import '../../features/forms/data/forms_directory_reader.dart';
import '../../features/forms/data/supabase_superadmin_forms_directory_reader.dart';
import '../../features/forms/data/supabase_forms_api.dart';
import 'package:coelo_api/coelo_api.dart';
import '../../features/institutions/data/supabase_institution_directory_repository.dart';
import '../../features/institutions/domain/institution_directory_repository.dart';
import '../../features/people/data/supabase_person_directory_repository.dart';
import '../../features/people/domain/person_directory.dart';
import '../../features/people/domain/person_detail_reader.dart';
import '../../features/people/data/supabase_person_detail_reader.dart';
import '../../features/people/domain/person_identity.dart';
import '../../features/groups/domain/group_directory.dart';
import '../../features/access_profiles/data/supabase_access_profile_repository.dart';
import '../../features/access_profiles/domain/access_profile.dart';
import '../../features/platform_users/data/supabase_platform_user_repository.dart';
import '../../features/platform_users/domain/platform_user.dart';
import '../../features/units/data/unavailable_unit_composition.dart';
import '../../features/units/data/supabase_unit_backend_commands_gateway.dart';
import '../../features/units/domain/unit_backend_commands.dart';
import '../../features/units/domain/unit_directory.dart';
import '../../features/safety/data/supabase_child_safety_repository.dart';
import '../../features/safety/domain/child_safety_contract.dart';
import '../../features/student_tracking/domain/student_tracking.dart';
import '../guards/superadmin_session.dart';
import 'superadmin_app_config.dart';
import 'superadmin_media_scope.dart';
import '../../features/forms/data/form_export_download_resolver.dart';
import '../../features/forms/data/forms_media_reader.dart';

typedef SupabaseInitializer =
    Future<SupabaseClient> Function({
      required String url,
      required String publishableKey,
      required LocalStorage localStorage,
    });

typedef CoeloAuthGatewayFactory =
    CoeloAuthLifecycleGateway Function({
      required SupabaseClient client,
      required CoeloAuthSessionPersistence sessionPersistence,
      required String? initialRecoveryAccessToken,
    });

typedef SuperadminAuthContextGatewayFactory =
    SuperadminAuthContextGateway Function(SupabaseClient client);

final class SuperadminAuthScope {
  const SuperadminAuthScope({
    required this.session,
    required this.login,
    required this.logout,
    required this.requestPasswordRecovery,
    required this.resetPassword,
    required this.institutionDirectoryRepository,
    required this.activityDirectoryRepository,
    required this.activityCommandRepository,
    required this.assessmentRepository,
    required this.assessmentMutationsEnabled,
    required this.personDirectoryRepository,
    this.personDetailReader = const UnavailablePersonDetailReader(),
    this.personIdentityRepository = const UnavailablePersonIdentityRepository(),
    required this.accessProfileRepository,
    this.platformUserRepository,
    required this.groupDirectoryRepository,
    this.groupDetailRepository = const UnavailableGroupDetailRepository(),
    this.unitDetailRepository = const UnavailableUnitDetailRepository(),
    required this.unitDirectoryRepository,
    required this.unitBackendCommands,
    required this.structureMutationsEnabled,
    required this.importRepository,
    this.planCatalogRepository = const UnavailablePlanCatalogRepository(),
    this.agendaRepository,
    required this.chatRepository,
    required this.circularRepository,
    required this.inviteRepository,
    required this.noticeRepository,
    required this.attendanceRepository,
    this.childDirectoryRead = unavailableChildDirectoryRead,
    this.studentTrackingRepository = const UnavailableStudentTrackingRepository(),
    required this.attendancePermissions,
    required this.routineRepository,
    required this.auditRepository,
    required this.childSafetyRepository,
    required this.medicationPlanRepository,
    required this.healthCareRepository,
    required this.mealPlanRepository,
    required this.mealPlanImageRepository,
    this.authorizedMealPlanTenantId,
    required this.formsApi,
    this.formsDirectoryReader,
    this.formsMediaReader,
    this.formsMediaScope,
    this.principalRuntimeContextRepository,
    this.profileAboutRepository,
    this.principalCircularRepository,
    this.principalHappensFeedRepository,
    this.principalMixedFeedRepository,
    this.principalCircularResponseRepository,
    this.principalCircularMediaRepository,
    this.principalMomentsFeedRepository,
    this.principalMomentsWithdrawalRepository,
    this.happensPublicationRepository,
    this.principalNowFeedRepository,
    this.momentsPublicationRepository,
    this.nowPublicationRepository,
  });

  final SuperadminSession session;
  final LoginAction login;
  final LogoutAction logout;
  final PasswordRecoveryAction requestPasswordRecovery;
  final ResetPasswordAction resetPassword;
  final InstitutionDirectoryRepository institutionDirectoryRepository;
  final ActivityDirectoryRepository activityDirectoryRepository;
  final ActivityCommandRepository activityCommandRepository;
  final AssessmentRepository assessmentRepository;
  final bool assessmentMutationsEnabled;
  final PersonDirectoryRepository personDirectoryRepository;
  final PersonDetailReader personDetailReader;
  final PersonIdentityRepository personIdentityRepository;
  final AccessProfileRepository accessProfileRepository;
  final PlatformUserRepository? platformUserRepository;
  final GroupDirectoryRepository groupDirectoryRepository;
  final GroupDetailRepository groupDetailRepository;
  final UnitDetailRepository unitDetailRepository;
  final UnitDirectoryRepository unitDirectoryRepository;
  final UnitBackendCommandsGateway unitBackendCommands;
  final bool structureMutationsEnabled;
  final ImportRepository importRepository;
  final PlanCatalogRepository planCatalogRepository;
  final AgendaRepository? agendaRepository;
  final ChatRepository chatRepository;
  final SuperadminCircularRepository circularRepository;
  final InviteRepository inviteRepository;
  final NoticeRepository noticeRepository;
  final AttendanceRepository attendanceRepository;
  final ChildDirectoryRead childDirectoryRead;
  final StudentTrackingRepository studentTrackingRepository;
  final AttendancePermissions attendancePermissions;
  final RoutineRepository routineRepository;
  final AuditRepository auditRepository;
  final ChildSafetyRepository childSafetyRepository;
  final MedicationPlanRepository medicationPlanRepository;
  final HealthCareRepository healthCareRepository;
  final MealPlanRepository mealPlanRepository;
  final MealPlanImageRepository mealPlanImageRepository;
  final String? authorizedMealPlanTenantId;
  final FormsApi? formsApi;
  final FormsDirectoryReader? formsDirectoryReader;
  final MediaReader? formsMediaReader;
  final SuperadminMediaScope? formsMediaScope;
  final PrincipalRuntimeContextRepository? principalRuntimeContextRepository;
  final ProfileAboutRepository? profileAboutRepository;

  /// The Principal-side circular read. It is not the administrative directory:
  /// it projects `list_visible_profile_circulars`, which authorizes the actor
  /// by institution, unit and group on the server.
  final CircularRepository? principalCircularRepository;
  final PrincipalHappensFeedRepository? principalHappensFeedRepository;
  final PrincipalMixedFeedRepository? principalMixedFeedRepository;
  final CircularResponseRepository? principalCircularResponseRepository;
  final CircularMediaRepository? principalCircularMediaRepository;
  final PrincipalMomentsFeedRepository? principalMomentsFeedRepository;
  final PrincipalMomentsWithdrawalRepository? principalMomentsWithdrawalRepository;
  final HappensPublicationRepository? happensPublicationRepository;
  final PrincipalNowFeedRepository? principalNowFeedRepository;
  final MomentsPublicationRepository? momentsPublicationRepository;
  final NowPublicationRepository? nowPublicationRepository;
}

Future<SuperadminAuthScope> createSuperadminAuthScope({
  String supabaseUrl = SuperadminAppConfig.supabaseUrl,
  String supabasePublishableKey = SuperadminAppConfig.supabasePublishableKey,
  bool enableAssessmentMutations = SuperadminAppConfig.assessmentMutationsEnabled,
  SupabaseInitializer initializeSupabase = _initializeSupabase,
  CoeloAuthGatewayFactory createAuthGateway = _createAuthGateway,
  SuperadminAuthContextGatewayFactory createAuthContextGateway = _createAuthContextGateway,
  Uri? appUri,
}) async {
  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    return _createUnavailableScope(const UnavailableCoeloAuthGateway());
  }

  SupabaseCoeloAuthGateway? ownedAuth;
  SuperadminSession? ownedSession;
  try {
    final initialUri = appUri ?? Uri.base;
    final storage = ConditionalSupabaseLocalStorage(
      delegate: SharedPreferencesLocalStorage(persistSessionKey: 'coelo.superadmin.auth.session'),
    );
    final client = await initializeSupabase(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      localStorage: storage,
    );
    final auth = createAuthGateway(
      client: client,
      sessionPersistence: storage,
      initialRecoveryAccessToken: superadminPasswordRecoveryAccessToken(initialUri),
    );
    if (auth is SupabaseCoeloAuthGateway) {
      ownedAuth = auth;
      // Synchronize the SDK's initial replay before deciding whether this is
      // productive authentication or a recovery-only session.
      await auth.authSessionStateChanges.first;
    }
    final authContext = createAuthContextGateway(client);
    final initialState = auth.currentSessionState;
    final platformUsers = SupabasePlatformUserRepository(client);
    // Ler e retirar Momentos compartilham a mesma implementacao autorizada;
    // uma instancia so evita dois clientes divergentes para o mesmo dominio.
    final momentsFeed = SupabasePrincipalMomentsFeedRepository(client);
    SuperadminMediaScope? ownedMediaScope;
    final session = SuperadminSession(
      isPasswordRecovery: initialState.isPasswordRecovery,
      authSessionStateChanges: auth.authSessionStateChanges,
      onDispose: () {
        try {
          ownedMediaScope?.dispose();
          platformUsers.clearSessionCache();
        } finally {
          if (auth is SupabaseCoeloAuthGateway) unawaited(auth.dispose());
        }
      },
    );
    ownedSession = session;
    final formsMediaScope = SuperadminMediaScope(
      session: session,
      downloadGateway: SupabaseFormExportDownloadGateway(client),
    );
    ownedMediaScope = formsMediaScope;
    if (initialState.kind == CoeloAuthSessionKind.authenticated) {
      final expectedRevision = session.authorizationInvalidationRevision;
      final initialContext = await authContext.bootstrap();
      var mediaPrepared = false;
      final beforePurge = auth.currentSessionState;
      if (initialContext != null &&
          session.authorizationInvalidationRevision == expectedRevision &&
          beforePurge.kind == CoeloAuthSessionKind.authenticated &&
          beforePurge.sessionId == initialState.sessionId) {
        mediaPrepared = await formsMediaScope.prepareAuthorization();
      }
      final latestState = auth.currentSessionState;
      final authorized =
          mediaPrepared &&
          initialContext != null &&
          initialState.sessionId != null &&
          latestState.sessionId == initialState.sessionId &&
          latestState.kind == CoeloAuthSessionKind.authenticated &&
          session.authorizeIfCurrent(
            initialContext,
            sessionId: initialState.sessionId!,
            expectedInvalidationRevision: expectedRevision,
          );
      if (authorized) formsMediaScope.authorizationCommitted();
      final recoveryArrivedDuringBootstrap =
          latestState.isPasswordRecovery &&
          latestState.sessionId != null &&
          session.isPasswordRecovery &&
          session.authorizationInvalidationRevision != expectedRevision;
      final credentialsReplaced =
          latestState.sessionId != null && latestState.sessionId != initialState.sessionId;
      if (!authorized && !recoveryArrivedDuringBootstrap && !credentialsReplaced) {
        try {
          await auth.signOut();
        } on Exception {
          // The local Supabase session is cleared before remote revocation.
        }
      }
    }
    final formsBackend = SupabaseFormsBackendGateway(client);
    session.addListener(platformUsers.clearSessionCache);
    return SuperadminAuthScope(
      session: session,
      login: createCoeloAuthLoginAction(
        auth: auth,
        authContext: authContext,
        session: session,
        prepareAuthorization: formsMediaScope.prepareAuthorization,
        onAuthorizationCommitted: formsMediaScope.authorizationCommitted,
      ),
      logout: createCoeloAuthLogoutAction(auth: auth, session: session),
      requestPasswordRecovery: createCoeloAuthPasswordRecoveryAction(
        auth: auth,
        redirectTo: buildSuperadminPasswordRecoveryRedirect(initialUri),
      ),
      resetPassword: createCoeloAuthResetPasswordAction(auth: auth),
      institutionDirectoryRepository: SupabaseInstitutionDirectoryRepository(client),
      activityDirectoryRepository: SupabaseActivityDirectoryRepository(client),
      activityCommandRepository: SupabaseActivityCommandRepository(client),
      assessmentRepository: SupabaseAssessmentRepository(client),
      assessmentMutationsEnabled: enableAssessmentMutations,
      personDirectoryRepository: SupabasePersonDirectoryRepository(client),
      personDetailReader: SupabasePersonDetailReader(client),
      personIdentityRepository: const UnavailablePersonIdentityRepository(),
      accessProfileRepository: SupabaseAccessProfileRepository(client),
      platformUserRepository: platformUsers,
      groupDirectoryRepository: const UnavailableGroupDirectoryRepository(),
      groupDetailRepository: SupabaseGroupDetailRepository(client),
      unitDetailRepository: SupabaseUnitDetailRepository(client),
      unitDirectoryRepository: const UnavailableUnitDirectoryRepository(),
      unitBackendCommands: SupabaseUnitBackendCommandsGateway(client),
      // OQ-032/OQ-043: these CRUD repositories still target the legacy
      // people-based realm. Keep production mutations fail-closed until the
      // internal v2 directory and command gateways exist.
      structureMutationsEnabled: false,
      importRepository: const UnavailableImportRepository(),
      planCatalogRepository: SupabasePlanCatalogRepository(client),
      agendaRepository: SupabaseAgendaRepository(client),
      chatRepository: SupabaseChatRepository(client),
      circularRepository: SupabaseSuperadminCircularRepository(client),
      inviteRepository: SupabaseInviteRepository(client),
      noticeRepository: SupabaseNoticeRepository(client),
      attendanceRepository: SupabaseAttendanceRepository(client),
      childDirectoryRead: SupabaseChildDirectoryReader(client).fetchPage,
      studentTrackingRepository: const UnavailableStudentTrackingRepository(),
      attendancePermissions: const AttendancePermissions.backend(),
      // Chave de composição do pacote de Cuidado, Medicação e Rotina. Enquanto
      // as migrations 20260910010000 a 20260910010500 não estiverem aplicadas,
      // estas três famílias continuam honestamente indisponíveis em vez de
      // falharem contra um banco que não tem seus objetos.
      routineRepository: SuperadminAppConfig.careAndRoutineBackendEnabled
          ? SupabaseRoutineRepository(client)
          : const UnavailableRoutineRepository(),
      auditRepository: SupabaseAuditRepository(client),
      childSafetyRepository: SupabaseChildSafetyRepository(client),
      medicationPlanRepository: SuperadminAppConfig.careAndRoutineBackendEnabled
          ? SupabaseMedicationPlanRepository(client)
          : const UnavailableMedicationPlanRepository(),
      healthCareRepository: SuperadminAppConfig.careAndRoutineBackendEnabled
          ? SupabaseHealthCareRepository(client)
          : const UnavailableHealthCareRepository(),
      mealPlanRepository: SupabaseMealPlanRepository(client),
      mealPlanImageRepository: SupabaseMealPlanImageRepository(client),
      formsApi: SupabaseFormsApi(formsBackend),
      formsDirectoryReader: SupabaseSuperadminFormsDirectoryReader(formsBackend),
      formsMediaReader: FormsMediaReader(gateway: formsBackend),
      formsMediaScope: formsMediaScope,
      principalRuntimeContextRepository: SupabasePrincipalRuntimeContextRepository(client),
      profileAboutRepository: SupabaseProfileAboutRepository(client),
      principalCircularRepository: SupabaseCircularRepository(client),
      principalHappensFeedRepository: SupabasePrincipalHappensFeedRepository(client),
      principalMixedFeedRepository: SupabasePrincipalMixedFeedRepository(client),
      principalCircularResponseRepository: SupabaseCircularResponseRepository(client),
      principalCircularMediaRepository: SupabaseCircularMediaRepository(client),
      principalMomentsFeedRepository: momentsFeed,
      principalMomentsWithdrawalRepository: momentsFeed,
      happensPublicationRepository: SupabaseHappensPublicationRepository(client),
      principalNowFeedRepository: SupabasePrincipalNowFeedRepository(client),
      momentsPublicationRepository: SupabaseMomentsPublicationRepository(client),
      nowPublicationRepository: SupabaseNowPublicationRepository(client),
    );
  } on Exception catch (error, stackTrace) {
    ownedSession?.dispose();
    await ownedAuth?.dispose();
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

SuperadminAuthScope _createUnavailableScope(CoeloAuthLifecycleGateway auth) {
  final session = SuperadminSession();
  const authContext = UnavailableSuperadminAuthContextGateway();
  return SuperadminAuthScope(
    session: session,
    login: createCoeloAuthLoginAction(auth: auth, authContext: authContext, session: session),
    logout: createCoeloAuthLogoutAction(auth: auth, session: session),
    requestPasswordRecovery: createCoeloAuthPasswordRecoveryAction(
      auth: auth,
      redirectTo: buildSuperadminPasswordRecoveryRedirect(Uri.base),
    ),
    resetPassword: createCoeloAuthResetPasswordAction(auth: auth),
    institutionDirectoryRepository: const UnavailableInstitutionDirectoryRepository(),
    activityDirectoryRepository: const UnavailableActivityDirectoryRepository(),
    activityCommandRepository: const UnavailableActivityCommandRepository(),
    assessmentRepository: const UnavailableAssessmentRepository(),
    assessmentMutationsEnabled: false,
    personDirectoryRepository: const UnavailablePersonDirectoryRepository(),
    personIdentityRepository: const UnavailablePersonIdentityRepository(),
    accessProfileRepository: const UnavailableAccessProfileRepository(),
    groupDirectoryRepository: const UnavailableGroupDirectoryRepository(),
    unitDirectoryRepository: const UnavailableUnitDirectoryRepository(),
    unitBackendCommands: const UnavailableUnitBackendCommandsGateway(),
    structureMutationsEnabled: false,
    importRepository: const UnavailableImportRepository(),
    planCatalogRepository: const UnavailablePlanCatalogRepository(),
    agendaRepository: null,
    chatRepository: const UnavailableChatRepository(),
    circularRepository: const UnavailableSuperadminCircularRepository(),
    inviteRepository: const UnavailableInviteRepository(),
    noticeRepository: const UnavailableNoticeRepository(),
    attendanceRepository: const UnavailableAttendanceRepository(),
    studentTrackingRepository: const UnavailableStudentTrackingRepository(),
    attendancePermissions: const AttendancePermissions.readOnly(),
    routineRepository: const UnavailableRoutineRepository(),
    auditRepository: const UnavailableAuditRepository(),
    childSafetyRepository: const UnavailableChildSafetyRepository(),
    medicationPlanRepository: const UnavailableMedicationPlanRepository(),
    healthCareRepository: const UnavailableHealthCareRepository(),
    mealPlanRepository: const UnavailableMealPlanRepository(),
    mealPlanImageRepository: const UnavailableMealPlanImageRepository(),
    formsApi: null,
    principalRuntimeContextRepository: null,
    profileAboutRepository: null,
    principalCircularRepository: null,
    principalHappensFeedRepository: null,
    principalMixedFeedRepository: null,
    principalCircularResponseRepository: null,
    principalCircularMediaRepository: null,
    principalMomentsFeedRepository: null,
    principalMomentsWithdrawalRepository: null,
    happensPublicationRepository: null,
    principalNowFeedRepository: null,
    momentsPublicationRepository: null,
    nowPublicationRepository: null,
  );
}

CoeloAuthLifecycleGateway _createAuthGateway({
  required SupabaseClient client,
  required CoeloAuthSessionPersistence sessionPersistence,
  required String? initialRecoveryAccessToken,
}) {
  return SupabaseCoeloAuthGateway(
    client,
    sessionPersistence: sessionPersistence,
    initialRecoveryAccessToken: initialRecoveryAccessToken,
  );
}

SuperadminAuthContextGateway _createAuthContextGateway(SupabaseClient client) =>
    SupabaseSuperadminAuthContextGateway(client);

Uri buildSuperadminPasswordRecoveryRedirect(Uri appUri) => Uri(
  scheme: appUri.scheme,
  host: appUri.host,
  port: appUri.hasPort ? appUri.port : null,
  path: '/reset-password',
);

bool isSuperadminPasswordRecoveryRedirect(Uri uri) {
  return superadminPasswordRecoveryAccessToken(uri) != null;
}

String? superadminPasswordRecoveryAccessToken(Uri uri) {
  if (uri.path != '/reset-password') {
    return null;
  }
  try {
    final fragment = uri.fragment.isEmpty
        ? const <String, String>{}
        : Uri.splitQueryString(uri.fragment);
    final accessToken = fragment['access_token'];
    final refreshToken = fragment['refresh_token'];
    if (fragment['type'] != 'recovery' ||
        accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }
    return accessToken;
  } on FormatException {
    return null;
  }
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

final class UnavailableMealPlanImageRepository implements MealPlanImageRepository {
  const UnavailableMealPlanImageRepository();

  @override
  Future<MealPlanImageAsset> upload(MealPlanImageUploadRequest request) =>
      Future<MealPlanImageAsset>.error(const MealPlanImageUnavailableException());

  @override
  Future<Uri> createSignedReadUrl(String assetId) =>
      Future<Uri>.error(const MealPlanImageUnavailableException());

  @override
  Future<void> delete({required String assetId, required String requestId}) =>
      Future<void>.error(const MealPlanImageUnavailableException());
}
