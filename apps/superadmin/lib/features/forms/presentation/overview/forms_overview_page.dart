import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../data/development_forms_api.dart';

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
    this.development = false,
    super.key,
  });

  const FormsOverviewPage.development({
    required this.formId,
    this.onEdit,
    this.onTest,
    this.onMonitor,
    this.onResponses,
    this.onFiles,
    super.key,
  }) : api = null,
       canManageLifecycle = true,
       canTransferCrossInstitution = false,
       development = true;

  final FormsApi? api;
  final String formId;
  final VoidCallback? onEdit;
  final VoidCallback? onTest;
  final VoidCallback? onMonitor;
  final VoidCallback? onResponses;
  final VoidCallback? onFiles;
  final bool canManageLifecycle;
  final bool canTransferCrossInstitution;
  final bool development;

  @override
  State<FormsOverviewPage> createState() => _FormsOverviewPageState();
}

final class _FormsOverviewPageState extends State<FormsOverviewPage> {
  FormOverview? _overview;
  FormApiException? _failure;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant FormsOverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.formId != widget.formId || !identical(oldWidget.api, widget.api)) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.development) {
      if (!mounted) return;
      setState(() {
        _failure = null;
        _overview = _developmentOverview(widget.formId);
      });
      return;
    }
    final api = widget.api;
    final formId = widget.formId;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (!mounted || generation != _loadGeneration) return;
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
      final result = await api.getOverview(formId);
      if (_isCurrentLoad(generation, api, formId)) setState(() => _overview = result);
    } on FormApiException catch (error) {
      if (_isCurrentLoad(generation, api, formId)) setState(() => _failure = error);
    }
  }

  bool _isCurrentLoad(int generation, FormsApi api, String formId) =>
      mounted &&
      generation == _loadGeneration &&
      identical(api, widget.api) &&
      formId == widget.formId;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contentPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space6
          : CoeloSpacing.space4;
      final failure = _failure;
      final overview = _overview;
      return ListView(
        key: const Key('forms-overview-content'),
        padding: EdgeInsets.all(contentPadding),
        children: [
          if (failure != null)
            CoeloStatePanel(
              title: failure.kind == FormApiFailureKind.unauthorized
                  ? 'Acesso não autorizado'
                  : 'Não foi possível carregar o formulário',
              message: failure.message,
              icon: failure.kind == FormApiFailureKind.unauthorized
                  ? Icons.lock_outline_rounded
                  : Icons.error_outline_rounded,
              actionLabel: failure.kind == FormApiFailureKind.unauthorized
                  ? null
                  : 'Tentar novamente',
              onAction: failure.kind == FormApiFailureKind.unauthorized ? null : _load,
            )
          else if (overview == null)
            const CoeloStatePanel(
              title: 'Carregando formulário',
              message: 'Aguarde enquanto o resumo autorizado é carregado.',
              loading: true,
            )
          else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(overview.definition.title, style: Theme.of(context).textTheme.headlineMedium),
                Text('Versão de gestão ${overview.definition.managementVersion}'),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            _OverviewActions(
              onEdit: widget.onEdit,
              onTest: widget.onTest,
              onMonitor: widget.onMonitor,
              onResponses: widget.onResponses,
              onFiles: widget.onFiles,
            ),
            const SizedBox(height: CoeloSpacing.space6),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
                return Wrap(
                  key: const Key('forms-overview-metrics'),
                  spacing: CoeloSpacing.space6,
                  runSpacing: CoeloSpacing.space6,
                  children: [
                    _metric(context, width, 'Distribuições', overview.applicationCount),
                    _metric(context, width, 'Ocorrências', overview.occurrenceCount),
                    _metric(context, width, 'Respostas', overview.responseCount),
                  ],
                );
              },
            ),
            if (widget.development) ...[
              const SizedBox(height: CoeloSpacing.space6),
              const _DevelopmentOperations(),
            ],
          ],
        ],
      );
    },
  );

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

final class _OverviewActions extends StatelessWidget {
  const _OverviewActions({
    this.onEdit,
    this.onTest,
    this.onMonitor,
    this.onResponses,
    this.onFiles,
  });

  final VoidCallback? onEdit;
  final VoidCallback? onTest;
  final VoidCallback? onMonitor;
  final VoidCallback? onResponses;
  final VoidCallback? onFiles;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: CoeloSpacing.space2,
    runSpacing: CoeloSpacing.space2,
    children: [
      OutlinedButton.icon(
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Editar'),
      ),
      OutlinedButton.icon(
        onPressed: onTest,
        icon: const Icon(Icons.science_outlined),
        label: const Text('Testar'),
      ),
      OutlinedButton.icon(
        onPressed: onMonitor,
        icon: const Icon(Icons.monitor_heart_outlined),
        label: const Text('Monitorar'),
      ),
      OutlinedButton.icon(
        onPressed: onResponses,
        icon: const Icon(Icons.fact_check_outlined),
        label: const Text('Respostas'),
      ),
      OutlinedButton.icon(
        onPressed: onFiles,
        icon: const Icon(Icons.folder_outlined),
        label: const Text('Arquivos'),
      ),
    ],
  );
}

final class _DevelopmentOperations extends StatelessWidget {
  const _DevelopmentOperations();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Fixture local · sem persistência remota',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: CoeloSpacing.space3),
      const _OperationCard(
        icon: Icons.account_tree_outlined,
        title: 'Distribuições e audiências',
        detail: 'Instituição · Unidade · Turma · Atividade · Perfil · Pessoa',
      ),
      const _OperationCard(
        icon: Icons.event_repeat_outlined,
        title: 'Agendamento único e recorrente',
        detail: 'Uma vez · semanal · mensal · janela configurada',
      ),
      const _OperationCard(
        icon: Icons.notifications_active_outlined,
        title: 'Ocorrências, fuso e lembretes',
        detail: 'America/Sao_Paulo · 24 h antes · 1 h antes',
      ),
      const _OperationCard(
        icon: Icons.history_rounded,
        title: 'Versionamento',
        detail: 'Versão publicada 3',
        trailing: 'Rascunho de edição 4',
      ),
    ],
  );
}

final class _OperationCard extends StatelessWidget {
  const _OperationCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.trailing,
  });
  final IconData icon;
  final String title, detail;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: CoeloAdminInteractiveCard(
      semanticLabel: '$title, $detail${trailing == null ? '' : ', $trailing'}',
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(detail),
                  if (trailing != null) Text(trailing!),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

FormOverview _developmentOverview(String formId) => FormOverview(
  definition: FormDefinition(
    id: formId,
    institutionId: 'institution-fixture',
    kind: FormKind.form,
    identityMode: FormIdentityMode.identified,
    responseUnit: FormResponseUnit.person,
    title: developmentFormTitle(formId, fallback: 'Pesquisa das famílias'),
    managementVersion: 4,
    sections: const [],
  ),
  applicationCount: 3,
  occurrenceCount: 12,
  responseCount: 28,
);

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
