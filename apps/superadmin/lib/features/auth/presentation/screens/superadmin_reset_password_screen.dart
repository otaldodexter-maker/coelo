import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../domain/reset_password_action.dart';
import '../view_models/reset_password_view_model.dart';
import '../widgets/login_card.dart';
import '../widgets/login_feedback.dart';
import '../widgets/login_header.dart';
import '../widgets/login_security_notice.dart';
import '../widgets/login_submit_button.dart';
import '../widgets/superadmin_reset_password_form.dart';

enum RecoveryLinkState { processing, valid, invalid }

class SuperadminResetPasswordScreen extends StatefulWidget {
  const SuperadminResetPasswordScreen({
    required this.resetPassword,
    required this.onBackToLogin,
    required this.onThemeModeChanged,
    this.initialLinkState = RecoveryLinkState.valid,
    super.key,
  });

  final ResetPasswordAction resetPassword;
  final VoidCallback onBackToLogin;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final RecoveryLinkState initialLinkState;

  @override
  State<SuperadminResetPasswordScreen> createState() => _SuperadminResetPasswordScreenState();
}

class _SuperadminResetPasswordScreenState extends State<SuperadminResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmationFocusNode = FocusNode();
  late final ResetPasswordViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ResetPasswordViewModel(resetPassword: widget.resetPassword);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _passwordFocusNode.dispose();
    _confirmationFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _viewModel.submit(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        builder: (context, child) => _buildContent(),
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

  Widget _buildContent() {
    final body = switch ((widget.initialLinkState, _viewModel.isSuccess)) {
      (_, true) => _buildStatus(
        icon: Icons.check_circle_outline,
        title: 'Senha atualizada',
        message: 'Sua senha foi redefinida com segurança. Entre novamente para continuar.',
        isSuccess: true,
        onBackToLogin: widget.onBackToLogin,
      ),
      (RecoveryLinkState.processing, false) => _buildProcessing(),
      (RecoveryLinkState.invalid, false) => _buildStatus(
        icon: Icons.link_off_outlined,
        title: 'Este link não é mais válido',
        message: 'Solicite um novo link para redefinir sua senha.',
        isSuccess: false,
        onBackToLogin: widget.onBackToLogin,
      ),
      (RecoveryLinkState.valid, false) => _buildForm(),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        body,
        const SizedBox(height: CoeloSpacing.space6),
        const LoginSecurityNotice(),
      ],
    );
  }

  Widget _buildForm() {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LoginHeader(
            title: 'Crie uma nova senha',
            subtitle: 'Escolha uma nova senha para recuperar o acesso à sua conta.',
          ),
          if (_viewModel.errorMessage case final message?) ...[
            const SizedBox(height: CoeloSpacing.space5),
            LoginFeedback(message: message, semanticLabelPrefix: 'Erro ao redefinir senha'),
          ],
          const SizedBox(height: CoeloSpacing.space4),
          SuperadminResetPasswordForm(
            formKey: _formKey,
            passwordController: _passwordController,
            confirmationController: _confirmationController,
            passwordFocusNode: _passwordFocusNode,
            confirmationFocusNode: _confirmationFocusNode,
            viewModel: _viewModel,
            onSubmit: _submit,
          ),
          const SizedBox(height: CoeloSpacing.space2),
          TextButton(
            onPressed: _viewModel.isLoading ? null : widget.onBackToLogin,
            child: const Text('Voltar para entrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    final theme = Theme.of(context);
    final status = theme.extension<CoeloStatusColors>()!;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: CoeloSize.touchMin),
          Center(child: CircularProgressIndicator(color: status.info)),
          const SizedBox(height: CoeloSpacing.space6),
          Text(
            'Validando link...',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(
            'Estamos verificando se este link de recuperação pode ser usado.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatus({
    required IconData icon,
    required String title,
    required String message,
    required bool isSuccess,
    required VoidCallback onBackToLogin,
  }) {
    final theme = Theme.of(context);
    final status = theme.extension<CoeloStatusColors>()!;
    final backgroundColor = isSuccess ? status.successContainer : status.errorContainer;
    final foregroundColor = isSuccess ? status.onSuccessContainer : status.onErrorContainer;

    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: CoeloSize.touchMin),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space4),
                child: Icon(icon, size: CoeloSize.iconLg, color: foregroundColor),
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space6),
          Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: CoeloSpacing.space3),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CoeloSpacing.space8),
          LoginSubmitButton(
            isLoading: false,
            onPressed: onBackToLogin,
            label: 'Voltar para entrar',
          ),
        ],
      ),
    );
  }
}
