import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

enum FormsOperationsSurface { monitor, responses, responseDetail, files }

enum FormsOperationsState { content, loading, empty, noResults, error, unauthorized, unavailable }

final class FormsFilesDevelopmentStore extends ChangeNotifier {
  bool assetPresent = true;
  bool accessExpired = false;
  bool uploadCanceled = false;
  String? feedback;

  void cancelUpload() {
    uploadCanceled = true;
    notifyListeners();
  }

  void expireAccess() {
    accessExpired = true;
    notifyListeners();
  }

  void deleteAsset() {
    assetPresent = false;
    notifyListeners();
  }

  void showFeedback(String value) {
    feedback = value;
    notifyListeners();
  }
}

final class FormsOperationsPage extends StatefulWidget {
  const FormsOperationsPage.monitor({
    this.api,
    this.formId,
    this.development = false,
    this.state = FormsOperationsState.content,
    super.key,
  }) : surface = FormsOperationsSurface.monitor,
       anonymous = false,
       developmentStore = null,
       responseId = null;

  const FormsOperationsPage.responses({
    this.api,
    this.formId,
    this.development = false,
    this.state = FormsOperationsState.content,
    super.key,
  }) : surface = FormsOperationsSurface.responses,
       anonymous = false,
       developmentStore = null,
       responseId = null;

  const FormsOperationsPage.responseDetail({
    this.api,
    this.responseId,
    this.development = false,
    this.anonymous = false,
    this.state = FormsOperationsState.content,
    super.key,
  }) : surface = FormsOperationsSurface.responseDetail,
       developmentStore = null,
       formId = null;

  const FormsOperationsPage.files({
    this.api,
    this.formId,
    this.development = false,
    this.state = FormsOperationsState.content,
    this.developmentStore,
    super.key,
  }) : surface = FormsOperationsSurface.files,
       anonymous = false,
       responseId = null;

  final FormsOperationsSurface surface;
  final bool development;
  final bool anonymous;
  final FormsOperationsState state;
  final FormsFilesDevelopmentStore? developmentStore;
  final FormsApi? api;
  final String? formId;
  final String? responseId;

  @override
  State<FormsOperationsPage> createState() => _FormsOperationsPageState();
}

final class _FormsOperationsPageState extends State<FormsOperationsPage> {
  late FormsOperationsState _state = widget.state;
  Object? _projection;

  bool get _usesProductionApi => !widget.development && widget.api != null;

  @override
  void initState() {
    super.initState();
    if (_usesProductionApi) unawaited(_loadProduction());
  }

  @override
  void didUpdateWidget(covariant FormsOperationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _state = widget.state;
    if (oldWidget.api != widget.api ||
        oldWidget.formId != widget.formId ||
        oldWidget.responseId != widget.responseId) {
      if (_usesProductionApi) unawaited(_loadProduction());
    }
  }

