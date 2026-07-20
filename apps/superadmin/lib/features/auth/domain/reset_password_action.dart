typedef ResetPasswordAction = Future<ResetPasswordResult> Function(String password);

final class ResetPasswordResult {
  const ResetPasswordResult._({required this.isSuccess, this.message});

  const ResetPasswordResult.success() : this._(isSuccess: true);

  const ResetPasswordResult.failure(String message) : this._(isSuccess: false, message: message);

  final bool isSuccess;
  final String? message;
}

Future<ResetPasswordResult> unavailableResetPassword(String password) {
  return Future.value(
    const ResetPasswordResult.failure('Redefinição de senha ainda não está conectada.'),
  );
}
