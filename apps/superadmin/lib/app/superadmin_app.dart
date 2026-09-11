import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import '../features/groups/domain/group_detail.dart';
import '../features/units/domain/unit_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:coelo_api/coelo_api.dart';

import '../core/config/superadmin_app_config.dart';
import '../core/config/superadmin_media_scope.dart';
import '../core/guards/superadmin_session.dart';
import '../features/activities/domain/activity_command.dart';
import '../features/activities/domain/activity_directory.dart';
import '../features/activities/domain/activity_read_detail.dart';
import '../features/assessments/assessment.dart';
import '../features/auth/domain/superadmin_auth_context.dart';
import '../features/auth/domain/login_request.dart';
import '../features/auth/domain/logout_action.dart';
import '../features/auth/domain/password_recovery.dart';
import '../features/auth/domain/reset_password_action.dart';
import '../features/chat/domain/chat_repository.dart';
import '../features/children/presentation/child_directory_controller.dart';
import '../features/circulars/domain/superadmin_circular_repository.dart';
import '../features/attendance/attendance.dart';
import '../features/attendance/data/supabase_attendance_repository.dart';
import '../features/account/data/user_preferences_repository.dart';
import '../features/account/data/account_profile_repository.dart';
import '../features/support/data/support_repository.dart';
import '../features/account/presentation/user_preferences_controller.dart';
import '../features/institutions/data/supabase_institution_directory_repository.dart';
import '../features/institutions/domain/institution_directory_repository.dart';
import '../features/locations/domain/location_capabilities.dart';
import '../features/locations/domain/location_catalog_reader.dart';
import '../features/locations/domain/location_catalog_writer.dart';
import '../features/locations/domain/location_reservation_gateway.dart';
import '../features/locations/domain/location_consumer_bindings_reader.dart';
import '../features/locations/domain/location_consumer_selection_reader.dart';
import '../features/units/data/unavailable_unit_composition.dart';
import '../features/units/domain/unit_backend_commands.dart';
import '../features/units/domain/unit_directory.dart';
import '../features/people/data/supabase_person_directory_repository.dart';
import '../features/people/domain/person_directory.dart';
import '../features/people/domain/person_detail_reader.dart';
import '../features/people/domain/person_identity.dart';
import '../features/access_profiles/data/supabase_access_profile_repository.dart';
import '../features/imports/domain/import_repository.dart';
import '../features/agenda/domain/agenda_repository.dart';
import '../features/plans/domain/plan_catalog_repository.dart';
import '../features/meal_plans/domain/meal_plan_image_repository.dart';
import '../features/meal_plans/domain/meal_plan_repository.dart';
import '../features/invites/domain/platform_invite.dart';
import '../features/notices/domain/notice_repository.dart';
import '../features/principal_circulars/domain/circular_repository.dart'
    show CircularMediaRepository, CircularRepository, CircularResponseRepository;
import '../features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import '../features/principal_happens/domain/principal_happens_feed_repository.dart';
import '../features/principal_moments/domain/principal_moments_feed_repository.dart';
import '../features/principal_happens_publication/domain/happens_publication.dart';
import '../features/principal_moments_publication/domain/moments_publication.dart';
import '../features/principal_now/domain/principal_now_feed_repository.dart';
import '../features/principal_now_publication/domain/now_publication.dart';
import '../features/principal_shared/domain/principal_runtime_context.dart';
import '../features/daily_routine/domain/routine_contract.dart';
import '../features/audit/domain/audit.dart';
import '../features/safety/application/child_safety_controller.dart';
import '../features/safety/domain/child_safety_contract.dart';
import '../features/access_profiles/domain/access_profile.dart';
import '../features/platform_users/domain/platform_user.dart';
import '../features/groups/domain/group_directory.dart';
import '../features/health_care/domain/health_care_repository.dart';
import '../features/students/domain/student_link.dart';
import '../features/health_care/domain/medication_plan_repository.dart';
import '../features/forms/data/forms_directory_reader.dart';
import 'router/superadmin_router.dart';
import 'theme/superadmin_theme_mode_scope.dart';
import '../features/principal_circulars/domain/circular_repository.dart';
import '../features/profile_about/domain/profile_about_repository.dart';

const _instantPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _InstantPageTransitionsBuilder(),
    TargetPlatform.fuchsia: _InstantPageTransitionsBuilder(),
    TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
    TargetPlatform.linux: _InstantPageTransitionsBuilder(),
    TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
    TargetPlatform.windows: _InstantPageTransitionsBuilder(),
  },
);

