import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:coelo_auth/coelo_auth.dart';

import '../../features/auth/domain/superadmin_auth_context.dart';

final class SuperadminSession extends ChangeNotifier {
  SuperadminSession({
    bool isPasswordRecovery = false,
    Stream<bool>? authStateChanges,
    Stream<CoeloAuthSessionState>? authSessionStateChanges,
  }) : _isAuthenticated = isPasswordRecovery,
       _authContext = null,
       _isPasswordRecovery = isPasswordRecovery {
    _authStateSubscription = authStateChanges?.distinct().listen(
      (isAuthenticated) => _setAuthentication(value: isAuthenticated),
      onError: _reportAuthStateError,
    );
    _authSessionStateSubscription = authSessionStateChanges?.distinct().listen(
      _handleAuthSessionState,
      onError: _reportAuthStateError,
    );
  }

  bool _isAuthenticated;
  bool _isPasswordRecovery;
  SuperadminAuthContext? _authContext;
  String? _sessionId;
  int _authorizationInvalidationRevision = 0;
  StreamSubscription<bool>? _authStateSubscription;
  StreamSubscription<CoeloAuthSessionState>? _authSessionStateSubscription;

  bool get isAuthenticated => _isAuthenticated;
  bool get isPasswordRecovery => _isPasswordRecovery;
  SuperadminAuthContext? get authContext => _authContext;
  int get authorizationInvalidationRevision => _authorizationInvalidationRevision;

  void authorize(SuperadminAuthContext context, {required String sessionId}) {
    _authContext = context;
    _sessionId = sessionId;
    _setSessionState(CoeloAuthSessionState.authenticated(sessionId: sessionId));
  }

  bool authorizeIfCurrent(
    SuperadminAuthContext context, {
    required String sessionId,
    required int expectedInvalidationRevision,
  }) {
    if (_authorizationInvalidationRevision != expectedInvalidationRevision) {
      return false;
    }
    authorize(context, sessionId: sessionId);
    return true;
  }

  @visibleForTesting
  void signInForTesting() => authorize(
    const SuperadminAuthContext(
      platformRoleCode: 'test-role',
      scopeKind: SuperadminAuthScopeKind.platform,
      permissionCodes: {'platform.read'},
      aal: 'aal1',
    ),
    sessionId: '00000000-0000-4000-8000-000000000001',
  );

  void signOut() => _setSessionState(const CoeloAuthSessionState.signedOut());

  void _reportAuthStateError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'superadmin_session',
        context: ErrorDescription('while listening to auth state changes'),
      ),
    );
  }

  void _setAuthentication({required bool value}) {
    if (value && _authContext == null) {
      return;
    }
    _setSessionState(
      value ? const CoeloAuthSessionState.authenticated() : const CoeloAuthSessionState.signedOut(),
    );
  }

  void _handleAuthSessionState(CoeloAuthSessionState state) {
    if (state.kind == CoeloAuthSessionKind.authenticated) {
      if (_authContext == null) return;
      if (state.sessionId == null || state.sessionId != _sessionId) {
        _setSessionState(const CoeloAuthSessionState.signedOut());
        return;
      }
    }
    _setSessionState(state);
  }

  void _setSessionState(CoeloAuthSessionState state) {
    if (!state.isAuthenticated || state.isPasswordRecovery) {
      _authorizationInvalidationRevision++;
      _authContext = null;
      _sessionId = null;
    }
    if (_isAuthenticated == state.isAuthenticated &&
        _isPasswordRecovery == state.isPasswordRecovery) {
      return;
    }
    _isAuthenticated = state.isAuthenticated;
    _isPasswordRecovery = state.isPasswordRecovery;
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _authSessionStateSubscription?.cancel();
    super.dispose();
  }
}
