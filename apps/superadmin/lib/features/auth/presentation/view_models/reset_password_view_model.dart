import 'package:flutter/foundation.dart';

import '../../domain/reset_password_action.dart';

final class ResetPasswordViewModel extends ChangeNotifier {
  ResetPasswordViewModel({required ResetPasswordAction resetPassword})
    : _resetPassword = resetPassword;

  static const genericErrorMessage = 'Não foi possível redefinir a senha. Tente novamente.';

  final ResetPasswordAction _resetPassword;

  bool _isLoading = false;
  bool _isSuccess = false;
  bool _isPasswordVisible = false;
  bool _isConfirmationVisible = false;
  bool _isDisposed = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isSuccess => _isSuccess;
  bool get isPasswordVisible => _isPasswordVisible;
  bool get isConfirmationVisible => _isConfirmationVisible;
  String? get errorMessage => _errorMessage;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    _notifyIfActive();
  }

  void toggleConfirmationVisibility() {
    _isConfirmationVisible = !_isConfirmationVisible;
    _notifyIfActive();
  }

  Future<bool> submit(String password) async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _isSuccess = false;
    _errorMessage = null;
    _notifyIfActive();

    try {
      final result = await _resetPassword(password);
      _isSuccess = result.isSuccess;
      _errorMessage = result.isSuccess ? null : result.message;
      return result.isSuccess;
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