final _superadminLightTheme = CoeloTheme.light.copyWith(
  scaffoldBackgroundColor: CoeloTheme.light.colorScheme.surface,
  pageTransitionsTheme: _instantPageTransitions,
);
final _superadminDarkTheme = CoeloTheme.dark.copyWith(
  scaffoldBackgroundColor: CoeloTheme.dark.colorScheme.surface,
  pageTransitionsTheme: _instantPageTransitions,
);

LocationCapabilities _noLocationCapabilities(SuperadminAuthContext? _) => LocationCapabilities.none;

final class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class SuperadminApp extends StatefulWidget {
  const SuperadminApp({
    this.session,
    this.login = unavailableSuperadminLogin,
    this.logout = unavailableSuperadminLogout,
    this.requestPasswordRecovery = unavailableSuperadminPasswordRecovery,
    this.resetPassword = unavailableResetPassword,
    this.institutionDirectoryRepository = const UnavailableInstitutionDirectoryRepository(),
    this.groupDirectoryRepository = const UnavailableGroupDirectoryRepository(),
    this.groupDetailRepository = const UnavailableGroupDetailRepository(),
    this.unitDetailRepository = const UnavailableUnitDetailRepository(),
    this.locationCatalogReader = const UnavailableLocationCatalogReader(),
    this.locationConsumerBindingsReader = const UnavailableLocationConsumerBindingsReader(),
    this.locationConsumerSelectionReader = const UnavailableLocationConsumerSelectionReader(),
    this.locationCatalogWriter = const UnavailableLocationCatalogWriter(),
    this.locationReservationGateway = const UnavailableLocationReservationGateway(),
    this.locationCapabilities = _noLocationCapabilities,
    this.activityDirectoryRepository = const UnavailableActivityDirectoryRepository(),
    this.activityReadDetailRepository = const UnavailableActivityReadDetailRepository(),
    this.activityCommandRepository = const UnavailableActivityCommandRepository(),
    this.assessmentRepository = const UnavailableAssessmentRepository(),
    this.assessmentMutationsEnabled = false,
    this.personDirectoryRepository = const UnavailablePersonDirectoryRepository(),
    this.personDetailReader = const UnavailablePersonDetailReader(),
    this.personIdentityRepository = const UnavailablePersonIdentityRepository(),
    this.unitDirectoryRepository = const UnavailableUnitDirectoryRepository(),
    this.unitBackendCommands = const UnavailableUnitBackendCommandsGateway(),
    this.structureMutationsEnabled = false,
    this.activityLocationCreateEnabled = false,
    this.accessProfileRepository = const UnavailableAccessProfileRepository(),
    this.platformUserRepository,
    this.importRepository = const UnavailableImportRepository(),
    this.planCatalogRepository = const UnavailablePlanCatalogRepository(),
    this.agendaRepository,
    this.formsApi,
    this.formsDirectoryReader,
    this.formsMediaReader,
    this.formsMediaScope,
    this.mealPlanRepository = const UnavailableMealPlanRepository(),
    this.mealPlanImageRepository = const UnavailableMealPlanImageRepository(),
    this.authorizedMealPlanTenantId,
    this.chatRepository = const UnavailableChatRepository(),
    this.mediaReader,
    this.mediaSession,
    this.circularRepository = const UnavailableSuperadminCircularRepository(),
    this.inviteRepository = const UnavailableInviteRepository(),
    this.noticeRepository = const UnavailableNoticeRepository(),
    this.attendanceRepository = const UnavailableAttendanceRepository(),
    this.childDirectoryRead = unavailableChildDirectoryRead,
    this.attendancePermissions = const AttendancePermissions.readOnly(),
    this.routineRepository = const UnavailableRoutineRepository(),
    this.auditRepository = const UnavailableAuditRepository(),
    this.childSafetyRepository = const UnavailableChildSafetyRepository(),
    this.medicationPlanRepository = const UnavailableMedicationPlanRepository(),
    this.healthCareRepository = const UnavailableHealthCareRepository(),
    this.studentLinkRepository = const UnavailableStudentLinkRepository(),
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
    this.userPreferencesRepository,
    this.accountProfileRepository = const UnavailableAccountProfileRepository(),
    this.supportRepository,
    super.key,
  });

