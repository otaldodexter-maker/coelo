import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/guards/superadmin_session.dart';
import '../../core/config/superadmin_app_config.dart';
import '../activity/superadmin_activity.dart';
import '../prototype/superadmin_prototype_store.dart';
import '../../features/activities/data/fake_activity_directory_repository.dart';
import '../../features/activities/data/supabase_activity_directory_repository.dart';
import '../../features/activities/domain/activity_directory.dart';
import '../../features/activities/presentation/activity_detail_page.dart';
import '../../features/activities/presentation/activity_directory_page.dart';
import '../../features/activities/presentation/activity_form_page.dart';
import '../../features/account/data/account_profile_repository.dart';
import '../../features/account/data/user_preferences_repository.dart';
import '../../features/account/presentation/account_controller.dart';
import '../../features/account/presentation/screens/profile_page.dart';
import '../../features/account/presentation/screens/settings_page.dart';
import '../../features/account/presentation/user_preferences_controller.dart';
import '../../features/access_profiles/data/fake_access_profile_repository.dart';
import '../../features/access_profiles/data/supabase_access_profile_repository.dart';
import '../../features/access_profiles/domain/access_profile.dart';
import '../../features/access_profiles/presentation/access_profile_detail_page.dart';
import '../../features/access_profiles/presentation/access_profile_directory_page.dart';
import '../../features/access_profiles/presentation/access_profile_form_page.dart';
import '../../features/auth/domain/login_request.dart';
import '../../features/auth/domain/logout_action.dart';
import '../../features/auth/domain/password_recovery.dart';
import '../../features/auth/domain/reset_password_action.dart';
import '../../features/auth/presentation/screens/superadmin_forgot_password_screen.dart';
import '../../features/auth/presentation/screens/superadmin_login_screen.dart';
import '../../features/auth/presentation/screens/superadmin_reset_password_screen.dart';
import '../../features/attendance/attendance.dart';
import '../../features/attendance/attendance_pages.dart';
import '../../features/daily_routine/daily_routine.dart';
import '../../features/daily_routine/daily_routine_pages.dart';
import '../../features/catalog/presentation/catalog_host_page.dart';
import '../../features/chat/presentation/screens/superadmin_chat_page.dart';
import '../../features/errors/presentation/screens/superadmin_error_screen.dart';
import '../../features/groups/data/fake_group_directory_repository.dart';
import '../../features/groups/presentation/group_directory_page.dart';
import '../../features/groups/presentation/group_form_page.dart';
import '../../features/help_center/presentation/screens/superadmin_help_center_page.dart';
import '../../features/health_safety/data/demo_health_safety_repository.dart';
import '../../features/health_safety/presentation/health_safety_controller.dart';
import '../../features/health_safety/presentation/health_safety_detail_page.dart';
import '../../features/health_safety/presentation/health_safety_directory_page.dart';
import '../../features/institutions/data/fake_institution_directory_repository.dart';
import '../../features/institutions/data/supabase_institution_directory_repository.dart';
import '../../features/institutions/domain/institution_directory_repository.dart';
import '../../features/institutions/presentation/institution_context_options.dart';
import '../../features/institutions/presentation/screens/institution_directory_page.dart';
import '../../features/institutions/presentation/screens/institution_form_page.dart';
import '../../features/audit/presentation/audit_directory_page.dart';
import '../../features/imports/data/fake_import_repository.dart';
import '../../features/imports/presentation/import_directory_page.dart';
import '../../features/imports/presentation/import_wizard_controller.dart';
import '../../features/imports/presentation/import_wizard_page.dart';
import '../../features/invites/data/fake_invite_repository.dart';
import '../../features/invites/presentation/invite_detail_page.dart';
import '../../features/invites/presentation/invite_directory_page.dart';
import '../../features/invites/presentation/invite_form_page.dart';
import '../../features/notices/data/fake_notice_repository.dart';
import '../../features/notices/presentation/notice_directory_page.dart';
import '../../features/notices/presentation/notice_form_page.dart';
import '../../features/plans/data/fake_plan_catalog_repository.dart';
import '../../features/plans/presentation/plan_directory_page.dart';
import '../../features/plans/presentation/plan_form_page.dart';
import '../../features/platform_users/data/fake_platform_user_repository.dart';
import '../../features/platform_users/domain/platform_user.dart';
import '../../features/platform_users/presentation/platform_user_detail_page.dart';
import '../../features/platform_users/presentation/platform_user_directory_page.dart';
import '../../features/platform_users/presentation/platform_user_form_page.dart';
import '../../features/people/data/fake_person_directory_repository.dart';
import '../../features/people/data/supabase_person_directory_repository.dart';
import '../../features/people/domain/person_directory.dart' hide PersonDirectoryPage;
import '../../features/people/presentation/person_directory_page.dart';
import '../../features/people/presentation/person_edit_route_page.dart';
import '../../features/people/presentation/person_form_page.dart';
import '../../features/support/presentation/screens/support_page.dart';
import '../../features/support/presentation/view_models/support_prototype_controller.dart';
import '../../features/units/data/fake_unit_directory_repository.dart';
import '../../features/units/presentation/unit_directory_page.dart';
import '../../features/units/presentation/unit_form_page.dart';
import '../dev_menu/dev_menu_overlay.dart';
import '../shell/superadmin_shell.dart';
import 'superadmin_routes.dart';

