import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'form_response_page.dart';

/// Loads the current editable definition and renders a non-persistent response
/// simulation. Route wiring intentionally lives outside this feature surface.
final class FormsTestPage extends StatefulWidget {
  const FormsTestPage({required this.api, required this.formId, super.key});

  final FormsApi? api;
  final String formId;

  @override
  State<FormsTestPage> createState() => _FormsTestPageState();
}

final class _FormsTestPageState extends State<FormsTestPage> {
  FormDefinition? _definition;
  String? _failureMessage;
  var _unauthorized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(() => _failureMessage = 'O serviço de Formulários não está disponível.');
      return;
    }
    try {
      final projection = await api.getEditor(widget.formId);
      if (const FormDefinitionValidator().validate(projection.definition).isNotEmpty) {
        if (mounted) {
          setState(() => _failureMessage = 'Revise a estrutura do formulário antes de testá-lo.');
        }
        return;
      }
      if (mounted) setState(() => _definition = projection.definition);
    } on FormApiException catch (error) {
      if (mounted) {
        setState(() {
          _unauthorized = error.kind == FormApiFailureKind.unauthorized;
          _failureMessage = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failureMessage = 'Não foi possível abrir o teste deste formulário.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final failureMessage = _failureMessage;
    if (failureMessage != null) {
      return CoeloStatePanel(
        title: _unauthorized ? 'Acesso não autorizado' : 'Teste indisponível',
        message: failureMessage,
        icon: Icons.lock_outline_rounded,
      );
    }
    final definition = _definition;
    if (definition == null) {
      return const CoeloStatePanel(
        title: 'Abrindo teste',
        message: 'Carregando a definição sem criar participação.',
        loading: true,
      );
    }
    return FormResponsePage.test(definition: definition);
  }
}
