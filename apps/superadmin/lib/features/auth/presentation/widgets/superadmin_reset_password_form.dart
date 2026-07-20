import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../view_models/reset_password_view_model.dart';
import 'login_submit_button.dart';
import 'login_text_field.dart';

class SuperadminResetPasswordForm extends StatelessWidget {
  const SuperadminResetPasswordForm({
    required this.formKey,
    required this.passwordController,
    required this.confirmationController,
    required this.passwordFocusNode,
    required this.confirmationFocusNode,
    required this.viewModel,
    required this.onSubmit,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmationController;
  final FocusNode passwordFocusNode;
  final FocusNode confirmationFocusNode;
  final ResetPasswordViewModel viewModel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !viewModel.isLoading;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoginTextField(
            fieldKey: const ValueKey('superadmin-reset-password'),
            controller: passwordController,
            focusNode: passwordFocusNode,
            enabled: isEnabled,
            labelText: 'Nova senha',
            hintText: 'Digite a nova senha',
            prefixIcon: Icons.lock_outline,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            obscureText: !viewModel.isPasswordVisible,
            enableSuggestions: false,
            autocorrect: false,
            suffixIcon: IconButton(
              tooltip: viewModel.isPasswordVisible ? 'Ocultar nova senha' : 'Mostrar nova senha',
              onPressed: isEnabled ? viewModel.togglePasswordVisibility : null,
              icon: Icon(
                viewModel.isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            validator: _validatePassword,
            onFieldSubmitted: (_) => confirmationFocusNode.requestFocus(),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          LoginTextField(
            fieldKey: const ValueKey('superadmin-reset-password-confirmation'),
            controller: confirmationController,
            focusNode: confirmationFocusNode,
            enabled: isEnabled,
            labelText: 'Confirmar nova senha',
            hintText: 'Digite a nova senha novamente',
            prefixIcon: Icons.lock_outline,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            obscureText: !viewModel.isConfirmationVisible,
            enableSuggestions: false,
            autocorrect: false,
            suffixIcon: IconButton(
              tooltip: viewModel.isConfirmationVisible
                  ? 'Ocultar confirmação de senha'
                  : 'Mostrar confirmação de senha',
              onPressed: isEnabled ? viewModel.toggleConfirmationVisibility : null,
              icon: Icon(
                viewModel.isConfirmationVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
            validator: (value) => _validateConfirmation(value, passwordController.text),
            onFieldSubmitted: (_) {
              if (isEnabled) {
                onSubmit();
              }
            },
          ),
          const SizedBox(height: CoeloSpacing.space5),
          LoginSubmitButton(
            isLoading: viewModel.isLoading,
            onPressed: onSubmit,
            label: 'Salvar nova senha',
            loadingLabel: 'Salvando...',
          ),
        ],
      ),
    );
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe a nova senha.';
    }
    if (value.length < 8) {
      return 'A senha precisa ter pelo menos 8 caracteres.';
    }
    return null;
  }

  String? _validateConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirme a nova senha.';
    }
    if (value != password) {
      return 'As senhas não coincidem.';
    }
    return null;
  }
}
