import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signs out through the gateway and clears the local session', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession(isAuthenticated: true);
    addTearDown(session.dispose);
    final logout = createCoeloAuthLogoutAction(auth: auth, session: session);

    final result = await logout();

    expect(result.isSuccess, isTrue);
    expect(result.message, isNull);
    expect(auth.didSignOut, isTrue);
    expect(session.isAuthenticated, isFalse);
  });

  test('keeps the session state and returns a safe message when logout fails', () async {
    final auth = _FakeCoeloAuthGateway(signOutException: Exception('network details'));
    final session = SuperadminSession(isAuthenticated: true);
    addTearDown(session.dispose);
    final logout = createCoeloAuthLogoutAction(auth: auth, session: session);

    final result = await logout();

    expect(result.isSuccess, isFalse);
    expect(result.message, LogoutResult.genericFailureMessage);
    expect(result.message, isNot(contains('network details')));
    expect(session.isAuthenticated, isTrue);
  });
}

final class _FakeCoeloAuthGateway implements CoeloAuthGateway {
  _FakeCoeloAuthGateway({this.signOutException});

  final Exception? signOutException;
  bool didSignOut = false;

  @override
  Stream<bool> get authStateChanges => const Stream<bool>.empty();

  @override
  bool get isAuthenticated => false;

  @override
  Future<CoeloAuthSignInResult> signInWithPassword({
    required String email,
    required String password,
    required bool persistSession,
  }) async {
    return const CoeloAuthSignInResult.success();
  }

  @override
  Future<void> signOut() async {
    if (signOutException case final exception?) {
      throw exception;
    }
    didSignOut = true;
  }
}
