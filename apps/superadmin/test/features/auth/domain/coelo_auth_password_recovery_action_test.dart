import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forwards the email to Coelo auth and maps success', () async {
    final auth = _FakeCoeloAuthGateway();
    final action = createCoeloAuthPasswordRecoveryAction(
      auth: auth,
      redirectTo: Uri.parse('http://127.0.0.1:8766/reset-password'),
    );

    final result = await action('owner@coelo.me');

    expect(auth.lastRecoveryEmail, 'owner@coelo.me');
    expect(auth.lastRecoveryRedirect?.path, '/reset-password');
    expect(result.isSuccess, isTrue);
    expect(result.message, isNull);
  });

  test('maps a safe recovery failure from Coelo auth', () async {
    final auth = _FakeCoeloAuthGateway(
      recoveryResult: const CoeloAuthPasswordRecoveryResult.failure(
        CoeloAuthPasswordRecoveryResult.genericFailureMessage,
      ),
    );
    final action = createCoeloAuthPasswordRecoveryAction(
      auth: auth,
      redirectTo: Uri.parse('http://127.0.0.1:8766/reset-password'),
    );

    final result = await action('owner@coelo.me');

    expect(result.isSuccess, isFalse);
    expect(result.message, CoeloAuthPasswordRecoveryResult.genericFailureMessage);
  });
}

final class _FakeCoeloAuthGateway implements CoeloAuthGateway {
  _FakeCoeloAuthGateway({this.recoveryResult = const CoeloAuthPasswordRecoveryResult.success()});

  final CoeloAuthPasswordRecoveryResult recoveryResult;
  String? lastRecoveryEmail;
  Uri? lastRecoveryRedirect;

  @override
  Stream<CoeloAuthSessionState> get authStateChanges => const Stream<CoeloAuthSessionState>.empty();

  @override
  CoeloAuthSessionState get currentSessionState => const CoeloAuthSessionState.signedOut();

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecovery({
    required String email,
    required Uri redirectTo,
  }) async {
    lastRecoveryEmail = email;
    lastRecoveryRedirect = redirectTo;
    return recoveryResult;
  }

  @override
  Future<CoeloAuthPasswordUpdateResult> updatePassword({required String password}) async =>
      const CoeloAuthPasswordUpdateResult.success();

  @override
  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) async => const CoeloAuthSignInResult.success();

  @override
  Future<void> signOut() async {}
}