  final SuperadminSession? session;
  final LoginAction login;
  final LogoutAction logout;
  final PasswordRecoveryAction requestPasswordRecovery;
  final ResetPasswordAction resetPassword;
  final InstitutionDirectoryRepository institutionDirectoryRepository;
  final GroupDirectoryRepository groupDirectoryRepository;
  final GroupDetailRepository groupDetailRepository;
  final UnitDetailRepository unitDetailRepository;
  final LocationCatalogReader locationCatalogReader;
  final LocationConsumerBindingsReader locationConsumerBindingsReader;
  final LocationConsumerSelectionReader locationConsumerSelectionReader;
  final LocationCatalogWriter locationCatalogWriter;
  final LocationReservationGateway locationReservationGateway;
  final LocationCapabilities Function(SuperadminAuthContext?) locationCapabilities;
  final ActivityDirectoryRepository activityDirectoryRepository;
  final ActivityReadDetailRepository activityReadDetailRepository;
  final ActivityCommandRepository activityCommandRepository;
  final AssessmentRepository assessmentRepository;
  final bool assessmentMutationsEnabled;
  final PersonDirectoryRepository personDirectoryRepository;
  final PersonDetailReader personDetailReader;
  final PersonIdentityRepository personIdentityRepository;
  final UnitDirectoryRepository unitDirectoryRepository;
  final UnitBackendCommandsGateway unitBackendCommands;
  final bool structureMutationsEnabled;

  /// Chave de composicao: a selecao de local ao criar uma atividade so aparece
  /// quando superadmin_activity_location_create_v2 (180150) esta no projeto
  /// ligado; ligar a chave nao autoriza o ator, o servidor continua decidindo.
  final bool activityLocationCreateEnabled;
  final AccessProfileRepository accessProfileRepository;
  final PlatformUserRepository? platformUserRepository;
  final ImportRepository importRepository;
  final PlanCatalogRepository planCatalogRepository;
  final AgendaRepository? agendaRepository;
  final FormsApi? formsApi;
  final FormsDirectoryReader? formsDirectoryReader;
  final MediaReader? formsMediaReader;
  final SuperadminMediaScope? formsMediaScope;
  final MealPlanRepository mealPlanRepository;
  final MealPlanImageRepository mealPlanImageRepository;
  final String? authorizedMealPlanTenantId;
  final ChatRepository chatRepository;
  final MediaReader? mediaReader;
  final MediaSession? mediaSession;
  final SuperadminCircularRepository circularRepository;
  final InviteRepository inviteRepository;
  final NoticeRepository noticeRepository;
  final AttendanceRepository attendanceRepository;
  final ChildDirectoryRead childDirectoryRead;
  final AttendancePermissions attendancePermissions;
  final RoutineRepository routineRepository;
  final AuditRepository auditRepository;
  final ChildSafetyRepository childSafetyRepository;
  final MedicationPlanRepository medicationPlanRepository;
  final HealthCareRepository healthCareRepository;
  final StudentLinkRepository studentLinkRepository;
  final PrincipalRuntimeContextRepository? principalRuntimeContextRepository;
  final ProfileAboutRepository? profileAboutRepository;
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
  final UserPreferencesRepository? userPreferencesRepository;
  final AccountProfileRepository accountProfileRepository;
  final SupportRepository? supportRepository;

  @override
  State<SuperadminApp> createState() => _SuperadminAppState();
}

