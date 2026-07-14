import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/guards/superadmin_session.dart';
import '../../domain/login_request.dart';
import '../view_models/login_view_model.dart';
import '../widgets/login_card.dart';
import '../widgets/login_feedback.dart';
import '../widgets/login_header.dart';
import '../widgets/login_security_notice.dart';
import '../widgets/superadmin_login_form.dart';

class SuperadminLoginScreen extends StatefulWidget {
  const SuperadminLoginScreen({required this.session, required this.login, super.key});

  final SuperadminSession session;
  final LoginAction login;

  @override
  State<SuperadminLoginScreen> createState() => _SuperadminLoginScreenState();
}

class _SuperadminLoginScreenState extends State<SuperadminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  late final LoginViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = LoginViewModel(login: widget.login);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final didSignIn = await _viewModel.submit(
      LoginRequest(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        keepSessionOpen: _viewModel.keepSessionOpen,
      ),
    );
    if (!mounted || !didSignIn) {
      return;
    }

    TextInput.finishAutofillContext();
    widget.session.signIn();
  }

  void _showPasswordRecoveryFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recuperação de senha ainda não está disponível.')),
    );
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
                        builder: (context, child) {
                          return AutofillGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const LoginHeader(),
                                if (_viewModel.errorMessage case final message?) ...[
                                  const SizedBox(height: CoeloSpacing.space5),
                                  LoginFeedback(message: message),
                                ],
                                const SizedBox(height: CoeloSpacing.space6),
                                SuperadminLoginForm(
                                  formKey: _formKey,
                                  emailController: _emailController,
                                  passwordController: _passwordController,
                                  emailFocusNode: _emailFocusNode,
                                  passwordFocusNode: _passwordFocusNode,
                                  viewModel: _viewModel,
                                  onSubmit: _submit,
                                  onForgotPassword: _showPasswordRecoveryFeedback,
                                ),
                                const SizedBox(height: CoeloSpacing.space6),
                                const LoginSecurityNotice(),
                              ],
                            ),
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