  Future<void> _loadProduction() async {
    final api = widget.api;
    if (api == null) return;
    final formId = widget.formId;
    final responseId = widget.responseId;
    if ((widget.surface != FormsOperationsSurface.responseDetail && formId == null) ||
        (widget.surface == FormsOperationsSurface.responseDetail && responseId == null)) {
      setState(() => _state = FormsOperationsState.unavailable);
      return;
    }
    setState(() => _state = FormsOperationsState.loading);
    try {
      final projection = switch (widget.surface) {
        FormsOperationsSurface.monitor => api.getMonitor(FormMonitorQuery(formId: formId!)),
        FormsOperationsSurface.responses => api.listResponses(FormResponsesQuery(formId: formId!)),
        FormsOperationsSurface.responseDetail => api.getResponseDetail(responseId!),
        FormsOperationsSurface.files => api.listFileJobs(formId: formId!),
      };
      final value = await projection;
      if (mounted) {
        setState(() {
          _projection = value;
          _state = FormsOperationsState.content;
        });
      }
    } on FormApiException catch (error) {
      if (mounted) {
        setState(
          () => _state = error.kind == FormApiFailureKind.unauthorized
              ? FormsOperationsState.unauthorized
              : FormsOperationsState.error,
        );
      }
    } on Object {
      if (mounted) setState(() => _state = FormsOperationsState.error);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return ListView(
          key: Key('forms-operations-${widget.surface.name}'),
          padding: EdgeInsets.fromLTRB(inset, CoeloSpacing.space5, inset, CoeloSpacing.space8),
          children: [
            _Header(surface: widget.surface),
            const SizedBox(height: CoeloSpacing.space4),
            if (_usesProductionApi) ...[
              if (_state != FormsOperationsState.content)
                _OperationsStatePanel(
                  state: _state,
                  onRetry: _state == FormsOperationsState.error ? _loadProduction : null,
                )
              else
                _productionContent(),
            ] else if (!widget.development) ...[
              const CoeloStatePanel(
                key: Key('forms-operations-unavailable'),
                icon: Icons.lock_outline_rounded,
                title: 'Operação indisponível',
                message:
                    'A composição visual está pronta, mas leitura, persistência e autorização produtivas permanecem bloqueadas.',
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _surfaceContent(available: false),
            ] else if (_state == FormsOperationsState.unavailable)
              const CoeloStatePanel(
                key: Key('forms-operations-unavailable'),
                icon: Icons.lock_outline_rounded,
                title: 'Operação indisponível',
                message: 'A fixture local está indisponível para este estado de demonstração.',
              )
            else if (_state != FormsOperationsState.content)
              _OperationsStatePanel(
                state: _state,
                onRetry: _state == FormsOperationsState.error
                    ? () => setState(() => _state = FormsOperationsState.content)
                    : null,
              )
            else
              _surfaceContent(available: true),
          ],
        );
      },
    ),
  );

  Widget _surfaceContent({required bool available}) => switch (widget.surface) {
    FormsOperationsSurface.monitor => _MonitorContent(available: available),
    FormsOperationsSurface.responses => _ResponsesContent(available: available),
    FormsOperationsSurface.responseDetail => _ResponseDetailContent(
      anonymous: available && widget.anonymous,
      available: available,
    ),
    FormsOperationsSurface.files => _FilesContent(
      available: available,
      developmentStore: widget.developmentStore,
    ),
  };

  Widget _productionContent() {
    final (title, message) = switch (_projection) {
      FormMonitorProjection value => (
        'Monitoramento autorizado',
        '${value.respondedCount} respostas de ${value.eligibleCount} pessoas elegíveis.',
      ),
      FormCursorPage<FormResponseSummary> value => (
        'Respostas autorizadas',
        '${value.items.length} resposta(s) carregada(s) nesta página.',
      ),
      FormResponseDetail value => (
        'Resposta autorizada',
        '${value.answers.length} resposta(s) carregada(s) para consulta.',
      ),
      FormCursorPage<FormFileJob> value => (
        'Arquivos autorizados',
        '${value.items.length} job(s) de arquivo carregado(s).',
      ),
      _ => ('Dados indisponíveis', 'Não foi possível interpretar a projeção autorizada.'),
    };
    return CoeloStatePanel(
      key: Key('forms-operations-production-${widget.surface.name}'),
      icon: Icons.verified_user_outlined,
      title: title,
      message: message,
    );
  }
}

final class _OperationsStatePanel extends StatelessWidget {
  const _OperationsStatePanel({required this.state, this.onRetry});
  final FormsOperationsState state;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon, loading) = switch (state) {
      FormsOperationsState.loading => (
        'Carregando',
        'Aguarde enquanto os dados autorizados são preparados.',
        Icons.hourglass_top_rounded,
        true,
      ),
      FormsOperationsState.empty => (
        'Nenhum item ainda',
        'Esta operação ainda não possui dados.',
        Icons.inbox_outlined,
        false,
      ),
      FormsOperationsState.noResults => (
        'Nenhum resultado',
        'Ajuste os filtros ou a busca para tentar novamente.',
        Icons.search_off_rounded,
        false,
      ),
      FormsOperationsState.error => (
        'Não foi possível carregar',
        'Os dados locais foram preservados. Tente novamente.',
        Icons.error_outline_rounded,
        false,
      ),
      FormsOperationsState.unauthorized => (
        'Acesso não autorizado',
        'Você não possui permissão para consultar este conteúdo.',
        Icons.lock_outline_rounded,
        false,
      ),
      FormsOperationsState.content ||
      FormsOperationsState.unavailable => throw StateError('Estado tratado fora deste painel.'),
    };
    return CoeloStatePanel(
      key: Key('forms-operations-state-${state.name}'),
      title: title,
      message: message,
      icon: icon,
      loading: loading,
      actionLabel: state == FormsOperationsState.error ? 'Tentar novamente' : null,
      onAction: state == FormsOperationsState.error ? onRetry : null,
    );
  }
}

