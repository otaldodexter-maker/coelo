import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../view_models/login_view_model.dart';
import 'login_submit_button.dart';

class SuperadminLoginForm extends StatelessWidget {
  const SuperadminLoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.viewModel,
    required this.onSubmit,
    required this.onForgotPassword,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final LoginViewModel viewModel;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isEnabled = !viewModel.isLoading;
    final visibilityLabel = viewModel.isPasswordVisible ? 'Ocultar senha' : 'Mostrar senha';

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('E-mail', style: theme.textTheme.labelLarge),
          const SizedBox(height: CoeloSpacing.space2),
          TextFormField(
            key: const ValueKey('superadmin-login-email'),
            controller: emailController,
            focusNode: emailFocusNode,
            enabled: isEnabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'nome@coelo.me',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: validateSuperadminEmail,
            onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Text('Senha', style: theme.textTheme.labelLarge),
          const SizedBox(height: CoeloSpacing.space2),
          TextFormField(
            key: const ValueKey('superadmin-login-password'),
            controller: passwordController,
            focusNode: passwordFocusNode,
            enabled: isEnabled,
            obscureText: !viewModel.isPasswordVisible,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Digite sua senha',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: visibilityLabel,
                onPressed: isEnabled ? viewModel.togglePasswordVisibility : null,
                icon: Icon(
                  viewModel.isPasswordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: validateSuperadminPassword,
            onFieldSubmitted: (_) {
              if (isEnabled) {
                onSubmit();
              }
            },
          ),
          const SizedBox(height: CoeloSpacing.space2),
          CheckboxListTile(
            value: viewModel.keepSessionOpen,
            onChanged: isEnabled
                ? (value) => viewModel.setKeepSessionOpen(value: value ?? false)
                : null,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              'Manter sessão aberta',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          LoginSubmitButton(isLoading: viewModel.isLoading, onPressed: onSubmit),
          const SizedBox(height: CoeloSpacing.space2),
          TextButton(
            onPressed: isEnabled ? onForgotPassword : null,
            child: const Text('Esqueci minha senha'),
          ),
        ],
      ),
    );
  }
}

String? validateSuperadminEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Informe seu e-mail.';
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

String? validateSuperadminPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Informe sua senha.';
  }
  return null;
}
