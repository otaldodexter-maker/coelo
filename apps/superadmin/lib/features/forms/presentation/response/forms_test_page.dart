import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

/// Dormant test surface kept fail-closed until the backend-authorized flow is
/// reproducible from tracked sources.
final class FormsTestPage extends StatelessWidget {
  const FormsTestPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: CoeloStatePanel(
          title: 'Teste de formulário indisponível',
          message: 'O teste de formulários está temporariamente indisponível.',
          icon: Icons.lock_outline_rounded,
        ),
      ),
    ),
  );
}
