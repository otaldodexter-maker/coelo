import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'forms_files_page.dart';

/// Resolves the management version on the server before allowing an export.
///
/// Keeping that version out of the URL prevents a caller from selecting a
/// stale or arbitrary optimistic-concurrency version for a file command.
final class FormsFilesRoutePage extends StatefulWidget {
  const FormsFilesRoutePage({required this.api, required this.formId, this.onDownload, super.key});

  final FormsApi? api;
  final String formId;
  final ValueChanged<String>? onDownload;

  @override
  State<FormsFilesRoutePage> createState() => _FormsFilesRoutePageState();
}

final class _FormsFilesRoutePageState extends State<FormsFilesRoutePage> {
  FormOverview? _overview;
  FormApiException? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) {
      setState(() {
        _failure = const FormApiException(
          FormApiFailureKind.unavailable,
          'O servi\u00e7o de arquivos n\u00e3o est\u00e1 dispon\u00edvel.',
        );
      });
      return;
    }
    try {
      final overview = await api.getOverview(widget.formId);
      if (mounted) setState(() => _overview = overview);
    } on FormApiException catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return CoeloStatePanel(
        title: failure.kind == FormApiFailureKind.unauthorized
            ? 'Acesso n\u00e3o autorizado'
            : 'Arquivos indispon\u00edveis',
        message: failure.message,
        icon: Icons.lock_outline_rounded,
      );
    }
    final overview = _overview;
    if (overview == null) {
      return const CoeloStatePanel(
        title: 'Carregando arquivos',
        message: 'Validando a vers\u00e3o autorizada do formul\u00e1rio.',
        loading: true,
      );
    }
    return FormsFilesPage(
      api: widget.api,
      formId: widget.formId,
      managementVersion: overview.definition.managementVersion,
      onDownload: widget.onDownload,
    );
  }
}
