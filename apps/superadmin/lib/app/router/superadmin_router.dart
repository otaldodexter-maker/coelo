import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/guards/superadmin_session.dart';
import '../../features/auth/domain/login_request.dart';
import '../../features/auth/domain/logout_action.dart';
import '../../features/auth/presentation/screens/superadmin_login_screen.dart';
import '../shell/superadmin_shell.dart';
import 'superadmin_routes.dart';

GoRouter createSuperadminRouter({
  required SuperadminSession session,
  required LoginAction login,
  required LogoutAction logout,
  required ValueChanged<ThemeMode> onThemeModeChanged,
}) {
  return GoRouter(
    initialLocation: SuperadminRoutes.login,
    refreshListenable: session,
    redirect: (context, state) {
      final isOnLogin = state.matchedLocation == SuperadminRoutes.login;
      if (!session.isAuthenticated) {
        return isOnLogin ? null : SuperadminRoutes.login;
      }
      return isOnLogin ? SuperadminRoutes.home : null;
    },
    routes: [
      GoRoute(
        path: SuperadminRoutes.login,
        name: SuperadminRoutes.loginName,
        builder: (context, state) => SuperadminLoginScreen(
          session: session,
          login: login,
          onThemeModeChanged: onThemeModeChanged,
        ),
      ),
      GoRoute(
        path: SuperadminRoutes.home,
        name: SuperadminRoutes.homeName,
        builder: (context, state) => SuperadminShell(logout: logout),
      ),
    ],
  );
}
