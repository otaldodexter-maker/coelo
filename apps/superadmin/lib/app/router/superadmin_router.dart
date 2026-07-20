import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/guards/superadmin_session.dart';
import '../../features/auth/domain/login_request.dart';
import '../../features/auth/domain/logout_action.dart';
import '../../features/auth/domain/password_recovery.dart';
import '../../features/auth/domain/reset_password_action.dart';
import '../../features/auth/presentation/screens/superadmin_forgot_password_screen.dart';
import '../../features/auth/presentation/screens/superadmin_login_screen.dart';
import '../../features/auth/presentation/screens/superadmin_reset_password_screen.dart';
import '../../features/institutions/data/fake_institution_directory_repository.dart';
import '../../features/institutions/data/supabase_institution_directory_repository.dart';
import '../../features/institutions/domain/institution_directory_repository.dart';
import '../../features/institutions/presentation/screens/institution_directory_page.dart';
import '../dev_menu/dev_menu_overlay.dart';
import 'superadmin_routes.dart';

GoRouter createSuperadminRouter({
  required SuperadminSession session,
  required LoginAction login,
  required LogoutAction logout,
  required PasswordRecoveryAction requestPasswordRecovery,
  InstitutionDirectoryRepository institutionDirectoryRepository =
      const UnavailableInstitutionDirectoryRepository(),
  ResetPasswordAction resetPassword = unavailableResetPassword,
  required ValueChanged<ThemeMode> onThemeModeChanged,
}) {
  return GoRouter(
    initialLocation: SuperadminRoutes.login,
    refreshListenable: session,
    redirect: (context, state) {
      final location = state.matchedLocation;
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
      if (isOnPublicAuthRoute || location == SuperadminRoutes.home) {
        return SuperadminRoutes.institutions;
      }
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => DevMenuOverlay(onNavigate: context.go, child: child),
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
            builder: (context, state) => InstitutionDirectoryPage(
              repository: institutionDirectoryRepository,
              logout: logout,
            ),
          ),
          GoRoute(
            path: SuperadminRoutes.institutions,
            name: SuperadminRoutes.institutionsName,
            builder: (context, state) => InstitutionDirectoryPage(
              repository: institutionDirectoryRepository,
              logout: logout,
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
            path: SuperadminRoutes.devInstitutions,
            name: SuperadminRoutes.devInstitutionsName,
            builder: (context, state) => const InstitutionDirectoryPage(
              repository: FakeInstitutionDirectoryRepository(),
              logout: _previewLogout,
            ),
          ),
        ],
      ),
    ],
  );
}

Future<LogoutResult> _previewLogout() async => const LogoutResult.success();