GoRouter createSuperadminRouter({
  required SuperadminSession session,
  required LoginAction login,
  required LogoutAction logout,
  required PasswordRecoveryAction requestPasswordRecovery,
  InstitutionDirectoryRepository institutionDirectoryRepository =
      const UnavailableInstitutionDirectoryRepository(),
  ActivityDirectoryRepository activityDirectoryRepository =
      const UnavailableActivityDirectoryRepository(),
  PersonDirectoryRepository personDirectoryRepository =
      const UnavailablePersonDirectoryRepository(),
  AccessProfileRepository accessProfileRepository = const UnavailableAccessProfileRepository(),
  ResetPasswordAction resetPassword = unavailableResetPassword,
  String catalogUrl = const String.fromEnvironment(
    'COELO_CATALOG_URL',
    defaultValue: 'https://catalog.coelo.me',
  ),
  ValueChanged<Uri>? openExternalCatalog,
  SupportPrototypeController? supportController,
  UserPreferencesController? userPreferencesController,
  bool allowDevelopmentPreview = !kReleaseMode || SuperadminAppConfig.environment == 'local',
  required ValueChanged<ThemeMode> onThemeModeChanged,
}) {
  final sessionSupportController = supportController ?? SupportPrototypeController();
  final accountActivities = SuperadminActivityController();
  final operationalActivities = SuperadminActivityController();
  final operationalStore = SuperadminPrototypeStore(activityController: operationalActivities);
  final planRepository = FakePlanCatalogRepository(store: operationalStore);
  final importRepository = FakeImportRepository();
  final inviteRepository = FakeInviteRepository(prototypeStore: operationalStore);
  final noticeRepository = FakeNoticeRepository(store: operationalStore);
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
  final prototypeRepository = institutionDirectoryRepository is FakeInstitutionDirectoryRepository
      ? institutionDirectoryRepository
      : FakeInstitutionDirectoryRepository();
  final unitRepository = FakeUnitDirectoryRepository(prototypeRepository);
  final groupRepository = FakeGroupDirectoryRepository(prototypeRepository);
  final activityPreviewRepository = FakeActivityDirectoryRepository();
  final attendanceActivities = SuperadminActivityController();
  final attendanceRepository = InMemoryAttendanceRepository.seeded(
    activities: attendanceActivities,
  );
  final dailyRoutineRepository = InMemoryDailyRoutineRepository.seeded(
    activities: attendanceActivities,
  );
  final healthSafetyRepository = DemoHealthSafetyRepository();
  final accessProfilePreviewRepository = FakeAccessProfileRepository();
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
      GroupFormSaveResult.created => 'Grupo criado com sucesso.',
      GroupFormSaveResult.updated => 'Alterações do grupo salvas com sucesso.',
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
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          final location = state.matchedLocation;
          final routedChild = _usesPersistentShell(location)
              ? SuperadminShell.host(
                  key: const Key('superadmin-persistent-shell'),
                  logout: logout,
                  currentDestination: _destinationForLocation(location),
                  onDestinationSelected: (destination) =>
                      _navigateFromPersistentShell(context, destination),
                  onBugReportSubmitted: sessionSupportController.submitReport,
                  child: child,
                )
              : child;
          return DevMenuOverlay(
            onNavigate: context.go,
            showTrigger:
                location != SuperadminRoutes.conversations &&
                location != SuperadminRoutes.devConversations,
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
              repository: prototypeRepository,
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
              repository: prototypeRepository,
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
              repository: prototypeRepository,
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
              logout: logout,
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
              institutions: prototypeRepository,
              repository: groupRepository,
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.groupsName),
              onSaved: (result) => context.goNamed(SuperadminRoutes.groupsName, extra: result),
              onBugReportSubmitted: sessionSupportController.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.groupEdit,
            name: SuperadminRoutes.groupEditName,
            builder: (context, state) => GroupFormPage(
              institutions: prototypeRepository,
              repository: groupRepository,
              groupId: state.pathParameters['groupId'],
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.groupsName),
              onSaved: (result) => context.goNamed(SuperadminRoutes.groupsName, extra: result),
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
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.activityEditName,
                pathParameters: {'activityId': id},
              ),
              onView: (id) => context.goNamed(
                SuperadminRoutes.activityDetailName,
                pathParameters: {'activityId': id},
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
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.activitiesName),
              onPrototypeSubmitted: () => context.goNamed(SuperadminRoutes.activitiesName),
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
              onCancel: () => context.goNamed(
                SuperadminRoutes.activityDetailName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
              onPrototypeSubmitted: () => context.goNamed(
                SuperadminRoutes.activityDetailName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
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
              permissions: const AttendancePermissions.owner(),
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
              permissions: const AttendancePermissions.owner(),
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.attendanceName),
              onCreated: (id) => context.goNamed(
                SuperadminRoutes.attendanceCallName,
                pathParameters: {'callId': id},
              ),
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
              permissions: const AttendancePermissions.owner(),
              logout: logout,
              onBack: () => context.goNamed(SuperadminRoutes.attendanceName),
              onPreview: () => context.goNamed(
                SuperadminRoutes.attendanceTeacherPreviewName,
                pathParameters: {'callId': state.pathParameters['callId']!},
              ),
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.attendanceTeacherPreview,
            name: SuperadminRoutes.attendanceTeacherPreviewName,
            builder: (context, state) => AttendanceTeacherPreviewPage(
              repository: attendanceRepository,
              callId: state.pathParameters['callId']!,
              permissions: const AttendancePermissions.teacher(
                assignedGroupIds: {'group-sun'},
                assignedActivityContextIds: {'activity-music-group-sun'},
              ),
              onBack: () => context.goNamed(
                SuperadminRoutes.attendanceCallName,
                pathParameters: {'callId': state.pathParameters['callId']!},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.dailyRoutine,
            name: SuperadminRoutes.dailyRoutineName,
            builder: (context, state) => DailyRoutineDirectoryPage(
              repository: dailyRoutineRepository,
              permissions: DailyRoutinePermissions.owner,
              logout: logout,
              activityController: attendanceActivities,
              onCreate: () => context.goNamed(SuperadminRoutes.dailyRoutineCreateName),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.dailyRoutineEditName,
                pathParameters: {'modelId': id},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.dailyRoutineCreate,
            name: SuperadminRoutes.dailyRoutineCreateName,
            builder: (context, state) => DailyRoutineEditorPage(
              repository: dailyRoutineRepository,
              permissions: DailyRoutinePermissions.owner,
              logout: logout,
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.dailyRoutineEdit,
            name: SuperadminRoutes.dailyRoutineEditName,
            builder: (context, state) => DailyRoutineEditorPage(
              repository: dailyRoutineRepository,
              permissions: DailyRoutinePermissions.owner,
              logout: logout,
              modelId: state.pathParameters['modelId'],
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthSafety,
            name: SuperadminRoutes.healthSafetyName,
            builder: (context, state) => HealthSafetyDirectoryPage(
              controller: HealthSafetyController(healthSafetyRepository),
              logout: logout,
              onChildSelected: (childId) => context.pushNamed(
                SuperadminRoutes.healthSafetyDetailName,
                pathParameters: {'childId': childId},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.healthSafetyDetail,
            name: SuperadminRoutes.healthSafetyDetailName,
            builder: (context, state) => HealthSafetyDetailPage(
              controller: HealthSafetyController(healthSafetyRepository),
              childId: state.pathParameters['childId']!,
              logout: logout,
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
            path: SuperadminRoutes.personCreate,
            name: SuperadminRoutes.personCreateName,
            builder: (context, state) => PersonFormPage(
              repository: personDirectoryRepository,
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.peopleName),
              onSaved: (_) =>
                  context.goNamed(SuperadminRoutes.peopleName, extra: 'Pessoa criada com sucesso.'),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.personEdit,
            name: SuperadminRoutes.personEditName,
            builder: (context, state) => PersonEditRoutePage(
              personId: state.pathParameters['personId']!,
              repository: personDirectoryRepository,
              logout: logout,
              onCancel: () => context.goNamed(SuperadminRoutes.peopleName),
              onSaved: (_) => context.goNamed(
                SuperadminRoutes.peopleName,
                extra: 'Alterações salvas com sucesso.',
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromPersistentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.profiles,
            name: SuperadminRoutes.profilesName,
            builder: (context, state) => AccessProfileDirectoryPage(
              repository: accessProfileRepository,
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
            path: SuperadminRoutes.profileCreate,
            name: SuperadminRoutes.profileCreateName,
            builder: (context, state) {
              final domain = _accessDomainOrNull(state.pathParameters['domain']);
              if (domain == null) {
                return _invalidAccessProfileRoute(context, SuperadminRoutes.profilesName);
              }
              return AccessProfileFormPage(
                repository: accessProfileRepository,
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
              contextOptions: institutionContextOptions(prototypeRepository.records),
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
              repository: prototypeRepository,
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
              repository: prototypeRepository,
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
              repository: prototypeRepository,
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
              repository: unitRepository,
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
              repository: unitRepository,
              logout: _previewLogout,
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
              repository: unitRepository,
              unitId: state.pathParameters['unitId'],
              logout: _previewLogout,
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
              repository: groupRepository,
              logout: _previewLogout,
              successMessage: groupSuccessMessage(state.extra),
              onCreate: () => context.goNamed(SuperadminRoutes.devGroupCreateName),
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
              institutions: prototypeRepository,
              repository: groupRepository,
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devGroupsName),
              onSaved: (result) => context.goNamed(SuperadminRoutes.devGroupsName, extra: result),
              onBugReportSubmitted: sessionSupportController.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devGroupEdit,
            name: SuperadminRoutes.devGroupEditName,
            builder: (context, state) => GroupFormPage(
              institutions: prototypeRepository,
              repository: groupRepository,
              groupId: state.pathParameters['groupId'],
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devGroupsName),
              onSaved: (result) => context.goNamed(SuperadminRoutes.devGroupsName, extra: result),
              onBugReportSubmitted: sessionSupportController.submitReport,
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devActivities,
            name: SuperadminRoutes.devActivitiesName,
            builder: (context, state) => ActivityDirectoryPage(
              repository: activityPreviewRepository,
              logout: _previewLogout,
              onCreate: () => context.goNamed(SuperadminRoutes.devActivityCreateName),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.devActivityEditName,
                pathParameters: {'activityId': id},
              ),
              onView: (id) => context.goNamed(
                SuperadminRoutes.devActivityDetailName,
                pathParameters: {'activityId': id},
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
              repository: activityPreviewRepository,
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devActivitiesName),
              onPrototypeSubmitted: () => context.goNamed(SuperadminRoutes.devActivitiesName),
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
              repository: activityPreviewRepository,
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
              repository: activityPreviewRepository,
              logout: _previewLogout,
              onCancel: () => context.goNamed(
                SuperadminRoutes.devActivityDetailName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
              onPrototypeSubmitted: () => context.goNamed(
                SuperadminRoutes.devActivityDetailName,
                pathParameters: {'activityId': state.pathParameters['activityId']!},
              ),
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
              permissions: const AttendancePermissions.owner(),
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
              permissions: const AttendancePermissions.owner(),
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devAttendanceName),
              onCreated: (id) => context.goNamed(
                SuperadminRoutes.devAttendanceCallName,
                pathParameters: {'callId': id},
              ),
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
              permissions: const AttendancePermissions.owner(),
              logout: _previewLogout,
              onBack: () => context.goNamed(SuperadminRoutes.devAttendanceName),
              onPreview: () => context.goNamed(
                SuperadminRoutes.devAttendanceTeacherPreviewName,
                pathParameters: {'callId': state.pathParameters['callId']!},
              ),
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAttendanceTeacherPreview,
            name: SuperadminRoutes.devAttendanceTeacherPreviewName,
            builder: (context, state) => AttendanceTeacherPreviewPage(
              repository: attendanceRepository,
              callId: state.pathParameters['callId']!,
              permissions: const AttendancePermissions.teacher(
                assignedGroupIds: {'group-sun'},
                assignedActivityContextIds: {'activity-music-group-sun'},
              ),
              onBack: () => context.goNamed(
                SuperadminRoutes.devAttendanceCallName,
                pathParameters: {'callId': state.pathParameters['callId']!},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devDailyRoutine,
            name: SuperadminRoutes.devDailyRoutineName,
            builder: (context, state) => DailyRoutineDirectoryPage(
              repository: dailyRoutineRepository,
              permissions: DailyRoutinePermissions.owner,
              logout: _previewLogout,
              activityController: attendanceActivities,
              onCreate: () => context.goNamed(SuperadminRoutes.devDailyRoutineCreateName),
              onEdit: (id) => context.goNamed(
                SuperadminRoutes.devDailyRoutineEditName,
                pathParameters: {'modelId': id},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devDailyRoutineCreate,
            name: SuperadminRoutes.devDailyRoutineCreateName,
            builder: (context, state) => DailyRoutineEditorPage(
              repository: dailyRoutineRepository,
              permissions: DailyRoutinePermissions.owner,
              logout: _previewLogout,
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devDailyRoutineEdit,
            name: SuperadminRoutes.devDailyRoutineEditName,
            builder: (context, state) => DailyRoutineEditorPage(
              repository: dailyRoutineRepository,
              permissions: DailyRoutinePermissions.owner,
              logout: _previewLogout,
              modelId: state.pathParameters['modelId'],
              activityController: attendanceActivities,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthSafety,
            name: SuperadminRoutes.devHealthSafetyName,
            builder: (context, state) => HealthSafetyDirectoryPage(
              controller: HealthSafetyController(healthSafetyRepository),
              logout: _previewLogout,
              onChildSelected: (childId) => context.pushNamed(
                SuperadminRoutes.devHealthSafetyDetailName,
                pathParameters: {'childId': childId},
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devHealthSafetyDetail,
            name: SuperadminRoutes.devHealthSafetyDetailName,
            builder: (context, state) => HealthSafetyDetailPage(
              controller: HealthSafetyController(healthSafetyRepository),
              childId: state.pathParameters['childId']!,
              logout: _previewLogout,
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
            path: SuperadminRoutes.devPersonCreate,
            name: SuperadminRoutes.devPersonCreateName,
            builder: (context, state) => PersonFormPage(
              repository: peoplePreviewRepository,
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devPeopleName),
              onSaved: (_) => context.goNamed(
                SuperadminRoutes.devPeopleName,
                extra: 'Pessoa criada com sucesso.',
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devPersonEdit,
            name: SuperadminRoutes.devPersonEditName,
            builder: (context, state) => PersonEditRoutePage(
              personId: state.pathParameters['personId']!,
              repository: peoplePreviewRepository,
              logout: _previewLogout,
              onCancel: () => context.goNamed(SuperadminRoutes.devPeopleName),
              onSaved: (_) => context.goNamed(
                SuperadminRoutes.devPeopleName,
                extra: 'Alterações salvas com sucesso.',
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
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
            builder: (context, state) {
              final id = state.pathParameters['internalUserId']!;
              return PlatformUserDetailPage(
                repository: previewPlatformUsers(),
                internalUserId: id,
                capability: PlatformUserCapability.owner,
                logout: _previewLogout,
                onBack: () => context.goNamed(SuperadminRoutes.devInternalUsersName),
                onEdit: () => context.goNamed(
                  SuperadminRoutes.devInternalUserEditName,
                  pathParameters: {'internalUserId': id},
                ),
                onDestinationSelected: (destination) =>
                    _navigateFromDevelopmentShell(context, destination),
              );
            },
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
            path: SuperadminRoutes.devImports,
            name: SuperadminRoutes.devImportsName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Importações',
              subtitle: 'Execute importações locais determinísticas.',
              destination: 'import',
              child: ImportDirectoryPage(
                repository: importRepository,
                onNewImport: () => context.goNamed(SuperadminRoutes.devImportCreateName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devImportCreate,
            name: SuperadminRoutes.devImportCreateName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Nova importação',
              subtitle: 'Simule o envio e a validação de um arquivo.',
              destination: 'import',
              child: ImportWizardPage(
                controller: ImportWizardController(
                  repository: importRepository,
                  store: operationalStore,
                ),
                onFinished: () => context.goNamed(SuperadminRoutes.devImportsName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInvites,
            name: SuperadminRoutes.devInvitesName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Convites',
              subtitle: 'Gerencie convites fictícios e mascarados.',
              destination: 'invites',
              child: InviteDirectoryPage(
                repository: inviteRepository,
                onCreate: () => context.goNamed(SuperadminRoutes.devInviteCreateName),
                onOpen: (id) => context.goNamed(
                  SuperadminRoutes.devInviteDetailName,
                  pathParameters: {'inviteId': id},
                ),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInviteCreate,
            name: SuperadminRoutes.devInviteCreateName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Novo convite',
              subtitle: 'Envie um convite fictício com validade de 48 horas.',
              destination: 'invites',
              child: InviteFormPage(
                repository: inviteRepository,
                onSent: (_) => context.goNamed(SuperadminRoutes.devInvitesName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devInviteDetail,
            name: SuperadminRoutes.devInviteDetailName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Detalhe do convite',
              subtitle: 'Consulte o histórico e ações permitidas.',
              destination: 'invites',
              child: InviteDetailPage(
                repository: inviteRepository,
                inviteId: state.pathParameters['inviteId']!,
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devNotices,
            name: SuperadminRoutes.devNoticesName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Avisos',
              subtitle: 'Publique avisos fictícios para audiências identificadas.',
              destination: 'notices',
              child: NoticeDirectoryPage(
                repository: noticeRepository,
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
              subtitle: 'Revise o preview antes de publicar.',
              destination: 'notices',
              child: NoticeFormPage(
                repository: noticeRepository,
                onSaved: (_) => context.goNamed(SuperadminRoutes.devNoticesName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devNoticeEdit,
            name: SuperadminRoutes.devNoticeEditName,
            builder: (context, state) => operationalPage(
              context,
              title: 'Editar aviso',
              subtitle: 'Altere um aviso fictício.',
              destination: 'notices',
              child: NoticeFormPage(
                repository: noticeRepository,
                noticeId: state.pathParameters['noticeId'],
                onSaved: (_) => context.goNamed(SuperadminRoutes.devNoticesName),
              ),
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devAudit,
            name: SuperadminRoutes.devAuditName,
            builder: (context, state) => AuditDirectoryPage(
              store: operationalStore,
              logout: _previewLogout,
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
              contextOptions: institutionContextOptions(prototypeRepository.records),
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
            path: SuperadminRoutes.devProfiles,
            name: SuperadminRoutes.devProfilesName,
            builder: (context, state) => AccessProfileDirectoryPage(
              repository: accessProfilePreviewRepository,
              logout: _previewLogout,
              onCreate: (domain) => context.goNamed(
                SuperadminRoutes.devProfileCreateName,
                pathParameters: {'domain': domain.databaseValue},
              ),
              onOpen: (domain, id) => context.goNamed(
                SuperadminRoutes.devProfileDetailName,
                pathParameters: {'domain': domain.databaseValue, 'profileId': id},
              ),
              onDestinationSelected: (destination) =>
                  _navigateFromDevelopmentShell(context, destination),
              onBugReportSubmitted: sessionSupportController.submitReport,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.devProfileCreate,
            name: SuperadminRoutes.devProfileCreateName,
            builder: (context, state) {
              final domain = _accessDomainOrNull(state.pathParameters['domain']);
              if (domain == null) {
                return _invalidAccessProfileRoute(context, SuperadminRoutes.devProfilesName);
              }
              return AccessProfileFormPage(
                repository: accessProfilePreviewRepository,
                logout: _previewLogout,
                domain: domain,
                onCancel: () => context.goNamed(SuperadminRoutes.devProfilesName),
                onSaved: (profile) => context.goNamed(
                  SuperadminRoutes.devProfileDetailName,
                  pathParameters: {'domain': profile.domain.databaseValue, 'profileId': profile.id},
                ),
                onDestinationSelected: (destination) =>
                    _navigateFromDevelopmentShell(context, destination),
                onBugReportSubmitted: sessionSupportController.submitReport,
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devProfileDetail,
            name: SuperadminRoutes.devProfileDetailName,
            builder: (context, state) {
              final domain = _accessDomainOrNull(state.pathParameters['domain']);
              if (domain == null) {
                return _invalidAccessProfileRoute(context, SuperadminRoutes.devProfilesName);
              }
              final profileId = state.pathParameters['profileId']!;
              return AccessProfileDetailPage(
                repository: accessProfilePreviewRepository,
                logout: _previewLogout,
                domain: domain,
                profileId: profileId,
                onBack: () => context.goNamed(SuperadminRoutes.devProfilesName),
                onEdit: () => context.goNamed(
                  SuperadminRoutes.devProfileEditName,
                  pathParameters: {'domain': domain.databaseValue, 'profileId': profileId},
                ),
                onDeleted: () => context.goNamed(SuperadminRoutes.devProfilesName),
                onDestinationSelected: (destination) =>
                    _navigateFromDevelopmentShell(context, destination),
                onBugReportSubmitted: sessionSupportController.submitReport,
              );
            },
          ),
          GoRoute(
            path: SuperadminRoutes.devProfileEdit,
            name: SuperadminRoutes.devProfileEditName,
            builder: (context, state) {
              final domain = _accessDomainOrNull(state.pathParameters['domain']);
              if (domain == null) {
                return _invalidAccessProfileRoute(context, SuperadminRoutes.devProfilesName);
              }
              final profileId = state.pathParameters['profileId']!;
              return AccessProfileFormPage(
                repository: accessProfilePreviewRepository,
                logout: _previewLogout,
                domain: domain,
                profileId: profileId,
                onCancel: () => context.goNamed(
                  SuperadminRoutes.devProfileDetailName,
                  pathParameters: {'domain': domain.databaseValue, 'profileId': profileId},
                ),
                onSaved: (profile) => context.goNamed(
                  SuperadminRoutes.devProfileDetailName,
                  pathParameters: {'domain': profile.domain.databaseValue, 'profileId': profile.id},
                ),
                onDestinationSelected: (destination) =>
                    _navigateFromDevelopmentShell(context, destination),
                onBugReportSubmitted: sessionSupportController.submitReport,
              );
            },
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
  return !location.startsWith('/dev/') &&
      location != SuperadminRoutes.login &&
      location != SuperadminRoutes.forgotPassword &&
      location != SuperadminRoutes.resetPassword;
}

String _destinationForLocation(String location) {
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
  if (location.startsWith('/health-safety')) {
    return 'health-safety';
  }
  if (location.startsWith('/people')) {
    return 'people';
  }
  if (location.startsWith('/profiles')) {
    return 'profiles';
  }
  return switch (location) {
    SuperadminRoutes.home => 'home',
    SuperadminRoutes.governanceCatalog => 'catalog',
    SuperadminRoutes.support => 'support',
    SuperadminRoutes.conversations => 'conversations',
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
    case 'health-safety':
      context.goNamed(SuperadminRoutes.healthSafetyName);
    case 'people':
      context.goNamed(SuperadminRoutes.peopleName);
    case 'profiles':
      context.goNamed(SuperadminRoutes.profilesName);
    case 'catalog':
      context.goNamed(SuperadminRoutes.governanceCatalogName);
    case 'support':
      context.goNamed(SuperadminRoutes.supportName);
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
    case 'people':
      context.goNamed(SuperadminRoutes.devPeopleName);
    case 'profiles':
      context.goNamed(SuperadminRoutes.devProfilesName);
    case 'plans':
      context.goNamed(SuperadminRoutes.devPlansName);
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
    case 'catalog':
      context.goNamed(SuperadminRoutes.devCatalogName);
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
