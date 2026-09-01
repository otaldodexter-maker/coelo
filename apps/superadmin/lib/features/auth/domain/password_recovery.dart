import 'package:coelo_auth/coelo_auth.dart';

typedef PasswordRecoveryAction = Future<PasswordRecoveryResult> Function(String email);

final class PasswordRecoveryResult {
  const PasswordRecoveryResult._({required this.isSuccess, this.message});

  const PasswordRecoveryResult.success() : this._(isSuccess: true);

  const PasswordRecoveryResult.failure(String message) : this._(isSuccess: false, message: message);

  final bool isSuccess;
  final String? message;
}

PasswordRecoveryAction createCoeloAuthPasswordRecoveryAction({
  required CoeloAuthGateway auth,
  required Uri redirectTo,
}) {
  return (email) async {
    final result = await auth.requestPasswordRecovery(email: email, redirectTo: redirectTo);
    if (result.isSuccess) {
      return const PasswordRecoveryResult.success();
    }

    return PasswordRecoveryResult.failure(
      result.message ?? CoeloAuthPasswordRecoveryResult.genericFailureMessage,
    );
  };
}

Future<PasswordRecoveryResult> unavailableSuperadminPasswordRecovery(String email) {
  return Future.value(
    const PasswordRecoveryResult.failure(CoeloAuthPasswordRecoveryResult.genericFailureMessage),
  );
}
