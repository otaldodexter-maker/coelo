import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

enum FormsOperationsSurface { monitor, responses, responseDetail, files }

enum FormsOperationsState { content, loading, empty, noResults, error, unauthorized, unavailable }

final class FormsOperationsPage extends StatelessWidget {
  const FormsOperationsPage.monitor({
    this.development = false,
    this.state = FormsOperationsState.content,
    super.key,
  }) : surface = FormsOperationsSurface.monitor,
       anonymous = false;

  const FormsOperationsPage.responses({
    this.development = false,
    this.state = FormsOperationsState.content,
    super.key,
  }) : surface = FormsOperationsSurface.responses,
       anonymous = false;

  const FormsOperationsPage.responseDetail({
    this.development = false,
    this.anonymous = false,
    this.state = FormsOperationsState.content,
    super.key,
  }) : surface = FormsOperationsSurface.responseDetail;

  const FormsOperationsPage.files({
    this.development = false,
    this.state = FormsOperationsState.content,
    super.key,
  }) : surface = FormsOperationsSurface.files,
       anonymous = false;

  final FormsOperationsSurface surface;
  final bool development;
  final bool anonymous;
  final FormsOperationsState state;

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
          key: Key('forms-operations-${surface.name}'),
          padding: EdgeInsets.fromLTRB(inset, CoeloSpacing.space5, inset, CoeloSpacing.space8),
          children: [
            _Header(surface: surface),
            const SizedBox(height: CoeloSpacing.space4),
            if (!development) ...[
              const CoeloStatePanel(
                key: Key('forms-operations-unavailable'),
                icon: Icons.lock_outline_rounded,
                title: 'Operação indisponível',
                message:
                    'A composição visual está pronta, mas leitura, persistência e autorização produtivas permanecem bloqueadas.',
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _surfaceContent(available: false),
            ] else if (state == FormsOperationsState.unavailable)
              const CoeloStatePanel(
                key: Key('forms-operations-unavailable'),
                icon: Icons.lock_outline_rounded,
                title: 'Operação indisponível',
                message: 'A fixture local está indisponível para este estado de demonstração.',
              )
            else if (state != FormsOperationsState.content)
              _OperationsStatePanel(state: state)
            else
              _surfaceContent(available: true),
          ],
        );
      },
    ),
  );

  Widget _surfaceContent({required bool available}) => switch (surface) {
    FormsOperationsSurface.monitor => _MonitorContent(available: available),
    FormsOperationsSurface.responses => _ResponsesContent(available: available),
    FormsOperationsSurface.responseDetail => _ResponseDetailContent(
      anonymous: available && anonymous,
      available: available,
    ),
    FormsOperationsSurface.files => _FilesContent(available: available),
  };
}

final class _OperationsStatePanel extends StatelessWidget {
  const _OperationsStatePanel({required this.state});
  final FormsOperationsState state;

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
      onAction: state == FormsOperationsState.error ? () {} : null,
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

final class _MonitorContent extends StatelessWidget {
  const _MonitorContent({required this.available});

