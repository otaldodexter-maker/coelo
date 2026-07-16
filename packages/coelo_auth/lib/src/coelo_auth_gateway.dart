abstract interface class CoeloAuthGateway {
  bool get isAuthenticated;
  Stream<bool> get authStateChanges;

  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  });

  Future<void> signOut();
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

final class UnavailableCoeloAuthGateway implements CoeloAuthGateway {
  const UnavailableCoeloAuthGateway({this.message = defaultMessage});

  static const defaultMessage =
      'Autenticação não está configurada neste ambiente.';

  final String message;

  @override
  Stream<bool> get authStateChanges => const Stream<bool>.empty();

  @override
  bool get isAuthenticated => false;

  @override
  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) {
    return Future.value(CoeloAuthSignInResult.failure(message));
  }

  @override
  Future<void> signOut() {
    return Future.value();
  }
}
