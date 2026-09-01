import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/features/auth/domain/reset_password_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updates the password through Coelo auth and maps success', () async {
    final auth = _FakeCoeloAuthGateway();
    final action = createCoeloAuthResetPasswordAction(auth: auth);

    final result = await action('new-secret-password');

    expect(auth.lastUpdatedPassword, 'new-secret-password');
    expect(result.isSuccess, isTrue);
    expect(result.message, isNull);
  });

  test('maps password update failure to its stable safe message', () async {
    final auth = _FakeCoeloAuthGateway(
      updateResult: const CoeloAuthPasswordUpdateResult.failure(
        CoeloAuthPasswordUpdateResult.genericFailureMessage,
      ),
    );
    final action = createCoeloAuthResetPasswordAction(auth: auth);

    final result = await action('new-secret-password');

    expect(result.isSuccess, isFalse);
    expect(result.message, CoeloAuthPasswordUpdateResult.genericFailureMessage);
    expect(result.message, isNot(contains('new-secret-password')));
  });
}

final class _FakeCoeloAuthGateway implements CoeloAuthGateway {
  _FakeCoeloAuthGateway({this.updateResult = const CoeloAuthPasswordUpdateResult.success()});

  final CoeloAuthPasswordUpdateResult updateResult;
  String? lastUpdatedPassword;

  @override
  Stream<CoeloAuthSessionState> get authStateChanges => const Stream<CoeloAuthSessionState>.empty();

  @override
  CoeloAuthSessionState get currentSessionState => const CoeloAuthSessionState.passwordRecovery();

  @override
  Future<CoeloAuthPasswordRecoveryResult> requestPasswordRecovery({
    required String email,
    required Uri redirectTo,
  }) async => const CoeloAuthPasswordRecoveryResult.success();

  @override
  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) async => const CoeloAuthSignInResult.success();

  @override
  Future<void> signOut() async {}

  @override
  Future<CoeloAuthPasswordUpdateResult> updatePassword({required String password}) async {
    lastUpdatedPassword = password;
    return updateResult;
  }
}
