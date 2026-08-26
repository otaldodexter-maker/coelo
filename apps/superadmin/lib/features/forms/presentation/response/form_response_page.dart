import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

/// Dormant response surface kept only for source compatibility.
///
/// Routed response flows remain fail-closed until the server-owned
/// authorization and persistence composition is available.
final class FormResponsePage extends StatelessWidget {
  const FormResponsePage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: CoeloStatePanel(
          title: 'Resposta de formulário indisponível',
          message: 'O envio de respostas está temporariamente indisponível.',
          icon: Icons.lock_outline_rounded,
        ),
      ),
    ),
  );
}
