import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import '../../core/guards/superadmin_session.dart';
import '../../core/config/superadmin_app_config.dart';
import '../../core/config/superadmin_auth_scope.dart' show UnavailableMealPlanImageRepository;
import '../../core/platform/open_download.dart';
import '../dev_menu/development_assessment_repository.dart';
import '../dev_menu/development_activity_fixture_repository.dart';
import '../dev_menu/development_attendance_repository.dart';
import '../dev_menu/development_invite_repository.dart';
import '../dev_menu/development_routine_repository.dart';
import '../activity/superadmin_activity.dart';
import '../prototype/superadmin_prototype_store.dart';
import '../../features/activities/data/dev/dev_activity_command_repository.dart';
import '../../features/activities/data/dev/dev_activity_directory_repository.dart';
import '../../features/activities/data/dev/dev_activity_session_store.dart';
import '../../features/activities/domain/activity_command.dart';
import '../../features/activities/domain/activity_directory.dart';
import '../../features/activities/domain/activity_profile_about_repository.dart';
import '../../features/activities/presentation/activity_detail_page.dart';
import '../../features/activities/presentation/activity_directory_page.dart';
import '../../features/activities/presentation/activity_form_controller.dart';
import '../../features/activities/presentation/activity_form_page.dart';
import '../../features/activities/presentation/activity_form_draft.dart';
import '../../features/assessments/assessment.dart';
import '../../features/assessments/assessment_pages.dart';
import '../../features/account/data/account_profile_repository.dart';
import '../../features/account/data/user_preferences_repository.dart';
import '../../features/account/presentation/account_controller.dart';
import '../../features/account/presentation/screens/profile_page.dart';
import '../../features/principal_happens/presentation/principal_happens_preview_page.dart';
import '../../features/principal_for_you/presentation/principal_for_you_preview_page.dart';
import '../../features/principal_happens_publication/domain/happens_publication.dart';
import '../../features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import '../../features/principal_moments/presentation/principal_moments_preview_page.dart';
import '../../features/principal_moments_publication/presentation/principal_moments_publication_page.dart';
import '../../features/principal_now/presentation/principal_now_preview_page.dart';
import '../../features/principal_now_publication/domain/now_publication.dart';
import '../../features/principal_now_publication/presentation/principal_now_publication_page.dart';
import '../../features/principal_profile/presentation/principal_profile_preview_page.dart';
import '../../features/account/presentation/screens/settings_page.dart';
import '../../features/account/presentation/user_preferences_controller.dart';
import '../../features/imports/domain/import_job.dart';
import '../../features/access_profiles/data/supabase_access_profile_repository.dart';
import '../../features/access_profiles/domain/access_profile.dart';
import '../../features/agenda/data/agenda_prototype_store.dart';
import '../../features/agenda/presentation/agenda_calendar_page.dart';
import '../../features/agenda/presentation/agenda_event_form_page.dart';
import '../../features/agenda/presentation/agenda_events_page.dart';
import '../../features/agenda/presentation/agenda_module_shell.dart';
import '../../features/agenda/presentation/agenda_permissions_page.dart';
import '../../features/agenda/presentation/agenda_requests_page.dart';
import '../../features/auth/domain/login_request.dart';
import '../../features/auth/domain/logout_action.dart';
import '../../features/auth/domain/password_recovery.dart';
import '../../features/auth/domain/reset_password_action.dart';
import '../../features/auth/presentation/screens/superadmin_forgot_password_screen.dart';
import '../../features/auth/presentation/screens/superadmin_login_screen.dart';
import '../../features/auth/presentation/screens/superadmin_reset_password_screen.dart';
import '../../features/attendance/attendance.dart';
import '../../features/attendance/data/supabase_attendance_repository.dart';
import '../../features/attendance/attendance_pages.dart';
import '../../features/daily_routine/daily_routine.dart';
import '../../features/daily_routine/daily_routine_pages.dart';
import '../../features/catalog/presentation/catalog_host_page.dart';
import '../../features/chat/presentation/screens/superadmin_chat_page.dart';
import '../../features/errors/presentation/screens/superadmin_error_screen.dart';
import '../../features/forms/presentation/editor/forms_editor_page.dart';
import '../../features/groups/data/fake_group_directory_repository.dart';
import '../../features/groups/domain/group_directory.dart' hide GroupDirectoryPage;
import '../../features/groups/presentation/group_directory_page.dart';
import '../../features/groups/presentation/group_form_page.dart';
import '../../features/help_center/presentation/screens/superadmin_help_center_page.dart';
import '../../features/health_care/domain/health_care_repository.dart';
import '../../features/health_care/data/dev/dev_health_care_repository.dart';
import '../../features/health_care/data/dev/dev_medication_plan_health_care_repository.dart';
import '../../features/health_care/data/dev/dev_medication_plan_repository.dart';
import '../../features/health_care/domain/medication_plan_repository.dart';
import '../../features/health_care/presentation/health_care_controller.dart';
import '../../features/health_care/presentation/health_care_directory_page.dart';
import '../../features/health_care/presentation/health_care_form_pages.dart';
import '../../features/health_care/presentation/health_medication_form_sections.dart';
import '../../features/health_care/presentation/health_medication_plan_directory_page.dart';
import '../../features/institutions/data/fake_institution_directory_repository.dart';
import '../../features/institutions/data/supabase_institution_directory_repository.dart';
import '../../features/institutions/domain/institution_directory_repository.dart';
import '../../features/institutions/presentation/screens/institution_directory_page.dart';
import '../../features/institutions/presentation/screens/institution_form_page.dart';
import '../../features/audit/presentation/audit_directory_page.dart';
import '../../features/audit/presentation/audit_controller.dart';
import '../../features/audit/domain/audit.dart';
import '../../features/imports/domain/import_repository.dart';
import '../../features/imports/presentation/import_directory_page.dart';
import '../../features/imports/presentation/import_wizard_controller.dart';
import '../../features/imports/presentation/import_wizard_page.dart';
import '../../features/invites/domain/platform_invite.dart';
import '../../features/invites/presentation/invite_detail_page.dart';
import '../../features/invites/presentation/invite_directory_page.dart';
import '../../features/invites/presentation/invite_form_page.dart';
import '../../features/notices/domain/notice_repository.dart'
    show NoticeRepository, UnavailableNoticeRepository;
import '../../features/notices/data/development_notice_repository.dart';
import '../../features/notices/presentation/notice_directory_page.dart';
import '../../features/notices/presentation/notice_form_page.dart';
import '../../features/plans/data/fake_plan_catalog_repository.dart';
import '../../features/plans/presentation/plan_directory_page.dart';
import '../../features/plans/presentation/plan_form_page.dart';
import '../../features/platform_users/data/fake_platform_user_repository.dart';
import '../../features/platform_users/domain/platform_user.dart';
import '../../features/platform_users/presentation/platform_user_directory_page.dart';
import '../../features/platform_users/presentation/platform_user_form_page.dart';
import '../../features/people/data/supabase_person_directory_repository.dart';
import '../dev_menu/development_person_directory_repository.dart';
import '../dev_menu/development_person_identity_repository.dart';
import '../../features/people/domain/person_directory.dart' hide PersonDirectoryPage;
import '../../features/people/domain/person_identity.dart';
import '../../features/people/presentation/person_directory_page.dart';
import '../../features/people/presentation/person_edit_route_page.dart';
import '../../features/people/presentation/person_form_page.dart';
import '../../features/people/presentation/person_identity_lookup_gate.dart';
import '../../features/safety/application/child_safety_controller.dart';
import '../../features/safety/data/dev/dev_child_safety_repository.dart';
import '../../features/safety/domain/child_safety_contract.dart';
import '../../features/safety/presentation/safety_pages.dart';
import '../../features/meal_plans/domain/meal_plan_repository.dart';
import '../../features/meal_plans/domain/meal_plan_image_repository.dart'
    hide UnavailableMealPlanImageRepository;
import '../../features/meal_plans/data/dev/development_meal_plan_repository.dart';
import '../../features/meal_plans/presentation/meal_plan_directory_page.dart';
import '../../features/meal_plans/presentation/meal_plan_wizard_page.dart';
import '../../features/forms/presentation/directory/forms_directory_page.dart';
import '../../features/forms/presentation/overview/forms_overview_page.dart';
import '../../features/support/presentation/screens/support_page.dart';
import '../../features/support/presentation/view_models/support_prototype_controller.dart';
import '../../features/student_tracking/domain/student_tracking.dart';
import '../../features/student_tracking/presentation/student_tracking_page.dart';
import '../../features/units/data/fake_unit_directory_repository.dart';
import '../../features/units/data/unavailable_unit_composition.dart';
import '../../features/units/domain/unit_backend_commands.dart';
import '../../features/units/domain/unit_directory.dart' hide UnitDirectoryPage;
import '../../features/units/presentation/unit_directory_page.dart';
import '../../features/units/presentation/unit_form_page.dart';
import '../dev_menu/dev_menu_overlay.dart';
import '../shell/superadmin_shell.dart';
import 'superadmin_routes.dart';

const _productionMutationUnavailablePath = '/errors/mutation-capability-unavailable';

void _returnToOr(
  BuildContext context,
  GoRouterState state,
  String fallbackRouteName, {
  Object? extra,
}) {
  final returnTo = state.uri.queryParameters['returnTo'];
  if (returnTo != null && returnTo.startsWith('/')) {
    context.go(returnTo);
    return;
  }
  context.goNamed(fallbackRouteName, extra: extra);
}

SupportPrototypeController _createDevelopmentSupportController() => SupportPrototypeController();

