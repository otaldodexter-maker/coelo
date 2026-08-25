import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../directory/forms_lifecycle_actions.dart';

final class FormsOverviewPage extends StatefulWidget {
  const FormsOverviewPage({
    required this.api,
    required this.formId,
    this.onEdit,
    this.onTest,
    this.onMonitor,
    this.onResponses,
    this.onFiles,
    this.canManageLifecycle = false,
    this.canTransferCrossInstitution = false,
    super.key,
  });

  final FormsApi? api;
  final String formId;
  final VoidCallback? onEdit;
  final VoidCallback? onTest;
  final VoidCallback? onMonitor;
  final VoidCallback? onResponses;
  final VoidCallback? onFiles;
  final bool canManageLifecycle;
  final bool canTransferCrossInstitution;

  @override
  State<FormsOverviewPage> createState() => _FormsOverviewPageState();
}

final class _FormsOverviewPageState extends State<FormsOverviewPage> {
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
      setState(
        () => _failure = const FormApiException(
          FormApiFailureKind.unavailable,
          'O serviço de Formulários não está disponível.',
        ),
      );
      return;
    }
    setState(() {
      _failure = null;
      _overview = null;
    });
    try {
      final result = await api.getOverview(widget.formId);
      if (mounted) setState(() => _overview = result);
    } on FormApiException catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final overview = _overview;
    if (failure != null) {
      return CoeloStatePanel(
        title: failure.kind == FormApiFailureKind.unauthorized
            ? 'Acesso não autorizado'
            : 'Não foi possível carregar o formulário',
        message: failure.message,
        icon: failure.kind == FormApiFailureKind.unauthorized
            ? Icons.lock_outline_rounded
            : Icons.error_outline_rounded,
        actionLabel: failure.kind == FormApiFailureKind.unauthorized ? null : 'Tentar novamente',
        onAction: failure.kind == FormApiFailureKind.unauthorized ? null : _load,
      );
    }
    if (overview == null) {
      return const CoeloStatePanel(
        title: 'Carregando formulário',
        message: 'Aguarde enquanto o resumo autorizado é carregado.',
        loading: true,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: CoeloSpacing.space4,
          runSpacing: CoeloSpacing.space3,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(overview.definition.title, style: Theme.of(context).textTheme.headlineMedium),
                Text('Versão de gestão ${overview.definition.managementVersion}'),
              ],
            ),
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [
                OutlinedButton(onPressed: widget.onTest, child: const Text('Testar')),
                OutlinedButton(onPressed: widget.onMonitor, child: const Text('Monitorar')),
                OutlinedButton(onPressed: widget.onFiles, child: const Text('Arquivos')),
                FilledButton(onPressed: widget.onEdit, child: const Text('Editar')),
                if (widget.canManageLifecycle)
                  FormsLifecycleActions(
                    api: widget.api,
                    formId: overview.definition.id,
                    formTitle: overview.definition.title,
                    managementVersion: overview.definition.managementVersion,
                    canManage: widget.canManageLifecycle,
                    canTransferCrossInstitution: widget.canTransferCrossInstitution,
                    onCompleted: _load,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space5),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 3 : 1;
            final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space4) / columns;
            return Wrap(
              spacing: CoeloSpacing.space4,
              runSpacing: CoeloSpacing.space4,
              children: [
                _metric(context, width, 'Distribuições', overview.applicationCount),
                _metric(context, width, 'Ocorrências', overview.occurrenceCount),
                _metric(
                  context,
                  width,
                  'Respostas',
                  overview.responseCount,
                  onPressed: widget.onResponses,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _metric(
    BuildContext context,
    double width,
    String label,
    int value, {
    VoidCallback? onPressed,
  }) => SizedBox(
    width: width,
    child: CoeloAdminInteractiveCard(
      semanticLabel: '$label: $value',
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

@Preview(name: 'Formulários · visão geral · desktop', size: Size(1024, 720))
Widget formsOverviewPreview() => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: FormsOverviewPage(
      api: _FormsOverviewPreviewApi(),
      formId: 'preview-form',
      canManageLifecycle: true,
    ),
  ),
);

final class _FormsOverviewPreviewApi implements FormsApi {
  @override
  Future<FormOverview> getOverview(String formId) async => FormOverview(
    definition: FormDefinition(
      id: formId,
      institutionId: 'preview-institution',
      kind: FormKind.form,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      title: 'Pesquisa das famílias',
      managementVersion: 4,
      sections: const [],
    ),
    applicationCount: 3,
    occurrenceCount: 12,
    responseCount: 28,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
