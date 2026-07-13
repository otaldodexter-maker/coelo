import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/presentation/view_models/login_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = LoginRequest(
    email: 'owner@coelo.me',
    password: 'not-a-real-password',
    keepSessionOpen: true,
  );

  test('starts idle with private defaults', () {
    final viewModel = LoginViewModel(login: unavailableSuperadminLogin);

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.isPasswordVisible, isFalse);
    expect(viewModel.keepSessionOpen, isFalse);
    expect(viewModel.errorMessage, isNull);
  });

  test('default login reports that authentication is not connected', () async {
    final result = await unavailableSuperadminLogin(request);

    expect(result.isSuccess, isFalse);
    expect(result.message, 'Autenticação ainda não está conectada.');
  });

  test('toggles password visibility and session preference', () {
    final viewModel = LoginViewModel(login: unavailableSuperadminLogin);

    viewModel.togglePasswordVisibility();
    viewModel.setKeepSessionOpen(value: true);

    expect(viewModel.isPasswordVisible, isTrue);
    expect(viewModel.keepSessionOpen, isTrue);
  });

  test('exposes loading and forwards the request before succeeding', () async {
    final completer = Completer<LoginResult>();
    LoginRequest? receivedRequest;
    final viewModel = LoginViewModel(
      login: (value) {
        receivedRequest = value;
        return completer.future;
      },
    );

    final submission = viewModel.submit(request);

    expect(viewModel.isLoading, isTrue);
    expect(receivedRequest, same(request));

    completer.complete(const LoginResult.success());

    expect(await submission, isTrue);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, isNull);
  });

  test('surfaces a safe failure returned by authentication', () async {
    final viewModel = LoginViewModel(
      login: (_) async =>
          const LoginResult.failure('Credenciais inválidas. Verifique e tente novamente.'),
    );

    expect(await viewModel.submit(request), isFalse);
    expect(viewModel.errorMessage, 'Credenciais inválidas. Verifique e tente novamente.');
    expect(viewModel.isLoading, isFalse);
  });

  test('maps unexpected exceptions to a generic message', () async {
    final viewModel = LoginViewModel(
      login: (_) => Future<LoginResult>.error(Exception('sensitive detail')),
    );

    expect(await viewModel.submit(request), isFalse);
    expect(viewModel.errorMessage, LoginViewModel.genericErrorMessage);
    expect(viewModel.errorMessage, isNot(contains('sensitive detail')));
  });

  test('does not hide programming errors', () async {
    final viewModel = LoginViewModel(
      login: (_) => Future<LoginResult>.error(StateError('programming error')),
    );

    await expectLater(viewModel.submit(request), throwsA(isA<StateError>()));
    expect(viewModel.isLoading, isFalse);
  });

  test('can be disposed while authentication is pending', () async {
    final completer = Completer<LoginResult>();
    final viewModel = LoginViewModel(login: (_) => completer.future);

    final submission = viewModel.submit(request);
    viewModel.dispose();
    completer.complete(const LoginResult.failure('Falha segura.'));

    expect(await submission, isFalse);
  });

  test('ignores a concurrent submission', () async {
    final completer = Completer<LoginResult>();
    var calls = 0;
    final viewModel = LoginViewModel(
      login: (_) {
        calls += 1;
        return completer.future;
      },
    );

    final firstSubmission = viewModel.submit(request);
    final secondResult = await viewModel.submit(request);

    expect(secondResult, isFalse);
    expect(calls, 1);

    completer.complete(const LoginResult.success());
    expect(await firstSubmission, isTrue);
  });
}