  final bool available;

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
            value: available ? '128' : '—',
            icon: Icons.groups_outlined,
            available: available,
          ),
          _Metric(
            label: 'Responderam',
            value: available ? '89' : '—',
            icon: Icons.task_alt_rounded,
            available: available,
          ),
          _Metric(
            label: 'Não responderam',
            value: available ? '37' : '—',
            icon: Icons.schedule_rounded,
            available: available,
          ),
          _Metric(
            label: 'Perdeu elegibilidade',
            value: available ? '2' : '—',
            icon: Icons.person_off_outlined,
            available: available,
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space5),
      Semantics(
        key: const Key('forms-monitor-hierarchy'),
        label: 'Hierarquia de monitoramento',
        child: Column(
          children: available
              ? const [
                  _HierarchyRow(
                    label: 'Colégio Horizonte',
                    detail: '89 de 128 responderam',
                    level: 0,
                    available: true,
                  ),
                  _HierarchyRow(
                    label: 'Unidade Centro',
                    detail: '61 de 84 responderam',
                    level: 1,
                    available: true,
                  ),
                  _HierarchyRow(
                    label: '7º ano A',
                    detail: '24 de 31 responderam',
                    level: 2,
                    available: true,
                  ),
                  _HierarchyRow(
                    label: 'Famílias',
                    detail: '18 de 23 responderam',
                    level: 3,
                    available: true,
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
    ],
  );
}

final class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.available,
  });
  final String label, value;
  final IconData icon;
  final bool available;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: CoeloAdminInteractiveCard(
      semanticLabel: '$label: $value',
      onPressed: available ? () {} : null,
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
  });
  final String label, detail;
  final int level;
  final bool available;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: CoeloAdminInteractiveCard(
      semanticLabel: '$label, $detail',
      onPressed: available ? () {} : null,
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

final class _ResponsesContent extends StatelessWidget {
  const _ResponsesContent({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          FilterChip(
            label: const Text('Identificadas'),
            selected: available,
            onSelected: available ? (_) {} : null,
          ),
          FilterChip(
            label: const Text('Anônimas'),
            selected: false,
            onSelected: available ? (_) {} : null,
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space4),
      for (final item
          in available
              ? const [
                  ('Marina Souza', 'Enviada em 30 ago 2026 · 14:32'),
                  ('Carlos Oliveira', 'Enviada em 30 ago 2026 · 13:48'),
                  ('Resposta anônima', 'Enviada em 29 ago 2026 · 18:05'),
                ]
              : const [('Nenhuma resposta autorizada carregada', 'Conteúdo indisponível')])
        Padding(
          padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
          child: CoeloAdminInteractiveCard(
            semanticLabel: '${item.$1}, ${item.$2}',
            onPressed: available ? () {} : null,
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
      Wrap(
        alignment: WrapAlignment.end,
        spacing: CoeloSpacing.space2,
        children: [
          OutlinedButton(onPressed: null, child: const Text('Anterior')),
          OutlinedButton(
            key: const Key('forms-cursor-next'),
            onPressed: available ? () {} : null,
            child: const Text('Próxima página'),
          ),
        ],
      ),
    ],
  );
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
  const _FilesContent({required this.available});

  final bool available;

  @override
  State<_FilesContent> createState() => _FilesContentState();
}

final class _FilesContentState extends State<_FilesContent> {
  bool _assetPresent = true;
  bool _accessExpired = false;

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
    if (confirmed == true && mounted) setState(() => _assetPresent = false);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
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
                    onPressed: widget.available ? () {} : null,
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
      const SizedBox(height: CoeloSpacing.space4),
      if (widget.available && _assetPresent)
        CoeloAdminInteractiveCard(
          semanticLabel: 'Arquivo protegido autorização passeio',
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('autorizacao-passeio.pdf', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  _accessExpired
                      ? 'Acesso temporário expirado'
                      : 'Disponível por acesso temporário',
                ),
                const SizedBox(height: CoeloSpacing.space2),
                Wrap(
                  spacing: CoeloSpacing.space2,
                  runSpacing: CoeloSpacing.space2,
                  children: [
                    OutlinedButton(
                      onPressed: _accessExpired ? null : () {},
                      child: const Text('Abrir temporariamente'),
                    ),
                    OutlinedButton(
                      onPressed: _accessExpired
                          ? null
                          : () => setState(() => _accessExpired = true),
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
            onPressed: widget.available ? () {} : null,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Exportar'),
          ),
          OutlinedButton(onPressed: widget.available ? () {} : null, child: const Text('CSV')),
          OutlinedButton(onPressed: widget.available ? () {} : null, child: const Text('XLSX')),
          OutlinedButton(onPressed: widget.available ? () {} : null, child: const Text('ZIP')),
        ],
      ),
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
          child: _JobRow(id: job.$1, status: job.$2, progress: job.$3, available: widget.available),
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
  });
  final String id, status;
  final double progress;
  final bool available;

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
              onPressed: available ? () {} : null,
              icon: const Icon(Icons.download_rounded),
            ),
        ],
      ),
    ),
  );
}
