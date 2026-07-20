import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/reset_password_action.dart';
import 'package:coelo_superadmin/features/auth/presentation/view_models/reset_password_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default action reports that password reset is not connected', () async {
    final result = await unavailableResetPassword('not-a-real-password');

    expect(result.isSuccess, isFalse);
    expect(result.message, 'Redefinição de senha ainda não está conectada.');
  });

  test('starts idle with both password fields hidden', () {
    final viewModel = ResetPasswordViewModel(resetPassword: _resetPassword);
    addTearDown(viewModel.dispose);

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.isSuccess, isFalse);
    expect(viewModel.isPasswordVisible, isFalse);
    expect(viewModel.isConfirmationVisible, isFalse);
    expect(viewModel.errorMessage, isNull);
  });

  test('toggles password fields independently', () {
    final viewModel = ResetPasswordViewModel(resetPassword: _resetPassword);
    addTearDown(viewModel.dispose);

    viewModel.togglePasswordVisibility();
    expect(viewModel.isPasswordVisible, isTrue);
    expect(viewModel.isConfirmationVisible, isFalse);

    viewModel.toggleConfirmationVisibility();
    expect(viewModel.isPasswordVisible, isTrue);
    expect(viewModel.isConfirmationVisible, isTrue);
  });

  test('exposes loading and forwards the new password before succeeding', () async {
    final completer = Completer<ResetPasswordResult>();
    String? receivedPassword;
    final viewModel = ResetPasswordViewModel(
      resetPassword: (password) {
        receivedPassword = password;
        return completer.future;
      },
    );
    addTearDown(viewModel.dispose);

    final submission = viewModel.submit('new-secret-password');

    expect(viewModel.isLoading, isTrue);
    expect(receivedPassword, 'new-secret-password');

    completer.complete(const ResetPasswordResult.success());

    expect(await submission, isTrue);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.isSuccess, isTrue);
    expect(viewModel.errorMessage, isNull);
  });

  test('surfaces a safe failure returned by the action', () async {
    final viewModel = ResetPasswordViewModel(
      resetPassword: (_) async => const ResetPasswordResult.failure('Falha segura.'),
    );
    addTearDown(viewModel.dispose);

    expect(await viewModel.submit('new-secret-password'), isFalse);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.isSuccess, isFalse);
    expect(viewModel.errorMessage, 'Falha segura.');
  });

  test('maps unexpected exceptions to a generic message', () async {
    final viewModel = ResetPasswordViewModel(
      resetPassword: (_) => Future<ResetPasswordResult>.error(Exception('sensitive detail')),
    );
    addTearDown(viewModel.dispose);

    expect(await viewModel.submit('new-secret-password'), isFalse);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, ResetPasswordViewModel.genericErrorMessage);
    expect(viewModel.errorMessage, isNot(contains('sensitive detail')));
  });

  test('ignores a concurrent submission', () async {
    final completer = Completer<ResetPasswordResult>();
    var calls = 0;
    final viewModel = ResetPasswordViewModel(
      resetPassword: (_) {
        calls += 1;
        return completer.future;
      },
    );
    addTearDown(viewModel.dispose);

    final firstSubmission = viewModel.submit('new-secret-password');
    final secondResult = await viewModel.submit('another-password');

    expect(secondResult, isFalse);
    expect(calls, 1);

    completer.complete(const ResetPasswordResult.success());
    expect(await firstSubmission, isTrue);
  });

  test('can be disposed while a submission is pending', () async {
    final completer = Completer<ResetPasswordResult>();
    final viewModel = ResetPasswordViewModel(resetPassword: (_) => completer.future);

    final submission = viewModel.submit('new-secret-password');
    viewModel.dispose();
    completer.complete(const ResetPasswordResult.failure('Falha segura.'));

    expect(await submission, isFalse);
  });
}

Future<ResetPasswordResult> _resetPassword(String password) {
  return Future.value(const ResetPasswordResult.failure('Falha segura.'));
}
