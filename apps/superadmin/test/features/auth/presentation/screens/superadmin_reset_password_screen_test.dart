import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/reset_password_action.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_reset_password_screen.dart';
import 'package:coelo_superadmin/features/auth/presentation/widgets/login_feedback.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpResetPassword(
    WidgetTester tester, {
    ResetPasswordAction resetPassword = unavailableResetPassword,
    RecoveryLinkState initialLinkState = RecoveryLinkState.valid,
    VoidCallback? onBackToLogin,
    ThemeData? theme,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme ?? CoeloTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: SuperadminResetPasswordScreen(
            resetPassword: resetPassword,
            initialLinkState: initialLinkState,
            onBackToLogin: onBackToLogin ?? () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );
  }

  Future<void> expectCompactLayout(WidgetTester tester, {required ThemeData theme}) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpResetPassword(tester, theme: theme, textScaler: const TextScaler.linear(2));
    await tester.pump();

    expect(tester.takeException(), isNull);

    final submit = find.widgetWithText(FilledButton, 'Salvar nova senha');
    await tester.ensureVisible(submit);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(CoeloSize.touchMin));
  }

  testWidgets('does not expose theme switching from new password', (tester) async {
    await pumpResetPassword(tester);

    expect(find.byKey(const ValueKey('superadmin-login-theme-toggle')), findsNothing);
  });

  testWidgets('renders the reset password form with Coelo auth context', (tester) async {
    await pumpResetPassword(tester);

    expect(find.text('Superadmin'), findsOneWidget);
    expect(find.text('Crie uma nova senha'), findsOneWidget);
    expect(
      find.text('Escolha uma nova senha para recuperar o acesso à sua conta.'),
      findsOneWidget,
    );
    expect(find.text('Nova senha'), findsOneWidget);
    expect(find.text('Confirmar nova senha'), findsOneWidget);
    expect(find.text('Salvar nova senha'), findsOneWidget);
    expect(find.text('Voltar para entrar'), findsOneWidget);
    expect(
      find.text('Acesso restrito à equipe autorizada. Ações sensíveis podem ser auditadas.'),
      findsOneWidget,
    );
  });

  testWidgets('validates required, minimum length, and matching passwords', (tester) async {
    await pumpResetPassword(tester);

    final submit = find.widgetWithText(FilledButton, 'Salvar nova senha');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Informe a nova senha.'), findsOneWidget);
    expect(find.text('Confirme a nova senha.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('superadmin-reset-password')), 'curta');
    await tester.enterText(
      find.byKey(const ValueKey('superadmin-reset-password-confirmation')),
      'curta',
    );
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('A senha precisa ter pelo menos 8 caracteres.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('superadmin-reset-password')),
      'nova-senha-segura',
    );
    await tester.enterText(
      find.byKey(const ValueKey('superadmin-reset-password-confirmation')),
      'senha-diferente',
    );
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('As senhas não coincidem.'), findsOneWidget);
  });

  testWidgets('toggles both password fields independently', (tester) async {
    await pumpResetPassword(tester);

    EditableText passwordField() => tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('superadmin-reset-password')),
        matching: find.byType(EditableText),
      ),
    );
    EditableText confirmationField() => tester.widget(
      find.descendant(
        of: find.byKey(const ValueKey('superadmin-reset-password-confirmation')),
        matching: find.byType(EditableText),
      ),
    );

    expect(passwordField().obscureText, isTrue);
    expect(confirmationField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar nova senha'));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(confirmationField().obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar confirmação de senha'));
    await tester.pump();

    expect(passwordField().obscureText, isFalse);
    expect(confirmationField().obscureText, isFalse);
  });

  testWidgets('shows loading, disables fields, and forwards the password', (tester) async {
    final completer = Completer<ResetPasswordResult>();
    String? submittedPassword;
    await pumpResetPassword(
      tester,
      resetPassword: (password) {
        submittedPassword = password;
        return completer.future;
      },
    );

    await tester.enterText(
      find.byKey(const ValueKey('superadmin-reset-password')),
      'nova-senha-segura',
    );
    await tester.enterText(
      find.byKey(const ValueKey('superadmin-reset-password-confirmation')),
      'nova-senha-segura',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar nova senha'));
    await tester.pump();

    expect(submittedPassword, 'nova-senha-segura');
    expect(find.text('Salvando...'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byKey(const ValueKey('superadmin-reset-password'))).enabled,
      isFalse,
    );

    completer.complete(const ResetPasswordResult.failure('Falha segura.'));
    await tester.pump();
  });

  testWidgets('shows a semantic failure returned by the action', (tester) async {
    await pumpResetPassword(
      tester,
      resetPassword: (_) async => const ResetPasswordResult.failure('Falha segura.'),
    );

    await tester.enterText(
      find.byKey(const ValueKey('superadmin-reset-password')),
      'nova-senha-segura',
    );
    await tester.enterText(
      find.byKey(const ValueKey('superadmin-reset-password-confirmation')),
      'nova-senha-segura',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar nova senha'));
    await tester.pumpAndSettle();

    expect(find.text('Falha segura.'), findsOneWidget);
    final semantics = tester.getSemantics(find.byType(LoginFeedback));
    expect(semantics.label, 'Erro ao redefinir senha: Falha segura.');
  });

  testWidgets('shows success and returns to login', (tester) async {
    var returnedToLogin = false;
    await pumpResetPassword(
      tester,
      resetPassword: (_) async => const ResetPasswordResult.success(),
      onBackToLogin: () => returnedToLogin = true,
    );

    await tester.enterText(
      find.byKey(const ValueKey('superadmin-reset-password')),
      'nova-senha-segura',
    );
    await tester.enterText(
      find.byKey(const ValueKey('superadmin-reset-password-confirmation')),
      'nova-senha-segura',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar nova senha'));
    await tester.pumpAndSettle();

    expect(find.text('Senha atualizada'), findsOneWidget);
    expect(
      find.text('Sua senha foi redefinida com segurança. Entre novamente para continuar.'),
      findsOneWidget,
    );
    expect(find.text('Nova senha'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Voltar para entrar'));
    expect(returnedToLogin, isTrue);
  });

  testWidgets('shows recovery link processing state', (tester) async {
    await pumpResetPassword(tester, initialLinkState: RecoveryLinkState.processing);

    expect(find.text('Validando link...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Nova senha'), findsNothing);
  });

  testWidgets('shows invalid link state and returns to login', (tester) async {
    var returnedToLogin = false;
    await pumpResetPassword(
      tester,
      initialLinkState: RecoveryLinkState.invalid,
      onBackToLogin: () => returnedToLogin = true,
    );

    expect(find.text('Este link não é mais válido'), findsOneWidget);
    expect(find.text('Solicite um novo link para redefinir sua senha.'), findsOneWidget);
    expect(find.text('Nova senha'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Voltar para entrar'));
    expect(returnedToLogin, isTrue);
  });

  testWidgets('supports 320x568 at 200 percent text in light theme', (tester) async {
    await expectCompactLayout(tester, theme: CoeloTheme.light);
  });

  testWidgets('supports 320x568 at 200 percent text in dark theme', (tester) async {
    await expectCompactLayout(tester, theme: CoeloTheme.dark);
  });
}
