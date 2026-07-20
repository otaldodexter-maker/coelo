import 'package:flutter/foundation.dart';

import '../../domain/password_recovery.dart';

final class PasswordRecoveryViewModel extends ChangeNotifier {
  PasswordRecoveryViewModel({required PasswordRecoveryAction requestPasswordRecovery})
    : _requestPasswordRecovery = requestPasswordRecovery;

  static const genericErrorMessage =
      'Não foi possível enviar o e-mail de recuperação. Tente novamente.';

  final PasswordRecoveryAction _requestPasswordRecovery;

  bool _isLoading = false;
  bool _isSuccess = false;
  bool _isDisposed = false;
  String? _errorMessage;
  String? _email;

  bool get isLoading => _isLoading;
  bool get isSuccess => _isSuccess;
  String? get errorMessage => _errorMessage;
  String? get email => _email;

  Future<bool> submit(String email) {
    return _request(email.trim());
  }

  Future<bool> resend() {
    final email = _email;
    if (email == null) {
      return Future.value(false);
    }
    return _request(email);
  }

  Future<bool> _request(String email) async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _notifyIfActive();

    try {
      final result = await _requestPasswordRecovery(email);
      if (result.isSuccess) {
        _email = email;
        _isSuccess = true;
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
