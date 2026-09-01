import 'package:coelo_auth/coelo_auth.dart';

typedef ResetPasswordAction = Future<ResetPasswordResult> Function(String password);

final class ResetPasswordResult {
  const ResetPasswordResult._({required this.isSuccess, this.message});

  const ResetPasswordResult.success() : this._(isSuccess: true);

  const ResetPasswordResult.failure(String message) : this._(isSuccess: false, message: message);

  final bool isSuccess;
  final String? message;
}

ResetPasswordAction createCoeloAuthResetPasswordAction({required CoeloAuthLifecycleGateway auth}) {
  return (password) async {
    final result = await auth.updatePassword(password: password);
    if (result.isSuccess) {
      return const ResetPasswordResult.success();
    }
    return ResetPasswordResult.failure(
      result.message ?? CoeloAuthPasswordUpdateResult.genericFailureMessage,
    );
  };
}

Future<ResetPasswordResult> unavailableResetPassword(String password) {
  return Future.value(
    const ResetPasswordResult.failure('Redefinição de senha ainda não está conectada.'),
  );
}
