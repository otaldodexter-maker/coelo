import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../view_models/login_view_model.dart';
import 'login_forgot_password_button.dart';
import 'login_submit_button.dart';
import 'login_text_field.dart';

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
    final isEnabled = !viewModel.isLoading;
    final visibilityLabel = viewModel.isPasswordVisible ? 'Ocultar senha' : 'Mostrar senha';

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoginTextField(
            fieldKey: const ValueKey('superadmin-login-email'),
            controller: emailController,
            focusNode: emailFocusNode,
            enabled: isEnabled,
            labelText: 'E-mail',
            hintText: 'seu.email@coelo.me',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            autocorrect: false,
            validator: validateSuperadminEmail,
            onFieldSubmitted: (_) => passwordFocusNode.requestFocus(),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          LoginTextField(
            fieldKey: const ValueKey('superadmin-login-password'),
            controller: passwordController,
            focusNode: passwordFocusNode,
            enabled: isEnabled,
            labelText: 'Senha',
            hintText: 'Digite sua senha',
            prefixIcon: Icons.lock_outline,
            obscureText: !viewModel.isPasswordVisible,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            enableSuggestions: false,
            autocorrect: false,
            suffixIcon: IconButton(
              tooltip: visibilityLabel,
              onPressed: isEnabled ? viewModel.togglePasswordVisibility : null,
              icon: Icon(
                viewModel.isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
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
          _KeepSessionOpenControl(
            value: viewModel.keepSessionOpen,
            enabled: isEnabled,
            onChanged: (value) => viewModel.setKeepSessionOpen(value: value),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          LoginSubmitButton(isLoading: viewModel.isLoading, onPressed: onSubmit),
          const SizedBox(height: CoeloSpacing.space2),
          LoginForgotPasswordButton(onPressed: isEnabled ? onForgotPassword : null),
        ],
      ),
    );
  }
}

class _KeepSessionOpenControl extends StatefulWidget {
  const _KeepSessionOpenControl({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  State<_KeepSessionOpenControl> createState() => _KeepSessionOpenControlState();
}

class _KeepSessionOpenControlState extends State<_KeepSessionOpenControl> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'Manter sessão aberta');
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.enabled) widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final actionColors = theme.extension<CoeloActionColors>()!;
    final radius = BorderRadius.circular(CoeloRadius.sm);

    return Semantics(
      key: const ValueKey('superadmin-login-keep-session'),
      container: true,
      checked: widget.value,
      enabled: widget.enabled,
      label: 'Manter sessão aberta',
      onTap: widget.enabled ? _toggle : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
        child: DecoratedBox(
          key: _focused ? const ValueKey('superadmin-login-keep-session-focus-ring') : null,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: _focused ? Border.all(color: actionColors.focusRing, width: 2) : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(
              key: const ValueKey('superadmin-login-keep-session-control'),
              focusNode: _focusNode,
              canRequestFocus: widget.enabled,
              borderRadius: radius,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              onFocusChange: (focused) => setState(() => _focused = focused),
              onTap: widget.enabled ? _toggle : null,
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    ExcludeFocus(
                      child: Checkbox(
                        value: widget.value,
                        onChanged: widget.enabled ? (_) => _toggle() : null,
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                      ),
                    ),
                    const SizedBox(width: CoeloSpacing.space1),
                    Expanded(
                      child: Text(
                        'Manter sessão aberta',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: widget.enabled ? colors.onSurface : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