final class _Header extends StatelessWidget {
  const _Header({required this.surface});

  final FormsOperationsSurface surface;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = switch (surface) {
      FormsOperationsSurface.monitor => (
        'Monitoramento',
        'Acompanhe elegibilidade e participação por contexto.',
      ),
      FormsOperationsSurface.responses => (
        'Respostas',
        'Consulte envios identificados e anônimos sem expor dados protegidos.',
      ),
      FormsOperationsSurface.responseDetail => (
        'Detalhe da resposta',
        'Revise o conteúdo enviado e a trilha disponível.',
      ),
      FormsOperationsSurface.files => (
        'Arquivos e exportações',
        'Acompanhe uploads protegidos e jobs de CSV, XLSX e ZIP.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: CoeloSpacing.space1),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

final class _MonitorContent extends StatefulWidget {
  const _MonitorContent({required this.available});

  final bool available;

  @override
  State<_MonitorContent> createState() => _MonitorContentState();
}

final class _MonitorContentState extends State<_MonitorContent> {
  String? _detail;

  void _select(String label) => setState(() => _detail = label);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space3,
        children: [
          _Metric(
            label: 'Elegíveis',
            value: widget.available ? '128' : '—',
            icon: Icons.groups_outlined,
            available: widget.available,
            onPressed: () => _select('Elegíveis'),
          ),
          _Metric(
            label: 'Responderam',
            value: widget.available ? '89' : '—',
            icon: Icons.task_alt_rounded,
            available: widget.available,
            onPressed: () => _select('Responderam'),
          ),
          _Metric(
            label: 'Não responderam',
            value: widget.available ? '37' : '—',
            icon: Icons.schedule_rounded,
            available: widget.available,
            onPressed: () => _select('Não responderam'),
          ),
          _Metric(
            label: 'Perdeu elegibilidade',
            value: widget.available ? '2' : '—',
            icon: Icons.person_off_outlined,
            available: widget.available,
            onPressed: () => _select('Perdeu elegibilidade'),
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space5),
      Semantics(
        key: const Key('forms-monitor-hierarchy'),
        label: 'Hierarquia de monitoramento',
        child: Column(
          children: widget.available
              ? [
                  _HierarchyRow(
                    label: 'Colégio Horizonte',
                    detail: '89 de 128 responderam',
                    level: 0,
                    available: true,
                    onPressed: () => _select('Colégio Horizonte'),
                  ),
                  _HierarchyRow(
                    label: 'Unidade Centro',
                    detail: '61 de 84 responderam',
                    level: 1,
                    available: true,
                    onPressed: () => _select('Unidade Centro'),
                  ),
                  _HierarchyRow(
                    label: '7º ano A',
                    detail: '24 de 31 responderam',
                    level: 2,
                    available: true,
                    onPressed: () => _select('7º ano A'),
                  ),
                  _HierarchyRow(
                    label: 'Famílias',
                    detail: '18 de 23 responderam',
                    level: 3,
                    available: true,
                    onPressed: () => _select('Famílias'),
                  ),
                ]
              : const [
                  _HierarchyRow(
                    label: 'Contexto indisponível',
                    detail: 'Dados autorizados não carregados',
                    level: 0,
                    available: false,
                  ),
                ],
        ),
      ),
      if (_detail != null) ...[
        const SizedBox(height: CoeloSpacing.space3),
        CoeloStatePanel(
          icon: Icons.manage_search_rounded,
          title: 'Detalhamento: $_detail',
          message: 'A fixture local preserva o contexto selecionado sem consultar dados remotos.',
        ),
      ],
    ],
  );
}

final class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.available,
    this.onPressed,
  });
  final String label, value;
  final IconData icon;
  final bool available;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: CoeloAdminInteractiveCard(
      semanticLabel: '$label: $value',
      onPressed: available ? onPressed : null,
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
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _HierarchyRow extends StatelessWidget {
  const _HierarchyRow({
    required this.label,
    required this.detail,
    required this.level,
    required this.available,
    this.onPressed,
  });
  final String label, detail;
  final int level;
  final bool available;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: CoeloAdminInteractiveCard(
      semanticLabel: '$label, $detail',
      onPressed: available ? onPressed : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          CoeloSpacing.space4 + level * CoeloSpacing.space4,
          CoeloSpacing.space3,
          CoeloSpacing.space4,
          CoeloSpacing.space3,
        ),
        child: Row(
          children: [
            const Icon(Icons.account_tree_outlined),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            Flexible(child: Text(detail, textAlign: TextAlign.end)),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

final class _ResponsesContent extends StatefulWidget {
  const _ResponsesContent({required this.available});

  final bool available;

  @override
  State<_ResponsesContent> createState() => _ResponsesContentState();
}

final class _ResponsesContentState extends State<_ResponsesContent> {
  bool _anonymous = false;
  int _page = 1;
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final items = !widget.available
        ? const [('Nenhuma resposta autorizada carregada', 'Conteúdo indisponível')]
        : _anonymous
        ? const [('Resposta anônima', 'Enviada em 29 ago 2026 · 18:05')]
        : _page == 1
        ? const [
            ('Marina Souza', 'Enviada em 30 ago 2026 · 14:32'),
            ('Carlos Oliveira', 'Enviada em 30 ago 2026 · 13:48'),
          ]
        : const [('Ana Pereira', 'Enviada em 28 ago 2026 · 09:12')];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            FilterChip(
              label: const Text('Identificadas'),
              selected: widget.available && !_anonymous,
              onSelected: widget.available
                  ? (_) => setState(() {
                      _anonymous = false;
                      _page = 1;
                      _selected = null;
                    })
                  : null,
            ),
            FilterChip(
              label: const Text('Anônimas'),
              selected: widget.available && _anonymous,
              onSelected: widget.available
                  ? (_) => setState(() {
                      _anonymous = true;
                      _page = 1;
                      _selected = null;
                    })
                  : null,
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
            child: CoeloAdminInteractiveCard(
              semanticLabel: '${item.$1}, ${item.$2}',
              onPressed: widget.available ? () => setState(() => _selected = item.$1) : null,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space4,
                  vertical: CoeloSpacing.space2,
                ),
                leading: Icon(
                  item.$1 == 'Resposta anônima'
                      ? Icons.visibility_off_outlined
                      : Icons.person_outline_rounded,
                ),
                title: Text(item.$1),
                subtitle: Text(item.$2),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        const SizedBox(height: CoeloSpacing.space2),
        if (_selected != null) ...[
          CoeloStatePanel(
            icon: Icons.fact_check_outlined,
            title: 'Resposta selecionada: $_selected',
            message: 'Detalhe local pronto para navegação pela composition root.',
          ),
          const SizedBox(height: CoeloSpacing.space2),
        ],
        Wrap(
          alignment: WrapAlignment.end,
          spacing: CoeloSpacing.space2,
          children: [
            OutlinedButton(
              onPressed: widget.available && _page > 1 ? () => setState(() => _page--) : null,
              child: const Text('Anterior'),
            ),
            Text('Página $_page'),
            OutlinedButton(
              key: const Key('forms-cursor-next'),
              onPressed: widget.available && _page == 1 ? () => setState(() => _page++) : null,
              child: const Text('Próxima página'),
            ),
          ],
        ),
      ],
    );
  }
}

final class _ResponseDetailContent extends StatelessWidget {
  const _ResponseDetailContent({required this.anonymous, required this.available});
  final bool anonymous;
  final bool available;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloAdminInteractiveCard(
        semanticLabel: available
            ? (anonymous ? 'Resposta anônima' : 'Resposta de Marina Souza')
            : 'Resposta indisponível',
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                available
                    ? (anonymous ? 'Resposta anônima' : 'Resposta de Marina Souza')
                    : 'Resposta indisponível',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                !available
                    ? 'Conteúdo autorizado não carregado.'
                    : anonymous
                    ? 'A identidade e a edição não podem ser recuperadas quando o segredo anônimo é perdido.'
                    : 'Identificada · enviada em 30 ago 2026 às 14:32',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      if (available) ...[
        const _Answer(question: 'Como você avalia a comunicação?', answer: 'Muito boa'),
        const _Answer(
          question: 'O que podemos melhorar?',
          answer: 'Manter os lembretes com antecedência.',
        ),
      ] else
        const _Answer(question: 'Conteúdo protegido', answer: 'Não carregado'),
    ],
  );
}

final class _Answer extends StatelessWidget {
  const _Answer({required this.question, required this.answer});
  final String question, answer;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: CoeloAdminInteractiveCard(
      semanticLabel: '$question: $answer',
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CoeloSpacing.space2),
            Text(answer),
          ],
        ),
      ),
    ),
  );
}

