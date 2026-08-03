import 'dart:async';
import 'dart:ui';

import 'package:coelo_superadmin/core/guards/superadmin_session.dart';
import 'package:coelo_superadmin/features/auth/domain/login_request.dart';
import 'package:coelo_superadmin/features/auth/presentation/screens/superadmin_login_screen.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLogin(
    WidgetTester tester, {
    required SuperadminSession session,
    required LoginAction login,
    VoidCallback? onForgotPassword,
    TextScaler textScaler = TextScaler.noScaling,
    ThemeData? theme,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme ?? CoeloTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: SuperadminLoginScreen(
            session: session,
            login: login,
            onForgotPassword: onForgotPassword ?? () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );
  }

  Future<void> enterValidCredentials(WidgetTester tester) async {
    await tester.enterText(find.byKey(const ValueKey('superadmin-login-email')), 'owner@coelo.me');
    await tester.enterText(
      find.byKey(const ValueKey('superadmin-login-password')),
      'not-a-real-password',
    );
  }

  testWidgets('renders the private access context and form', (tester) async {
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await pumpLogin(tester, session: session, login: unavailableSuperadminLogin);

    expect(find.text('Superadmin'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-brand-mark')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-brand-logo')), findsOneWidget);
    expect(find.text('Acesse sua conta'), findsOneWidget);
    expect(find.text('Ambiente interno da operação Coelo.'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Manter sessão aberta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);
    expect(
      find.text('Acesso restrito à equipe autorizada. Ações sensíveis podem ser auditadas.'),
      findsOneWidget,
    );
  });

  testWidgets('matches the approved light login anatomy and semantic colors', (tester) async {
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await pumpLogin(tester, session: session, login: unavailableSuperadminLogin);

    final context = tester.element(find.byType(SuperadminLoginScreen));
    final colors = Theme.of(context).colorScheme;
    final card = tester.widget<Card>(find.byType(Card));
    final email = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('superadmin-login-email')),
        matching: find.byType(TextField),
      ),
    );

    final divider = tester.widget<Divider>(
      find.byKey(const ValueKey('superadmin-login-header-divider')),
    );

    expect(
      tester.getSize(find.byKey(const Key('superadmin-brand-mark'))),
      const Size.square(CoeloSize.brandMarkLg),
    );
    expect(find.byKey(const ValueKey('superadmin-login-header-divider')), findsOneWidget);
    expect(card.color, colors.surface);
    expect(card.surfaceTintColor, colors.surface);
    expect(card.shape, isA<RoundedRectangleBorder>());
    final cardShape = card.shape! as RoundedRectangleBorder;
    expect(cardShape.side, BorderSide.none);
    expect(card.elevation, CoeloElevation.level1);
    expect(card.shadowColor, colors.shadow.withValues(alpha: 0.08));
    expect(divider.color, colors.outlineVariant);
    expect(email.decoration?.labelText, 'E-mail');
    expect(email.decoration?.hintText, 'seu.email@coelo.me');
    expect(email.decoration?.fillColor, colors.surfaceContainerLowest);
  });

  testWidgets('keeps the login header compact with semantic spacing tokens', (tester) async {
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await pumpLogin(tester, session: session, login: unavailableSuperadminLogin);

    double gap(String key) {
      return tester.widget<SizedBox>(find.byKey(ValueKey<String>(key))).height!;
    }

    expect(gap('superadmin-login-gap-logo-chip'), CoeloSpacing.space1);
    expect(gap('superadmin-login-gap-chip-title'), CoeloSpacing.space2);
    expect(gap('superadmin-login-gap-title-subtitle'), CoeloSpacing.space1);
    expect(gap('superadmin-login-gap-subtitle-divider'), CoeloSpacing.space3);
    expect(gap('superadmin-login-gap-header-form'), CoeloSpacing.space4);
  });

  testWidgets('underlines password recovery on hover without a background overlay', (tester) async {
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await pumpLogin(tester, session: session, login: unavailableSuperadminLogin);

    final context = tester.element(find.byType(SuperadminLoginScreen));
    final colors = Theme.of(context).colorScheme;
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Esqueci minha senha'),
    );
    final hovered = <WidgetState>{WidgetState.hovered};

    expect(button.style?.overlayColor?.resolve(hovered), colors.surface.withValues(alpha: 0));
    expect(button.style?.textStyle?.resolve(hovered)?.decoration, TextDecoration.underline);
  });

  testWidgets('uses a darker semantic primary hover in light and dark themes', (tester) async {
    for (final theme in [CoeloTheme.light, CoeloTheme.dark]) {
      final session = SuperadminSession();
      addTearDown(session.dispose);

      await pumpLogin(tester, session: session, login: unavailableSuperadminLogin, theme: theme);

      final context = tester.element(find.byType(SuperadminLoginScreen));
      final colors = Theme.of(context).colorScheme;
      final actionColors = Theme.of(context).extension<CoeloActionColors>()!;
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Entrar'));
      final hoveredBackground = button.style?.backgroundColor?.resolve(<WidgetState>{
        WidgetState.hovered,
      });

      expect(hoveredBackground, actionColors.primaryHover);
      expect(hoveredBackground!.computeLuminance(), lessThan(colors.primary.computeLuminance()));
    }
  });

  testWidgets('uses the semantic Peach hover state on light login fields', (tester) async {
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await pumpLogin(tester, session: session, login: unavailableSuperadminLogin);

    final field = find.byKey(const ValueKey('superadmin-login-email'));
    final context = tester.element(field);
    final colors = Theme.of(context).colorScheme;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(field));
    await tester.pump();

    final textField = tester.widget<TextField>(
      find.descendant(of: field, matching: find.byType(TextField)),
    );
    expect(textField.decoration?.fillColor, colors.surfaceContainerLow);
  });

  testWidgets('validates empty fields and malformed email', (tester) async {
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await pumpLogin(tester, session: session, login: unavailableSuperadminLogin);

    final submitButton = find.widgetWithText(FilledButton, 'Entrar');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('superadmin-login-email')), 'email-invalido');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
  });

  testWidgets('toggles password visibility and session preference', (tester) async {
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await pumpLogin(tester, session: session, login: unavailableSuperadminLogin);

    EditableText passwordField() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('superadmin-login-password')),
        matching: find.byType(EditableText),
      ),
    );

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);

    var checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(checkbox.value, isFalse);
    await tester.tap(find.text('Manter sessão aberta'));
    await tester.pump();
    checkbox = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
    expect(checkbox.value, isTrue);
  });

  testWidgets('shows loading and safe authentication feedback', (tester) async {
    final session = SuperadminSession();
    final completer = Completer<LoginResult>();
    addTearDown(session.dispose);

    await pumpLogin(tester, session: session, login: (_) => completer.future);
    await enterValidCredentials(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Entrando...'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byKey(const ValueKey('superadmin-login-email'))).enabled,
      isFalse,
    );

    completer.complete(
      const LoginResult.failure('Credenciais inválidas. Verifique e tente novamente.'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Credenciais inválidas. Verifique e tente novamente.'), findsOneWidget);
    expect(session.isAuthenticated, isFalse);
  });

  testWidgets('forwards form values and signs in after success', (tester) async {
    final session = SuperadminSession();
    LoginRequest? receivedRequest;
    addTearDown(session.dispose);

    await pumpLogin(
      tester,
      session: session,
      login: (request) async {
        receivedRequest = request;
        return const LoginResult.success();
      },
    );
    await enterValidCredentials(tester);
    await tester.tap(find.text('Manter sessão aberta'));
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(receivedRequest?.email, 'owner@coelo.me');
    expect(receivedRequest?.password, 'not-a-real-password');
    expect(receivedRequest?.keepSessionOpen, isTrue);
    expect(session.isAuthenticated, isTrue);
  });

  testWidgets('delegates password recovery navigation', (tester) async {
    final session = SuperadminSession();
    var recoveryCalls = 0;
    addTearDown(session.dispose);

    await pumpLogin(
      tester,
      session: session,
      login: unavailableSuperadminLogin,
      onForgotPassword: () => recoveryCalls += 1,
    );
    final forgotPassword = find.text('Esqueci minha senha');
    await tester.ensureVisible(forgotPassword);
    await tester.tap(forgotPassword);
    expect(recoveryCalls, 1);
  });

  testWidgets('does not overflow on a compact window with enlarged text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await pumpLogin(
      tester,
      session: session,
      login: unavailableSuperadminLogin,
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('renders from the Coelo dark theme', (tester) async {
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await pumpLogin(
      tester,
      session: session,
      login: unavailableSuperadminLogin,
      theme: CoeloTheme.dark,
    );

    final scaffoldContext = tester.element(find.byType(Scaffold));
    expect(Theme.of(scaffoldContext).brightness, Brightness.dark);
    expect(find.byKey(const Key('superadmin-brand-mark')), findsOneWidget);
    expect(find.byKey(const Key('superadmin-brand-logo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not expose theme switching from the login screen', (tester) async {
    final session = SuperadminSession();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        darkTheme: CoeloTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(),
          child: SuperadminLoginScreen(
            session: session,
            login: unavailableSuperadminLogin,
            onForgotPassword: () {},
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );

    final themeToggle = find.byKey(const ValueKey('superadmin-login-theme-toggle'));
    expect(themeToggle, findsNothing);
  });
}
