import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/coelo_auth_login_action.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = LoginRequest(
    email: 'owner@coelo.me',
    password: 'secret-password',
    keepSessionOpen: false,
  );

  test('forwards credentials to Coelo auth and signs the session in on success', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    addTearDown(session.dispose);

    final action = createCoeloAuthLoginAction(auth: auth, session: session);
    final result = await action(request);

    expect(auth.lastEmail, request.email);
    expect(auth.lastPassword, request.password);
    expect(auth.persistSession, isFalse);
    expect(result.isSuccess, isTrue);
    expect(session.isAuthenticated, isTrue);
  });

  test('requests persistent storage when keep session open is selected', () async {
    final auth = _FakeCoeloAuthGateway();
    final session = SuperadminSession();
    addTearDown(session.dispose);

    final action = createCoeloAuthLoginAction(auth: auth, session: session);
    final result = await action(
      const LoginRequest(
        email: 'owner@coelo.me',
        password: 'secret-password',
        keepSessionOpen: true,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(auth.persistSession, isTrue);
  });

  test('keeps the session signed out and returns a safe failure from Coelo auth', () async {
    final auth = _FakeCoeloAuthGateway(
      nextResult: const CoeloAuthSignInResult.failure(CoeloAuthSignInResult.genericFailureMessage),
    );
    final session = SuperadminSession();
    addTearDown(session.dispose);

    final action = createCoeloAuthLoginAction(auth: auth, session: session);
    final result = await action(request);

    expect(result.isSuccess, isFalse);
    expect(result.message, CoeloAuthSignInResult.genericFailureMessage);
    expect(session.isAuthenticated, isFalse);
  });
}

final class _FakeCoeloAuthGateway implements CoeloAuthGateway {
  _FakeCoeloAuthGateway({this.nextResult = const CoeloAuthSignInResult.success()});

  String? lastEmail;
  String? lastPassword;
  bool? persistSession;
  final CoeloAuthSignInResult nextResult;

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
    lastEmail = email;
    lastPassword = password;
    this.persistSession = persistSession;
    return nextResult;
  }

  @override
  Future<void> signOut() async {}
}
