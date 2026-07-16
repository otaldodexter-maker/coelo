import 'package:coelo_auth/coelo_auth.dart';

import '../../../../core/guards/superadmin_session.dart';

typedef LogoutAction = Future<LogoutResult> Function();

final class LogoutResult {
  const LogoutResult._({required this.isSuccess, this.message});

  const LogoutResult.success() : this._(isSuccess: true);

  const LogoutResult.failure(String message) : this._(isSuccess: false, message: message);

  static const genericFailureMessage =
      'Não foi possível sair. Verifique sua conexão e tente novamente.';

  final bool isSuccess;
  final String? message;
}

LogoutAction createCoeloAuthLogoutAction({
  required CoeloAuthGateway auth,
  required SuperadminSession session,
}) {
  return () async {
    try {
      await auth.signOut();
      session.signOut();
      return const LogoutResult.success();
    } on Exception {
      return const LogoutResult.failure(LogoutResult.genericFailureMessage);
    }
  };
}

Future<LogoutResult> unavailableSuperadminLogout() {
  return Future.value(const LogoutResult.failure(LogoutResult.genericFailureMessage));
}
