import 'package:flutter/foundation.dart';

import '../../domain/login_request.dart';

final class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required LoginAction login}) : _login = login;

  static const genericErrorMessage =
      'Não foi possível entrar. Verifique os dados e tente novamente.';

  final LoginAction _login;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _keepSessionOpen = false;
  bool _isDisposed = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isPasswordVisible => _isPasswordVisible;
  bool get keepSessionOpen => _keepSessionOpen;
  String? get errorMessage => _errorMessage;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    _notifyIfActive();
  }

  void setKeepSessionOpen({required bool value}) {
    _keepSessionOpen = value;
    _notifyIfActive();
  }

  Future<bool> submit(LoginRequest request) async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _notifyIfActive();

    try {
      final result = await _login(request);
      if (result.isSuccess) {
        return true;
      }

      _errorMessage = result.message ?? genericErrorMessage;
      return false;
    } on Exception {
      _errorMessage = genericErrorMessage;
      return false;
    } finally {
      _isLoading = false;
      _notifyIfActive();
    }
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
