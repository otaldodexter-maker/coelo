import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/presentation/view_models/password_recovery_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts idle without retaining an email', () {
    final viewModel = PasswordRecoveryViewModel(
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.isLoading, isFalse);
    expect(viewModel.isSuccess, isFalse);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.email, isNull);
  });

  test('normalizes the email and exposes loading before success', () async {
    final completer = Completer<PasswordRecoveryResult>();
    String? receivedEmail;
    final viewModel = PasswordRecoveryViewModel(
      requestPasswordRecovery: (email) {
        receivedEmail = email;
        return completer.future;
      },
    );
    addTearDown(viewModel.dispose);

    final submission = viewModel.submit('  owner@coelo.me  ');

    expect(viewModel.isLoading, isTrue);
    expect(receivedEmail, 'owner@coelo.me');

    completer.complete(const PasswordRecoveryResult.success());

    expect(await submission, isTrue);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.isSuccess, isTrue);
    expect(viewModel.email, 'owner@coelo.me');
    expect(viewModel.errorMessage, isNull);
  });

  test('keeps the form visible after a safe initial failure', () async {
    final viewModel = PasswordRecoveryViewModel(
      requestPasswordRecovery: (_) async => const PasswordRecoveryResult.failure('Falha segura.'),
    );
    addTearDown(viewModel.dispose);

    expect(await viewModel.submit('owner@coelo.me'), isFalse);
    expect(viewModel.isSuccess, isFalse);
    expect(viewModel.errorMessage, 'Falha segura.');
  });

  test('maps unexpected exceptions to a generic message', () async {
    final viewModel = PasswordRecoveryViewModel(
      requestPasswordRecovery: (_) =>
          Future<PasswordRecoveryResult>.error(Exception('sensitive detail')),
    );
    addTearDown(viewModel.dispose);

    expect(await viewModel.submit('owner@coelo.me'), isFalse);
    expect(viewModel.errorMessage, PasswordRecoveryViewModel.genericErrorMessage);
    expect(viewModel.errorMessage, isNot(contains('sensitive detail')));
  });

  test('ignores a concurrent request', () async {
    final completer = Completer<PasswordRecoveryResult>();
    var calls = 0;
    final viewModel = PasswordRecoveryViewModel(
      requestPasswordRecovery: (_) {
        calls += 1;
        return completer.future;
      },
    );
    addTearDown(viewModel.dispose);

    final first = viewModel.submit('owner@coelo.me');
    final second = await viewModel.submit('other@coelo.me');

    expect(second, isFalse);
    expect(calls, 1);

    completer.complete(const PasswordRecoveryResult.success());
    expect(await first, isTrue);
  });

  test('resends to the stored email and preserves success on failure', () async {
    final receivedEmails = <String>[];
    var calls = 0;
    final viewModel = PasswordRecoveryViewModel(
      requestPasswordRecovery: (email) async {
        receivedEmails.add(email);
        calls += 1;
        return calls == 1
            ? const PasswordRecoveryResult.success()
            : const PasswordRecoveryResult.failure('Não foi possível reenviar.');
      },
    );
    addTearDown(viewModel.dispose);

    expect(await viewModel.submit(' owner@coelo.me '), isTrue);
    expect(await viewModel.resend(), isFalse);

    expect(receivedEmails, ['owner@coelo.me', 'owner@coelo.me']);
    expect(viewModel.isSuccess, isTrue);
    expect(viewModel.errorMessage, 'Não foi possível reenviar.');
  });

  test('can be disposed while a request is pending', () async {
    final completer = Completer<PasswordRecoveryResult>();
    final viewModel = PasswordRecoveryViewModel(requestPasswordRecovery: (_) => completer.future);

    final submission = viewModel.submit('owner@coelo.me');
    viewModel.dispose();
    completer.complete(const PasswordRecoveryResult.success());

    expect(await submission, isTrue);
  });
}
