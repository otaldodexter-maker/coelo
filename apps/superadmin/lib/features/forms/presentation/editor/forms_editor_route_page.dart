import 'dart:async';
import 'dart:math';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'forms_editor_page.dart';

final class FormsEditorRoutePage extends StatefulWidget {
  const FormsEditorRoutePage({
    required this.api,
    this.formId,
    this.institutionId,
    this.readOnly = false,
    super.key,
  });

  final FormsApi? api;
  final String? formId;
  final String? institutionId;
  final bool readOnly;

  @override
  State<FormsEditorRoutePage> createState() => _FormsEditorRoutePageState();
}

final class _FormsEditorRoutePageState extends State<FormsEditorRoutePage> {
  FormDefinition? _definition;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(() => _failure = StateError('forms unavailable'));
      return;
    }
    try {
      final definition = widget.formId == null
          ? _newDefinition(widget.institutionId)
          : await api.getEditor(widget.formId!);
      if (mounted) setState(() => _definition = definition);
    } catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  FormDefinition _newDefinition(String? institutionId) {
    if (institutionId == null || institutionId.isEmpty) {
      throw const FormatException('institution context required');
    }
    return FormDefinition(
      id: _uuid(),
      institutionId: institutionId,
      kind: FormKind.form,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      title: 'Novo formulário',
      sections: const [],
    );
  }

  String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_failure != null) {
      return const CoeloStatePanel(
        title: 'Editor indisponível',
        message: 'Selecione uma instituição autorizada e tente novamente.',
        icon: Icons.lock_outline_rounded,
      );
    }
    final definition = _definition;
    if (definition == null) {
      return const CoeloStatePanel(
        title: 'Abrindo editor',
        message: 'Carregando a definição autorizada.',
        loading: true,
      );
    }
    if (widget.readOnly) {
      return AbsorbPointer(
        child: FormsEditorPage(api: widget.api, initialDefinition: definition),
      );
    }
    return FormsEditorPage(api: widget.api, initialDefinition: definition);
  }
}