final class _FilesContent extends StatefulWidget {
  const _FilesContent({required this.available, this.developmentStore});

  final bool available;
  final FormsFilesDevelopmentStore? developmentStore;

  @override
  State<_FilesContent> createState() => _FilesContentState();
}

final class _FilesContentState extends State<_FilesContent> {
  late FormsFilesDevelopmentStore _store;
  late bool _ownsStore;

  @override
  void initState() {
    super.initState();
    _attachStore(widget.developmentStore);
  }

  @override
  void didUpdateWidget(covariant _FilesContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.developmentStore, widget.developmentStore)) {
      _detachStore();
      _attachStore(widget.developmentStore);
    }
  }

  void _attachStore(FormsFilesDevelopmentStore? value) {
    _ownsStore = value == null;
    _store = value ?? FormsFilesDevelopmentStore();
    _store.addListener(_storeChanged);
  }

  void _detachStore() {
    _store.removeListener(_storeChanged);
    if (_ownsStore) _store.dispose();
  }

  @override
  void dispose() {
    _detachStore();
    super.dispose();
  }

  void _storeChanged() {
    if (mounted) setState(() {});
  }

  void _showFeedback(String message) => _store.showFeedback(message);

  void _queueExport(String format) => _showFeedback('Exportação $format adicionada à fila local');

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CoeloAdminDialogShell(
        title: 'Excluir arquivo protegido?',
        closeTooltip: 'Fechar confirmação',
        body: const Text(
          'O arquivo deixará de aparecer após o recarregamento. Esta demonstração altera apenas a fixture local.',
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Excluir arquivo'),
        ),
      ),
    );
    if (confirmed == true && mounted) _store.deleteAsset();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (!_store.uploadCanceled)
        CoeloAdminInteractiveCard(
          semanticLabel: 'Upload protegido em andamento, 64 por cento',
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.upload_file_outlined),
                    const SizedBox(width: CoeloSpacing.space3),
                    Expanded(
                      child: Text(
                        widget.available
                            ? 'comprovante-familia.pdf'
                            : 'Nenhum arquivo autorizado carregado',
                      ),
                    ),
                    TextButton(
                      onPressed: widget.available ? _store.cancelUpload : null,
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space2),
                LinearProgressIndicator(
                  key: Key('forms-upload-progress'),
                  value: widget.available ? .64 : 0,
                  semanticsLabel: widget.available ? 'Progresso do upload' : 'Upload indisponível',
                  semanticsValue: widget.available ? '64' : '0',
                ),
              ],
            ),
          ),
        ),
      if (_store.uploadCanceled)
        const CoeloStatePanel(
          icon: Icons.cancel_outlined,
          title: 'Upload cancelado',
          message: 'Os demais dados locais foram preservados.',
        ),
      const SizedBox(height: CoeloSpacing.space4),
      if (widget.available && _store.assetPresent)
        CoeloAdminInteractiveCard(
          semanticLabel: 'Arquivo protegido autorização passeio',
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('autorizacao-passeio.pdf', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  _store.accessExpired
                      ? 'Acesso temporário expirado'
                      : 'Disponível por acesso temporário',
                ),
                const SizedBox(height: CoeloSpacing.space2),
                Wrap(
                  spacing: CoeloSpacing.space2,
                  runSpacing: CoeloSpacing.space2,
                  children: [
                    OutlinedButton(
                      onPressed: _store.accessExpired
                          ? null
                          : () => _showFeedback('Acesso temporário solicitado'),
                      child: const Text('Abrir temporariamente'),
                    ),
                    OutlinedButton(
                      onPressed: _store.accessExpired ? null : _store.expireAccess,
                      child: const Text('Expirar acesso'),
                    ),
                    TextButton(
                      onPressed: _confirmDelete,
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: const Text('Excluir arquivo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )
      else if (widget.available)
        const CoeloStatePanel(
          key: Key('forms-file-absent-after-reload'),
          icon: Icons.delete_outline_rounded,
          title: 'Arquivo ausente após reload',
          message: 'A fixture local representa a exclusão sem afirmar persistência remota.',
        ),
      const SizedBox(height: CoeloSpacing.space4),
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          FilledButton.icon(
            onPressed: widget.available ? () => _queueExport('ZIP') : null,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Exportar'),
          ),
          OutlinedButton(
            onPressed: widget.available ? () => _queueExport('CSV') : null,
            child: const Text('CSV'),
          ),
          OutlinedButton(
            onPressed: widget.available ? () => _queueExport('XLSX') : null,
            child: const Text('XLSX'),
          ),
          OutlinedButton(
            onPressed: widget.available ? () => _queueExport('ZIP') : null,
            child: const Text('ZIP'),
          ),
        ],
      ),
      if (_store.feedback != null) ...[
        const SizedBox(height: CoeloSpacing.space3),
        CoeloStatePanel(
          icon: Icons.info_outline_rounded,
          title: _store.feedback!,
          message: 'Ação concluída somente na fixture local.',
        ),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      for (final job
          in widget.available
              ? const [
                  ('job-101', 'Aguardando', 0.0),
                  ('job-102', 'Processando', .46),
                  ('job-103', 'Concluído', 1.0),
                  ('job-104', 'Dividido', 1.0),
                  ('job-105', 'Expirado', 1.0),
                  ('job-106', 'Falhou', .72),
                ]
              : const [('—', 'Indisponível', 0.0)])
        Padding(
          padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
          child: _JobRow(
            id: job.$1,
            status: job.$2,
            progress: job.$3,
            available: widget.available,
            onDownload: () => _showFeedback('Download local preparado para ${job.$1}'),
          ),
        ),
    ],
  );
}

final class _JobRow extends StatelessWidget {
  const _JobRow({
    required this.id,
    required this.status,
    required this.progress,
    required this.available,
    this.onDownload,
  });
  final String id, status;
  final double progress;
  final bool available;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    semanticLabel: 'Exportação $id, $status',
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Row(
        children: [
          Icon(status == 'Falhou' ? Icons.error_outline_rounded : Icons.archive_outlined),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exportação $id', style: Theme.of(context).textTheme.titleSmall),
                if (status == 'Processando') LinearProgressIndicator(value: progress),
              ],
            ),
          ),
          const SizedBox(width: CoeloSpacing.space2),
          Text(status),
          if (status == 'Concluído' || status == 'Dividido')
            IconButton(
              tooltip: 'Baixar exportação $id',
              onPressed: available ? onDownload : null,
              icon: const Icon(Icons.download_rounded),
            ),
        ],
      ),
    ),
  );
}
