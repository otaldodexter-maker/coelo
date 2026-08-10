import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/password_recovery.dart';
import '../view_models/password_recovery_view_model.dart';
import '../widgets/login_card.dart';
import '../widgets/login_feedback.dart';
import '../widgets/login_header.dart';
import '../widgets/login_security_notice.dart';
import '../widgets/login_submit_button.dart';
import '../widgets/login_text_field.dart';
import '../widgets/superadmin_login_form.dart';

class SuperadminForgotPasswordScreen extends StatefulWidget {
  const SuperadminForgotPasswordScreen({
    required this.requestPasswordRecovery,
    required this.onBackToLogin,
    required this.onThemeModeChanged,
    super.key,
  });

  final PasswordRecoveryAction requestPasswordRecovery;
  final VoidCallback onBackToLogin;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SuperadminForgotPasswordScreen> createState() => _SuperadminForgotPasswordScreenState();
}

class _SuperadminForgotPasswordScreenState extends State<SuperadminForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  late final PasswordRecoveryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = PasswordRecoveryViewModel(requestPasswordRecovery: widget.requestPasswordRecovery);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _viewModel.submit(_emailController.text);
  }

  Future<void> _resend() {
    return _viewModel.resend();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth <= CoeloBreakpoints.compact.maxWidth;
            final horizontalPadding = isCompact ? CoeloSpacing.space4 : CoeloSpacing.space6;
            final verticalPadding = isCompact ? CoeloSpacing.space4 : CoeloSpacing.space8;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: math.max(0, constraints.maxHeight - (verticalPadding * 2)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: LoginCard(
                      isCompact: isCompact,
                      child: ListenableBuilder(
                        listenable: _viewModel,
                        builder: (context, child) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_viewModel.isSuccess)
                                _PasswordRecoverySuccess(
                                  viewModel: _viewModel,
                                  onBackToLogin: widget.onBackToLogin,
                                  onResend: _resend,
                                )
                              else
                                AutofillGroup(
                                  child: _PasswordRecoveryForm(
                                    formKey: _formKey,
                                    emailController: _emailController,
                                    emailFocusNode: _emailFocusNode,
                                    viewModel: _viewModel,
                                    onSubmit: _submit,
                                    onBackToLogin: widget.onBackToLogin,
                                  ),
                                ),
                              const SizedBox(height: CoeloSpacing.space6),
                              const LoginSecurityNotice(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PasswordRecoveryForm extends StatelessWidget {
  const _PasswordRecoveryForm({
    required this.formKey,
    required this.emailController,
    required this.emailFocusNode,
    required this.viewModel,
    required this.onSubmit,
    required this.onBackToLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final FocusNode emailFocusNode;
  final PasswordRecoveryViewModel viewModel;
  final VoidCallback onSubmit;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !viewModel.isLoading;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LoginHeader(
            title: 'Recupere seu acesso',
            subtitle: 'Informe o e-mail associado à sua conta para receber um link de recuperação.',
          ),
          if (viewModel.errorMessage case final message?) ...[
            const SizedBox(height: CoeloSpacing.space5),
            LoginFeedback(message: message),
          ],
          const SizedBox(height: CoeloSpacing.space4),
          LoginTextField(
            fieldKey: const ValueKey('superadmin-forgot-password-email'),
            controller: emailController,
            focusNode: emailFocusNode,
            enabled: isEnabled,
            labelText: 'E-mail',
            hintText: 'seu.email@coelo.me',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            validator: validateSuperadminEmail,
            onFieldSubmitted: (_) {
              if (isEnabled) {
                onSubmit();
              }
            },
          ),
          const SizedBox(height: CoeloSpacing.space4),
          LoginSubmitButton(
            isLoading: viewModel.isLoading,
            onPressed: onSubmit,
            label: 'Enviar link de recuperação',
            loadingLabel: 'Enviando...',
          ),
          const SizedBox(height: CoeloSpacing.space2),
          TextButton(
            onPressed: isEnabled ? onBackToLogin : null,
            child: const Text('Voltar para entrar'),
          ),
        ],
      ),
    );
  }
}

class _PasswordRecoverySuccess extends StatelessWidget {
  const _PasswordRecoverySuccess({
    required this.viewModel,
    required this.onBackToLogin,
    required this.onResend,
  });

  final PasswordRecoveryViewModel viewModel;
  final VoidCallback onBackToLogin;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = theme.extension<CoeloStatusColors>()!;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: CoeloSize.touchMin),
          Center(
            child: DecoratedBox(
              key: const ValueKey('superadmin-forgot-password-success-icon'),
              decoration: BoxDecoration(color: status.successContainer, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space4),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: CoeloSize.iconLg,
                  color: status.onSuccessContainer,
                ),
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space6),
          Text(
            'Confira seu e-mail',
            style: theme.textTheme.headlineSmall?.copyWith(color: colors.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(
            'Se existir uma conta associada a este e-mail, enviaremos as instruções para redefinir a senha.',
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (viewModel.errorMessage case final message?) ...[
            const SizedBox(height: CoeloSpacing.space5),
            LoginFeedback(message: message),
          ],
          const SizedBox(height: CoeloSpacing.space8),
          LoginSubmitButton(
            isLoading: false,
            onPressed: onBackToLogin,
            label: 'Voltar para entrar',
          ),
          const SizedBox(height: CoeloSpacing.space2),
          TextButton(
            onPressed: viewModel.isLoading ? null : onResend,
            child: Text(viewModel.isLoading ? 'Reenviando...' : 'Reenviar e-mail'),
          ),
        ],
      ),
    );
  }
}
