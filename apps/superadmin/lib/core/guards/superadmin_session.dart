import 'dart:async';

import 'package:flutter/foundation.dart';

final class SuperadminSession extends ChangeNotifier {
  SuperadminSession({bool isAuthenticated = false, Stream<bool>? authStateChanges})
    : _isAuthenticated = isAuthenticated {
    _authStateSubscription = authStateChanges?.distinct().listen(
      (isAuthenticated) => _setAuthentication(value: isAuthenticated),
      onError: _reportAuthStateError,
    );
  }

  bool _isAuthenticated;
  StreamSubscription<bool>? _authStateSubscription;

  bool get isAuthenticated => _isAuthenticated;

  void signIn() => _setAuthentication(value: true);

  void signOut() => _setAuthentication(value: false);

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
    if (_isAuthenticated == value) {
      return;
    }
    _isAuthenticated = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
