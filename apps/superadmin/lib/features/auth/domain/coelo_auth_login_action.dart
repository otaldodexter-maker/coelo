import 'package:coelo_auth/coelo_auth.dart';

import '../../../../core/guards/superadmin_session.dart';
import 'login_request.dart';
import 'superadmin_auth_context.dart';

LoginAction createCoeloAuthLoginAction({
  required CoeloAuthLifecycleGateway auth,
  required SuperadminAuthContextGateway authContext,
  required SuperadminSession session,
  Future<bool> Function()? prepareAuthorization,
  void Function()? onAuthorizationCommitted,
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
        var mediaPrepared = prepareAuthorization == null;
        final beforePurge = auth.currentSessionState;
        if (context != null &&
            session.authorizationInvalidationRevision == expectedRevision &&
            authenticatedState.kind == CoeloAuthSessionKind.authenticated &&
            authenticatedState.sessionId != null &&
            beforePurge.kind == CoeloAuthSessionKind.authenticated &&
            beforePurge.sessionId == authenticatedState.sessionId) {
          try {
            mediaPrepared = await prepareAuthorization?.call() ?? true;
          } catch (_) {
            mediaPrepared = false;
          }
        }
        final latestState = auth.currentSessionState;
        // TEMP-DIAG (nao commitar)
        // ignore: avoid_print
        print('login-diag: mediaPrepared=$mediaPrepared context=${context != null} authKind=${authenticatedState.kind} sid=${authenticatedState.sessionId != null} latestKind=${latestState.kind} sameSid=${latestState.sessionId == authenticatedState.sessionId} rev=${session.authorizationInvalidationRevision}/$expectedRevision');
        final authorized =
            mediaPrepared &&
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
          if (latestState.sessionId != null &&
              latestState.sessionId != authenticatedState.sessionId) {
            // A replacement credential may still be awaiting its own bootstrap.
            // Retire only this stale local context; never revoke the new token.
            if (session.authorizationInvalidationRevision == expectedRevision) {
              session.signOut();
            }
            return const LoginResult.failure(CoeloAuthSignInResult.genericFailureMessage);
          }
          final cleanupRevision = session.authorizationInvalidationRevision;
          try {
            await auth.signOut();
          } catch (_) {
            // Cleanup can fail before or after local credential teardown.
            // Keep login denied and protect newer authorization below.
          }
          if (session.authorizationInvalidationRevision == cleanupRevision) {
            session.signOut();
          }
          return const LoginResult.failure(CoeloAuthSignInResult.genericFailureMessage);
        }
        onAuthorizationCommitted?.call();
        // TEMP-DIAG (nao commitar)
        // ignore: avoid_print
        print('login-diag: success');
        return const LoginResult.success();
      }

      // TEMP-DIAG (nao commitar)
      // ignore: avoid_print
      print('login-diag: signIn failed: ${result.message}');
      return LoginResult.failure(result.message ?? CoeloAuthSignInResult.genericFailureMessage);
    } finally {
      inProgress = false;
    }
  };
}
