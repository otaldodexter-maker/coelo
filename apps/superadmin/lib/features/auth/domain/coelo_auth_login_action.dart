import 'package:coelo_auth/coelo_auth.dart';

import '../../../../core/guards/superadmin_session.dart';
import 'login_request.dart';

LoginAction createCoeloAuthLoginAction({
  required CoeloAuthGateway auth,
  required SuperadminSession session,
}) {
  return (request) async {
    final result = await auth.signInWithPassword(
      email: request.email,
      password: request.password,
      persistSession: request.keepSessionOpen,
    );

    if (result.isSuccess) {
      session.signIn();
      return const LoginResult.success();
    }

    return LoginResult.failure(result.message ?? CoeloAuthSignInResult.genericFailureMessage);
  };
}
