import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/config/superadmin_app_config.dart';
import '../core/guards/superadmin_session.dart';
import '../features/activities/data/supabase_activity_directory_repository.dart';
import '../features/activities/data/supabase_activity_command_repository.dart';
import '../features/activities/domain/activity_command.dart';
import '../features/activities/domain/activity_directory.dart';
import '../features/auth/domain/login_request.dart';
import '../features/auth/domain/logout_action.dart';
import '../features/auth/domain/password_recovery.dart';
import '../features/auth/domain/reset_password_action.dart';
import '../features/attendance/attendance.dart';
import '../features/attendance/data/supabase_attendance_repository.dart';
import '../features/account/data/user_preferences_repository.dart';
import '../features/account/presentation/user_preferences_controller.dart';
import '../features/institutions/data/supabase_institution_directory_repository.dart';
import '../features/institutions/domain/institution_directory_repository.dart';
import '../features/units/data/unavailable_unit_composition.dart';
import '../features/units/domain/unit_backend_commands.dart';
import '../features/units/domain/unit_directory.dart';
import '../features/people/data/supabase_person_directory_repository.dart';
import '../features/people/domain/person_directory.dart';
import '../features/people/domain/person_identity.dart';
import '../features/access_profiles/data/supabase_access_profile_repository.dart';
import '../features/access_profiles/data/unavailable_access_profile_extended_repository.dart';
import '../features/imports/domain/import_repository.dart';
import '../features/invites/domain/platform_invite.dart';
import '../features/notices/domain/notice_repository.dart';
import '../features/daily_routine/domain/routine_contract.dart';
import '../features/audit/domain/audit.dart';
import '../features/safety/application/child_safety_controller.dart';
import '../features/safety/domain/child_safety_contract.dart';

import '../features/access_profiles/domain/access_profile.dart';
import '../features/groups/data/supabase_group_directory_repository.dart';
import '../features/groups/domain/group_directory.dart';
import '../features/health_care/domain/medication_plan_repository.dart';
import 'router/superadmin_router.dart';
import 'theme/superadmin_theme_mode_scope.dart';

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
    this.activityDirectoryRepository = const UnavailableActivityDirectoryRepository(),
    this.activityCommandRepository = const UnavailableActivityCommandRepository(),
    this.personDirectoryRepository = const UnavailablePersonDirectoryRepository(),
    this.personIdentityRepository = const UnavailablePersonIdentityRepository(),
    this.unitDirectoryRepository = const UnavailableUnitDirectoryRepository(),
    this.unitBackendCommands = const UnavailableUnitBackendCommandsGateway(),
    this.accessProfileRepository = const UnavailableAccessProfileRepository(),
    this.accessProfileExtendedRepository = const UnavailableAccessProfileExtendedRepository(),
    this.importRepository = const UnavailableImportRepository(),
    this.inviteRepository = const UnavailableInviteRepository(),
    this.noticeRepository = const UnavailableNoticeRepository(),
    this.attendanceRepository = const UnavailableAttendanceRepository(),
    this.attendancePermissions = const AttendancePermissions.readOnly(),
    this.routineRepository = const UnavailableRoutineRepository(),
    this.auditRepository = const UnavailableAuditRepository(),
    this.childSafetyRepository = const UnavailableChildSafetyRepository(),
    this.medicationPlanRepository = const UnavailableMedicationPlanRepository(),
    this.userPreferencesRepository,
    super.key,
  });

  final SuperadminSession? session;
  final LoginAction login;
  final LogoutAction logout;
  final PasswordRecoveryAction requestPasswordRecovery;
  final ResetPasswordAction resetPassword;
  final InstitutionDirectoryRepository institutionDirectoryRepository;
  final GroupDirectoryRepository groupDirectoryRepository;
  final ActivityDirectoryRepository activityDirectoryRepository;
  final ActivityCommandRepository activityCommandRepository;
  final PersonDirectoryRepository personDirectoryRepository;
  final PersonIdentityRepository personIdentityRepository;
  final UnitDirectoryRepository unitDirectoryRepository;
  final UnitBackendCommandsGateway unitBackendCommands;
  final AccessProfileRepository accessProfileRepository;
  final AccessProfileExtendedRepository accessProfileExtendedRepository;
  final ImportRepository importRepository;
  final InviteRepository inviteRepository;
  final NoticeRepository noticeRepository;
  final AttendanceRepository attendanceRepository;
  final AttendancePermissions attendancePermissions;
  final RoutineRepository routineRepository;
  final AuditRepository auditRepository;
  final ChildSafetyRepository childSafetyRepository;
  final MedicationPlanRepository medicationPlanRepository;
  final UserPreferencesRepository? userPreferencesRepository;

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
    _preferencesController.load();
    _childSafetyController = ChildSafetyController(widget.childSafetyRepository);
    _router = createSuperadminRouter(
      session: _session,
      login: widget.login,
      logout: widget.logout,
      requestPasswordRecovery: widget.requestPasswordRecovery,
      resetPassword: widget.resetPassword,
      institutionDirectoryRepository: widget.institutionDirectoryRepository,
      groupDirectoryRepository: widget.groupDirectoryRepository,
      activityDirectoryRepository: widget.activityDirectoryRepository,
      activityCommandRepository: widget.activityCommandRepository,
      personDirectoryRepository: widget.personDirectoryRepository,
      personIdentityRepository: widget.personIdentityRepository,
      unitDirectoryRepository: widget.unitDirectoryRepository,
      unitBackendCommands: widget.unitBackendCommands,
      accessProfileRepository: widget.accessProfileRepository,
      accessProfileExtendedRepository: widget.accessProfileExtendedRepository,
      importRepository: widget.importRepository,
      inviteRepository: widget.inviteRepository,
      noticeRepository: widget.noticeRepository,
      attendanceRepository: widget.attendanceRepository,
      attendancePermissions: widget.attendancePermissions,
      routineRepository: widget.routineRepository,
      auditRepository: widget.auditRepository,
      childSafetyController: _childSafetyController,
      medicationPlanRepository: widget.medicationPlanRepository,
      userPreferencesController: _preferencesController,
      onThemeModeChanged: _setThemeMode,
    );
  }

  void _setThemeMode(ThemeMode mode) {
    _preferencesController.setThemeMode(mode);
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
