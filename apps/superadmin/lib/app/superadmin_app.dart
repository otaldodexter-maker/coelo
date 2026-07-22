import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/superadmin_app_config.dart';
import '../core/guards/superadmin_session.dart';
import '../features/auth/domain/login_request.dart';
import '../features/auth/domain/logout_action.dart';
import '../features/auth/domain/password_recovery.dart';
import '../features/auth/domain/reset_password_action.dart';
import '../features/institutions/data/supabase_institution_directory_repository.dart';
import '../features/institutions/domain/institution_directory_repository.dart';
import 'router/superadmin_router.dart';
import 'theme/superadmin_theme_mode_scope.dart';

class SuperadminApp extends StatefulWidget {
  const SuperadminApp({
    this.session,
    this.login = unavailableSuperadminLogin,
    this.logout = unavailableSuperadminLogout,
    this.requestPasswordRecovery = unavailableSuperadminPasswordRecovery,
    this.resetPassword = unavailableResetPassword,
    this.institutionDirectoryRepository = const UnavailableInstitutionDirectoryRepository(),
    super.key,
  });

  final SuperadminSession? session;
  final LoginAction login;
  final LogoutAction logout;
  final PasswordRecoveryAction requestPasswordRecovery;
  final ResetPasswordAction resetPassword;
  final InstitutionDirectoryRepository institutionDirectoryRepository;

  @override
  State<SuperadminApp> createState() => _SuperadminAppState();
}

class _SuperadminAppState extends State<SuperadminApp> {
  late final SuperadminSession _session;
  late final GoRouter _router;
  late final bool _ownsSession;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.session == null;
    _session = widget.session ?? SuperadminSession();
    _router = createSuperadminRouter(
      session: _session,
      login: widget.login,
      logout: widget.logout,
      requestPasswordRecovery: widget.requestPasswordRecovery,
      resetPassword: widget.resetPassword,
      institutionDirectoryRepository: widget.institutionDirectoryRepository,
      onThemeModeChanged: _setThemeMode,
    );
  }

  void _setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  void dispose() {
    _router.dispose();
    if (_ownsSession) {
      _session.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return MaterialApp.router(
      title: SuperadminAppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: _themeMode,
      themeAnimationStyle: reduceMotion
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 420), curve: Curves.easeInOut),
      builder: (context, child) => SuperadminThemeModeScope(
        mode: _themeMode,
        onChanged: _setThemeMode,
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: _router,
    );
  }
}
