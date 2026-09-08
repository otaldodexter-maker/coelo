import 'package:coelo_auth/coelo_auth.dart';

import '../../../../core/guards/superadmin_session.dart';
import 'login_request.dart';
import 'superadmin_auth_context.dart';

LoginAction createCoeloAuthLoginAction({
  required CoeloAuthLifecycleGateway auth,
  required SuperadminAuthContextGateway authContext,
  required SuperadminSession session,
}) {
  // The action outlives a login screen, including browser-history remounts.
  var inProgress = false;
  return (request) async {
    if (inProgress) {
      return const LoginResult.failure(CoeloAuthSignInResult.genericFailureMessage);
    }
    inProgress = true;
    try {
      final result = await auth.signInWithPassword(
        email: request.email,
        password: request.password,
        persistSession: request.keepSessionOpen,
      );

      if (result.isSuccess) {
        final authenticatedState = auth.currentSessionState;
        final expectedRevision = session.authorizationInvalidationRevision;
        final context = await authContext.bootstrap();
        final latestState = auth.currentSessionState;
        final authorized =
            context != null &&
            authenticatedState.kind == CoeloAuthSessionKind.authenticated &&
            authenticatedState.sessionId != null &&
            latestState.kind == CoeloAuthSessionKind.authenticated &&
            latestState.sessionId == authenticatedState.sessionId &&
            session.authorizeIfCurrent(
              context,
              sessionId: authenticatedState.sessionId!,
              expectedInvalidationRevision: expectedRevision,
            );
        if (!authorized) {
          final winningAuthorization =
              session.isAuthenticated &&
              session.sessionId != null &&
              session.sessionId == latestState.sessionId &&
              session.authorizationInvalidationRevision != expectedRevision;
          final recoveryArrivedDuringBootstrap =
              latestState.isPasswordRecovery &&
              latestState.sessionId != null &&
              session.isPasswordRecovery &&
              session.authorizationInvalidationRevision != expectedRevision;
          if (winningAuthorization || recoveryArrivedDuringBootstrap) {
            return const LoginResult.failure(CoeloAuthSignInResult.genericFailureMessage);
          }
          final cleanupRevision = session.authorizationInvalidationRevision;
          try {
            await auth.signOut();
          } on Exception {
            // Supabase clears its local session before the remote revoke request.
          }
          if (session.authorizationInvalidationRevision == cleanupRevision) {
            session.signOut();
          }
          return const LoginResult.failure(CoeloAuthSignInResult.genericFailureMessage);
        }
        return const LoginResult.success();
      }

      return LoginResult.failure(result.message ?? CoeloAuthSignInResult.genericFailureMessage);
    } finally {
      inProgress = false;
    }
  };
}
