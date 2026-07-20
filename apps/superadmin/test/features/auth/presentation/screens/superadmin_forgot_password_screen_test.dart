import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/password_recovery.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_forgot_password_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpForgotPassword(
    WidgetTester tester, {
    required PasswordRecoveryAction requestPasswordRecovery,
    VoidCallback? onBackToLogin,
    ThemeData? theme,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme ?? CoeloTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: SuperadminForgotPasswordScreen(
            requestPasswordRecovery: requestPasswordRecovery,
            onBackToLogin: onBackToLogin ?? () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );
  }

  Future<void> submitEmail(WidgetTester tester, String email) async {
    await tester.enterText(find.byKey(const ValueKey('superadmin-forgot-password-email')), email);
    final submit = find.widgetWithText(FilledButton, 'Enviar link de recuperação');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
  }

  testWidgets('renders the recovery form with existing auth components', (tester) async {
    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
    );

    expect(find.text('Superadmin'), findsOneWidget);
    expect(find.text('Recupere seu acesso'), findsOneWidget);
    expect(
      find.text('Informe o e-mail associado à sua conta para receber um link de recuperação.'),
      findsOneWidget,
    );
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Enviar link de recuperação'), findsOneWidget);
    expect(find.text('Voltar para entrar'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('validates empty and malformed email before requesting', (tester) async {
    var calls = 0;
    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: (_) async {
        calls += 1;
        return const PasswordRecoveryResult.success();
      },
    );

    final submit = find.widgetWithText(FilledButton, 'Enviar link de recuperação');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('superadmin-forgot-password-email')),
      'email-invalido',
    );
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('shows loading and disables the email field', (tester) async {
    final completer = Completer<PasswordRecoveryResult>();
    await pumpForgotPassword(tester, requestPasswordRecovery: (_) => completer.future);

    await submitEmail(tester, 'owner@coelo.me');

    expect(find.text('Enviando...'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('superadmin-forgot-password-email')))
          .enabled,
      isFalse,
    );

    completer.complete(const PasswordRecoveryResult.success());
    await tester.pumpAndSettle();
  });

  testWidgets('keeps the form visible after a safe request failure', (tester) async {
    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: (_) async => const PasswordRecoveryResult.failure('Falha segura.'),
    );

    await submitEmail(tester, 'owner@coelo.me');
    await tester.pumpAndSettle();

    expect(find.text('Falha segura.'), findsOneWidget);
    expect(find.text('Recupere seu acesso'), findsOneWidget);
    expect(find.text('Confira seu e-mail'), findsNothing);
  });

  testWidgets('shows neutral success and resends the normalized email', (tester) async {
    final receivedEmails = <String>[];
    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: (email) async {
        receivedEmails.add(email);
        return const PasswordRecoveryResult.success();
      },
    );

    await submitEmail(tester, '  owner@coelo.me  ');
    await tester.pumpAndSettle();

    expect(find.text('Confira seu e-mail'), findsOneWidget);
    expect(
      find.text(
        'Se existir uma conta associada a este e-mail, enviaremos as instruções para redefinir a senha.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Reenviar e-mail'));
    await tester.pumpAndSettle();

    expect(receivedEmails, ['owner@coelo.me', 'owner@coelo.me']);
  });

  testWidgets('keeps success visible when resend fails', (tester) async {
    var calls = 0;
    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: (_) async {
        calls += 1;
        return calls == 1
            ? const PasswordRecoveryResult.success()
            : const PasswordRecoveryResult.failure('Não foi possível reenviar.');
      },
    );

    await submitEmail(tester, 'owner@coelo.me');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reenviar e-mail'));
    await tester.pumpAndSettle();

    expect(find.text('Confira seu e-mail'), findsOneWidget);
    expect(find.text('Não foi possível reenviar.'), findsOneWidget);
  });

  testWidgets('shows resend loading and disables the resend action', (tester) async {
    final resendCompleter = Completer<PasswordRecoveryResult>();
    var calls = 0;
    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: (_) {
        calls += 1;
        return calls == 1
            ? Future.value(const PasswordRecoveryResult.success())
            : resendCompleter.future;
      },
    );

    await submitEmail(tester, 'owner@coelo.me');
    await tester.pumpAndSettle();
    final resendFinder = find.widgetWithText(TextButton, 'Reenviar e-mail');
    final idleSize = tester.getSize(resendFinder);
    await tester.tap(resendFinder);
    await tester.pump();

    final loadingFinder = find.widgetWithText(TextButton, 'Reenviando...');
    final resendButton = tester.widget<TextButton>(loadingFinder);
    expect(resendButton.onPressed, isNull);
    expect(tester.getSize(loadingFinder), idleSize);

    resendCompleter.complete(const PasswordRecoveryResult.success());
    await tester.pumpAndSettle();
  });

  testWidgets('returns to login from form and success', (tester) async {
    var backCalls = 0;
    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: (_) async => const PasswordRecoveryResult.success(),
      onBackToLogin: () => backCalls += 1,
    );

    await tester.tap(find.text('Voltar para entrar'));
    expect(backCalls, 1);

    await submitEmail(tester, 'owner@coelo.me');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Voltar para entrar'));

    expect(backCalls, 2);
  });

  testWidgets('uses semantic success colors in the dark theme', (tester) async {
    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: (_) async => const PasswordRecoveryResult.success(),
      theme: CoeloTheme.dark,
    );

    await submitEmail(tester, 'owner@coelo.me');
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(SuperadminForgotPasswordScreen));
    final status = Theme.of(context).extension<CoeloStatusColors>()!;
    final icon = tester.widget<Icon>(find.byIcon(Icons.mark_email_read_outlined));
    final decoration = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('superadmin-forgot-password-success-icon')),
    );

    expect(icon.color, status.onSuccessContainer);
    expect((decoration.decoration as BoxDecoration).color, status.successContainer);
  });

  testWidgets('announces the neutral success state to assistive technology', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: (_) async => const PasswordRecoveryResult.success(),
    );

    await submitEmail(tester, 'owner@coelo.me');
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('Confira seu e-mail')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('does not overflow on a compact window with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpForgotPassword(
      tester,
      requestPasswordRecovery: unavailableSuperadminPasswordRecovery,
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
