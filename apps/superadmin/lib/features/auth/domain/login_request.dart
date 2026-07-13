typedef LoginAction = Future<LoginResult> Function(LoginRequest request);

final class LoginRequest {
  const LoginRequest({required this.email, required this.password, required this.keepSessionOpen});

  final String email;
  final String password;
  final bool keepSessionOpen;
}

final class LoginResult {
  const LoginResult._({required this.isSuccess, this.message});

  const LoginResult.success() : this._(isSuccess: true);

  const LoginResult.failure(String message) : this._(isSuccess: false, message: message);

  final bool isSuccess;
  final String? message;
}

Future<LoginResult> unavailableSuperadminLogin(LoginRequest request) {
  return Future.value(const LoginResult.failure('Autenticação ainda não está conectada.'));
}
