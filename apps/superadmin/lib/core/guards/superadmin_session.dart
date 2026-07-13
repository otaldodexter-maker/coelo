import 'package:flutter/foundation.dart';

final class SuperadminSession extends ChangeNotifier {
  SuperadminSession({bool isAuthenticated = false}) : _isAuthenticated = isAuthenticated;

  bool _isAuthenticated;

  bool get isAuthenticated => _isAuthenticated;

  void signIn() => _setAuthentication(value: true);

  void signOut() => _setAuthentication(value: false);

  void _setAuthentication({required bool value}) {
    if (_isAuthenticated == value) {
      return;
    }
    _isAuthenticated = value;
    notifyListeners();
  }
}