GoRouter createSuperadminRouter({
  required SuperadminSession session,
  required LoginAction login,
  required LogoutAction logout,
  required PasswordRecoveryAction requestPasswordRecovery,
  InstitutionDirectoryRepository institutionDirectoryRepository =
      const UnavailableInstitutionDirectoryRepository(),
  GroupDirectoryRepository groupDirectoryRepository = const UnavailableGroupDirectoryRepository(),
  ActivityDirectoryRepository activityDirectoryRepository =
      const UnavailableActivityDirectoryRepository(),
  ActivityCommandRepository activityCommandRepository =
      const UnavailableActivityCommandRepository(),
  AssessmentRepository assessmentRepository = const UnavailableAssessmentRepository(),
  PersonDirectoryRepository personDirectoryRepository =
      const UnavailablePersonDirectoryRepository(),
  PersonIdentityRepository personIdentityRepository = const UnavailablePersonIdentityRepository(),
  UnitDirectoryRepository unitDirectoryRepository = const UnavailableUnitDirectoryRepository(),
  UnitBackendCommandsGateway unitBackendCommands = const UnavailableUnitBackendCommandsGateway(),
  AccessProfileRepository accessProfileRepository = const UnavailableAccessProfileRepository(),
  ResetPasswordAction resetPassword = unavailableResetPassword,
  String catalogUrl = const String.fromEnvironment(
    'COELO_CATALOG_URL',
    defaultValue: 'https://catalog.coelo.me',
  ),
  ValueChanged<Uri>? openExternalCatalog,
  SupportPrototypeController? supportController,
  UserPreferencesController? userPreferencesController,
  ImportRepository importRepository = const UnavailableImportRepository(),
  InviteRepository inviteRepository = const UnavailableInviteRepository(),
  NoticeRepository noticeRepository = const UnavailableNoticeRepository(),
  AttendanceRepository attendanceRepository = const UnavailableAttendanceRepository(),
  StudentTrackingRepository studentTrackingRepository =
      const UnavailableStudentTrackingRepository(),
  AttendancePermissions attendancePermissions = const AttendancePermissions.readOnly(),
  RoutineRepository routineRepository = const UnavailableRoutineRepository(),
  AuditRepository auditRepository = const UnavailableAuditRepository(),
  MedicationPlanRepository medicationPlanRepository = const UnavailableMedicationPlanRepository(),
  DevMedicationPlanRepository? developmentMedicationPlanRepository,
  MealPlanRepository mealPlanRepository = const UnavailableMealPlanRepository(),
  MealPlanImageRepository mealPlanImageRepository = const UnavailableMealPlanImageRepository(),
  FormsApi? formsApi,
  NowPublicationRepository? nowPublicationRepository,
  ChildSafetyController? childSafetyController,
  bool allowDevelopmentPreview = SuperadminAppConfig.allowDevelopmentPreview,
  required ValueChanged<ThemeMode> onThemeModeChanged,
}) {
  final resolvedChildSafetyController =
      childSafetyController ?? ChildSafetyController(const UnavailableChildSafetyRepository());
  final developmentChildSafetyController = ChildSafetyController(DevChildSafetyRepository());
  final productionSupportController = supportController;
  final developmentSupportController = _createDevelopmentSupportController();
  final accountActivities = SuperadminActivityController();
  final operationalActivities = SuperadminActivityController();
  final operationalStore = SuperadminPrototypeStore(activityController: operationalActivities);
  final developmentAssessmentRepository = DevelopmentAssessmentRepository();
  final developmentNoticeRepository = DevelopmentNoticeRepository();
  final developmentMealPlanRepository = DevelopmentMealPlanRepository();
  final planRepository = FakePlanCatalogRepository(store: operationalStore);
  final importedRepository = importRepository;
  const developmentImportRepository = UnavailableImportRepository();
  final agendaPrototypeStore = AgendaPrototypeStore.seeded();
  final developmentAccountController = AccountController(
    repository: InMemoryAccountProfileRepository(),
    activities: accountActivities,
  );
  final productionPreferencesController =
      userPreferencesController ??
      UserPreferencesController(SharedPreferencesUserPreferencesRepository());
  final developmentPreferencesController = UserPreferencesController(
    InMemoryUserPreferencesRepository(),
  );
  var productionPreferencesLoadStarted = productionPreferencesController.loaded;
  unawaited(developmentAccountController.load());
  unawaited(developmentPreferencesController.load());
  FakeInstitutionDirectoryRepository? cachedInstitutionPreviewRepository;
  FakeInstitutionDirectoryRepository institutionPreviewRepository() =>
      cachedInstitutionPreviewRepository ??= FakeInstitutionDirectoryRepository();
  final unitRepository = unitDirectoryRepository;
  FakeUnitDirectoryRepository? cachedUnitPreviewRepository;
  UnitDirectoryRepository unitPreviewRepository() =>
      cachedUnitPreviewRepository ??= FakeUnitDirectoryRepository(institutionPreviewRepository());
  final groupRepository = groupDirectoryRepository;
  FakeGroupDirectoryRepository? cachedGroupPreviewRepository;
  FakeGroupDirectoryRepository groupPreviewRepository() =>
      cachedGroupPreviewRepository ??= FakeGroupDirectoryRepository(institutionPreviewRepository());
  DevelopmentAttendanceRepository? cachedAttendancePreviewRepository;
  DevelopmentAttendanceRepository attendancePreviewRepository() =>
      cachedAttendancePreviewRepository ??= DevelopmentAttendanceRepository.content();
  final attendanceActivities = SuperadminActivityController();
  final dailyRoutineRepository = routineRepository;
  DevelopmentRoutineRepository? cachedRoutinePreviewRepository;
  DevelopmentRoutineRepository routinePreviewRepository() =>
      cachedRoutinePreviewRepository ??= DevelopmentRoutineRepository.content();
  DevelopmentInviteRepository? cachedInvitePreviewRepository;
  DevelopmentInviteRepository invitePreviewRepository() =>
      cachedInvitePreviewRepository ??= DevelopmentInviteRepository();
  const productionActivityAboutRepository = UnavailableActivityProfileAboutRepository();
  final developmentActivityStore = DevActivitySessionStore.content();
  final developmentActivityDirectoryRepository = DevActivityDirectoryRepository(
    store: developmentActivityStore,
  );
  final developmentActivityCommandRepository = DevActivityCommandRepository(
    store: developmentActivityStore,
  );
  final developmentActivityAboutRepository = DevelopmentActivityProfileAboutRepository();
  const blockedCareProfilesRepository = UnavailableHealthCareRepository();
  DevHealthCareRepository? cachedCareProfilesPreviewRepository;
  DevHealthCareRepository careProfilesPreviewRepository() =>
      cachedCareProfilesPreviewRepository ??= DevHealthCareRepository.content();
  final medicationPlansPreviewRepository =
      developmentMedicationPlanRepository ?? DevMedicationPlanRepository();
  const developmentCareProfileChildren = <HealthCareProfileChildOption>[
    HealthCareProfileChildOption(id: 'child-demo-a', label: 'Criança Demo A'),
    HealthCareProfileChildOption(id: 'child-demo-b', label: 'Criança Demo B'),
  ];
  const developmentMedicationChildren = <HealthCareFormChoice>[
    HealthCareFormChoice(id: 'child-demo-a', label: 'Criança Demo A'),
    HealthCareFormChoice(id: 'child-demo-b', label: 'Criança Demo B'),
  ];
  final medicationPlanDirectoryPreviewRepository = DevMedicationPlanHealthCareRepository(
    medicationPlans: medicationPlansPreviewRepository,
    childLabels: {for (final child in developmentMedicationChildren) child.id: child.label},
  );
  final medicationPlanLoadFutures = <String, Future<MedicationPlanDetail>>{};

  Future<HealthMedicationPlanSaveReceipt> saveDevelopmentMedicationPlanDraft(
    HealthMedicationPlanFormDraft draft,
  ) async {
    const timezone = 'America/Sao_Paulo';
    final time = draft.time;
    final saved = await medicationPlansPreviewRepository.save(
      MedicationPlanSaveCommand(
        requestId: draft.requestId!,
        planId: draft.planId,
        childPersonId: draft.childId,
        expectedVersion: draft.expectedVersion,
        medicationName: draft.medicationName,
        doseAmount: draft.doseAmount,
        doseUnit: draft.doseUnit,
        administrationRoute: draft.administrationRoute,
        validFrom: draft.validFrom!,
        validUntil: draft.validUntil,
        reason: 'Prévia local de desenvolvimento',
        scopeKind: 'institution',
        institutionId: 'institution-dev',
        timezone: timezone,
        schedules: [
          MedicationScheduleDraft(
            timeOfDay: time == null
                ? '08:00'
                : '${time.hour.toString().padLeft(2, '0')}:'
                      '${time.minute.toString().padLeft(2, '0')}',
            weekdays: draft.weekdays.isEmpty ? const {1, 2, 3, 4, 5} : draft.weekdays,
            timezone: timezone,
          ),
        ],
      ),
    );
    return HealthMedicationPlanSaveReceipt(planId: saved.id, version: saved.currentVersion);
  }

  HealthMedicationPlanFormDraft developmentMedicationDraft(MedicationPlanDetail detail) {
    final schedule = detail.schedules.first;
    final timeParts = schedule.timeOfDay.split(':');
    return HealthMedicationPlanFormDraft(
      planId: detail.id,
      expectedVersion: detail.currentVersion,
      childId: detail.childPersonId,
      medicationName: detail.medicationName,
      doseAmount: detail.doseAmount,
      doseUnit: detail.doseUnit,
      administrationRoute: detail.administrationRoute,
      validFrom: detail.validFrom,
      validUntil: detail.validUntil,
      time: TimeOfDay(hour: int.parse(timeParts.first), minute: int.parse(timeParts.last)),
      weekdays: schedule.weekdays,
      responsibleIds: const {},
    );
  }

  final peoplePreviewRepository = DevelopmentPersonDirectoryRepository();
  FakePlatformUserRepository? platformUserPreviewRepository;
  FakePlatformUserRepository previewPlatformUsers() =>
      platformUserPreviewRepository ??= FakePlatformUserRepository();
  String? successMessage(Object? extra) {
    return switch (extra) {
      InstitutionFormSaveResult.created => 'Instituição criada com sucesso.',
      InstitutionFormSaveResult.updated => 'Alterações salvas com sucesso.',
      _ => null,
    };
  }

  String? unitSuccessMessage(Object? extra) {
    return switch (extra) {
      UnitFormSaveResult.created => 'Unidade criada com sucesso.',
      UnitFormSaveResult.updated => 'Alterações da unidade salvas com sucesso.',
      _ => null,
    };
  }

  String? groupSuccessMessage(Object? extra) {
    return switch (extra) {
      GroupFormSaveResult.created => 'Turma criada com sucesso.',
      GroupFormSaveResult.updated => 'Alterações da turma salvas com sucesso.',
      _ => null,
    };
  }

  Widget operationalPage(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String destination,
    required Widget child,
  }) => SuperadminShell(
    logout: _previewLogout,
    title: title,
    subtitle: subtitle,
    currentDestination: destination,
    activityController: operationalActivities,
    onDestinationSelected: (value) => _navigateFromDevelopmentShell(context, value),
    child: child,
  );
  Widget productionOperationalPage(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String destination,
    required Widget child,
  }) => SuperadminShell(
    logout: logout,
    title: title,
    subtitle: subtitle,
    currentDestination: destination,
    activityController: operationalActivities,
    onDestinationSelected: (value) => _navigateFromPersistentShell(context, value),
    child: child,
  );
  Widget blockedProductionMutationPage(BuildContext context) => SuperadminErrorScreen(
    key: const Key('production-mutation-capability-unavailable'),
    kind: SuperadminErrorKind.unavailable,
    onAction: () => context.goNamed(SuperadminRoutes.homeName),
  );
  bool hasAuthoritativeMutationCapability() => false;
  void openAgendaArea(BuildContext context, AgendaModuleArea area) {
    context.goNamed(switch (area) {
      AgendaModuleArea.calendar => SuperadminRoutes.devAgendaName,
      AgendaModuleArea.events => SuperadminRoutes.devAgendaEventsName,
      AgendaModuleArea.requests => SuperadminRoutes.devAgendaRequestsName,
      AgendaModuleArea.permissions => SuperadminRoutes.devAgendaPermissionsName,
    });
  }

  Widget agendaAreaShell(BuildContext context, AgendaModuleArea area, Widget child) =>
      AgendaModuleShell(
        logout: _previewLogout,
        selectedArea: area,
        onAreaSelected: (value) => openAgendaArea(context, value),
        onDestinationSelected: (destination) => _navigateFromDevelopmentShell(context, destination),
        child: child,
      );

  Future<void> saveActivity(
    ActivityFormDraft draft, {
    required ActivityCommandIntent intent,
    String? activityId,
    required ActivityCommandRepository commandRepository,
    required ActivityProfileAboutRepository aboutRepository,
  }) async {
    final aboutPage = draft.aboutPage;
    if (aboutPage != null && !aboutRepository.isAvailable) {
      throw const ActivityProfileAboutUnavailableException();
    }
    final result = await commandRepository.save(
      _activitySaveCommand(draft, intent: intent, activityId: activityId),
    );
    if (aboutPage != null) {
      await aboutRepository.save(
        page: aboutPage,
        institutionId: draft.institutionId,
        activityId: result.activityId,
        requestId: _activityRequestId(),
      );
    }
  }

  Future<void> createActivityTemplate(
    ActivityTemplateCreateDraft draft,
    ActivityCommandRepository repository,
  ) => repository.createTemplate(
    ActivityTemplateCreateCommand(
      requestId: _activityRequestId(),
      institutionId: draft.institutionId,
      name: draft.name,
      description: draft.description,
      taxonomyId: draft.taxonomyId,
      governance: draft.governance,
    ),
  );

  Future<List<ActivityFormLocationOption>> createActivityLocations(
    ActivityLocationDraft draft,
    ActivityCommandRepository repository,
  ) async {
    final locations = await repository.createLocations(
      ActivityLocationCommand(
        requestId: _activityRequestId(),
        institutionId: draft.institutionId,
        unitIds: draft.unitIds,
        name: draft.name,
      ),
    );
    return locations
        .map(
          (location) => ActivityFormLocationOption(
            id: location.id,
            unitId: location.unitId,
            name: location.name,
          ),
        )
        .toList(growable: false);
  }

  return GoRouter(
    initialLocation: SuperadminRoutes.login,
    refreshListenable: session,
    errorBuilder: (context, state) => SuperadminErrorScreen(
      kind: SuperadminErrorKind.notFound,
      onAction: () => context.goNamed(SuperadminRoutes.homeName),
    ),
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (!allowDevelopmentPreview && location.startsWith('/dev/')) {
        return session.isAuthenticated ? SuperadminRoutes.home : SuperadminRoutes.login;
      }
      if (location.startsWith('/dev/')) {
        return null;
      }
      final isOnLogin = location == SuperadminRoutes.login;
      final isOnForgotPassword = location == SuperadminRoutes.forgotPassword;
      final isOnResetPassword = location == SuperadminRoutes.resetPassword;
      final isOnPublicAuthRoute = isOnLogin || isOnForgotPassword || isOnResetPassword;
      if (!session.isAuthenticated) {
        return isOnPublicAuthRoute ? null : SuperadminRoutes.login;
      }
      if (isOnPublicAuthRoute) {
        return SuperadminRoutes.home;
      }
      if (_isProductionMutationLocation(location) && !hasAuthoritativeMutationCapability()) {
        return _productionMutationUnavailablePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: _productionMutationUnavailablePath,
        builder: (context, state) => blockedProductionMutationPage(context),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final location = state.matchedLocation;
          final developmentPreview = location.startsWith('/dev/');
          final routedChild = _usesPersistentShell(location)
              ? SuperadminShell.host(
                  key: const Key('superadmin-persistent-shell'),
                  logout: developmentPreview ? _previewLogout : logout,
                  currentDestination: _destinationForLocation(location),
                  onDestinationSelected: (destination) => developmentPreview
                      ? _navigateFromDevelopmentShell(context, destination)
                      : _navigateFromPersistentShell(context, destination),
                  onBugReportSubmitted: productionSupportController?.submitReport,
                  canAccessCapability: (capability) => switch (capability) {
                    'attendance.create' => developmentPreview,
                    'activities.create' => developmentPreview,
                    _ => developmentPreview,
                  },
                  child: child,
                )
              : child;
          return DevMenuOverlay(
            onNavigate: (destination) => _navigateFromDevelopmentShell(context, destination),
            showTrigger:
                allowDevelopmentPreview &&
                (developmentPreview || location == SuperadminRoutes.login) &&
                location != SuperadminRoutes.conversations,
            child: routedChild,
          );
        },
        routes: [
          GoRoute(
            path: SuperadminRoutes.login,
            name: SuperadminRoutes.loginName,
            builder: (context, state) => SuperadminLoginScreen(
              session: session,
              login: login,
              onForgotPassword: () => context.goNamed(SuperadminRoutes.forgotPasswordName),
              onThemeModeChanged: onThemeModeChanged,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.forgotPassword,
            name: SuperadminRoutes.forgotPasswordName,
            builder: (context, state) => SuperadminForgotPasswordScreen(
              requestPasswordRecovery: requestPasswordRecovery,
              onBackToLogin: () => context.goNamed(SuperadminRoutes.loginName),
              onThemeModeChanged: onThemeModeChanged,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.resetPassword,
            name: SuperadminRoutes.resetPasswordName,
            builder: (context, state) => SuperadminResetPasswordScreen(
              resetPassword: resetPassword,
              onBackToLogin: () => context.goNamed(SuperadminRoutes.loginName),
              onThemeModeChanged: onThemeModeChanged,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.home,
            name: SuperadminRoutes.homeName,
            builder: (context, state) => SuperadminHelpCenterPage(
              logout: logout,
              onOpenConversations: () => context.goNamed(
                SuperadminRoutes.conversationsName,
                queryParameters: const {'from': 'home'},
              ),
              onDestinationSelected: (destination) {
                if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.institutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.unitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.groupsName);
                } else if (destination == 'activities') {
                  context.goNamed(SuperadminRoutes.activitiesName);
                } else if (destination == 'attendance') {
                  context.goNamed(SuperadminRoutes.attendanceName);
                } else if (destination == 'daily-routine') {
                  context.goNamed(SuperadminRoutes.dailyRoutineName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.peopleName);
                } else if (destination == 'catalog') {
                  context.goNamed(SuperadminRoutes.governanceCatalogName);
                } else if (destination == 'support') {
                  context.goNamed(SuperadminRoutes.supportName);
                } else if (destination == 'conversations') {
                  context.goNamed(SuperadminRoutes.conversationsName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.institutions,
            name: SuperadminRoutes.institutionsName,
            builder: (context, state) => InstitutionDirectoryPage(
              repository: institutionDirectoryRepository,
              logout: logout,
              onHomeOpen: () => context.goNamed(SuperadminRoutes.homeName),
              onUnitsOpen: () => context.goNamed(SuperadminRoutes.unitsName),
              onPeopleOpen: () => context.goNamed(SuperadminRoutes.peopleName),
              successMessage: successMessage(state.extra),
              onCreate: null,
              onEdit: null,
              onCatalogOpen: () =>
                  openConfiguredCatalogExternally(catalogUrl, openExternally: openExternalCatalog),
              onSupportOpen: () => context.goNamed(SuperadminRoutes.supportName),
              onBugReportSubmitted: productionSupportController?.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.conversationsName,
                queryParameters: const {'from': 'institutions'},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.institutionCreate,
            name: SuperadminRoutes.institutionCreateName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : InstitutionFormPage(
                    repository: institutionDirectoryRepository,
                    logout: logout,
                    onCancel: () => context.goNamed(SuperadminRoutes.institutionsName),
                    onSaved: (result) =>
                        context.goNamed(SuperadminRoutes.institutionsName, extra: result),
                    onDestinationSelected: (destination) {
                      if (destination == 'home') {
                        context.goNamed(SuperadminRoutes.homeName);
                      } else if (destination == 'institutions') {
                        context.goNamed(SuperadminRoutes.institutionsName);
                      } else if (destination == 'units') {
                        context.goNamed(SuperadminRoutes.unitsName);
                      } else if (destination == 'groups') {
                        context.goNamed(SuperadminRoutes.groupsName);
                      } else if (destination == 'people') {
                        context.goNamed(SuperadminRoutes.peopleName);
                      } else if (destination == 'catalog') {
                        context.goNamed(SuperadminRoutes.governanceCatalogName);
                      } else if (destination == 'support') {
                        context.goNamed(SuperadminRoutes.supportName);
                      } else if (destination == 'conversations') {
                        context.goNamed(SuperadminRoutes.conversationsName);
                      }
                    },
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.institutionEdit,
            name: SuperadminRoutes.institutionEditName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : InstitutionFormPage(
                    repository: institutionDirectoryRepository,
                    institutionId: state.pathParameters['institutionId'],
                    logout: logout,
                    onCancel: () => context.goNamed(SuperadminRoutes.institutionsName),
                    onSaved: (result) =>
                        context.goNamed(SuperadminRoutes.institutionsName, extra: result),
                    onDestinationSelected: (destination) {
                      if (destination == 'home') {
                        context.goNamed(SuperadminRoutes.homeName);
                      } else if (destination == 'institutions') {
                        context.goNamed(SuperadminRoutes.institutionsName);
                      } else if (destination == 'units') {
                        context.goNamed(SuperadminRoutes.unitsName);
                      } else if (destination == 'groups') {
                        context.goNamed(SuperadminRoutes.groupsName);
                      } else if (destination == 'people') {
                        context.goNamed(SuperadminRoutes.peopleName);
                      } else if (destination == 'catalog') {
                        context.goNamed(SuperadminRoutes.governanceCatalogName);
                      } else if (destination == 'support') {
                        context.goNamed(SuperadminRoutes.supportName);
                      }
                    },
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.units,
            name: SuperadminRoutes.unitsName,
            builder: (context, state) => UnitDirectoryPage(
              repository: unitRepository,
              backendCommands: null,
              logout: logout,
              successMessage: unitSuccessMessage(state.extra),
              onCreate: null,
              onEdit: null,
              onBugReportSubmitted: productionSupportController?.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.conversationsName,
                queryParameters: const {'from': 'units'},
              ),
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.homeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.institutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.unitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.groupsName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.peopleName);
                } else if (destination == 'catalog') {
                  openConfiguredCatalogExternally(catalogUrl, openExternally: openExternalCatalog);
                } else if (destination == 'support') {
                  context.goNamed(SuperadminRoutes.supportName);
                } else if (destination == 'conversations') {
                  context.goNamed(SuperadminRoutes.conversationsName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.unitCreate,
            name: SuperadminRoutes.unitCreateName,
            builder: (context, state) => UnitFormPage(
              repository: unitRepository,
              logout: logout,
              onCreateGroup: (institutionId, unitId) => context.goNamed(
                SuperadminRoutes.groupCreateName,
                queryParameters: {
                  'institutionId': institutionId,
                  'unitId': ?unitId,
                  'returnTo': state.uri.toString(),
                },
              ),
              onEditGroup: (id) => context.goNamed(
                SuperadminRoutes.groupEditName,
                pathParameters: {'groupId': id},
                queryParameters: {'returnTo': state.uri.toString()},
              ),
              onCreateActivity: (institutionId, unitId) => context.goNamed(
                SuperadminRoutes.activityCreateName,
                queryParameters: {
                  'institutionId': institutionId,
                  'unitId': ?unitId,
                  'returnTo': state.uri.toString(),
                },
              ),
              onEditActivity: (id) => context.goNamed(
                SuperadminRoutes.activityEditName,
                pathParameters: {'activityId': id},
                queryParameters: {'returnTo': state.uri.toString()},
              ),
              onCancel: () => context.goNamed(SuperadminRoutes.unitsName),
              onSaved: (result) => context.goNamed(SuperadminRoutes.unitsName, extra: result),
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.homeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.institutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.unitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.groupsName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.peopleName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.unitEdit,
            name: SuperadminRoutes.unitEditName,
            builder: (context, state) => UnitFormPage(
              repository: unitRepository,
              unitId: state.pathParameters['unitId'],
              logout: logout,
              onCreateGroup: (institutionId, unitId) => context.goNamed(
                SuperadminRoutes.groupCreateName,
                queryParameters: {
                  'institutionId': institutionId,
                  'unitId': ?unitId,
                  'returnTo': state.uri.toString(),
                },
              ),
              onEditGroup: (id) => context.goNamed(
                SuperadminRoutes.groupEditName,
                pathParameters: {'groupId': id},
                queryParameters: {'returnTo': state.uri.toString()},
              ),
              onCreateActivity: (institutionId, unitId) => context.goNamed(
                SuperadminRoutes.activityCreateName,
                queryParameters: {
                  'institutionId': institutionId,
                  'unitId': ?unitId,
                  'returnTo': state.uri.toString(),
                },
              ),
              onEditActivity: (id) => context.goNamed(
                SuperadminRoutes.activityEditName,
                pathParameters: {'activityId': id},
                queryParameters: {'returnTo': state.uri.toString()},
              ),
              onCancel: () => context.goNamed(SuperadminRoutes.unitsName),
              onSaved: (result) => context.goNamed(SuperadminRoutes.unitsName, extra: result),
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.homeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.institutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.unitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.groupsName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.peopleName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.groups,
            name: SuperadminRoutes.groupsName,
            builder: (context, state) => GroupDirectoryPage(
              repository: groupRepository,
              logout: logout,
              successMessage: groupSuccessMessage(state.extra),
              onCreate: null,
              onEdit: null,
              onBugReportSubmitted: productionSupportController?.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.groupCreate,
            name: SuperadminRoutes.groupCreateName,
            builder: (context, state) => GroupFormPage(
              repository: groupRepository,
              initialInstitutionId: state.uri.queryParameters['institutionId'],
              initialUnitId: state.uri.queryParameters['unitId'],
              logout: logout,
              onCancel: () => _returnToOr(context, state, SuperadminRoutes.groupsName),
              onSaved: (result) =>
                  _returnToOr(context, state, SuperadminRoutes.groupsName, extra: result),
              onBugReportSubmitted: productionSupportController?.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.groupEdit,
            name: SuperadminRoutes.groupEditName,
            builder: (context, state) => GroupFormPage(
              repository: groupRepository,
              groupId: state.pathParameters['groupId'],
              logout: logout,
              onCancel: () => _returnToOr(context, state, SuperadminRoutes.groupsName),
              onSaved: (result) =>
                  _returnToOr(context, state, SuperadminRoutes.groupsName, extra: result),
              onBugReportSubmitted: productionSupportController?.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.activities,
            name: SuperadminRoutes.activitiesName,
            builder: (context, state) => ActivityDirectoryPage(
              repository: activityDirectoryRepository,
              logout: logout,
              onCreate: null,
              onCreateFromTemplate: null,
              onDuplicateTemplate: null,
              onCreateTemplate: null,
              onEdit: null,
              onView: (id) => context.goNamed(
                SuperadminRoutes.activityDetailName,
                pathParameters: {'activityId': id},
              ),
              onExportRequested: null,
              onImportRequested: null,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: productionSupportController?.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.activityCreate,
            name: SuperadminRoutes.activityCreateName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : ActivityFormPage(
                    repository: activityDirectoryRepository,
                    initialTemplateId: state.uri.queryParameters['templateId'],
                    initialInstitutionId: state.uri.queryParameters['institutionId'],
                    initialUnitId: state.uri.queryParameters['unitId'],
                    aboutRepository: productionActivityAboutRepository,
                    logout: logout,
                    onCancel: () => _returnToOr(context, state, SuperadminRoutes.activitiesName),
                    onSaveDraft: (draft) => saveActivity(
                      draft,
                      intent: ActivityCommandIntent.saveDraft,
                      commandRepository: activityCommandRepository,
                      aboutRepository: productionActivityAboutRepository,
                    ),
                    onSubmit: (draft) async {
                      await saveActivity(
                        draft,
                        intent: ActivityCommandIntent.publish,
                        commandRepository: activityCommandRepository,
                        aboutRepository: productionActivityAboutRepository,
                      );
                      if (context.mounted) {
                        _returnToOr(context, state, SuperadminRoutes.activitiesName);
                      }
                    },
                    onCreateLocation: (draft) =>
                        createActivityLocations(draft, activityCommandRepository),
                    onDestinationSelected: (destination) =>
                        _navigateFromPersistentShell(context, destination),
                    onBugReportSubmitted: productionSupportController?.submitReport,
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.activityAssessmentSettings,
            name: SuperadminRoutes.activityAssessmentSettingsName,
            builder: (context, state) => AssessmentConfigurationPage(
              repository: assessmentRepository,
              logout: logout,
              activityId: state.pathParameters['activityId']!,
              institutionId: state.uri.queryParameters['institutionId'] ?? '',
              unitId: state.uri.queryParameters['unitId'],
              onCancel: () => context.goNamed(
                SuperadminRoutes.activityDetailName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.activityDetail,
            name: SuperadminRoutes.activityDetailName,
            builder: (context, state) => ActivityDetailPage(
              activityId: state.pathParameters['activityId']!,
              repository: activityDirectoryRepository,
              logout: logout,
              onBack: () => context.goNamed(SuperadminRoutes.activitiesName),
              onEdit: () => context.goNamed(
                SuperadminRoutes.activityEditName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
              onAssessmentSettings: (detail) => context.goNamed(
                SuperadminRoutes.activityAssessmentSettingsName,
                pathParameters: {'activityId': detail.item.id},
                queryParameters: {'institutionId': detail.item.institutionId},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: productionSupportController?.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.activityEdit,
            name: SuperadminRoutes.activityEditName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : ActivityFormPage(
                    activityId: state.pathParameters['activityId']!,
                    initialStep: state.uri.queryParameters['step'] == 'pedagogical'
                        ? ActivityFormStep.pedagogical
                        : null,
                    repository: activityDirectoryRepository,
                    aboutRepository: productionActivityAboutRepository,
                    logout: logout,
                    onCancel: () => state.uri.queryParameters.containsKey('returnTo')
                        ? _returnToOr(context, state, SuperadminRoutes.activitiesName)
                        : context.goNamed(
                            SuperadminRoutes.activityDetailName,
                            pathParameters: {'activityId': state.pathParameters['activityId']!},
                          ),
                    onSaveDraft: (draft) => saveActivity(
                      draft,
                      intent: ActivityCommandIntent.saveDraft,
                      activityId: state.pathParameters['activityId']!,
                      commandRepository: activityCommandRepository,
                      aboutRepository: productionActivityAboutRepository,
                    ),
                    onSubmit: (draft) async {
                      await saveActivity(
                        draft,
                        intent: ActivityCommandIntent.publish,
                        activityId: state.pathParameters['activityId']!,
                        commandRepository: activityCommandRepository,
                        aboutRepository: productionActivityAboutRepository,
                      );
                      if (!context.mounted) return;
                      state.uri.queryParameters.containsKey('returnTo')
                          ? _returnToOr(context, state, SuperadminRoutes.activitiesName)
                          : context.goNamed(
                              SuperadminRoutes.activityDetailName,
                              pathParameters: {'activityId': state.pathParameters['activityId']!},
                            );
                    },
                    onCreateLocation: (draft) =>
                        createActivityLocations(draft, activityCommandRepository),
                    onDestinationSelected: (destination) =>
                        _navigateFromPersistentShell(context, destination),
                    onBugReportSubmitted: productionSupportController?.submitReport,
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.assessmentEntry,
            name: SuperadminRoutes.assessmentEntryName,
            builder: (context, state) => AssessmentEntryPage(
              repository: assessmentRepository,
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.activitiesName),
              onSubmitted: (_) => context.goNamed(SuperadminRoutes.assessmentClosingName),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.assessmentGradebookEdit,
            name: SuperadminRoutes.assessmentGradebookEditName,
            builder: (context, state) => AssessmentEntryPage(
              repository: assessmentRepository,
              logout: logout,
              gradebookId: state.pathParameters['gradebookId']!,
              onCancel: () => context.goNamed(SuperadminRoutes.activitiesName),
              onSubmitted: (_) => context.goNamed(SuperadminRoutes.assessmentClosingName),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.assessmentClosing,
            name: SuperadminRoutes.assessmentClosingName,
            builder: (context, state) => AssessmentClosingPage(
              repository: assessmentRepository,
              logout: logout,
              onOpen: (id) => context.goNamed(
                SuperadminRoutes.assessmentClosingDetailName,
                pathParameters: {'gradebookId': id},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.assessmentClosingDetail,
            name: SuperadminRoutes.assessmentClosingDetailName,
            builder: (context, state) => AssessmentClosingDetailPage(
              repository: assessmentRepository,
              logout: logout,
              gradebookId: state.pathParameters['gradebookId']!,
              onBack: () => context.goNamed(SuperadminRoutes.assessmentClosingName),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.students,
            name: SuperadminRoutes.studentsName,
            builder: (context, state) => StudentTrackingPage(
              repository: studentTrackingRepository,
              logout: logout,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.studentManage,
            name: SuperadminRoutes.studentManageName,
            builder: (context, state) => SuperadminErrorScreen(
              kind: SuperadminErrorKind.unavailable,
              onAction: () => context.goNamed(SuperadminRoutes.homeName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.attendance,
            name: SuperadminRoutes.attendanceName,
            builder: (context, state) => AttendanceDashboardPage(
              repository: attendanceRepository,
              permissions: attendancePermissions,
              logout: logout,
              onCreate: null,
              onOpenCall: null,
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.attendanceCreate,
            name: SuperadminRoutes.attendanceCreateName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : AttendanceNewCallPage(
                    repository: attendanceRepository,
                    permissions: attendancePermissions,
                    logout: logout,
                    onCancel: () => context.goNamed(SuperadminRoutes.attendanceName),
                    onCreated: (id) => context.goNamed(
                      SuperadminRoutes.attendanceCallName,
                      pathParameters: {'callId': id},
                    ),
                    initialInstitutionId: state.uri.queryParameters['institution'],
                    initialUnitId: state.uri.queryParameters['unit'],
                    initialGroupId: state.uri.queryParameters['group'],
                    initialActivityId: state.uri.queryParameters['activity'],
                    activityController: attendanceActivities,
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.attendanceCall,
            name: SuperadminRoutes.attendanceCallName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : AttendanceCallPage(
                    repository: attendanceRepository,
                    callId: state.pathParameters['callId']!,
                    focusedParticipantId: state.uri.queryParameters['participant'],
                    permissions: attendancePermissions,
                    logout: logout,
                    onBack: () => context.goNamed(SuperadminRoutes.attendanceName),
                    activityController: attendanceActivities,
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.dailyRoutine,
            name: SuperadminRoutes.dailyRoutineName,
            builder: (context, state) => DailyRoutineDirectoryPage(
              repository: dailyRoutineRepository,
              logout: logout,
              activityController: attendanceActivities,
              onCreateEntry: null,
              onEdit: null,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.dailyRoutineCreate,
            name: SuperadminRoutes.dailyRoutineCreateName,
            builder: (context, state) => DailyRoutineEditorPage(
              repository: dailyRoutineRepository,
              logout: logout,
              activityController: attendanceActivities,
              entryType: state.extra is RoutineEntryKind
                  ? state.extra! as RoutineEntryKind
                  : RoutineEntryKind.model,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.dailyRoutineEdit,
            name: SuperadminRoutes.dailyRoutineEditName,
            builder: (context, state) => DailyRoutineEditorPage(
              repository: dailyRoutineRepository,
              logout: logout,
              modelId: state.pathParameters['modelId'],
              entryType: _routineEntryKind(state.uri.queryParameters['kind']),
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.forms,
            name: SuperadminRoutes.formsName,
            builder: (context, state) => FormsDirectoryPage(
              api: formsApi,
              onOpen: (form) => context.goNamed(
                SuperadminRoutes.formOverviewName,
                pathParameters: {'formId': form.id},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.formCreate,
            name: SuperadminRoutes.formCreateName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.formOverview,
            name: SuperadminRoutes.formOverviewName,
            builder: (context, state) =>
                FormsOverviewPage(api: formsApi, formId: state.pathParameters['formId']!),
          ),
          GoRoute(
            path: SuperadminRoutes.formEdit,
            name: SuperadminRoutes.formEditName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.formTest,
            name: SuperadminRoutes.formTestName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.formMonitor,
            name: SuperadminRoutes.formMonitorName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.formRespond,
            name: SuperadminRoutes.formRespondName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.formResponses,
            name: SuperadminRoutes.formResponsesName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.formResponseDetail,
            name: SuperadminRoutes.formResponseDetailName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.formFiles,
            name: SuperadminRoutes.formFilesName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.formMedia,
            name: SuperadminRoutes.formMediaName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.healthCareProfiles,
            name: SuperadminRoutes.healthCareProfilesName,
            builder: (context, state) => HealthCareProfileDirectoryPage(
              controller: HealthCareController(blockedCareProfilesRepository),
              logout: logout,
              onCreate: () => context.goNamed(SuperadminRoutes.healthCareProfileCreateName),
              onChildSelected: (childId) => context.pushNamed(
                SuperadminRoutes.healthCareProfileDetailName,
                pathParameters: {'childId': childId},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthCareProfileCreate,
            name: SuperadminRoutes.healthCareProfileCreateName,
            builder: (context, state) => HealthCareProfileFormPage(
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.healthCareProfilesName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthCareProfileDetail,
            name: SuperadminRoutes.healthCareProfileDetailName,
            redirect: (context, state) => _productionMutationUnavailablePath,
          ),
          GoRoute(
            path: SuperadminRoutes.healthCareProfileEdit,
            name: SuperadminRoutes.healthCareProfileEditName,
            builder: (context, state) => HealthCareProfileFormPage(
              logout: logout,
              childId: state.pathParameters['childId']!,
              onCancel: () => context.pop(),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthMedicationPlans,
            name: SuperadminRoutes.healthMedicationPlansName,
            builder: (context, state) => _unavailableMedicationPlans(context),
          ),
          GoRoute(
            path: SuperadminRoutes.healthMedicationPlanCreate,
            name: SuperadminRoutes.healthMedicationPlanCreateName,
            builder: (context, state) => _unavailableMedicationPlans(context),
          ),
          GoRoute(
            path: SuperadminRoutes.healthMedicationPlanDetail,
            name: SuperadminRoutes.healthMedicationPlanDetailName,
            builder: (context, state) => _unavailableMedicationPlans(context),
          ),
          GoRoute(
            path: SuperadminRoutes.healthMedicationPlanEdit,
            name: SuperadminRoutes.healthMedicationPlanEditName,
            builder: (context, state) => _unavailableMedicationPlans(context),
          ),
          GoRoute(
            path: SuperadminRoutes.people,
            name: SuperadminRoutes.peopleName,
            builder: (context, state) => PersonDirectoryPage(
              repository: personDirectoryRepository,
              logout: logout,
              successMessage: state.extra as String?,
              onCreate: null,
              onEdit: null,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: productionSupportController?.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.conversationsName,
                queryParameters: const {'from': 'people'},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.safety,
            name: SuperadminRoutes.safetyName,
            builder: (context, state) => SafetyLandingPage(
              controller: resolvedChildSafetyController,
              logout: logout,
              onOpenChild: (id) => context.goNamed(
                SuperadminRoutes.safetyChildName,
                pathParameters: {'childId': id},
              ),
              onCreate: null,
              onExport: null,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.safetyCreate,
            name: SuperadminRoutes.safetyCreateName,
            builder: (context, state) => ChildSafetyWizardPage(
              controller: resolvedChildSafetyController,
              childId: state.uri.queryParameters['childId'],
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.safetyName),
              onSaved: () => context.goNamed(SuperadminRoutes.safetyName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.safetyEdit,
            name: SuperadminRoutes.safetyEditName,
            builder: (context, state) => ChildSafetyWizardPage(
              controller: resolvedChildSafetyController,
              childId: state.pathParameters['childId'],
              authorizationId: state.pathParameters['authorizationId'],
              logout: logout,
              onCancel: () => context.goNamed(
                SuperadminRoutes.safetyChildName,
                pathParameters: {'childId': state.pathParameters['childId']!},
              ),
              onSaved: () => context.goNamed(
                SuperadminRoutes.safetyChildName,
                pathParameters: {'childId': state.pathParameters['childId']!},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.safetyChild,
            name: SuperadminRoutes.safetyChildName,
            builder: (context, state) => ChildSecurityPage(
              childId: state.pathParameters['childId']!,
              controller: resolvedChildSafetyController,
              logout: logout,
              onBack: () => context.goNamed(SuperadminRoutes.safetyName),
              onCreate: null,
              onEdit: null,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.personCreate,
            name: SuperadminRoutes.personCreateName,
            builder: (context, state) {
              if (!hasAuthoritativeMutationCapability()) {
                return blockedProductionMutationPage(context);
              }
              final creationMode = state.uri.queryParameters['personCreationMode'];
              final initialPersonType = switch (creationMode) {
                'child' => PersonType.child,
                'service' => PersonType.service,
                'professional' => PersonType.adult,
                _ => null,
              };
              return PersonIdentityLookupGate(
                repository: personIdentityRepository,
                institutionId: state.uri.queryParameters['institutionId'],
                unitId: state.uri.queryParameters['unitId'],
                onCancel: () => _returnToOr(context, state, SuperadminRoutes.peopleName),
                onExistingPerson: (personId) => context.goNamed(
                  SuperadminRoutes.personEditName,
                  pathParameters: {'personId': personId},
                ),
                formBuilder: (context) => PersonFormPage(
                  repository: personDirectoryRepository,
                  initialInstitutionId: state.uri.queryParameters['institutionId'],
                  initialUnitId: state.uri.queryParameters['unitId'],
                  initialPersonType: initialPersonType,
                  initialRole: state.uri.queryParameters['personRole'],
                  logout: logout,
                  onCancel: () => _returnToOr(context, state, SuperadminRoutes.peopleName),
                  onSaved: (_) => _returnToOr(
                    context,
                    state,
                    SuperadminRoutes.peopleName,
                    extra: 'Pessoa criada com sucesso.',
                  ),
                  onDestinationSelected: (destination) =>
                      _navigateFromPersistentShell(context, destination),
                ),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.personEdit,
            name: SuperadminRoutes.personEditName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : PersonEditRoutePage(
                    personId: state.pathParameters['personId']!,
                    repository: personDirectoryRepository,
                    logout: logout,
                    onCancel: () => _returnToOr(context, state, SuperadminRoutes.peopleName),
                    onSaved: (_) => _returnToOr(
                      context,
                      state,
                      SuperadminRoutes.peopleName,
                      extra: 'Alterações salvas com sucesso.',
                    ),
                    onDestinationSelected: (destination) =>
                        _navigateFromPersistentShell(context, destination),
                    onOpenChildSecurity: () => context.goNamed(
                      SuperadminRoutes.safetyChildName,
                      pathParameters: {'childId': state.pathParameters['personId']!},
                    ),
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.profiles,
            name: SuperadminRoutes.profilesName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.profileModels,
            name: SuperadminRoutes.profileModelsName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.profileModelCreate,
            name: SuperadminRoutes.profileModelCreateName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.profileModelDetail,
            name: SuperadminRoutes.profileModelDetailName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.profileModelEdit,
            name: SuperadminRoutes.profileModelEditName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.profileModelDuplicate,
            name: SuperadminRoutes.profileModelDuplicateName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.profileCreate,
            name: SuperadminRoutes.profileCreateName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.profileDetail,
            name: SuperadminRoutes.profileDetailName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.profileEdit,
            name: SuperadminRoutes.profileEditName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.governanceCatalog,
            name: SuperadminRoutes.governanceCatalogName,
            builder: (context, state) => CatalogHostPage(
              catalogUrl: catalogUrl,
              localPreview: true,
              logout: logout,
              onHomeOpen: () => context.goNamed(SuperadminRoutes.homeName),
              onInstitutionsOpen: () => context.goNamed(SuperadminRoutes.institutionsName),
              onUnitsOpen: () => context.goNamed(SuperadminRoutes.unitsName),
              onSupportOpen: () => context.goNamed(SuperadminRoutes.supportName),
              onBugReportSubmitted: productionSupportController?.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.conversationsName,
                queryParameters: const {'from': 'catalog'},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.support,
            name: SuperadminRoutes.supportName,
            builder: (context, state) {
              final controller = productionSupportController;
              if (controller == null) {
                return SuperadminErrorScreen(
                  kind: SuperadminErrorKind.unavailable,
                  onAction: () => context.goNamed(SuperadminRoutes.homeName),
                );
              }
              return SupportPage(
                controller: controller,
                logout: logout,
                onHomeOpen: () => context.goNamed(SuperadminRoutes.homeName),
                onInstitutionsOpen: () => context.goNamed(SuperadminRoutes.institutionsName),
                onUnitsOpen: () => context.goNamed(SuperadminRoutes.unitsName),
                onCatalogOpen: () => openConfiguredCatalogExternally(
                  catalogUrl,
                  openExternally: openExternalCatalog,
                ),
                onConversationsOpen: () => context.goNamed(
                  SuperadminRoutes.conversationsName,
                  queryParameters: const {'from': 'support'},
                ),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.conversations,
            name: SuperadminRoutes.conversationsName,
            builder: (context, state) => SuperadminChatPage(
              logout: logout,
              onBack: () {
                final origin = state.uri.queryParameters['from'];
                context.goNamed(switch (origin) {
                  'home' => SuperadminRoutes.homeName,
                  'catalog' => SuperadminRoutes.governanceCatalogName,
                  _ => SuperadminRoutes.institutionsName,
                });
              },
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.profile,
            name: SuperadminRoutes.profileName,
            builder: (context, state) => SuperadminErrorScreen(
              kind: SuperadminErrorKind.unavailable,
              onAction: () => context.goNamed(SuperadminRoutes.homeName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.settings,
            name: SuperadminRoutes.settingsName,
            builder: (context, state) {
              if (!productionPreferencesLoadStarted) {
                productionPreferencesLoadStarted = true;
                unawaited(productionPreferencesController.load());
              }
              return SettingsPage(
                controller: productionPreferencesController,
                logout: logout,
                onDestinationSelected: (destination) => _navigateFromAccount(context, destination),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devLogin,
            name: SuperadminRoutes.devLoginName,
            builder: (context, state) => SuperadminLoginScreen(
              session: session,
              login: unavailableSuperadminLogin,
              onForgotPassword: () => context.goNamed(SuperadminRoutes.devForgotPasswordName),
              onThemeModeChanged: onThemeModeChanged,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devForgotPassword,
            name: SuperadminRoutes.devForgotPasswordName,
            builder: (context, state) => SuperadminForgotPasswordScreen(
              requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
              onBackToLogin: () => context.goNamed(SuperadminRoutes.devLoginName),
              onThemeModeChanged: onThemeModeChanged,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devResetPassword,
            name: SuperadminRoutes.devResetPasswordName,
            builder: (context, state) => SuperadminResetPasswordScreen(
              resetPassword: unavailableResetPassword,
              onBackToLogin: () => context.goNamed(SuperadminRoutes.devLoginName),
              onThemeModeChanged: onThemeModeChanged,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHome,
            name: SuperadminRoutes.devHomeName,
            builder: (context, state) => SuperadminHelpCenterPage(
              logout: _previewLogout,
              onOpenConversations: () => context.goNamed(
                SuperadminRoutes.devConversationsName,
                queryParameters: const {'from': 'home'},
              ),
              onDestinationSelected: (destination) {
                if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.devInstitutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.devUnitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.devGroupsName);
                } else if (destination == 'activities') {
                  context.goNamed(SuperadminRoutes.devActivitiesName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.devPeopleName);
                } else if (destination == 'catalog') {
                  context.goNamed(SuperadminRoutes.devCatalogName);
                } else if (destination == 'support') {
                  context.goNamed(SuperadminRoutes.devSupportName);
                } else if (destination == 'conversations') {
                  context.goNamed(SuperadminRoutes.devConversationsName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInstitutions,
            name: SuperadminRoutes.devInstitutionsName,
            builder: (context, state) => InstitutionDirectoryPage(
              repository: institutionPreviewRepository(),
              logout: _previewLogout,
              onHomeOpen: () => context.goNamed(SuperadminRoutes.devHomeName),
              onUnitsOpen: () => context.goNamed(SuperadminRoutes.devUnitsName),
              onPeopleOpen: () => context.goNamed(SuperadminRoutes.devPeopleName),
              successMessage: successMessage(state.extra),
              onCreate: () => context.goNamed(SuperadminRoutes.devInstitutionCreateName),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.devInstitutionEditName,
                pathParameters: {'institutionId': id},
              ),
              onCatalogOpen: () => context.goNamed(SuperadminRoutes.devCatalogName),
              onSupportOpen: () => context.goNamed(SuperadminRoutes.devSupportName),
              onBugReportSubmitted: developmentSupportController.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.devConversationsName,
                queryParameters: const {'from': 'institutions'},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInstitutionCreate,
            name: SuperadminRoutes.devInstitutionCreateName,
            builder: (context, state) => InstitutionFormPage(
              repository: institutionPreviewRepository(),
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devInstitutionsName),
              onSaved: (result) =>
                  context.goNamed(SuperadminRoutes.devInstitutionsName, extra: result),
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.devHomeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.devInstitutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.devUnitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.devGroupsName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.devPeopleName);
                } else if (destination == 'support') {
                  context.goNamed(SuperadminRoutes.devSupportName);
                } else if (destination == 'conversations') {
                  context.goNamed(SuperadminRoutes.devConversationsName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInstitutionEdit,
            name: SuperadminRoutes.devInstitutionEditName,
            builder: (context, state) => InstitutionFormPage(
              repository: institutionPreviewRepository(),
              institutionId: state.pathParameters['institutionId'],
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devInstitutionsName),
              onSaved: (result) =>
                  context.goNamed(SuperadminRoutes.devInstitutionsName, extra: result),
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.devHomeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.devInstitutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.devUnitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.devGroupsName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.devPeopleName);
                } else if (destination == 'support') {
                  context.goNamed(SuperadminRoutes.devSupportName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devUnits,
            name: SuperadminRoutes.devUnitsName,
            builder: (context, state) => UnitDirectoryPage(
              repository: unitPreviewRepository(),
              backendCommands: null,
              logout: _previewLogout,
              successMessage: unitSuccessMessage(state.extra),
              onCreate: () => context.goNamed(SuperadminRoutes.devUnitCreateName),
              onEdit: (id) =>
                  context.goNamed(SuperadminRoutes.devUnitEditName, pathParameters: {'unitId': id}),
              onBugReportSubmitted: developmentSupportController.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.devConversationsName,
                queryParameters: const {'from': 'units'},
              ),
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.devHomeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.devInstitutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.devUnitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.devGroupsName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.devPeopleName);
                } else if (destination == 'catalog') {
                  context.goNamed(SuperadminRoutes.devCatalogName);
                } else if (destination == 'support') {
                  context.goNamed(SuperadminRoutes.devSupportName);
                } else if (destination == 'conversations') {
                  context.goNamed(SuperadminRoutes.devConversationsName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devUnitCreate,
            name: SuperadminRoutes.devUnitCreateName,
            builder: (context, state) => UnitFormPage(
              repository: unitPreviewRepository(),
              logout: _previewLogout,
              onCreateGroup: (institutionId, unitId) => context.goNamed(
                SuperadminRoutes.devGroupCreateName,
                queryParameters: {
                  'institutionId': institutionId,
                  'unitId': ?unitId,
                  'returnTo': state.uri.toString(),
                },
              ),
              onEditGroup: (id) => context.goNamed(
                SuperadminRoutes.devGroupEditName,
                pathParameters: {'groupId': id},
                queryParameters: {'returnTo': state.uri.toString()},
              ),
              onCreateActivity: (institutionId, unitId) => context.goNamed(
                SuperadminRoutes.devActivityCreateName,
                queryParameters: {
                  'institutionId': institutionId,
                  'unitId': ?unitId,
                  'returnTo': state.uri.toString(),
                },
              ),
              onEditActivity: (id) => context.goNamed(
                SuperadminRoutes.devActivityEditName,
                pathParameters: {'activityId': id},
                queryParameters: {'returnTo': state.uri.toString()},
              ),
              onCancel: () => context.goNamed(SuperadminRoutes.devUnitsName),
              onSaved: (result) => context.goNamed(SuperadminRoutes.devUnitsName, extra: result),
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.devHomeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.devInstitutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.devUnitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.devGroupsName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.devPeopleName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devUnitEdit,
            name: SuperadminRoutes.devUnitEditName,
            builder: (context, state) => UnitFormPage(
              repository: unitPreviewRepository(),
              unitId: state.pathParameters['unitId'],
              logout: _previewLogout,
              onCreateGroup: (institutionId, unitId) => context.goNamed(
                SuperadminRoutes.devGroupCreateName,
                queryParameters: {
                  'institutionId': institutionId,
                  'unitId': ?unitId,
                  'returnTo': state.uri.toString(),
                },
              ),
              onEditGroup: (id) => context.goNamed(
                SuperadminRoutes.devGroupEditName,
                pathParameters: {'groupId': id},
                queryParameters: {'returnTo': state.uri.toString()},
              ),
              onCreateActivity: (institutionId, unitId) => context.goNamed(
                SuperadminRoutes.devActivityCreateName,
                queryParameters: {
                  'institutionId': institutionId,
                  'unitId': ?unitId,
                  'returnTo': state.uri.toString(),
                },
              ),
              onEditActivity: (id) => context.goNamed(
                SuperadminRoutes.devActivityEditName,
                pathParameters: {'activityId': id},
                queryParameters: {'returnTo': state.uri.toString()},
              ),
              onCancel: () => context.goNamed(SuperadminRoutes.devUnitsName),
              onSaved: (result) => context.goNamed(SuperadminRoutes.devUnitsName, extra: result),
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.devHomeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.devInstitutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.devUnitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.devGroupsName);
                } else if (destination == 'people') {
                  context.goNamed(SuperadminRoutes.devPeopleName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devGroups,
            name: SuperadminRoutes.devGroupsName,
            builder: (context, state) => GroupDirectoryPage(
              repository: groupPreviewRepository(),
              logout: _previewLogout,
              successMessage: groupSuccessMessage(state.extra),
              onCreate: () => context.goNamed(SuperadminRoutes.devGroupCreateName),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.devGroupEditName,
                pathParameters: {'groupId': id},
              ),
              onBugReportSubmitted: developmentSupportController.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devGroupCreate,
            name: SuperadminRoutes.devGroupCreateName,
            builder: (context, state) => GroupFormPage(
              repository: groupPreviewRepository(),
              initialInstitutionId: state.uri.queryParameters['institutionId'],
              initialUnitId: state.uri.queryParameters['unitId'],
              logout: _previewLogout,
              onCancel: () => _returnToOr(context, state, SuperadminRoutes.devGroupsName),
              onSaved: (result) =>
                  _returnToOr(context, state, SuperadminRoutes.devGroupsName, extra: result),
              onBugReportSubmitted: developmentSupportController.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devGroupEdit,
            name: SuperadminRoutes.devGroupEditName,
            builder: (context, state) => GroupFormPage(
              repository: groupPreviewRepository(),
              groupId: state.pathParameters['groupId'],
              logout: _previewLogout,
              onCancel: () => _returnToOr(context, state, SuperadminRoutes.devGroupsName),
              onSaved: (result) =>
                  _returnToOr(context, state, SuperadminRoutes.devGroupsName, extra: result),
              onBugReportSubmitted: developmentSupportController.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivities,
            name: SuperadminRoutes.devActivitiesName,
            builder: (context, state) => ActivityDirectoryPage(
              repository: developmentActivityDirectoryRepository,
              logout: _previewLogout,
              onCreate: () => context.goNamed(SuperadminRoutes.devActivityCreateName),
              onCreateFromTemplate: (template) => context.goNamed(
                SuperadminRoutes.devActivityCreateName,
                queryParameters: {
                  'templateId': template.id,
                  if (template.scopeKind == ActivityTemplateScopeKind.institution &&
                      template.institutionId != null)
                    'institutionId': template.institutionId!,
                },
              ),
              onDuplicateTemplate: (template, institutionId, newName) async {
                await createActivityTemplate(
                  ActivityTemplateCreateDraft(
                    institutionId: institutionId,
                    name: newName,
                    description: template.description,
                    taxonomyId: template.taxonomyId,
                    governance: template.governance,
                  ),
                  developmentActivityCommandRepository,
                );
              },
              onCreateTemplate: (draft) =>
                  createActivityTemplate(draft, developmentActivityCommandRepository),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.devActivityEditName,
                pathParameters: {'activityId': id},
              ),
              onView: (id) => context.goNamed(
                SuperadminRoutes.devActivityDetailName,
                pathParameters: {'activityId': id},
              ),
              onExportRequested: null,
              onImportRequested: null,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: developmentSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivityCreate,
            name: SuperadminRoutes.devActivityCreateName,
            builder: (context, state) => ActivityFormPage(
              repository: developmentActivityDirectoryRepository,
              aboutRepository: developmentActivityAboutRepository,
              initialTemplateId: state.uri.queryParameters['templateId'],
              initialInstitutionId: state.uri.queryParameters['institutionId'],
              initialUnitId: state.uri.queryParameters['unitId'],
              logout: _previewLogout,
              onCancel: () => _returnToOr(context, state, SuperadminRoutes.devActivitiesName),
              onSaveDraft: (draft) => saveActivity(
                draft,
                intent: ActivityCommandIntent.saveDraft,
                commandRepository: developmentActivityCommandRepository,
                aboutRepository: developmentActivityAboutRepository,
              ),
              onSubmit: (draft) async {
                await saveActivity(
                  draft,
                  intent: ActivityCommandIntent.publish,
                  commandRepository: developmentActivityCommandRepository,
                  aboutRepository: developmentActivityAboutRepository,
                );
                if (context.mounted) {
                  _returnToOr(context, state, SuperadminRoutes.devActivitiesName);
                }
              },
              onCreateLocation: (draft) =>
                  createActivityLocations(draft, developmentActivityCommandRepository),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: developmentSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivityDetail,
            name: SuperadminRoutes.devActivityDetailName,
            builder: (context, state) => ActivityDetailPage(
              activityId: state.pathParameters['activityId']!,
              repository: developmentActivityDirectoryRepository,
              logout: _previewLogout,
              onBack: () => context.goNamed(SuperadminRoutes.devActivitiesName),
              onEdit: () => context.goNamed(
                SuperadminRoutes.devActivityEditName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
              onAssessmentSettings: (detail) => context.goNamed(
                SuperadminRoutes.devActivityAssessmentSettingsName,
                pathParameters: {'activityId': detail.item.id},
                queryParameters: {'institutionId': detail.item.institutionId},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: developmentSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivityEdit,
            name: SuperadminRoutes.devActivityEditName,
            builder: (context, state) => ActivityFormPage(
              activityId: state.pathParameters['activityId']!,
              initialStep: state.uri.queryParameters['step'] == 'pedagogical'
                  ? ActivityFormStep.pedagogical
                  : null,
              repository: developmentActivityDirectoryRepository,
              aboutRepository: developmentActivityAboutRepository,
              logout: _previewLogout,
              onCancel: () => context.goNamed(
                SuperadminRoutes.devActivityDetailName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
              onSaveDraft: (draft) => saveActivity(
                draft,
                intent: ActivityCommandIntent.saveDraft,
                activityId: state.pathParameters['activityId']!,
                commandRepository: developmentActivityCommandRepository,
                aboutRepository: developmentActivityAboutRepository,
              ),
              onSubmit: (draft) async {
                await saveActivity(
                  draft,
                  intent: ActivityCommandIntent.publish,
                  activityId: state.pathParameters['activityId']!,
                  commandRepository: developmentActivityCommandRepository,
                  aboutRepository: developmentActivityAboutRepository,
                );
                if (context.mounted) {
                  context.goNamed(
                    SuperadminRoutes.devActivityDetailName,
                    pathParameters: {'activityId': state.pathParameters['activityId']!},
                  );
                }
              },
              onCreateLocation: (draft) =>
                  createActivityLocations(draft, developmentActivityCommandRepository),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: developmentSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivityAssessmentSettings,
            name: SuperadminRoutes.devActivityAssessmentSettingsName,
            builder: (context, state) => AssessmentConfigurationPage(
              repository: developmentAssessmentRepository,
              logout: _previewLogout,
              activityId: state.pathParameters['activityId']!,
              institutionId: state.uri.queryParameters['institutionId'] ?? '',
              unitId: state.uri.queryParameters['unitId'],
              onCancel: () => context.goNamed(
                SuperadminRoutes.devActivityDetailName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAssessmentEntry,
            name: SuperadminRoutes.devAssessmentEntryName,
            builder: (context, state) => AssessmentEntryPage(
              repository: developmentAssessmentRepository,
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devActivitiesName),
              onSubmitted: (_) => context.goNamed(SuperadminRoutes.devAssessmentClosingName),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAssessmentGradebookEdit,
            name: SuperadminRoutes.devAssessmentGradebookEditName,
            builder: (context, state) => AssessmentEntryPage(
              repository: developmentAssessmentRepository,
              logout: _previewLogout,
              gradebookId: state.pathParameters['gradebookId']!,
              onCancel: () => context.goNamed(SuperadminRoutes.devActivitiesName),
              onSubmitted: (_) => context.goNamed(SuperadminRoutes.devAssessmentClosingName),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAssessmentClosing,
            name: SuperadminRoutes.devAssessmentClosingName,
            builder: (context, state) => AssessmentClosingPage(
              repository: developmentAssessmentRepository,
              logout: _previewLogout,
              onOpen: (id) => context.goNamed(
                SuperadminRoutes.devAssessmentClosingDetailName,
                pathParameters: {'gradebookId': id},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAssessmentClosingDetail,
            name: SuperadminRoutes.devAssessmentClosingDetailName,
            builder: (context, state) => AssessmentClosingDetailPage(
              repository: developmentAssessmentRepository,
              logout: _previewLogout,
              gradebookId: state.pathParameters['gradebookId']!,
              onBack: () => context.goNamed(SuperadminRoutes.devAssessmentClosingName),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAttendance,
            name: SuperadminRoutes.devAttendanceName,
            builder: (context, state) => AttendanceDashboardPage(
              repository: attendancePreviewRepository(),
              permissions: const AttendancePermissions.development(),
              logout: _previewLogout,
              onCreate: () => context.goNamed(SuperadminRoutes.devAttendanceCreateName),
              onOpenCall: (id) => context.goNamed(
                SuperadminRoutes.devAttendanceCallName,
                pathParameters: {'callId': id},
              ),
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAttendanceCreate,
            name: SuperadminRoutes.devAttendanceCreateName,
            builder: (context, state) => AttendanceNewCallPage(
              repository: attendancePreviewRepository(),
              permissions: const AttendancePermissions.development(),
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devAttendanceName),
              onCreated: (id) => context.goNamed(
                SuperadminRoutes.devAttendanceCallName,
                pathParameters: {'callId': id},
              ),
              initialInstitutionId: state.uri.queryParameters['institution'],
              initialUnitId: state.uri.queryParameters['unit'],
              initialGroupId: state.uri.queryParameters['group'],
              initialActivityId: state.uri.queryParameters['activity'],
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAttendanceCall,
            name: SuperadminRoutes.devAttendanceCallName,
            builder: (context, state) => AttendanceCallPage(
              repository: attendancePreviewRepository(),
              callId: state.pathParameters['callId']!,
              focusedParticipantId: state.uri.queryParameters['participant'],
              permissions: const AttendancePermissions.development(),
              logout: _previewLogout,
              onBack: () => context.goNamed(SuperadminRoutes.devAttendanceName),
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devStudents,
            name: SuperadminRoutes.devStudentsName,
            builder: (context, state) => StudentTrackingPage(
              repository: const UnavailableStudentTrackingRepository(),
              logout: _previewLogout,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devStudentManage,
            name: SuperadminRoutes.devStudentManageName,
            builder: (context, state) => SuperadminErrorScreen(
              kind: SuperadminErrorKind.unavailable,
              onAction: () => context.goNamed(SuperadminRoutes.devHomeName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devDailyRoutine,
            name: SuperadminRoutes.devDailyRoutineName,
            builder: (context, state) => DailyRoutineDirectoryPage(
              repository: routinePreviewRepository(),
              logout: _previewLogout,
              activityController: attendanceActivities,
              onCreateEntry: (type) =>
                  context.goNamed(SuperadminRoutes.devDailyRoutineCreateName, extra: type),
              onEdit: (entry) => context.goNamed(
                SuperadminRoutes.devDailyRoutineEditName,
                pathParameters: {'modelId': entry.id},
                queryParameters: {'kind': entry.kind.name},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devDailyRoutineCreate,
            name: SuperadminRoutes.devDailyRoutineCreateName,
            builder: (context, state) => DailyRoutineEditorPage(
              repository: routinePreviewRepository(),
              logout: _previewLogout,
              activityController: attendanceActivities,
              entryType: state.extra is RoutineEntryKind
                  ? state.extra! as RoutineEntryKind
                  : RoutineEntryKind.model,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devDailyRoutineEdit,
            name: SuperadminRoutes.devDailyRoutineEditName,
            builder: (context, state) => DailyRoutineEditorPage(
              repository: routinePreviewRepository(),
              logout: _previewLogout,
              modelId: state.pathParameters['modelId'],
              entryType: _routineEntryKind(state.uri.queryParameters['kind']),
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthCareProfiles,
            name: SuperadminRoutes.devHealthCareProfilesName,
            builder: (context, state) => HealthCareProfileDirectoryPage(
              controller: HealthCareController(careProfilesPreviewRepository()),
              logout: _previewLogout,
              onCreate: () => context.goNamed(SuperadminRoutes.devHealthCareProfileCreateName),
              onChildSelected: (childId) => context.pushNamed(
                SuperadminRoutes.devHealthCareProfileDetailName,
                pathParameters: {'childId': childId},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthCareProfileCreate,
            name: SuperadminRoutes.devHealthCareProfileCreateName,
            builder: (context, state) => HealthCareProfileFormPage(
              logout: _previewLogout,
              childOptions: developmentCareProfileChildren,
              onCancel: () => context.goNamed(SuperadminRoutes.devHealthCareProfilesName),
              onSaved: (draft) async {
                await careProfilesPreviewRepository().saveCareProfileDraft(draft);
              },
              onSaveSucceeded: () => context.goNamed(SuperadminRoutes.devHealthCareProfilesName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthCareProfileDetail,
            name: SuperadminRoutes.devHealthCareProfileDetailName,
            redirect: (context, state) => context.namedLocation(
              SuperadminRoutes.devHealthCareProfileEditName,
              pathParameters: {'childId': state.pathParameters['childId']!},
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthCareProfileEdit,
            name: SuperadminRoutes.devHealthCareProfileEditName,
            builder: (context, state) => HealthCareProfileFormPage(
              logout: _previewLogout,
              childOptions: developmentCareProfileChildren,
              childId: state.pathParameters['childId']!,
              loadDraft: careProfilesPreviewRepository().loadCareProfileDraft,
              onCancel: () => context.pop(),
              onSaved: (draft) async {
                await careProfilesPreviewRepository().saveCareProfileDraft(draft);
              },
              onSaveSucceeded: context.pop,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthMedicationPlans,
            name: SuperadminRoutes.devHealthMedicationPlansName,
            builder: (context, state) => HealthMedicationPlanDirectoryPage(
              controller: HealthCareController(medicationPlanDirectoryPreviewRepository),
              logout: _previewLogout,
              onCreate: () => context.goNamed(SuperadminRoutes.devHealthMedicationPlanCreateName),
              onPlanSelected: (medicationId) => context.pushNamed(
                SuperadminRoutes.devHealthMedicationPlanDetailName,
                pathParameters: {'medicationId': medicationId},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthMedicationPlanCreate,
            name: SuperadminRoutes.devHealthMedicationPlanCreateName,
            builder: (context, state) => HealthMedicationPlanFormPage(
              logout: _previewLogout,
              childOptions: developmentMedicationChildren,
              onCancel: () => context.goNamed(SuperadminRoutes.devHealthMedicationPlansName),
              onDraftSaved: saveDevelopmentMedicationPlanDraft,
              onSaved: () async => context.goNamed(SuperadminRoutes.devHealthMedicationPlansName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthMedicationPlanDetail,
            name: SuperadminRoutes.devHealthMedicationPlanDetailName,
            redirect: (context, state) => context.namedLocation(
              SuperadminRoutes.devHealthMedicationPlanEditName,
              pathParameters: {'medicationId': state.pathParameters['medicationId']!},
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthMedicationPlanEdit,
            name: SuperadminRoutes.devHealthMedicationPlanEditName,
            builder: (context, state) {
              final medicationId = state.pathParameters['medicationId']!;
              final load = medicationPlanLoadFutures.putIfAbsent(
                medicationId,
                () => medicationPlansPreviewRepository.fetchDetail(medicationId),
              );
              return FutureBuilder<MedicationPlanDetail>(
                future: load,
                builder: (context, snapshot) {
                  final detail = snapshot.data;
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CoeloStatePanel(
                        title: 'Carregando plano',
                        message: 'Buscando os dados locais do plano.',
                        loading: true,
                      ),
                    );
                  }
                  if (detail == null) {
                    return CoeloStatePanel(
                      title: 'Não foi possível carregar o plano',
                      message: 'Volte à listagem e tente novamente.',
                      actionLabel: 'Voltar',
                      onAction: () =>
                          context.goNamed(SuperadminRoutes.devHealthMedicationPlansName),
                    );
                  }
                  return HealthMedicationPlanFormPage(
                    key: ValueKey('dev-medication-edit-$medicationId'),
                    logout: _previewLogout,
                    medicationId: medicationId,
                    childId: detail.childPersonId,
                    initialDraft: developmentMedicationDraft(detail),
                    childOptions: developmentMedicationChildren,
                    onCancel: () => context.goNamed(SuperadminRoutes.devHealthMedicationPlansName),
                    onDraftSaved: saveDevelopmentMedicationPlanDraft,
                    onSaved: () async {
                      medicationPlanLoadFutures.remove(medicationId);
                      context.goNamed(SuperadminRoutes.devHealthMedicationPlansName);
                    },
                  );
                },
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devPeople,
            name: SuperadminRoutes.devPeopleName,
            builder: (context, state) => PersonDirectoryPage(
              repository: peoplePreviewRepository,
              logout: _previewLogout,
              successMessage: state.extra as String?,
              onCreate: () => context.goNamed(SuperadminRoutes.devPersonCreateName),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.devPersonEditName,
                pathParameters: {'personId': id},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: developmentSupportController.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.devConversationsName,
                queryParameters: const {'from': 'people'},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devSafety,
            name: SuperadminRoutes.devSafetyName,
            builder: (context, state) => SafetyLandingPage(
              controller: developmentChildSafetyController,
              logout: _previewLogout,
              onCreate: () => context.goNamed(SuperadminRoutes.devSafetyCreateName),
              onOpenChild: (id) => context.goNamed(
                SuperadminRoutes.devSafetyChildName,
                pathParameters: {'childId': id},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devSafetyCreate,
            name: SuperadminRoutes.devSafetyCreateName,
            builder: (context, state) => ChildSafetyWizardPage(
              controller: developmentChildSafetyController,
              childId: state.uri.queryParameters['childId'],
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devSafetyName),
              onSaved: () => context.goNamed(SuperadminRoutes.devSafetyName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devSafetyChild,
            name: SuperadminRoutes.devSafetyChildName,
            builder: (context, state) => ChildSecurityPage(
              childId: state.pathParameters['childId']!,
              controller: developmentChildSafetyController,
              logout: _previewLogout,
              onBack: () => context.goNamed(SuperadminRoutes.devSafetyName),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPersonCreate,
            name: SuperadminRoutes.devPersonCreateName,
            builder: (context, state) {
              final creationMode = state.uri.queryParameters['personCreationMode'];
              final initialPersonType = switch (creationMode) {
                'child' => PersonType.child,
                'service' => PersonType.service,
                'professional' => PersonType.adult,
                _ => null,
              };
              return PersonIdentityLookupGate(
                repository: const DevelopmentPersonIdentityRepository(),
                institutionId: state.uri.queryParameters['institutionId'],
                unitId: state.uri.queryParameters['unitId'],
                onCancel: () => _returnToOr(context, state, SuperadminRoutes.devPeopleName),
                onExistingPerson: (personId) => context.goNamed(
                  SuperadminRoutes.devPersonEditName,
                  pathParameters: {'personId': personId},
                ),
                formBuilder: (context) => PersonFormPage(
                  repository: peoplePreviewRepository,
                  initialInstitutionId: state.uri.queryParameters['institutionId'],
                  initialUnitId: state.uri.queryParameters['unitId'],
                  initialPersonType: initialPersonType,
                  initialRole: state.uri.queryParameters['personRole'],
                  logout: _previewLogout,
                  onCancel: () => _returnToOr(context, state, SuperadminRoutes.devPeopleName),
                  onSaved: (_) => _returnToOr(
                    context,
                    state,
                    SuperadminRoutes.devPeopleName,
                    extra: 'Pessoa criada com sucesso.',
                  ),
                  onDestinationSelected: (destination) =>
                      _navigateFromDevelopmentShell(context, destination),
                ),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devPersonEdit,
            name: SuperadminRoutes.devPersonEditName,
            builder: (context, state) => PersonEditRoutePage(
              personId: state.pathParameters['personId']!,
              repository: peoplePreviewRepository,
              logout: _previewLogout,
              onCancel: () => _returnToOr(context, state, SuperadminRoutes.devPeopleName),
              onSaved: (_) => _returnToOr(
                context,
                state,
                SuperadminRoutes.devPeopleName,
                extra: 'Alterações salvas com sucesso.',
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onOpenChildSecurity: () => context.goNamed(
                SuperadminRoutes.devSafetyChildName,
                pathParameters: {'childId': state.pathParameters['personId']!},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInternalUsers,
            name: SuperadminRoutes.devInternalUsersName,
            builder: (context, state) => PlatformUserDirectoryPage(
              repository: previewPlatformUsers(),
              capability: PlatformUserCapability.owner,
              logout: _previewLogout,
              successMessage: state.extra as String?,
              onCreate: () => context.goNamed(SuperadminRoutes.devInternalUserCreateName),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInternalUserCreate,
            name: SuperadminRoutes.devInternalUserCreateName,
            builder: (context, state) => PlatformUserFormPage(
              repository: previewPlatformUsers(),
              capability: PlatformUserCapability.owner,
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devInternalUsersName),
              onCreated: (result) =>
                  context.goNamed(SuperadminRoutes.devInternalUsersName, extra: result.message),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInternalUserEdit,
            name: SuperadminRoutes.devInternalUserEditName,
            builder: (context, state) {
              final id = state.pathParameters['internalUserId']!;
              return PlatformUserFormPage(
                repository: previewPlatformUsers(),
                internalUserId: id,
                capability: PlatformUserCapability.owner,
                logout: _previewLogout,
                onCancel: () => context.goNamed(SuperadminRoutes.devInternalUsersName),
                onUpdated: (_) => context.goNamed(SuperadminRoutes.devInternalUsersName),
                onDestinationSelected: (destination) =>
                    _navigateFromDevelopmentShell(context, destination),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devMealPlans,
            name: SuperadminRoutes.devMealPlansName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Cardápios',
              subtitle: 'Planeje refeições por período e escopo de atendimento.',
              destination: 'meal-plans',
              child: MealPlanDirectoryPage(
                repository: developmentMealPlanRepository,
                onCreate: (sourceId) => context.goNamed(
                  SuperadminRoutes.devMealPlanCreateName,
                  queryParameters: sourceId == null ? const {} : {'templateId': sourceId},
                ),
                onEdit: (id) => context.goNamed(
                  SuperadminRoutes.devMealPlanEditName,
                  pathParameters: {'mealPlanId': id},
                ),
                onCreateTemplate: () =>
                    context.goNamed(SuperadminRoutes.devMealPlanModelCreateName),
                onEditTemplate: (id) => context.goNamed(
                  SuperadminRoutes.devMealPlanModelEditName,
                  pathParameters: {'mealPlanModelId': id},
                ),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devMealPlanCreate,
            name: SuperadminRoutes.devMealPlanCreateName,
            builder: (context, state) {
              final templatePlanId = state.uri.queryParameters['templateId'];
              return operationalPage(
                context,
                title: 'Novo cardápio',
                subtitle: 'Construa a estrutura do cardápio e publique por período.',
                destination: 'meal-plans',
                child: MealPlanWizardPage(
                  repository: developmentMealPlanRepository,
                  imageRepository: const UnavailableMealPlanImageRepository(),
                  tenantId: 'dev-tenant',
                  imageSelectionEnabled: false,
                  templatePlanId: templatePlanId,
                  onSaved: () => context.goNamed(SuperadminRoutes.devMealPlansName),
                  onCancel: () => context.goNamed(SuperadminRoutes.devMealPlansName),
                ),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devMealPlanEdit,
            name: SuperadminRoutes.devMealPlanEditName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Editar cardápio',
              subtitle: 'Ajuste herança, período, refeições e regras de revisão.',
              destination: 'meal-plans',
              child: MealPlanWizardPage(
                repository: developmentMealPlanRepository,
                imageRepository: const UnavailableMealPlanImageRepository(),
                tenantId: 'dev-tenant',
                imageSelectionEnabled: false,
                mealPlanId: state.pathParameters['mealPlanId']!,
                onSaved: () => context.goNamed(SuperadminRoutes.devMealPlansName),
                onCancel: () => context.goNamed(SuperadminRoutes.devMealPlansName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devMealPlanModelCreate,
            name: SuperadminRoutes.devMealPlanModelCreateName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Novo modelo de cardápio',
              subtitle: 'Crie uma base reutilizável para novos cardápios.',
              destination: 'meal-plans',
              child: MealPlanWizardPage(
                repository: developmentMealPlanRepository,
                imageRepository: const UnavailableMealPlanImageRepository(),
                tenantId: 'dev-tenant',
                imageSelectionEnabled: false,
                isTemplate: true,
                onSaved: () => context.goNamed(SuperadminRoutes.devMealPlansName),
                onCancel: () => context.goNamed(SuperadminRoutes.devMealPlansName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devMealPlanModelEdit,
            name: SuperadminRoutes.devMealPlanModelEditName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Editar modelo de cardápio',
              subtitle: 'Atualize a base reutilizável sem alterar cardápios existentes.',
              destination: 'meal-plans',
              child: MealPlanWizardPage(
                repository: developmentMealPlanRepository,
                imageRepository: const UnavailableMealPlanImageRepository(),
                tenantId: 'dev-tenant',
                imageSelectionEnabled: false,
                isTemplate: true,
                mealPlanModelId: state.pathParameters['mealPlanModelId']!,
                onSaved: () => context.goNamed(SuperadminRoutes.devMealPlansName),
                onCancel: () => context.goNamed(SuperadminRoutes.devMealPlansName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPlans,
            name: SuperadminRoutes.devPlansName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Planos',
              subtitle: 'Configure os planos disponíveis na plataforma.',
              destination: 'plans',
              child: PlanDirectoryPage(
                repository: planRepository,
                onCreate: () => context.goNamed(SuperadminRoutes.devPlanCreateName),
                onEdit: (id) => context.goNamed(
                  SuperadminRoutes.devPlanEditName,
                  pathParameters: {'planId': id},
                ),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPlanCreate,
            name: SuperadminRoutes.devPlanCreateName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Novo plano',
              subtitle: 'Cadastre um plano da plataforma.',
              destination: 'plans',
              child: PlanFormPage(
                repository: planRepository,
                onSaved: () => context.goNamed(SuperadminRoutes.devPlansName),
                onCancel: () => context.goNamed(SuperadminRoutes.devPlansName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPlanEdit,
            name: SuperadminRoutes.devPlanEditName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Editar plano',
              subtitle: 'Altere um plano da plataforma.',
              destination: 'plans',
              child: PlanFormPage(
                repository: planRepository,
                planId: state.pathParameters['planId'],
                onSaved: () => context.goNamed(SuperadminRoutes.devPlansName),
                onCancel: () => context.goNamed(SuperadminRoutes.devPlansName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.audit,
            name: SuperadminRoutes.auditName,
            builder: (context, state) => AuditDirectoryPage(
              controller: AuditDirectoryController(
                repository: auditRepository,
                query: AuditQuery(pageSize: 8),
              ),
              activityController: operationalActivities,
              logout: logout,
              openDownloadUrl: openDownloadUrl,
              onDestinationSelected: (value) => _navigateFromPersistentShell(context, value),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.imports,
            name: SuperadminRoutes.importsName,
            builder: (context, state) => ImportDirectoryPage(
              repository: importedRepository,
              onNewImport: (preset) =>
                  context.goNamed(SuperadminRoutes.importCreateName, extra: preset),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.importCreate,
            name: SuperadminRoutes.importCreateName,
            builder: (context, state) {
              if (!hasAuthoritativeMutationCapability()) {
                return blockedProductionMutationPage(context);
              }
              final preset = state.extra is ImportCreationPreset
                  ? state.extra as ImportCreationPreset
                  : ImportCreationPreset.institutions;
              return ImportWizardPage(
                controller: ImportWizardController(
                  repository: importedRepository,
                  initialEntity: preset.defaultEntity,
                  initialContext: preset.defaultContext,
                ),
                onFinished: () => context.goNamed(SuperadminRoutes.importsName),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devImports,
            name: SuperadminRoutes.devImportsName,
            builder: (context, state) => ImportDirectoryPage(
              repository: developmentImportRepository,
              onNewImport: (preset) =>
                  context.goNamed(SuperadminRoutes.devImportCreateName, extra: preset),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devImportCreate,
            name: SuperadminRoutes.devImportCreateName,
            builder: (context, state) {
              final preset = state.extra is ImportCreationPreset
                  ? state.extra as ImportCreationPreset
                  : ImportCreationPreset.institutions;
              return ImportWizardPage(
                controller: ImportWizardController(
                  repository: developmentImportRepository,
                  initialEntity: preset.defaultEntity,
                  initialContext: preset.defaultContext,
                ),
                onFinished: () => context.goNamed(SuperadminRoutes.devImportsName),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devForms,
            name: SuperadminRoutes.devFormsName,
            builder: (context, state) => FormsDirectoryPage(
              api: null,
              onOpen: (form) => context.goNamed(
                SuperadminRoutes.devFormOverviewName,
                pathParameters: {'formId': form.id},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormCreate,
            name: SuperadminRoutes.devFormCreateName,
            builder: (context, state) => const FormsEditorPage.development(),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormOverview,
            name: SuperadminRoutes.devFormOverviewName,
            builder: (context, state) =>
                FormsOverviewPage(api: null, formId: state.pathParameters['formId']!),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormEdit,
            name: SuperadminRoutes.devFormEditName,
            builder: (context, state) => const FormsEditorPage.development(),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormTest,
            name: SuperadminRoutes.devFormTestName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormMonitor,
            name: SuperadminRoutes.devFormMonitorName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormRespond,
            name: SuperadminRoutes.devFormRespondName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormResponses,
            name: SuperadminRoutes.devFormResponsesName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormResponseDetail,
            name: SuperadminRoutes.devFormResponseDetailName,
            builder: (context, state) => _unavailableFormsRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormFiles,
            name: SuperadminRoutes.devFormFilesName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.devFormMedia,
            name: SuperadminRoutes.devFormMediaName,
            builder: (context, state) => _unavailableCompositionRootRoute(context),
          ),
          GoRoute(
            path: SuperadminRoutes.invites,
            name: SuperadminRoutes.invitesName,
            builder: (context, state) => InviteDirectoryPage(
              repository: inviteRepository,
              logout: logout,
              onDestinationSelected: (value) => _navigateFromPersistentShell(context, value),
              onCreate: null,
              onOpen: (id) => context.goNamed(
                SuperadminRoutes.inviteDetailName,
                pathParameters: {'inviteId': id},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.inviteCreate,
            name: SuperadminRoutes.inviteCreateName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : InviteFormPage(
                    repository: inviteRepository,
                    logout: logout,
                    onDestinationSelected: (value) => _navigateFromPersistentShell(context, value),
                    onCancel: () => context.goNamed(SuperadminRoutes.invitesName),
                    onSent: (_) => context.goNamed(SuperadminRoutes.invitesName),
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.inviteDetail,
            name: SuperadminRoutes.inviteDetailName,
            builder: (context, state) => InviteDetailPage(
              repository: inviteRepository,
              inviteId: state.pathParameters['inviteId']!,
              logout: logout,
              onDestinationSelected: (value) => _navigateFromPersistentShell(context, value),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInvites,
            name: SuperadminRoutes.devInvitesName,
            builder: (context, state) => InviteDirectoryPage(
              repository: invitePreviewRepository(),
              allowCommands: true,
              logout: _previewLogout,
              onDestinationSelected: (value) => _navigateFromDevelopmentShell(context, value),
              onCreate: () => context.goNamed(SuperadminRoutes.devInviteCreateName),
              onOpen: (id) => context.goNamed(
                SuperadminRoutes.devInviteDetailName,
                pathParameters: {'inviteId': id},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInviteCreate,
            name: SuperadminRoutes.devInviteCreateName,
            builder: (context, state) => InviteFormPage(
              repository: invitePreviewRepository(),
              logout: _previewLogout,
              onDestinationSelected: (value) => _navigateFromDevelopmentShell(context, value),
              onCancel: () => context.goNamed(SuperadminRoutes.devInvitesName),
              onSent: (_) => context.goNamed(SuperadminRoutes.devInvitesName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInviteDetail,
            name: SuperadminRoutes.devInviteDetailName,
            builder: (context, state) => InviteDetailPage(
              repository: invitePreviewRepository(),
              inviteId: state.pathParameters['inviteId']!,
              allowCommands: true,
              logout: _previewLogout,
              onDestinationSelected: (value) => _navigateFromDevelopmentShell(context, value),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.notices,
            name: SuperadminRoutes.noticesName,
            builder: (context, state) => productionOperationalPage(
              context,
              title: 'Avisos',
              subtitle: 'Crie e acompanhe avisos oficiais da plataforma.',
              destination: 'notices',
              child: NoticeDirectoryPage(
                repository: noticeRepository,
                onCreate: null,
                onEdit: null,
                canManageLifecycle: false,
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.noticeCreate,
            name: SuperadminRoutes.noticeCreateName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : productionOperationalPage(
                    context,
                    title: 'Novo aviso',
                    subtitle: 'Revise a prévia e o público antes de publicar.',
                    destination: 'notices',
                    child: NoticeFormPage(
                      repository: noticeRepository,
                      onSaved: (_) => context.goNamed(SuperadminRoutes.noticesName),
                      onCancel: () => context.goNamed(SuperadminRoutes.noticesName),
                    ),
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.noticeEdit,
            name: SuperadminRoutes.noticeEditName,
            builder: (context, state) => !hasAuthoritativeMutationCapability()
                ? blockedProductionMutationPage(context)
                : productionOperationalPage(
                    context,
                    title: 'Editar aviso',
                    subtitle: 'Altere um aviso dentro do ciclo permitido.',
                    destination: 'notices',
                    child: NoticeFormPage(
                      repository: noticeRepository,
                      noticeId: state.pathParameters['noticeId'],
                      onSaved: (_) => context.goNamed(SuperadminRoutes.noticesName),
                      onCancel: () => context.goNamed(SuperadminRoutes.noticesName),
                    ),
                  ),
          ),
          GoRoute(
            path: SuperadminRoutes.devNotices,
            name: SuperadminRoutes.devNoticesName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Avisos',
              subtitle: 'Crie e acompanhe avisos oficiais da plataforma.',
              destination: 'notices',
              child: NoticeDirectoryPage(
                repository: developmentNoticeRepository,
                canManageLifecycle: true,
                enableInlinePreview: true,
                onCreate: () => context.goNamed(SuperadminRoutes.devNoticeCreateName),
                onEdit: (id) => context.goNamed(
                  SuperadminRoutes.devNoticeEditName,
                  pathParameters: {'noticeId': id},
                ),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devNoticeCreate,
            name: SuperadminRoutes.devNoticeCreateName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Novo aviso',
              subtitle: 'Revise a pr\u00e9via e o p\u00fablico antes de publicar.',
              destination: 'notices',
              child: NoticeFormPage(
                repository: developmentNoticeRepository,
                onSaved: (_) => context.goNamed(SuperadminRoutes.devNoticesName),
                onCancel: () => context.goNamed(SuperadminRoutes.devNoticesName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devNoticeEdit,
            name: SuperadminRoutes.devNoticeEditName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Editar aviso',
              subtitle: 'Altere um aviso dentro do ciclo permitido.',
              destination: 'notices',
              child: NoticeFormPage(
                repository: developmentNoticeRepository,
                noticeId: state.pathParameters['noticeId'],
                onSaved: (_) => context.goNamed(SuperadminRoutes.devNoticesName),
                onCancel: () => context.goNamed(SuperadminRoutes.devNoticesName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAudit,
            name: SuperadminRoutes.devAuditName,
            builder: (context, state) => AuditDirectoryPage(
              controller: AuditDirectoryController(
                repository: const UnavailableAuditRepository(),
                query: AuditQuery(pageSize: 8),
              ),
              activityController: operationalActivities,
              logout: _previewLogout,
              openDownloadUrl: openDownloadUrl,
              onDestinationSelected: (value) => _navigateFromDevelopmentShell(context, value),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devCatalog,
            name: SuperadminRoutes.devCatalogName,
            builder: (context, state) => CatalogHostPage(
              catalogUrl: catalogUrl,
              localPreview: true,
              logout: _previewLogout,
              onHomeOpen: () => context.goNamed(SuperadminRoutes.devHomeName),
              onInstitutionsOpen: () => context.goNamed(SuperadminRoutes.devInstitutionsName),
              onUnitsOpen: () => context.goNamed(SuperadminRoutes.devUnitsName),
              onSupportOpen: () => context.goNamed(SuperadminRoutes.devSupportName),
              onBugReportSubmitted: developmentSupportController.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.devConversationsName,
                queryParameters: const {'from': 'catalog'},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devSupport,
            name: SuperadminRoutes.devSupportName,
            builder: (context, state) => SupportPage(
              controller: developmentSupportController,
              logout: _previewLogout,
              onHomeOpen: () => context.goNamed(SuperadminRoutes.devHomeName),
              onInstitutionsOpen: () => context.goNamed(SuperadminRoutes.devInstitutionsName),
              onUnitsOpen: () => context.goNamed(SuperadminRoutes.devUnitsName),
              onCatalogOpen: () => context.goNamed(SuperadminRoutes.devCatalogName),
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.devConversationsName,
                queryParameters: const {'from': 'support'},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devConversations,
            name: SuperadminRoutes.devConversationsName,
            builder: (context, state) => SuperadminChatPage(
              logout: _previewLogout,
              onBack: () => context.goNamed(
                state.uri.queryParameters['from'] == 'home'
                    ? SuperadminRoutes.devHomeName
                    : SuperadminRoutes.devInstitutionsName,
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPrincipalHappens,
            name: SuperadminRoutes.devPrincipalHappensName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Acontece',
              subtitle: 'Prévia da experiência do app Principal.',
              destination: 'principal-happens',
              child: PrincipalHappensPreviewPage.demo(
                embedded: true,
                onOpenForYou: () => context.goNamed(SuperadminRoutes.devPrincipalForYouName),
                onOpenMoments: () => context.pushNamed(SuperadminRoutes.devPrincipalMomentsName),
                onOpenProfile: () => context.goNamed(SuperadminRoutes.devPrincipalProfileName),
                onOpenAgenda: () => context.goNamed(SuperadminRoutes.devAgendaName),
                onOpenNow: () => context.pushNamed(SuperadminRoutes.devPrincipalNowName),
                onCreatePost: () =>
                    context.goNamed(SuperadminRoutes.devPrincipalHappensPublishName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPrincipalForYou,
            name: SuperadminRoutes.devPrincipalForYouName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Para você',
              subtitle: 'Prévia da experiência do app Principal.',
              destination: 'principal-for-you',
              child: PrincipalForYouPreviewPage(
                embedded: true,
                onOpenHappens: () => context.goNamed(SuperadminRoutes.devPrincipalHappensName),
                onOpenNow: () => context.goNamed(SuperadminRoutes.devPrincipalNowName),
                onOpenMoments: () => context.goNamed(SuperadminRoutes.devPrincipalMomentsName),
                onOpenAgenda: () => context.goNamed(SuperadminRoutes.devAgendaName),
                onOpenProfile: () => context.goNamed(SuperadminRoutes.devPrincipalProfileName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPrincipalHappensPublish,
            name: SuperadminRoutes.devPrincipalHappensPublishName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Publicar no Acontece',
              subtitle: 'Prepare o conteúdo e revise o público antes de publicar.',
              destination: 'principal-happens-publish',
              child: PrincipalHappensPublicationPage(
                embedded: true,
                repository: InMemoryHappensPublicationRepository(),
                onClose: () => context.goNamed(SuperadminRoutes.devPrincipalHappensName),
                onCompleted: (_) => context.goNamed(SuperadminRoutes.devPrincipalHappensName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPrincipalMoments,
            name: SuperadminRoutes.devPrincipalMomentsName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Momentos',
              subtitle: 'Prévia da experiência do app Principal.',
              destination: 'principal-moments',
              child: PrincipalMomentsPreviewPage(
                embedded: true,
                onOpenHappens: () => _closePrincipalViewer(context),
                onOpenProfile: () => context.goNamed(SuperadminRoutes.devPrincipalProfileName),
                onCreateMoment: () =>
                    context.goNamed(SuperadminRoutes.devPrincipalMomentsPublishName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPrincipalMomentsPublish,
            name: SuperadminRoutes.devPrincipalMomentsPublishName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Publicar momento',
              subtitle: 'Prepare a mídia e revise o público antes de publicar.',
              destination: 'principal-moments-publish',
              child: PrincipalMomentsPublicationPage(
                onClose: () => context.goNamed(SuperadminRoutes.devPrincipalMomentsName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPrincipalNow,
            name: SuperadminRoutes.devPrincipalNowName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Agora',
              subtitle: 'Prévia da experiência do app Principal.',
              destination: 'principal-now',
              child: PrincipalNowPreviewPage(
                onClose: () => _closePrincipalViewer(context),
                onOpenHappens: () => _closePrincipalViewer(context),
                onCreate: () => context.goNamed(SuperadminRoutes.devPrincipalNowPublicationName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPrincipalNowPublication,
            name: SuperadminRoutes.devPrincipalNowPublicationName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Publicar no Agora',
              subtitle: 'Prepare a sequência e revise o público antes de publicar.',
              destination: 'principal-now-publish',
              child: PrincipalNowPublicationPage(
                embedded: true,
                repository: InMemoryNowPublicationRepository(),
                onClose: () => context.goNamed(SuperadminRoutes.devPrincipalHappensName),
                onCompleted: (_) => context.goNamed(SuperadminRoutes.devPrincipalHappensName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPrincipalProfile,
            name: SuperadminRoutes.devPrincipalProfileName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Perfil',
              subtitle: 'Prévia da experiência do app Principal.',
              destination: 'principal-profile',
              child: PrincipalProfilePreviewPage(
                embedded: true,
                onOpenAgenda: () => context.goNamed(SuperadminRoutes.devAgendaName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devProfile,
            name: SuperadminRoutes.devProfileName,
            builder: (context, state) => ProfilePage(
              controller: developmentAccountController,
              logout: _previewLogout,
              onDestinationSelected: (destination) =>
                  _navigateFromAccount(context, destination, developmentPreview: true),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devSettings,
            name: SuperadminRoutes.devSettingsName,
            builder: (context, state) => SettingsPage(
              controller: developmentPreferencesController,
              logout: _previewLogout,
              onDestinationSelected: (destination) =>
                  _navigateFromAccount(context, destination, developmentPreview: true),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAgenda,
            name: SuperadminRoutes.devAgendaName,
            builder: (context, state) => AgendaCalendarPage(
              store: agendaPrototypeStore,
              logout: _previewLogout,
              onAreaSelected: (area) => openAgendaArea(context, area),
              onCreateItem: () => context.goNamed(SuperadminRoutes.devAgendaEventCreateName),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAgendaEvents,
            name: SuperadminRoutes.devAgendaEventsName,
            builder: (context, state) => agendaAreaShell(
              context,
              AgendaModuleArea.events,
              AgendaEventsPage(
                store: agendaPrototypeStore,
                onCreate: () => context.goNamed(SuperadminRoutes.devAgendaEventCreateName),
                onOpen: (id) => context.goNamed(
                  SuperadminRoutes.devAgendaEventDetailName,
                  pathParameters: {'eventId': id},
                ),
                onEdit: (id) => context.goNamed(
                  SuperadminRoutes.devAgendaEventEditName,
                  pathParameters: {'eventId': id},
                ),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAgendaEventCreate,
            name: SuperadminRoutes.devAgendaEventCreateName,
            builder: (context, state) => agendaAreaShell(
              context,
              AgendaModuleArea.events,
              AgendaEventFormPage(
                store: agendaPrototypeStore,
                onCancel: () => context.goNamed(SuperadminRoutes.devAgendaEventsName),
                onSaved: (id) => context.goNamed(
                  SuperadminRoutes.devAgendaEventDetailName,
                  pathParameters: {'eventId': id},
                ),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAgendaEventEdit,
            name: SuperadminRoutes.devAgendaEventEditName,
            builder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return agendaAreaShell(
                context,
                AgendaModuleArea.events,
                AgendaEventFormPage(
                  store: agendaPrototypeStore,
                  eventId: eventId,
                  onCancel: () => context.goNamed(
                    SuperadminRoutes.devAgendaEventDetailName,
                    pathParameters: {'eventId': eventId},
                  ),
                  onSaved: (id) => context.goNamed(
                    SuperadminRoutes.devAgendaEventDetailName,
                    pathParameters: {'eventId': id},
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devAgendaEventDetail,
            name: SuperadminRoutes.devAgendaEventDetailName,
            builder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return agendaAreaShell(
                context,
                AgendaModuleArea.events,
                AgendaEventDetailPage(
                  store: agendaPrototypeStore,
                  eventId: eventId,
                  onBack: () => context.goNamed(SuperadminRoutes.devAgendaEventsName),
                  onEdit: () => context.goNamed(
                    SuperadminRoutes.devAgendaEventEditName,
                    pathParameters: {'eventId': eventId},
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devAgendaRequests,
            name: SuperadminRoutes.devAgendaRequestsName,
            builder: (context, state) => agendaAreaShell(
              context,
              AgendaModuleArea.requests,
              AgendaRequestsPage(store: agendaPrototypeStore),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAgendaPermissions,
            name: SuperadminRoutes.devAgendaPermissionsName,
            builder: (context, state) => agendaAreaShell(
              context,
              AgendaModuleArea.permissions,
              AgendaPermissionsPage(store: agendaPrototypeStore),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devError,
            name: SuperadminRoutes.devErrorName,
            builder: (context, state) {
              final kind = SuperadminErrorKind.fromCode(state.pathParameters['code']);
              return SuperadminErrorScreen(
                kind: kind,
                onAction: switch (kind) {
                  SuperadminErrorKind.forbidden || SuperadminErrorKind.notFound =>
                    () => context.goNamed(SuperadminRoutes.devHomeName),
                  SuperadminErrorKind.internal || SuperadminErrorKind.unavailable => () {},
                },
              );
            },
          ),
        ],
      ),
    ],
  );
}

void _navigateFromAccount(
  BuildContext context,
  String destination, {
  bool developmentPreview = false,
}) {
  if (developmentPreview) {
    switch (destination) {
      case 'home':
        context.goNamed(SuperadminRoutes.devHomeName);
      case 'institutions':
        context.goNamed(SuperadminRoutes.devInstitutionsName);
      case 'units':
        context.goNamed(SuperadminRoutes.devUnitsName);
      case 'groups':
        context.goNamed(SuperadminRoutes.devGroupsName);
      case 'activities':
        context.goNamed(SuperadminRoutes.devActivitiesName);
      case 'people':
        context.goNamed(SuperadminRoutes.devPeopleName);
      case 'support':
        context.goNamed(SuperadminRoutes.devSupportName);
      case 'conversations':
        context.goNamed(
          SuperadminRoutes.devConversationsName,
          queryParameters: const {'from': 'profile'},
        );
      case 'profile':
        context.goNamed(SuperadminRoutes.devProfileName);
      case 'settings':
        context.goNamed(SuperadminRoutes.devSettingsName);
    }
    return;
  }
  switch (destination) {
    case 'home':
      context.goNamed(SuperadminRoutes.homeName);
    case 'institutions':
      context.goNamed(SuperadminRoutes.institutionsName);
    case 'units':
      context.goNamed(SuperadminRoutes.unitsName);
    case 'groups':
      context.goNamed(SuperadminRoutes.groupsName);
    case 'activities':
      context.goNamed(SuperadminRoutes.activitiesName);
    case 'assessment-entry':
      context.goNamed(SuperadminRoutes.assessmentEntryName);
    case 'assessment-closing':
      context.goNamed(SuperadminRoutes.assessmentClosingName);
    case 'assessments':
      context.goNamed(SuperadminRoutes.assessmentEntryName);
    case 'attendance':
      context.goNamed(SuperadminRoutes.attendanceName);
    case 'daily-routine':
      context.goNamed(SuperadminRoutes.dailyRoutineName);
    case 'students':
      context.goNamed(SuperadminRoutes.studentsName);
    case 'people':
      context.goNamed(SuperadminRoutes.peopleName);
    case 'safety':
      context.goNamed(SuperadminRoutes.safetyName);
    case 'profiles':
    case 'profile-create':
      context.goNamed(SuperadminRoutes.profilesName);
    case 'profile-models':
    case 'profile-model-create':
      context.goNamed(SuperadminRoutes.profileModelsName);
    case 'health-care-profiles':
      context.goNamed(SuperadminRoutes.healthCareProfilesName);
    case 'health-medication-plans':
      context.goNamed(SuperadminRoutes.healthMedicationPlansName);
    case 'forms':
      context.goNamed(SuperadminRoutes.formsName);
    case 'imports':
      context.goNamed(SuperadminRoutes.importsName);
    case 'invites':
      context.goNamed(SuperadminRoutes.invitesName);
    case 'notices':
      context.goNamed(SuperadminRoutes.noticesName);
    case 'audit':
      context.goNamed(SuperadminRoutes.auditName);
    case 'catalog':
      context.goNamed(SuperadminRoutes.governanceCatalogName);
    case 'support':
      context.goNamed(SuperadminRoutes.supportName);
    case 'conversations':
      context.goNamed(
        SuperadminRoutes.conversationsName,
        queryParameters: const {'from': 'profile'},
      );
    case 'profile':
      context.goNamed(SuperadminRoutes.profileName);
    case 'settings':
      context.goNamed(SuperadminRoutes.settingsName);
    case 'institution-create':
      context.goNamed(SuperadminRoutes.institutionCreateName);
    case 'unit-create':
      context.goNamed(SuperadminRoutes.unitCreateName);
    case 'group-create':
      context.goNamed(SuperadminRoutes.groupCreateName);
    case 'activity-create':
      context.goNamed(SuperadminRoutes.activityCreateName);
    case 'attendance-create':
      context.goNamed(SuperadminRoutes.attendanceCreateName);
    case 'daily-routine-create':
      context.goNamed(SuperadminRoutes.dailyRoutineCreateName);
    case 'health-care-profile-create':
      context.goNamed(SuperadminRoutes.healthCareProfileCreateName);
    case 'health-medication-plan-create':
      context.goNamed(SuperadminRoutes.healthMedicationPlanCreateName);
    case 'person-create':
      context.goNamed(SuperadminRoutes.personCreateName);
    case 'safety-create':
      context.goNamed(SuperadminRoutes.safetyCreateName);
    case 'form-create':
      context.goNamed(SuperadminRoutes.formCreateName);
    case 'import-create':
      context.goNamed(SuperadminRoutes.importCreateName);
    case 'invite-create':
      context.goNamed(SuperadminRoutes.inviteCreateName);
    case 'notice-create':
      context.goNamed(SuperadminRoutes.noticeCreateName);
  }
}

bool _usesPersistentShell(String location) {
  return location != SuperadminRoutes.login &&
      location != SuperadminRoutes.forgotPassword &&
      location != SuperadminRoutes.resetPassword &&
      location != SuperadminRoutes.devLogin &&
      location != SuperadminRoutes.devForgotPassword &&
      location != SuperadminRoutes.devResetPassword &&
      !location.startsWith('/dev/errors/');
}

bool _isProductionMutationLocation(String location) {
  if (location.startsWith('/dev/')) return false;
  if (location.endsWith('/new') ||
      location.contains('/new/') ||
      location.endsWith('/edit') ||
      location.endsWith('/duplicate') ||
      location.endsWith('/assessment-settings')) {
    return true;
  }
  return location.startsWith('/attendance/calls/') ||
      location == '/assessments/entry' ||
      location == '/assessments/closing' ||
      location.startsWith('/assessments/closing/') ||
      location.endsWith('/manage') ||
      location.contains('/occurrences/') && location.endsWith('/respond');
}

void _closePrincipalViewer(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.goNamed(SuperadminRoutes.devPrincipalHappensName);
}

String _destinationForLocation(String location) {
  if (location.startsWith('/dev/')) {
    return _destinationForLocation(location.substring('/dev'.length));
  }
  if (location.startsWith('/institutions/new')) {
    return 'institution-create';
  }
  if (location.startsWith('/institutions')) {
    return 'institutions';
  }
  if (location.startsWith('/units/new')) {
    return 'unit-create';
  }
  if (location.startsWith('/units')) {
    return 'units';
  }
  if (location.startsWith('/groups/new')) {
    return 'group-create';
  }
  if (location.startsWith('/groups')) {
    return 'groups';
  }
  if (location.startsWith('/activities/new')) {
    return 'activity-create';
  }
  if (location.startsWith('/activities')) {
    return 'activities';
  }
  if (location.startsWith('/assessments/closing')) {
    return 'assessment-closing';
  }
  if (location.startsWith('/assessments')) {
    return 'assessment-entry';
  }
  if (location.startsWith('/attendance/new')) {
    return 'attendance-create';
  }
  if (location.startsWith('/attendance')) {
    return 'attendance';
  }
  if (location.startsWith('/students')) {
    return 'students';
  }
  if (location.startsWith('/daily-routine/new')) {
    return 'daily-routine-create';
  }
  if (location.startsWith('/daily-routine')) {
    return 'daily-routine';
  }
  if (location.startsWith('/forms/new')) {
    return 'form-create';
  }
  if (location.startsWith('/forms')) {
    return 'forms';
  }
  if (location.startsWith('/health-care/medication-plans/new')) {
    return 'health-medication-plan-create';
  }
  if (location.startsWith('/health-care/medication-plans')) {
    return 'health-medication-plans';
  }
  if (location.startsWith('/health-care/profiles/new')) {
    return 'health-care-profile-create';
  }
  if (location.startsWith('/health-care/profiles')) {
    return 'health-care-profiles';
  }
  if (location.startsWith('/people/new')) {
    return 'person-create';
  }
  if (location.startsWith('/people')) {
    return 'people';
  }
  if (location.startsWith('/safety/new')) {
    return 'safety-create';
  }
  if (location.startsWith('/safety')) {
    return 'safety';
  }
  if (location.startsWith('/profile-models/new')) {
    return 'profile-models';
  }
  if (location.startsWith('/profile-models')) {
    return 'profile-models';
  }
  if (location.startsWith('/profiles/new')) {
    return 'profiles';
  }
  if (location.startsWith('/profiles')) {
    return 'profiles';
  }
  if (location.startsWith('/internal-users')) {
    return 'internal-users';
  }
  if (location.startsWith('/plans/new')) {
    return 'plan-create';
  }
  if (location.startsWith('/plans')) {
    return 'plans';
  }
  if (location.startsWith('/meal-plans/models/new')) {
    return 'meal-plan-model-create';
  }
  if (location.startsWith('/meal-plans/new')) {
    return 'meal-plan-create';
  }
  if (location.startsWith('/meal-plans')) {
    return 'meal-plans';
  }
  if (location.startsWith('/imports/new')) {
    return 'import-create';
  }
  if (location.startsWith('/imports')) {
    return 'import';
  }
  if (location.startsWith('/invites/new')) {
    return 'invite-create';
  }
  if (location.startsWith('/invites')) {
    return 'invites';
  }
  if (location.startsWith('/notices/new')) {
    return 'notice-create';
  }
  if (location.startsWith('/notices')) {
    return 'notices';
  }
  if (location.startsWith('/audit')) {
    return 'audit';
  }
  if (location.startsWith('/agenda/events/new')) {
    return 'event-create';
  }
  if (location.startsWith('/agenda/events')) {
    return 'events';
  }
  if (location.startsWith('/agenda/requests')) {
    return 'requests';
  }
  if (location.startsWith('/agenda/permissions')) {
    return 'permissions';
  }
  if (location.startsWith('/agenda')) {
    return 'agenda';
  }
  if (location.startsWith('/principal-happens/publish')) {
    return 'principal-happens-publish';
  }
  if (location.startsWith('/principal-happens')) {
    return 'principal-happens';
  }
  if (location.startsWith('/principal-for-you')) {
    return 'principal-for-you';
  }
  if (location.startsWith('/principal-moments/publish')) {
    return 'principal-moments-publish';
  }
  if (location.startsWith('/principal-moments')) {
    return 'principal-moments';
  }
  if (location.startsWith('/principal-now/publication')) {
    return 'principal-now-publish';
  }
  if (location.startsWith('/principal-now')) {
    return 'principal-now';
  }
  if (location.startsWith('/principal-profile')) {
    return 'principal-profile';
  }
  return switch (location) {
    SuperadminRoutes.home || '/home' => 'home',
    SuperadminRoutes.governanceCatalog || '/catalog' => 'catalog',
    SuperadminRoutes.support => 'support',
    SuperadminRoutes.conversations || '/conversations' => 'conversations',
    SuperadminRoutes.profile => 'profile',
    SuperadminRoutes.settings => 'settings',
    _ => 'home',
  };
}

void _navigateFromPersistentShell(BuildContext context, String destination) {
  switch (destination) {
    case 'home':
      context.goNamed(SuperadminRoutes.homeName);
    case 'institutions':
      context.goNamed(SuperadminRoutes.institutionsName);
    case 'units':
      context.goNamed(SuperadminRoutes.unitsName);
    case 'groups':
      context.goNamed(SuperadminRoutes.groupsName);
    case 'activities':
      context.goNamed(SuperadminRoutes.activitiesName);
    case 'assessment-entry':
      context.goNamed(SuperadminRoutes.assessmentEntryName);
    case 'assessment-closing':
      context.goNamed(SuperadminRoutes.assessmentClosingName);
    case 'attendance':
      context.goNamed(SuperadminRoutes.attendanceName);
    case 'students':
      context.goNamed(SuperadminRoutes.studentsName);
    case 'daily-routine':
      context.goNamed(SuperadminRoutes.dailyRoutineName);
    case 'forms':
      context.goNamed(SuperadminRoutes.formsName);
    case 'health-care-profiles':
      context.goNamed(SuperadminRoutes.healthCareProfilesName);
    case 'health-medication-plans':
      context.goNamed(SuperadminRoutes.healthMedicationPlansName);
    case 'people':
      context.goNamed(SuperadminRoutes.peopleName);
    case 'safety':
      context.goNamed(SuperadminRoutes.safetyName);
    case 'profiles':
      context.goNamed(SuperadminRoutes.profilesName);
    case 'profile-create':
      context.goNamed(SuperadminRoutes.profilesName);
    case 'profile-models':
      context.goNamed(SuperadminRoutes.profileModelsName);
    case 'profile-model-create':
      context.goNamed(SuperadminRoutes.profileModelsName);
    case 'catalog':
      context.goNamed(SuperadminRoutes.governanceCatalogName);
    case 'support':
      context.goNamed(SuperadminRoutes.supportName);
    case 'import':
      context.goNamed(SuperadminRoutes.importsName);
    case 'invites':
      context.goNamed(SuperadminRoutes.invitesName);
    case 'notices':
      context.goNamed(SuperadminRoutes.noticesName);
    case 'audit':
      context.goNamed(SuperadminRoutes.auditName);
    case 'conversations':
      context.goNamed(SuperadminRoutes.conversationsName);
    case 'profile':
      context.goNamed(SuperadminRoutes.profileName);
    case 'settings':
      context.goNamed(SuperadminRoutes.settingsName);
    case 'institution-create':
      context.goNamed(SuperadminRoutes.institutionCreateName);
    case 'unit-create':
      context.goNamed(SuperadminRoutes.unitCreateName);
    case 'group-create':
      context.goNamed(SuperadminRoutes.groupCreateName);
    case 'activity-create':
      context.goNamed(SuperadminRoutes.activityCreateName);
    case 'attendance-create':
      context.goNamed(SuperadminRoutes.attendanceCreateName);
    case 'daily-routine-create':
      context.goNamed(SuperadminRoutes.dailyRoutineCreateName);
    case 'person-create':
      context.goNamed(SuperadminRoutes.personCreateName);
    case 'safety-create':
      context.goNamed(SuperadminRoutes.safetyCreateName);
    case 'health-care-profile-create':
      context.goNamed(SuperadminRoutes.healthCareProfileCreateName);
    case 'health-medication-plan-create':
      context.goNamed(SuperadminRoutes.healthMedicationPlanCreateName);
    case 'form-create':
      context.goNamed(SuperadminRoutes.formCreateName);
    case 'import-create':
      context.goNamed(SuperadminRoutes.importCreateName);
    case 'invite-create':
      context.goNamed(SuperadminRoutes.inviteCreateName);
    case 'notice-create':
      context.goNamed(SuperadminRoutes.noticeCreateName);
  }
}

void _navigateFromDevelopmentShell(BuildContext context, String destination) {
  switch (destination) {
    case 'home':
      context.goNamed(SuperadminRoutes.devHomeName);
    case 'institutions':
      context.goNamed(SuperadminRoutes.devInstitutionsName);
    case 'units':
      context.goNamed(SuperadminRoutes.devUnitsName);
    case 'groups':
      context.goNamed(SuperadminRoutes.devGroupsName);
    case 'activities':
      context.goNamed(SuperadminRoutes.devActivitiesName);
    case 'assessment-entry':
      context.goNamed(SuperadminRoutes.devAssessmentEntryName);
    case 'assessment-closing':
      context.goNamed(SuperadminRoutes.devAssessmentClosingName);
    case 'attendance':
      context.goNamed(SuperadminRoutes.devAttendanceName);
    case 'daily-routine':
      context.goNamed(SuperadminRoutes.devDailyRoutineName);
    case 'students':
      context.goNamed(SuperadminRoutes.devStudentsName);
    case 'forms':
      context.goNamed(SuperadminRoutes.devFormsName);
    case 'health-care-profiles':
      context.goNamed(SuperadminRoutes.devHealthCareProfilesName);
    case 'health-medication-plans':
      context.goNamed(SuperadminRoutes.devHealthMedicationPlansName);
    case 'people':
      context.goNamed(SuperadminRoutes.devPeopleName);
    case 'safety':
      context.goNamed(SuperadminRoutes.devSafetyName);
    case 'profiles':
      context.goNamed(SuperadminRoutes.profilesName);
    case 'profile-models':
      context.goNamed(SuperadminRoutes.profileModelsName);
    case 'plans':
      context.goNamed(SuperadminRoutes.devPlansName);
    case 'agenda':
      context.goNamed(SuperadminRoutes.devAgendaName);
    case 'import':
      context.goNamed(SuperadminRoutes.devImportsName);
    case 'invites':
      context.goNamed(SuperadminRoutes.devInvitesName);
    case 'notices':
      context.goNamed(SuperadminRoutes.devNoticesName);
    case 'audit':
      context.goNamed(SuperadminRoutes.devAuditName);
    case 'catalog':
      context.goNamed(SuperadminRoutes.devCatalogName);
    case 'internal-users':
      context.goNamed(SuperadminRoutes.devInternalUsersName);
    case 'internal-user-create':
      context.goNamed(SuperadminRoutes.devInternalUserCreateName);
    case 'support':
      context.goNamed(SuperadminRoutes.devSupportName);
    case 'conversations':
      context.goNamed(SuperadminRoutes.devConversationsName);
    case 'profile':
      context.goNamed(SuperadminRoutes.devProfileName);
    case 'settings':
      context.goNamed(SuperadminRoutes.devSettingsName);
    case 'institution-create':
      context.goNamed(SuperadminRoutes.devInstitutionCreateName);
    case 'unit-create':
      context.goNamed(SuperadminRoutes.devUnitCreateName);
    case 'group-create':
      context.goNamed(SuperadminRoutes.devGroupCreateName);
    case 'activity-create':
      context.goNamed(SuperadminRoutes.devActivityCreateName);
    case 'attendance-create':
      context.goNamed(SuperadminRoutes.devAttendanceCreateName);
    case 'daily-routine-create':
      context.goNamed(SuperadminRoutes.devDailyRoutineCreateName);
    case 'health-care-profile-create':
      context.goNamed(SuperadminRoutes.devHealthCareProfileCreateName);
    case 'health-medication-plan-create':
      context.goNamed(SuperadminRoutes.devHealthMedicationPlanCreateName);
    case 'person-create':
      context.goNamed(SuperadminRoutes.devPersonCreateName);
    case 'safety-create':
      context.goNamed(SuperadminRoutes.devSafetyCreateName);
    case 'form-create':
      context.goNamed(SuperadminRoutes.devFormCreateName);
    case 'import-create':
      context.goNamed(SuperadminRoutes.devImportCreateName);
    case 'invite-create':
      context.goNamed(SuperadminRoutes.devInviteCreateName);
    case 'notice-create':
      context.goNamed(SuperadminRoutes.devNoticeCreateName);
    case 'plan-create':
      context.goNamed(SuperadminRoutes.devPlanCreateName);
    case 'profile-create':
      context.goNamed(SuperadminRoutes.profilesName);
    case 'profile-model-create':
      context.goNamed(SuperadminRoutes.profileModelsName);
    case 'meal-plans':
      context.goNamed(SuperadminRoutes.devMealPlansName);
    case 'meal-plan-create':
      context.goNamed(SuperadminRoutes.devMealPlanCreateName);
    case 'meal-plan-model-create':
      context.goNamed(SuperadminRoutes.devMealPlanModelCreateName);
    case 'events':
      context.goNamed(SuperadminRoutes.devAgendaEventsName);
    case 'event-create':
      context.goNamed(SuperadminRoutes.devAgendaEventCreateName);
    case 'requests':
      context.goNamed(SuperadminRoutes.devAgendaRequestsName);
    case 'permissions':
      context.goNamed(SuperadminRoutes.devAgendaPermissionsName);
    case 'principal-happens':
      context.goNamed(SuperadminRoutes.devPrincipalHappensName);
    case 'principal-happens-publish':
      context.goNamed(SuperadminRoutes.devPrincipalHappensPublishName);
    case 'principal-for-you':
      context.goNamed(SuperadminRoutes.devPrincipalForYouName);
    case 'principal-moments':
      context.goNamed(SuperadminRoutes.devPrincipalMomentsName);
    case 'principal-moments-publish':
      context.goNamed(SuperadminRoutes.devPrincipalMomentsPublishName);
    case 'principal-now':
      context.goNamed(SuperadminRoutes.devPrincipalNowName);
    case 'principal-now-publish':
      context.goNamed(SuperadminRoutes.devPrincipalNowPublicationName);
    case 'principal-profile':
      context.goNamed(SuperadminRoutes.devPrincipalProfileName);
  }
}

RoutineEntryKind _routineEntryKind(String? value) {
  for (final kind in RoutineEntryKind.values) {
    if (kind.name == value) return kind;
  }
  return RoutineEntryKind.model;
}

Widget _unavailableMedicationPlans(BuildContext context) => SuperadminErrorScreen(
  kind: SuperadminErrorKind.unavailable,
  onAction: () => context.goNamed(SuperadminRoutes.homeName),
);

Widget _unavailableFormsRoute(BuildContext context) => _unavailableCompositionRootRoute(context);

Widget _unavailableCompositionRootRoute(BuildContext context) => SuperadminErrorScreen(
  kind: SuperadminErrorKind.unavailable,
  onAction: () => context.goNamed(SuperadminRoutes.homeName),
);

Future<LogoutResult> _previewLogout() async => const LogoutResult.success();

ActivitySaveCommand _activitySaveCommand(
  ActivityFormDraft draft, {
  required ActivityCommandIntent intent,
  required String? activityId,
}) => ActivitySaveCommand(
  requestId: _activityRequestId(),
  intent: intent,
  activityId: activityId,
  templateId: activityId == null ? draft.template?.id : null,
  expectedVersion: draft.expectedManagementVersion,
  pedagogicalConfiguration: draft.pedagogicalConfiguration.toJson(),
  expectedAssessmentVersion: draft.pedagogicalConfiguration.expectedVersion,
  assessmentChangeJustification: draft.pedagogicalConfiguration.changeJustification,
  name: draft.name,
  description: draft.description,
  handleStem: draft.handleStem,
  taxonomyId:
      draft.subtype?.id ??
      draft.taxonomy?.id ??
      (throw const ActivityCommandUnavailableException()),
  taxonomyOtherDescription: draft.taxonomy?.isOther == true ? draft.taxonomyOtherDescription : '',
  governance: draft.governance,
  institutionId: draft.institutionId,
  unitIds: draft.unitIds,
  groupIds: draft.groupIds,
  participants: draft.studentSelections
      .map(
        (selection) => ActivityCommandParticipant(
          groupId: selection.groupId,
          childGroupLinkId: selection.childGroupLinkId,
          belongs: selection.belongs,
        ),
      )
      .toList(growable: false),
  assignments: draft.assignments
      .map(
        (assignment) => ActivityCommandAssignment(
          groupId: assignment.groupId,
          membershipId: assignment.professionalId,
          role: ActivityCommandProfessionalRole.values.byName(assignment.role.name),
          permissions: {
            'happens': _commandAccess(assignment.permissions.happens),
            'now': _commandAccess(assignment.permissions.now),
            'moments': _commandAccess(assignment.permissions.moments),
            'chat': _commandAccess(assignment.permissions.chat),
            'attendance': _commandAccess(assignment.permissions.attendance),
          },
        ),
      )
      .toList(growable: false),
  identity: ActivityCommandIdentity(
    kind: draft.imageBytes != null
        ? ActivityIdentityKind.image
        : draft.identityInitials.trim().isNotEmpty
        ? ActivityIdentityKind.initials
        : ActivityIdentityKind.icon,
    initials: draft.identityInitials,
    color: draft.identityColor,
    icon: draft.identityIcon.name,
    preserveExisting:
        activityId != null && draft.identityStorageRef != null && draft.imageBytes == null,
    imageName: draft.imageName,
    imageBytes: draft.imageBytes,
  ),
);

ActivityProfessionalAccessLevel _commandAccess(ActivityProfessionalAccess access) =>
    ActivityProfessionalAccessLevel.values.byName(access.name);

String _activityRequestId() {
  final random = math.Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20),
  ].join('-');
}
