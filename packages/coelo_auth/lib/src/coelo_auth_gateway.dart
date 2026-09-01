abstract interface class CoeloAuthGateway {
  bool get isAuthenticated;
  Stream<bool> get authStateChanges;

  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  });

  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecovery({
    required String email,
  });

  Future<void> signOut();
}

abstract class CoeloAuthLifecycleGateway implements CoeloAuthGateway {
  const CoeloAuthLifecycleGateway();

  CoeloAuthSessionState get currentSessionState;
  Stream<CoeloAuthSessionState> get authSessionStateChanges;

  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  });

  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecoveryWithRedirect({
    required String email,
    required Uri redirectTo,
  });

  Future<CoeloAuthPasswordUpdateResult> updatePassword({
    required String password,
  });

  @override
  bool get isAuthenticated =>
      currentSessionState.kind == CoeloAuthSessionKind.authenticated;

  @override
  Stream<bool> get authStateChanges => authSessionStateChanges
      .map((state) => state.kind == CoeloAuthSessionKind.authenticated)
      .distinct();

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecovery({
    required String email,
  }) {
    return Future.value(
      const CoeloAuthPasswordRecoveryResult.failure(
        CoeloAuthPasswordRecoveryResult.genericFailureMessage,
      ),
    );
  }
}

enum CoeloAuthSessionKind { signedOut, authenticated, passwordRecovery }

final class CoeloAuthSessionState {
  const CoeloAuthSessionState.signedOut()
    : kind = CoeloAuthSessionKind.signedOut,
      sessionId = null;

  const CoeloAuthSessionState.authenticated({this.sessionId})
    : kind = CoeloAuthSessionKind.authenticated;

  const CoeloAuthSessionState.passwordRecovery({this.sessionId})
    : kind = CoeloAuthSessionKind.passwordRecovery;

  final CoeloAuthSessionKind kind;
  final String? sessionId;

  bool get isAuthenticated => kind != CoeloAuthSessionKind.signedOut;
  bool get isPasswordRecovery => kind == CoeloAuthSessionKind.passwordRecovery;

  @override
  bool operator ==(Object other) =>
      other is CoeloAuthSessionState &&
      other.kind == kind &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(kind, sessionId);
}

final class CoeloAuthSignInResult {
  const CoeloAuthSignInResult._({required this.isSuccess, this.message});

  const CoeloAuthSignInResult.success() : this._(isSuccess: true);

  const CoeloAuthSignInResult.failure(String message)
    : this._(isSuccess: false, message: message);

  static const genericFailureMessage =
      'Não foi possível entrar. Verifique os dados e tente novamente.';

  final bool isSuccess;
  final String? message;
}

final class CoeloAuthPasswordRecoveryResult {
  const CoeloAuthPasswordRecoveryResult._({
    required this.isSuccess,
    this.message,
  });

  const CoeloAuthPasswordRecoveryResult.success() : this._(isSuccess: true);

  const CoeloAuthPasswordRecoveryResult.failure(String message)
    : this._(isSuccess: false, message: message);

  static const genericFailureMessage =
      'Não foi possível enviar o e-mail de recuperação. Tente novamente.';

  final bool isSuccess;
  final String? message;
}

final class CoeloAuthPasswordUpdateResult {
  const CoeloAuthPasswordUpdateResult._({
    required this.isSuccess,
    this.message,
  });

  const CoeloAuthPasswordUpdateResult.success() : this._(isSuccess: true);

  const CoeloAuthPasswordUpdateResult.failure(String message)
    : this._(isSuccess: false, message: message);

  static const genericFailureMessage =
      'Não foi possível redefinir a senha. Solicite um novo link e tente novamente.';

  final bool isSuccess;
  final String? message;
}

final class UnavailableCoeloAuthGateway extends CoeloAuthLifecycleGateway {
  const UnavailableCoeloAuthGateway({this.message = defaultMessage});

  static const defaultMessage =
      'Autenticação não está configurada neste ambiente.';

  final String message;

  @override
  Stream<CoeloAuthSessionState> get authSessionStateChanges =>
      const Stream<CoeloAuthSessionState>.empty();

  @override
  CoeloAuthSessionState get currentSessionState =>
      const CoeloAuthSessionState.signedOut();

  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) {
    return Future.value(CoeloAuthSignInResult.failure(message));
  }

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecoveryWithRedirect({
    required String email,
    required Uri redirectTo,
  }) {
    return Future.value(CoeloAuthPasswordRecoveryResult.failure(message));
  }

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecovery({
    required String email,
  }) {
    return Future.value(CoeloAuthPasswordRecoveryResult.failure(message));
  }

  @override
  Future<CoeloAuthPasswordUpdateResult> updatePassword({
    required String password,
  }) {
    return Future.value(CoeloAuthPasswordUpdateResult.failure(message));
  }

  @override
  Future<void> signOut() {
    return Future.value();
  }
}