class _SuperadminAppState extends State<SuperadminApp> {
  late final SuperadminSession _session;
  late final GoRouter _router;
  late final bool _ownsSession;
  late final UserPreferencesController _preferencesController;
  late final ChildSafetyController _childSafetyController;

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.session == null;
    _session = widget.session ?? SuperadminSession();
    _preferencesController = UserPreferencesController(
      widget.userPreferencesRepository ?? SharedPreferencesUserPreferencesRepository(),
    )..addListener(_preferencesChanged);
    unawaited(
      _preferencesController.load().onError<Object>((error, stackTrace) {
        // Settings renders the sanitized failure and offers retry.
      }),
    );
    _childSafetyController = ChildSafetyController(widget.childSafetyRepository);
    _router = createSuperadminRouter(
      session: _session,
      login: widget.login,
      logout: widget.logout,
      requestPasswordRecovery: widget.requestPasswordRecovery,
      resetPassword: widget.resetPassword,
      institutionDirectoryRepository: widget.institutionDirectoryRepository,
      groupDirectoryRepository: widget.groupDirectoryRepository,
      groupDetailRepository: widget.groupDetailRepository,
      unitDetailRepository: widget.unitDetailRepository,
      locationCatalogReader: widget.locationCatalogReader,
      locationConsumerBindingsReader: widget.locationConsumerBindingsReader,
      locationConsumerSelectionReader: widget.locationConsumerSelectionReader,
      locationCatalogWriter: widget.locationCatalogWriter,
      locationReservationGateway: widget.locationReservationGateway,
      locationCapabilities: widget.locationCapabilities,
      activityDirectoryRepository: widget.activityDirectoryRepository,
      activityReadDetailRepository: widget.activityReadDetailRepository,
      activityCommandRepository: widget.activityCommandRepository,
      assessmentRepository: widget.assessmentRepository,
      enableAssessmentMutations: widget.assessmentMutationsEnabled,
      personDirectoryRepository: widget.personDirectoryRepository,
      personDetailReader: widget.personDetailReader,
      personIdentityRepository: widget.personIdentityRepository,
      unitDirectoryRepository: widget.unitDirectoryRepository,
      unitBackendCommands: widget.unitBackendCommands,
      enableStructureMutations: widget.structureMutationsEnabled,
      enableActivityLocationCreate: widget.activityLocationCreateEnabled,
      accessProfileRepository: widget.accessProfileRepository,
      platformUserRepository: widget.platformUserRepository,
      importRepository: widget.importRepository,
      planCatalogRepository: widget.planCatalogRepository,
      agendaRepository: widget.agendaRepository,
      formsApi: widget.formsApi,
      formsDirectoryReader: widget.formsDirectoryReader,
      formsMediaReader: widget.formsMediaReader,
      formsMediaScope: widget.formsMediaScope,
      mealPlanRepository: widget.mealPlanRepository,
      mealPlanImageRepository: widget.mealPlanImageRepository,
      authorizedMealPlanTenantId: widget.authorizedMealPlanTenantId,
      chatRepository: widget.chatRepository,
      mediaReader: widget.mediaReader,
      mediaSession: widget.mediaSession,
      circularRepository: widget.circularRepository,
      inviteRepository: widget.inviteRepository,
      noticeRepository: widget.noticeRepository,
      attendanceRepository: widget.attendanceRepository,
      childDirectoryRead: widget.childDirectoryRead,
      attendancePermissions: widget.attendancePermissions,
      routineRepository: widget.routineRepository,
      auditRepository: widget.auditRepository,
      childSafetyController: _childSafetyController,
      medicationPlanRepository: widget.medicationPlanRepository,
      healthCareRepository: widget.healthCareRepository,
      studentLinkRepository: widget.studentLinkRepository,
      principalRuntimeContextRepository:
          widget.principalRuntimeContextRepository ??
          const UnavailablePrincipalRuntimeContextRepository(),
      profileAboutRepository: widget.profileAboutRepository,
      principalCircularRepository: widget.principalCircularRepository,
      principalHappensFeedRepository: widget.principalHappensFeedRepository,
      principalMixedFeedRepository: widget.principalMixedFeedRepository,
      principalCircularResponseRepository: widget.principalCircularResponseRepository,
      principalCircularMediaRepository: widget.principalCircularMediaRepository,
      principalMomentsFeedRepository: widget.principalMomentsFeedRepository,
      principalMomentsWithdrawalRepository: widget.principalMomentsWithdrawalRepository,
      happensPublicationRepository: widget.happensPublicationRepository,
      principalNowFeedRepository: widget.principalNowFeedRepository,
      momentsPublicationRepository: widget.momentsPublicationRepository,
      nowPublicationRepository: widget.nowPublicationRepository,
      userPreferencesController: _preferencesController,
      accountProfileRepository: widget.accountProfileRepository,
      supportRepository: widget.supportRepository,
      onThemeModeChanged: _setThemeMode,
    );
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    final operation = _preferencesController.setThemeMode(mode);
    final intentRevision = _preferencesController.intentRevision;
    try {
      await operation;
    } on Object {
      if (!mounted || _preferencesController.intentRevision != intentRevision) return;
      if (_preferencesController.loaded &&
          (!_preferencesController.saveFailed ||
              _preferencesController.preferences.themeMode != mode)) {
        return;
      }
      final currentContext = _router.routerDelegate.navigatorKey.currentContext;
      if (currentContext == null || !currentContext.mounted) return;
      ScaffoldMessenger.maybeOf(currentContext)?.showSnackBar(
        const SnackBar(content: Text('Não foi possível salvar as preferências neste dispositivo.')),
      );
    }
  }

  void _preferencesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _router.dispose();
    _childSafetyController.dispose();
    _preferencesController
      ..removeListener(_preferencesChanged)
      ..dispose();
    if (_ownsSession) {
      _session.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
        _preferencesController.preferences.reduceMotion;
    return MaterialApp.router(
      title: SuperadminAppConfig.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _superadminLightTheme,
      darkTheme: _superadminDarkTheme,
      themeMode: _preferencesController.preferences.themeMode,
      themeAnimationStyle: reduceMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 420), curve: Curves.easeInOut),
      builder: (context, child) {
        final inherited = MediaQuery.of(context);
        return SuperadminThemeModeScope(
          mode: _preferencesController.preferences.themeMode,
          onChanged: _setThemeMode,
          child: MediaQuery(
            data: inherited.copyWith(
              disableAnimations:
                  inherited.disableAnimations || _preferencesController.preferences.reduceMotion,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: _router,
    );
  }
}
