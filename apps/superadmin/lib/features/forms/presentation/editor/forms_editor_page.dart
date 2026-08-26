import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

/// Dormant editor surface kept only for source compatibility.
///
/// Editing remains fail-closed until its server-owned authorization and
/// persistence composition is reproducible from tracked sources.
final class FormsEditorPage extends StatelessWidget {
  const FormsEditorPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: CoeloStatePanel(
          title: 'Editor de formulários indisponível',
          message: 'A edição de formulários está temporariamente indisponível.',
          icon: Icons.lock_outline_rounded,
        ),
      ),
    ),
  );
}
