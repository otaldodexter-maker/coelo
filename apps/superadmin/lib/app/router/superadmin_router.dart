import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/guards/superadmin_session.dart';
import '../../core/config/superadmin_app_config.dart';
import '../../core/platform/open_download.dart';
import '../activity/superadmin_activity.dart';
import '../prototype/superadmin_prototype_store.dart';
import '../../features/activities/data/supabase_activity_command_repository.dart';
import '../../features/activities/data/supabase_activity_directory_repository.dart';
import '../../features/activities/domain/activity_command.dart';
import '../../features/activities/domain/activity_directory.dart';
import '../../features/activities/presentation/activity_detail_page.dart';
import '../../features/activities/presentation/activity_directory_page.dart';
import '../../features/activities/presentation/activity_form_page.dart';
import '../../features/activities/presentation/activity_form_draft.dart';
import '../../features/account/data/account_profile_repository.dart';
import '../../features/account/data/user_preferences_repository.dart';
import '../../features/account/presentation/account_controller.dart';
import '../../features/account/presentation/screens/profile_page.dart';
import '../../features/account/presentation/screens/settings_page.dart';
import '../../features/account/presentation/user_preferences_controller.dart';
import '../../features/imports/domain/import_job.dart';
import '../../features/access_profiles/data/supabase_access_profile_repository.dart';
import '../../features/access_profiles/data/unavailable_access_profile_extended_repository.dart';
import '../../features/access_profiles/domain/access_profile.dart';
import '../../features/access_profiles/presentation/access_profile_detail_page.dart';
import '../../features/access_profiles/presentation/access_profile_model_detail_page.dart';
import '../../features/access_profiles/presentation/access_profile_model_directory_page.dart';
import '../../features/access_profiles/presentation/access_profile_model_form_page.dart';
import '../../features/support/domain/support_ticket.dart';
import '../../features/access_profiles/presentation/access_profile_directory_page.dart';
import '../../features/access_profiles/presentation/access_profile_form_page.dart';
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
import '../../features/groups/data/fake_group_directory_repository.dart';
import '../../features/groups/data/supabase_group_directory_repository.dart';
import '../../features/groups/domain/group_directory.dart' hide GroupDirectoryPage;
import '../../features/groups/presentation/group_directory_page.dart';
import '../../features/groups/presentation/group_form_page.dart';
import '../../features/help_center/presentation/screens/superadmin_help_center_page.dart';
import '../../features/health_care/domain/health_care_repository.dart';
import '../../features/health_care/domain/medication_plan_repository.dart';
import '../../features/health_care/presentation/health_care_controller.dart';
import '../../features/health_care/presentation/health_care_directory_page.dart';
import '../../features/health_care/presentation/health_care_form_pages.dart';
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
import '../../features/notices/presentation/notice_directory_page.dart';
import '../../features/notices/presentation/notice_form_page.dart';
import '../../features/plans/data/fake_plan_catalog_repository.dart';
import '../../features/plans/presentation/plan_directory_page.dart';
import '../../features/plans/presentation/plan_form_page.dart';
import '../../features/platform_users/data/fake_platform_user_repository.dart';
import '../../features/platform_users/domain/platform_user.dart';
import '../../features/platform_users/presentation/platform_user_directory_page.dart';
import '../../features/platform_users/presentation/platform_user_form_page.dart';
import '../../features/people/data/fake_person_directory_repository.dart';
import '../../features/people/data/supabase_person_directory_repository.dart';
import '../../features/people/domain/person_directory.dart' hide PersonDirectoryPage;
import '../../features/people/presentation/person_directory_page.dart';
import '../../features/people/presentation/person_edit_route_page.dart';
import '../../features/people/presentation/person_form_page.dart';
import '../../features/safety/application/child_safety_controller.dart';
import '../../features/safety/domain/child_safety_contract.dart';
import '../../features/safety/presentation/safety_pages.dart';
import '../../features/support/presentation/screens/support_page.dart';
import '../../features/support/presentation/view_models/support_prototype_controller.dart';
import '../../features/units/data/fake_unit_directory_repository.dart';
import '../../features/units/data/supabase_unit_directory_repository.dart';
import '../../features/units/domain/unit_backend_commands.dart';
import '../../features/units/domain/unit_directory.dart' hide UnitDirectoryPage;
import '../../features/units/presentation/unit_directory_page.dart';
import '../../features/units/presentation/unit_form_page.dart';
import '../dev_menu/dev_menu_overlay.dart';
import '../shell/superadmin_shell.dart';
import 'superadmin_routes.dart';

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
  PersonDirectoryRepository personDirectoryRepository =
      const UnavailablePersonDirectoryRepository(),
  UnitDirectoryRepository unitDirectoryRepository = const UnavailableUnitDirectoryRepository(),
  UnitBackendCommandsGateway? unitBackendCommands,
  AccessProfileRepository accessProfileRepository = const UnavailableAccessProfileRepository(),
  AccessProfileExtendedRepository accessProfileExtendedRepository =
      const UnavailableAccessProfileExtendedRepository(),
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
  AttendancePermissions attendancePermissions = const AttendancePermissions.readOnly(),
  RoutineRepository routineRepository = const UnavailableRoutineRepository(),
  AuditRepository auditRepository = const UnavailableAuditRepository(),
  MedicationPlanRepository medicationPlanRepository = const UnavailableMedicationPlanRepository(),
  ChildSafetyController? childSafetyController,
  bool allowDevelopmentPreview = !kReleaseMode || SuperadminAppConfig.environment == 'local',
  required ValueChanged<ThemeMode> onThemeModeChanged,
}) {
  final resolvedChildSafetyController =
      childSafetyController ?? ChildSafetyController(const UnavailableChildSafetyRepository());
  final sessionSupportController = supportController ?? SupportPrototypeController();
  final accountActivities = SuperadminActivityController();
  final operationalActivities = SuperadminActivityController();
  final operationalStore = SuperadminPrototypeStore(activityController: operationalActivities);
  final planRepository = FakePlanCatalogRepository(store: operationalStore);
  final importedRepository = importRepository;
  final agendaPrototypeStore = AgendaPrototypeStore.seeded();
  final accountController = AccountController(
    repository: InMemoryAccountProfileRepository(),
    activities: accountActivities,
  );
  final preferencesController =
      userPreferencesController ?? UserPreferencesController(InMemoryUserPreferencesRepository());
  unawaited(accountController.load());
  if (!preferencesController.loaded) {
    unawaited(preferencesController.load());
  }
  FakeInstitutionDirectoryRepository? cachedInstitutionPreviewRepository;
  FakeInstitutionDirectoryRepository institutionPreviewRepository() =>
      cachedInstitutionPreviewRepository ??= FakeInstitutionDirectoryRepository();
  final unitRepository = unitDirectoryRepository;
  FakeUnitDirectoryRepository? cachedUnitPreviewRepository;
  UnitDirectoryRepository unitPreviewRepository() =>
      cachedUnitPreviewRepository ??= FakeUnitDirectoryRepository();
  final groupRepository = groupDirectoryRepository;
  FakeGroupDirectoryRepository? cachedGroupPreviewRepository;
  FakeGroupDirectoryRepository groupPreviewRepository() =>
      cachedGroupPreviewRepository ??= FakeGroupDirectoryRepository(institutionPreviewRepository());
  final attendanceActivities = SuperadminActivityController();
  final dailyRoutineRepository = routineRepository;
  const healthCareRepository = UnavailableHealthCareRepository();
  final peoplePreviewRepository = FakePersonDirectoryRepository();
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
  }) async {
    final detail = activityId == null
        ? null
        : await activityDirectoryRepository.fetchById(activityId);
    if (activityId != null && detail == null) {
      throw const ActivityCommandUnavailableException();
    }
    await activityCommandRepository.save(
      _activitySaveCommand(
        draft,
        intent: intent,
        activityId: activityId,
        expectedVersion: detail?.item.managementVersion ?? 0,
      ),
    );
  }

  Future<void> createActivityTemplate(ActivityTemplateCreateDraft draft) =>
      activityCommandRepository.createTemplate(
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
  ) async {
    final locations = await activityCommandRepository.createLocations(
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

  Future<ActivityDirectoryExportResult> exportActivities(
    ActivityDirectoryExportRequest request,
  ) async {
    final result = await activityCommandRepository.requestExport(
      request.query,
      format: request.format == ActivityDirectoryExportFormat.csv
          ? ActivityCommandExportFormat.csv
          : ActivityCommandExportFormat.xlsx,
    );
    if (!await openDownloadUrl(result.downloadUrl)) {
      throw const ActivityCommandUnavailableException();
    }
    return ActivityDirectoryExportResult(
      fileName: 'atividades-${request.tableView.name}.${request.format.name}',
    );
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
      final path = state.uri.path;
      if (path == SuperadminRoutes.devInvites ||
          path.startsWith('${SuperadminRoutes.devInvites}/')) {
        return state.uri.replace(path: path.substring('/dev'.length)).toString();
      }
      if (path == SuperadminRoutes.devAudit) {
        return state.uri.replace(path: SuperadminRoutes.audit).toString();
      }
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
      return null;
    },
    routes: [
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
                  onBugReportSubmitted: sessionSupportController.submitReport,
                  child: child,
                )
              : child;
          return DevMenuOverlay(
            onNavigate: context.go,
            showTrigger: location != SuperadminRoutes.conversations,
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
              onCreate: () => context.goNamed(SuperadminRoutes.institutionCreateName),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.institutionEditName,
                pathParameters: {'institutionId': id},
              ),
              onCatalogOpen: () =>
                  openConfiguredCatalogExternally(catalogUrl, openExternally: openExternalCatalog),
              onSupportOpen: () => context.goNamed(SuperadminRoutes.supportName),
              onBugReportSubmitted: sessionSupportController.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.conversationsName,
                queryParameters: const {'from': 'institutions'},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.institutionCreate,
            name: SuperadminRoutes.institutionCreateName,
            builder: (context, state) => InstitutionFormPage(
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
            builder: (context, state) => InstitutionFormPage(
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
              backendCommands: unitBackendCommands,
              logout: logout,
              successMessage: unitSuccessMessage(state.extra),
              onCreate: () => context.goNamed(SuperadminRoutes.unitCreateName),
              onEdit: (id) =>
                  context.goNamed(SuperadminRoutes.unitEditName, pathParameters: {'unitId': id}),
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              backendCommands: unitBackendCommands,
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
              onCreate: () => context.goNamed(SuperadminRoutes.groupCreateName),
              onImport: () => context.goNamed(
                SuperadminRoutes.importCreateName,
                extra: ImportCreationPreset.groups,
              ),
              onEdit: (id) =>
                  context.goNamed(SuperadminRoutes.groupEditName, pathParameters: {'groupId': id}),
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              onCreate: () => context.goNamed(SuperadminRoutes.activityCreateName),
              onCreateFromTemplate: (template) => context.goNamed(
                SuperadminRoutes.activityCreateName,
                queryParameters: {
                  'templateId': template.id,
                  if (template.scopeKind == ActivityTemplateScopeKind.institution &&
                      template.institutionId != null)
                    'institutionId': template.institutionId!,
                },
              ),
              onDuplicateTemplate: (template, institutionId) async {
                await activityCommandRepository.copyTemplate(
                  ActivityTemplateCopyCommand(
                    requestId: _activityRequestId(),
                    templateId: template.id,
                    institutionId: institutionId,
                  ),
                );
              },
              onCreateTemplate: createActivityTemplate,
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.activityEditName,
                pathParameters: {'activityId': id},
              ),
              onView: (id) => context.goNamed(
                SuperadminRoutes.activityDetailName,
                pathParameters: {'activityId': id},
              ),
              onExportRequested: exportActivities,
              onImportRequested: () async => context.goNamed(
                SuperadminRoutes.importCreateName,
                extra: ImportCreationPreset.activities,
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.activityCreate,
            name: SuperadminRoutes.activityCreateName,
            builder: (context, state) => ActivityFormPage(
              repository: activityDirectoryRepository,
              initialTemplateId: state.uri.queryParameters['templateId'],
              initialInstitutionId: state.uri.queryParameters['institutionId'],
              initialUnitId: state.uri.queryParameters['unitId'],
              logout: logout,
              onCancel: () => _returnToOr(context, state, SuperadminRoutes.activitiesName),
              onSaveDraft: (draft) => saveActivity(draft, intent: ActivityCommandIntent.saveDraft),
              onSubmit: (draft) async {
                await saveActivity(draft, intent: ActivityCommandIntent.publish);
                if (context.mounted) {
                  _returnToOr(context, state, SuperadminRoutes.activitiesName);
                }
              },
              onCreateLocation: createActivityLocations,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.activityEdit,
            name: SuperadminRoutes.activityEditName,
            builder: (context, state) => ActivityFormPage(
              activityId: state.pathParameters['activityId']!,
              repository: activityDirectoryRepository,
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
              ),
              onSubmit: (draft) async {
                await saveActivity(
                  draft,
                  intent: ActivityCommandIntent.publish,
                  activityId: state.pathParameters['activityId']!,
                );
                if (!context.mounted) return;
                state.uri.queryParameters.containsKey('returnTo')
                    ? _returnToOr(context, state, SuperadminRoutes.activitiesName)
                    : context.goNamed(
                        SuperadminRoutes.activityDetailName,
                        pathParameters: {'activityId': state.pathParameters['activityId']!},
                      );
              },
              onCreateLocation: createActivityLocations,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.attendance,
            name: SuperadminRoutes.attendanceName,
            builder: (context, state) => AttendanceDashboardPage(
              repository: attendanceRepository,
              permissions: attendancePermissions,
              logout: logout,
              onCreate: () => context.goNamed(SuperadminRoutes.attendanceCreateName),
              onOpenCall: (id) => context.goNamed(
                SuperadminRoutes.attendanceCallName,
                pathParameters: {'callId': id},
              ),
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.attendanceCreate,
            name: SuperadminRoutes.attendanceCreateName,
            builder: (context, state) => AttendanceNewCallPage(
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
            builder: (context, state) => AttendanceCallPage(
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
              onCreateEntry: (type) =>
                  context.goNamed(SuperadminRoutes.dailyRoutineCreateName, extra: type),
              onEdit: (entry) => context.goNamed(
                SuperadminRoutes.dailyRoutineEditName,
                pathParameters: {'modelId': entry.id},
                queryParameters: {'kind': entry.kind.name},
              ),
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
            path: SuperadminRoutes.healthCareProfiles,
            name: SuperadminRoutes.healthCareProfilesName,
            builder: (context, state) => HealthCareProfileDirectoryPage(
              controller: HealthCareController(healthCareRepository),
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
              onSaved: () async => context.goNamed(SuperadminRoutes.healthCareProfilesName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthCareProfileDetail,
            name: SuperadminRoutes.healthCareProfileDetailName,
            redirect: (context, state) => context.namedLocation(
              SuperadminRoutes.healthCareProfileEditName,
              pathParameters: {'childId': state.pathParameters['childId']!},
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthCareProfileEdit,
            name: SuperadminRoutes.healthCareProfileEditName,
            builder: (context, state) => HealthCareProfileFormPage(
              logout: logout,
              childId: state.pathParameters['childId']!,
              onCancel: () => context.pop(),
              onSaved: () async => context.pop(),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthMedicationPlans,
            name: SuperadminRoutes.healthMedicationPlansName,
            builder: (context, state) => HealthMedicationPlanDirectoryPage(
              controller: HealthCareController(healthCareRepository),
              logout: logout,
              onCreate: () => context.goNamed(SuperadminRoutes.healthMedicationPlanCreateName),
              onPlanSelected: (medicationId) => context.pushNamed(
                SuperadminRoutes.healthMedicationPlanDetailName,
                pathParameters: {'medicationId': medicationId},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthMedicationPlanCreate,
            name: SuperadminRoutes.healthMedicationPlanCreateName,
            builder: (context, state) => HealthMedicationPlanFormPage(
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.healthMedicationPlansName),
              onSaved: () async => context.goNamed(SuperadminRoutes.healthMedicationPlansName),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthMedicationPlanDetail,
            name: SuperadminRoutes.healthMedicationPlanDetailName,
            redirect: (context, state) => context.namedLocation(
              SuperadminRoutes.healthMedicationPlanEditName,
              pathParameters: {'medicationId': state.pathParameters['medicationId']!},
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthMedicationPlanEdit,
            name: SuperadminRoutes.healthMedicationPlanEditName,
            builder: (context, state) => HealthMedicationPlanFormPage(
              logout: logout,
              medicationId: state.pathParameters['medicationId']!,
              onCancel: () => context.pop(),
              onSaved: () async => context.pop(),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.people,
            name: SuperadminRoutes.peopleName,
            builder: (context, state) => PersonDirectoryPage(
              repository: personDirectoryRepository,
              logout: logout,
              successMessage: state.extra as String?,
              onCreate: () => context.goNamed(SuperadminRoutes.personCreateName),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.personEditName,
                pathParameters: {'personId': id},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              onCreate: () => context.goNamed(SuperadminRoutes.safetyCreateName),
              onExport: () async {
                await resolvedChildSafetyController.requestExport(
                  ChildSafetyExportCommand(
                    requestId: _activityRequestId(),
                    filters: {
                      'search': resolvedChildSafetyController.query.search.trim(),
                      'institution_ids': resolvedChildSafetyController.query.institutionIds
                          .toList(),
                      'unit_ids': resolvedChildSafetyController.query.unitIds.toList(),
                      'segment': resolvedChildSafetyController.query.segment.databaseValue,
                    },
                  ),
                );
              },
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
              onCreate: () => context.goNamed(
                SuperadminRoutes.safetyCreateName,
                queryParameters: {'childId': state.pathParameters['childId']!},
              ),
              onEdit: (authorizationId) => context.goNamed(
                SuperadminRoutes.safetyEditName,
                pathParameters: {
                  'childId': state.pathParameters['childId']!,
                  'authorizationId': authorizationId,
                },
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.personCreate,
            name: SuperadminRoutes.personCreateName,
            builder: (context, state) {
              final creationMode = state.uri.queryParameters['personCreationMode'];
              final initialPersonType = switch (creationMode) {
                'child' => PersonType.child,
                'service' => PersonType.service,
                'professional' => PersonType.adult,
                _ => null,
              };
              return PersonFormPage(
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
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.personEdit,
            name: SuperadminRoutes.personEditName,
            builder: (context, state) => PersonEditRoutePage(
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
            builder: (context, state) => AccessProfileDirectoryPage(
              repository: accessProfileRepository,
              extendedRepository: accessProfileExtendedRepository,
              logout: logout,
              onCreate: (domain) => context.goNamed(
                SuperadminRoutes.profileCreateName,
                pathParameters: {'domain': domain.databaseValue},
              ),
              onOpen: (domain, id) => context.goNamed(
                SuperadminRoutes.profileDetailName,
                pathParameters: {'domain': domain.databaseValue, 'profileId': id},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.profileModels,
            name: SuperadminRoutes.profileModelsName,
            builder: (context, state) => AccessProfileModelDirectoryPage(
              repository: accessProfileExtendedRepository,
              logout: logout,
              onCreate: (domain) => context.goNamed(
                SuperadminRoutes.profileModelCreateName,
                pathParameters: {'domain': domain.databaseValue},
              ),
              onOpen: (domain, id) => context.goNamed(
                SuperadminRoutes.profileModelDetailName,
                pathParameters: {'domain': domain.databaseValue, 'modelId': id},
              ),
              onDuplicate: (domain, id) => context.goNamed(
                SuperadminRoutes.profileModelDuplicateName,
                pathParameters: {'domain': domain.databaseValue, 'modelId': id},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.profileModelCreate,
            name: SuperadminRoutes.profileModelCreateName,
            builder: (context, state) {
              final domain = _accessDomainIncludingPrincipalOrNull(state.pathParameters['domain']);
              if (domain == null) {
                return _invalidAccessProfileRoute(context, SuperadminRoutes.profileModelsName);
              }
              return AccessProfileModelFormPage(
                repository: accessProfileExtendedRepository,
                logout: logout,
                domain: domain,
                onCancel: () => context.goNamed(SuperadminRoutes.profileModelsName),
                onSaved: (model) => context.goNamed(
                  SuperadminRoutes.profileModelDetailName,
                  pathParameters: {'domain': model.domain.databaseValue, 'modelId': model.id},
                ),
                onDestinationSelected: (destination) =>
                    _navigateFromPersistentShell(context, destination),
                onBugReportSubmitted: sessionSupportController.submitReport,
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.profileModelDetail,
            name: SuperadminRoutes.profileModelDetailName,
            builder: (context, state) {
              final domain = _accessDomainIncludingPrincipalOrNull(state.pathParameters['domain']);
              final modelId = state.pathParameters['modelId'];
              if (domain == null || modelId == null) {
                return _invalidAccessProfileRoute(context, SuperadminRoutes.profileModelsName);
              }
              return AccessProfileModelDetailPage(
                repository: accessProfileExtendedRepository,
                logout: logout,
                domain: domain,
                modelId: modelId,
                onBack: () => context.goNamed(SuperadminRoutes.profileModelsName),
                onEdit: () => context.goNamed(
                  SuperadminRoutes.profileModelEditName,
                  pathParameters: {'domain': domain.databaseValue, 'modelId': modelId},
                ),
                onDuplicate: () => context.goNamed(
                  SuperadminRoutes.profileModelDuplicateName,
                  pathParameters: {'domain': domain.databaseValue, 'modelId': modelId},
                ),
                onDestinationSelected: (destination) =>
                    _navigateFromPersistentShell(context, destination),
                onBugReportSubmitted: sessionSupportController.submitReport,
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.profileModelEdit,
            name: SuperadminRoutes.profileModelEditName,
            builder: (context, state) => _profileModelFormRoute(
              context,
              state,
              repository: accessProfileExtendedRepository,
              logout: logout,
              duplicate: false,
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.profileModelDuplicate,
            name: SuperadminRoutes.profileModelDuplicateName,
            builder: (context, state) => _profileModelFormRoute(
              context,
              state,
              repository: accessProfileExtendedRepository,
              logout: logout,
              duplicate: true,
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.profileCreate,
            name: SuperadminRoutes.profileCreateName,
            builder: (context, state) {
              final domain = _accessDomainOrNull(state.pathParameters['domain']);
              if (domain == null) {
                return _invalidAccessProfileRoute(context, SuperadminRoutes.profilesName);
              }
              return AccessProfileFormPage(
                repository: accessProfileRepository,
                extendedRepository: accessProfileExtendedRepository,
                logout: logout,
                domain: domain,
                onCancel: () => context.goNamed(SuperadminRoutes.profilesName),
                onSaved: (profile) => context.goNamed(
                  SuperadminRoutes.profileDetailName,
                  pathParameters: {'domain': profile.domain.databaseValue, 'profileId': profile.id},
                ),
                onDestinationSelected: (destination) =>
                    _navigateFromPersistentShell(context, destination),
                onBugReportSubmitted: sessionSupportController.submitReport,
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.profileDetail,
            name: SuperadminRoutes.profileDetailName,
            builder: (context, state) {
              final domain = _accessDomainOrNull(state.pathParameters['domain']);
              if (domain == null) {
                return _invalidAccessProfileRoute(context, SuperadminRoutes.profilesName);
              }
              final profileId = state.pathParameters['profileId']!;
              return AccessProfileDetailPage(
                repository: accessProfileRepository,
                logout: logout,
                domain: domain,
                profileId: profileId,
                onBack: () => context.goNamed(SuperadminRoutes.profilesName),
                onEdit: () => context.goNamed(
                  SuperadminRoutes.profileEditName,
                  pathParameters: {'domain': domain.databaseValue, 'profileId': profileId},
                ),
                onDeleted: () => context.goNamed(SuperadminRoutes.profilesName),
                onDestinationSelected: (destination) =>
                    _navigateFromPersistentShell(context, destination),
                onBugReportSubmitted: sessionSupportController.submitReport,
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.profileEdit,
            name: SuperadminRoutes.profileEditName,
            builder: (context, state) {
              final domain = _accessDomainOrNull(state.pathParameters['domain']);
              if (domain == null) {
                return _invalidAccessProfileRoute(context, SuperadminRoutes.profilesName);
              }
              final profileId = state.pathParameters['profileId']!;
              return AccessProfileFormPage(
                repository: accessProfileRepository,
                extendedRepository: accessProfileExtendedRepository,
                logout: logout,
                domain: domain,
                profileId: profileId,
                onCancel: () => context.goNamed(
                  SuperadminRoutes.profileDetailName,
                  pathParameters: {'domain': domain.databaseValue, 'profileId': profileId},
                ),
                onSaved: (profile) => context.goNamed(
                  SuperadminRoutes.profileDetailName,
                  pathParameters: {'domain': profile.domain.databaseValue, 'profileId': profile.id},
                ),
                onDestinationSelected: (destination) =>
                    _navigateFromPersistentShell(context, destination),
                onBugReportSubmitted: sessionSupportController.submitReport,
              );
            },
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
              onBugReportSubmitted: sessionSupportController.submitReport,
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.conversationsName,
                queryParameters: const {'from': 'catalog'},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.support,
            name: SuperadminRoutes.supportName,
            builder: (context, state) => SupportPage(
              controller: sessionSupportController,
              logout: logout,
              onHomeOpen: () => context.goNamed(SuperadminRoutes.homeName),
              onInstitutionsOpen: () => context.goNamed(SuperadminRoutes.institutionsName),
              onUnitsOpen: () => context.goNamed(SuperadminRoutes.unitsName),
              onCatalogOpen: () =>
                  openConfiguredCatalogExternally(catalogUrl, openExternally: openExternalCatalog),
              onConversationsOpen: () => context.goNamed(
                SuperadminRoutes.conversationsName,
                queryParameters: const {'from': 'support'},
              ),
            ),
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
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.homeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.institutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.unitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.groupsName);
                } else if (destination == 'catalog') {
                  context.goNamed(SuperadminRoutes.governanceCatalogName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.profile,
            name: SuperadminRoutes.profileName,
            builder: (context, state) => ProfilePage(
              controller: accountController,
              logout: logout,
              onDestinationSelected: (destination) => _navigateFromAccount(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.settings,
            name: SuperadminRoutes.settingsName,
            builder: (context, state) => SettingsPage(
              controller: preferencesController,
              logout: logout,
              onDestinationSelected: (destination) => _navigateFromAccount(context, destination),
            ),
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
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              logout: _previewLogout,
              successMessage: unitSuccessMessage(state.extra),
              onCreate: () => context.goNamed(SuperadminRoutes.devUnitCreateName),
              onEdit: (id) =>
                  context.goNamed(SuperadminRoutes.devUnitEditName, pathParameters: {'unitId': id}),
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              onImport: () => context.goNamed(
                SuperadminRoutes.importCreateName,
                extra: ImportCreationPreset.groups,
              ),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.devGroupEditName,
                pathParameters: {'groupId': id},
              ),
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              onBugReportSubmitted: sessionSupportController.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivities,
            name: SuperadminRoutes.devActivitiesName,
            builder: (context, state) => ActivityDirectoryPage(
              repository: activityDirectoryRepository,
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
              onDuplicateTemplate: (template, institutionId) async {
                await activityCommandRepository.copyTemplate(
                  ActivityTemplateCopyCommand(
                    requestId: _activityRequestId(),
                    templateId: template.id,
                    institutionId: institutionId,
                  ),
                );
              },
              onCreateTemplate: createActivityTemplate,
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.devActivityEditName,
                pathParameters: {'activityId': id},
              ),
              onView: (id) => context.goNamed(
                SuperadminRoutes.devActivityDetailName,
                pathParameters: {'activityId': id},
              ),
              onExportRequested: exportActivities,
              onImportRequested: () async => context.goNamed(
                SuperadminRoutes.importCreateName,
                extra: ImportCreationPreset.activities,
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivityCreate,
            name: SuperadminRoutes.devActivityCreateName,
            builder: (context, state) => ActivityFormPage(
              repository: activityDirectoryRepository,
              initialTemplateId: state.uri.queryParameters['templateId'],
              initialInstitutionId: state.uri.queryParameters['institutionId'],
              initialUnitId: state.uri.queryParameters['unitId'],
              logout: _previewLogout,
              onCancel: () => _returnToOr(context, state, SuperadminRoutes.devActivitiesName),
              onSaveDraft: (draft) => saveActivity(draft, intent: ActivityCommandIntent.saveDraft),
              onSubmit: (draft) async {
                await saveActivity(draft, intent: ActivityCommandIntent.publish);
                if (context.mounted) {
                  _returnToOr(context, state, SuperadminRoutes.devActivitiesName);
                }
              },
              onCreateLocation: createActivityLocations,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivityDetail,
            name: SuperadminRoutes.devActivityDetailName,
            builder: (context, state) => ActivityDetailPage(
              activityId: state.pathParameters['activityId']!,
              repository: activityDirectoryRepository,
              logout: _previewLogout,
              onBack: () => context.goNamed(SuperadminRoutes.devActivitiesName),
              onEdit: () => context.goNamed(
                SuperadminRoutes.devActivityEditName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivityEdit,
            name: SuperadminRoutes.devActivityEditName,
            builder: (context, state) => ActivityFormPage(
              activityId: state.pathParameters['activityId']!,
              repository: activityDirectoryRepository,
              logout: _previewLogout,
              onCancel: () => context.goNamed(
                SuperadminRoutes.devActivityDetailName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
              onSaveDraft: (draft) => saveActivity(
                draft,
                intent: ActivityCommandIntent.saveDraft,
                activityId: state.pathParameters['activityId']!,
              ),
              onSubmit: (draft) async {
                await saveActivity(
                  draft,
                  intent: ActivityCommandIntent.publish,
                  activityId: state.pathParameters['activityId']!,
                );
                if (context.mounted) {
                  context.goNamed(
                    SuperadminRoutes.devActivityDetailName,
                    pathParameters: {'activityId': state.pathParameters['activityId']!},
                  );
                }
              },
              onCreateLocation: createActivityLocations,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAttendance,
            name: SuperadminRoutes.devAttendanceName,
            builder: (context, state) => AttendanceDashboardPage(
              repository: attendanceRepository,
              permissions: attendancePermissions,
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
              repository: attendanceRepository,
              permissions: attendancePermissions,
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
              repository: attendanceRepository,
              callId: state.pathParameters['callId']!,
              focusedParticipantId: state.uri.queryParameters['participant'],
              permissions: attendancePermissions,
              logout: _previewLogout,
              onBack: () => context.goNamed(SuperadminRoutes.devAttendanceName),
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devDailyRoutine,
            name: SuperadminRoutes.devDailyRoutineName,
            builder: (context, state) => DailyRoutineDirectoryPage(
              repository: dailyRoutineRepository,
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
              repository: dailyRoutineRepository,
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
              repository: dailyRoutineRepository,
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
              controller: HealthCareController(healthCareRepository),
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
              onCancel: () => context.goNamed(SuperadminRoutes.devHealthCareProfilesName),
              onSaved: () async => context.goNamed(SuperadminRoutes.devHealthCareProfilesName),
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
              childId: state.pathParameters['childId']!,
              onCancel: () => context.pop(),
              onSaved: () async => context.pop(),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthMedicationPlans,
            name: SuperadminRoutes.devHealthMedicationPlansName,
            builder: (context, state) => HealthMedicationPlanDirectoryPage(
              controller: HealthCareController(healthCareRepository),
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
              onCancel: () => context.goNamed(SuperadminRoutes.devHealthMedicationPlansName),
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
            builder: (context, state) => HealthMedicationPlanFormPage(
              logout: _previewLogout,
              medicationId: state.pathParameters['medicationId']!,
              onCancel: () => context.pop(),
              onSaved: () async => context.pop(),
            ),
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
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              controller: resolvedChildSafetyController,
              logout: _previewLogout,
              onOpenChild: (id) => context.goNamed(
                SuperadminRoutes.devSafetyChildName,
                pathParameters: {'childId': id},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devSafetyChild,
            name: SuperadminRoutes.devSafetyChildName,
            builder: (context, state) => ChildSecurityPage(
              childId: state.pathParameters['childId']!,
              controller: resolvedChildSafetyController,
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
              return PersonFormPage(
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
              onView: (id) => context.goNamed(
                SuperadminRoutes.devInternalUserViewName,
                pathParameters: {'internalUserId': id},
              ),
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
            path: SuperadminRoutes.devInternalUserView,
            name: SuperadminRoutes.devInternalUserViewName,
            redirect: (context, state) => context.namedLocation(
              SuperadminRoutes.devInternalUserEditName,
              pathParameters: {'internalUserId': state.pathParameters['internalUserId']!},
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
                onCancel: () => context.goNamed(
                  SuperadminRoutes.devInternalUserViewName,
                  pathParameters: {'internalUserId': id},
                ),
                onUpdated: (_) => context.goNamed(
                  SuperadminRoutes.devInternalUserViewName,
                  pathParameters: {'internalUserId': id},
                ),
                onDestinationSelected: (destination) =>
                    _navigateFromDevelopmentShell(context, destination),
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devPlans,
            name: SuperadminRoutes.devPlansName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Planos',
              subtitle: 'Configure os planos fictícios da plataforma.',
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
              subtitle: 'Cadastre um plano fictício.',
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
              subtitle: 'Altere um plano fictício.',
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
            path: SuperadminRoutes.invites,
            name: SuperadminRoutes.invitesName,
            builder: (context, state) => InviteDirectoryPage(
              repository: inviteRepository,
              logout: logout,
              onDestinationSelected: (value) => _navigateFromPersistentShell(context, value),
              onCreate: () => context.goNamed(SuperadminRoutes.inviteCreateName),
              onOpen: (id) => context.goNamed(
                SuperadminRoutes.inviteDetailName,
                pathParameters: {'inviteId': id},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.inviteCreate,
            name: SuperadminRoutes.inviteCreateName,
            builder: (context, state) => InviteFormPage(
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
            redirect: (context, state) => SuperadminRoutes.invites,
          ),
          GoRoute(
            path: SuperadminRoutes.devInviteCreate,
            name: SuperadminRoutes.devInviteCreateName,
            redirect: (context, state) => SuperadminRoutes.inviteCreate,
          ),
          GoRoute(
            path: SuperadminRoutes.devInviteDetail,
            name: SuperadminRoutes.devInviteDetailName,
            redirect: (context, state) => state.namedLocation(
              SuperadminRoutes.inviteDetailName,
              pathParameters: {'inviteId': state.pathParameters['inviteId']!},
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.notices,
            name: SuperadminRoutes.noticesName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Avisos',
              subtitle: 'Crie e acompanhe avisos oficiais da plataforma.',
              destination: 'notices',
              child: NoticeDirectoryPage(
                repository: noticeRepository,
                onCreate: () => context.goNamed(SuperadminRoutes.noticeCreateName),
                onEdit: (id) => context.goNamed(
                  SuperadminRoutes.noticeEditName,
                  pathParameters: {'noticeId': id},
                ),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.noticeCreate,
            name: SuperadminRoutes.noticeCreateName,
            builder: (context, state) => operationalPage(
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
            builder: (context, state) => operationalPage(
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
            redirect: (context, state) => SuperadminRoutes.notices,
          ),
          GoRoute(
            path: SuperadminRoutes.devNoticeCreate,
            name: SuperadminRoutes.devNoticeCreateName,
            redirect: (context, state) => SuperadminRoutes.noticeCreate,
          ),
          GoRoute(
            path: SuperadminRoutes.devNoticeEdit,
            name: SuperadminRoutes.devNoticeEditName,
            redirect: (context, state) => state.namedLocation(
              SuperadminRoutes.noticeEditName,
              pathParameters: {'noticeId': state.pathParameters['noticeId']!},
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAudit,
            name: SuperadminRoutes.devAuditName,
            redirect: (context, state) => SuperadminRoutes.audit,
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
              onBugReportSubmitted: sessionSupportController.submitReport,
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
              controller: sessionSupportController,
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
              onDestinationSelected: (destination) {
                if (destination == 'home') {
                  context.goNamed(SuperadminRoutes.devHomeName);
                } else if (destination == 'institutions') {
                  context.goNamed(SuperadminRoutes.devInstitutionsName);
                } else if (destination == 'units') {
                  context.goNamed(SuperadminRoutes.devUnitsName);
                } else if (destination == 'groups') {
                  context.goNamed(SuperadminRoutes.devGroupsName);
                } else if (destination == 'catalog') {
                  context.goNamed(SuperadminRoutes.devCatalogName);
                }
              },
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devProfile,
            name: SuperadminRoutes.devProfileName,
            builder: (context, state) => ProfilePage(
              controller: accountController,
              logout: _previewLogout,
              onDestinationSelected: (destination) =>
                  _navigateFromAccount(context, destination, developmentPreview: true),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devSettings,
            name: SuperadminRoutes.devSettingsName,
            builder: (context, state) => SettingsPage(
              controller: preferencesController,
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
    case 'people':
      context.goNamed(SuperadminRoutes.peopleName);
    case 'safety':
      context.goNamed(SuperadminRoutes.safetyName);
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

String _destinationForLocation(String location) {
  if (location.startsWith('/dev/')) {
    return _destinationForLocation(location.substring('/dev'.length));
  }
  if (location.startsWith('/institutions')) {
    return 'institutions';
  }
  if (location.startsWith('/units')) {
    return 'units';
  }
  if (location.startsWith('/groups')) {
    return 'groups';
  }
  if (location.startsWith('/activities')) {
    return 'activities';
  }
  if (location.startsWith('/attendance')) {
    return 'attendance';
  }
  if (location.startsWith('/daily-routine')) {
    return 'daily-routine';
  }
  if (location.startsWith('/health-care/medication-plans')) {
    return 'health-medication-plans';
  }
  if (location.startsWith('/health-care/profiles')) {
    return 'health-care-profiles';
  }
  if (location.startsWith('/people')) {
    return 'people';
  }
  if (location.startsWith('/safety')) {
    return 'safety';
  }
  if (location.startsWith('/profile-models')) {
    return 'profile-models';
  }
  if (location.startsWith('/profiles')) {
    return 'profiles';
  }
  if (location.startsWith('/internal-users')) {
    return 'internal-users';
  }
  if (location.startsWith('/plans')) {
    return 'plans';
  }
  if (location.startsWith('/imports')) {
    return 'import';
  }
  if (location.startsWith('/invites')) {
    return 'invites';
  }
  if (location.startsWith('/notices')) {
    return 'notices';
  }
  if (location.startsWith('/audit')) {
    return 'audit';
  }
  if (location.startsWith('/agenda')) {
    return 'agenda';
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
    case 'attendance':
      context.goNamed(SuperadminRoutes.attendanceName);
    case 'daily-routine':
      context.goNamed(SuperadminRoutes.dailyRoutineName);
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
    case 'profile-models':
      context.goNamed(SuperadminRoutes.profileModelsName);
    case 'catalog':
      context.goNamed(SuperadminRoutes.governanceCatalogName);
    case 'support':
      context.goNamed(SuperadminRoutes.supportName);
    case 'import':
      context.goNamed(SuperadminRoutes.importsName);
    case 'invites':
      context.goNamed(SuperadminRoutes.invitesName);
    case 'conversations':
      context.goNamed(SuperadminRoutes.conversationsName);
    case 'profile':
      context.goNamed(SuperadminRoutes.profileName);
    case 'settings':
      context.goNamed(SuperadminRoutes.settingsName);
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
    case 'attendance':
      context.goNamed(SuperadminRoutes.devAttendanceName);
    case 'daily-routine':
      context.goNamed(SuperadminRoutes.devDailyRoutineName);
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
      context.goNamed(SuperadminRoutes.importsName);
    case 'invites':
      context.goNamed(SuperadminRoutes.invitesName);
    case 'notices':
      context.goNamed(SuperadminRoutes.devNoticesName);
    case 'audit':
      context.goNamed(SuperadminRoutes.auditName);
    case 'catalog':
      context.goNamed(SuperadminRoutes.devCatalogName);
    case 'internal-users':
      context.goNamed(SuperadminRoutes.devInternalUsersName);
    case 'support':
      context.goNamed(SuperadminRoutes.devSupportName);
    case 'conversations':
      context.goNamed(SuperadminRoutes.devConversationsName);
    case 'profile':
      context.goNamed(SuperadminRoutes.devProfileName);
    case 'settings':
      context.goNamed(SuperadminRoutes.devSettingsName);
  }
}

Widget _profileModelFormRoute(
  BuildContext context,
  GoRouterState state, {
  required AccessProfileExtendedRepository repository,
  required LogoutAction logout,
  required bool duplicate,
  required ValueChanged<SupportReportDraft>? onBugReportSubmitted,
}) {
  final domain = _accessDomainIncludingPrincipalOrNull(state.pathParameters['domain']);
  final modelId = state.pathParameters['modelId'];
  if (domain == null || modelId == null) {
    return _invalidAccessProfileRoute(context, SuperadminRoutes.profileModelsName);
  }
  return AccessProfileModelFormPage(
    repository: repository,
    logout: logout,
    domain: domain,
    modelId: modelId,
    duplicate: duplicate,
    onCancel: () => context.goNamed(
      SuperadminRoutes.profileModelDetailName,
      pathParameters: {'domain': domain.databaseValue, 'modelId': modelId},
    ),
    onSaved: (model) => context.goNamed(
      SuperadminRoutes.profileModelDetailName,
      pathParameters: {'domain': model.domain.databaseValue, 'modelId': model.id},
    ),
    onDestinationSelected: (destination) => _navigateFromPersistentShell(context, destination),
    onBugReportSubmitted: onBugReportSubmitted,
  );
}

AccessProfileDomain? _accessDomainIncludingPrincipalOrNull(String? value) {
  for (final domain in AccessProfileDomain.values) {
    if (domain.databaseValue == value) return domain;
  }
  return null;
}

RoutineEntryKind _routineEntryKind(String? value) {
  for (final kind in RoutineEntryKind.values) {
    if (kind.name == value) return kind;
  }
  return RoutineEntryKind.model;
}

AccessProfileDomain? _accessDomainOrNull(String? value) {
  for (final domain in AccessProfileDomain.values) {
    if (domain.databaseValue == value && domain != AccessProfileDomain.principal) {
      return domain;
    }
  }
  return null;
}

Widget _invalidAccessProfileRoute(BuildContext context, String destination) =>
    SuperadminErrorScreen(
      kind: SuperadminErrorKind.notFound,
      onAction: () => context.goNamed(destination),
    );
Future<LogoutResult> _previewLogout() async => const LogoutResult.success();

ActivitySaveCommand _activitySaveCommand(
  ActivityFormDraft draft, {
  required ActivityCommandIntent intent,
  required String? activityId,
  required int expectedVersion,
}) => ActivitySaveCommand(
  requestId: _activityRequestId(),
  intent: intent,
  activityId: activityId,
  templateId: activityId == null ? draft.template?.id : null,
  expectedVersion: expectedVersion,
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
