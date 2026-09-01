import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_placeholder_file_actions.dart';
import '../domain/agenda_models.dart';
import '../domain/agenda_repository.dart';

enum _ApprovalStatus { pending, approved, rejected }

extension on _ApprovalStatus {
  String get label => switch (this) {
    _ApprovalStatus.pending => 'Aguardando publicação',
    _ApprovalStatus.approved => 'Aprovado',
    _ApprovalStatus.rejected => 'Recusado',
  };
}

final class _ApprovalHistory {
  const _ApprovalHistory({required this.actor, required this.reason, required this.decidedAt});

  final String actor;
  final String reason;
  final DateTime decidedAt;
}

final class _AgendaApproval {
  const _AgendaApproval({
    required this.id,
    required this.title,
    required this.context,
    required this.requestedBy,
    required this.requestedAt,
    required this.status,
    this.history,
    this.publicationRequestId,
  });

  final String id;
  final String title;
  final String context;
  final String requestedBy;
  final DateTime requestedAt;
  final _ApprovalStatus status;
  final _ApprovalHistory? history;
  final String? publicationRequestId;

  _AgendaApproval decided({required _ApprovalStatus status, required String reason}) =>
      _AgendaApproval(
        id: id,
        title: title,
        context: context,
        requestedBy: requestedBy,
        requestedAt: requestedAt,
        status: status,
        publicationRequestId: publicationRequestId,
        history: _ApprovalHistory(
          actor: 'Marina Oliveira',
          reason: reason,
          decidedAt: DateTime(2026, 8, 31, 16, 40),
        ),
      );

  factory _AgendaApproval.fromPublicationRequest(AgendaPublicationRequest request) =>
      _AgendaApproval(
        id: request.id,
        title: request.title,
        context: request.contextLabel,
        requestedBy: request.requestedBy,
        requestedAt: request.requestedAt,
        status: switch (request.status) {
          AgendaPublicationRequestStatus.pending => _ApprovalStatus.pending,
          AgendaPublicationRequestStatus.approved => _ApprovalStatus.approved,
          AgendaPublicationRequestStatus.rejected => _ApprovalStatus.rejected,
        },
        history: request.decidedBy == null
            ? null
            : _ApprovalHistory(
                actor: request.decidedBy!,
                reason: request.reason ?? '',
                decidedAt: request.decidedAt!,
              ),
        publicationRequestId: request.id,
      );
}

final class AgendaApprovalsPage extends StatefulWidget {
  const AgendaApprovalsPage({required AgendaRepository this.store, super.key})
    : _available = true,
      _localFixtures = false;

  const AgendaApprovalsPage.localFixtures({this.store, super.key})
    : _available = true,
      _localFixtures = true;

  const AgendaApprovalsPage.unavailable({super.key})
    : store = null,
      _available = false,
      _localFixtures = false;

  final AgendaRepository? store;
  final bool _available;
  final bool _localFixtures;

  @override
  State<AgendaApprovalsPage> createState() => _AgendaApprovalsPageState();
}

final class _AgendaApprovalsPageState extends State<AgendaApprovalsPage> {
  late final List<_AgendaApproval> _fixtureItems = _fixtureApprovals();

  List<_AgendaApproval> get _items => [
    ...?widget.store?.publicationRequests.map(_AgendaApproval.fromPublicationRequest),
    if (widget._localFixtures) ..._fixtureItems,
  ];

  @override
  void initState() {
    super.initState();
    if (!widget._localFixtures) widget.store?.loadRequests();
  }

  Future<void> _openDecision(_AgendaApproval item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ApprovalDecisionDialog(
        item: item,
        onDecide: (status, reason) async {
          if (!mounted) return AgendaMutationResult.unavailable;
          final requestId = item.publicationRequestId;
          if (requestId != null) {
            return widget.store!.decidePublicationRequest(
              requestId: requestId,
              approve: status == _ApprovalStatus.approved,
              decidedBy: 'Marina Oliveira',
              reason: reason,
            );
          }
          final index = _fixtureItems.indexWhere((candidate) => candidate.id == item.id);
          if (index < 0) return AgendaMutationResult.notFound;
          setState(() => _fixtureItems[index] = item.decided(status: status, reason: reason));
          return AgendaMutationResult.success;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._available) return const _UnavailableApprovals();
    final store = widget.store;
    if (store == null) return _buildAvailable(context);
    return AnimatedBuilder(animation: store, builder: (context, _) => _buildAvailable(context));
  }

  Widget _buildAvailable(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final effectiveWidth = constraints.maxWidth / textScale;
      final compact = effectiveWidth < CoeloBreakpoints.medium.minWidth;
      final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : compact
          ? CoeloSpacing.space4
          : CoeloSpacing.space6;
      return ListView(
        key: const Key('agenda-approvals-scroll'),
        padding: EdgeInsets.all(padding),
        children: [
          Text('Aprovações de publicação', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: CoeloSpacing.space1),
          const Text(
            'Revise itens enviados por pessoas sem permissão de publicação e registre a decisão.',
          ),
          const SizedBox(height: CoeloSpacing.space2),
          const Align(
            alignment: Alignment.centerRight,
            child: SuperadminPlaceholderFileActions(resourceLabel: 'aprovações da agenda'),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          if (widget._localFixtures) const _LocalFixtureNotice(),
          const SizedBox(height: CoeloSpacing.space5),
          if (compact)
            _ApprovalCardList(items: _items, onDecide: _openDecision)
          else
            SizedBox(
              height: _items.length <= 3 ? 500 : 80 + _items.length * 140,
              child: _ApprovalTable(items: _items, onDecide: _openDecision),
            ),
          const SizedBox(height: CoeloSpacing.space4),
          SuperadminListingPaginationFooter(
            horizontalPadding: 0,
            child: const CoeloAdminPagination(
              currentPage: 1,
              totalPages: 1,
              onPrevious: null,
              onNext: null,
              pageSize: 8,
              pageSizeOptions: [8, 20, 50, 100],
            ),
          ),
        ],
      );
    },
  );
}

final class _ApprovalDecisionDialog extends StatefulWidget {
  const _ApprovalDecisionDialog({required this.item, required this.onDecide});

  final _AgendaApproval item;
  final Future<AgendaMutationResult> Function(_ApprovalStatus status, String reason) onDecide;

  @override
  State<_ApprovalDecisionDialog> createState() => _ApprovalDecisionDialogState();
}

final class _ApprovalDecisionDialogState extends State<_ApprovalDecisionDialog> {
  final _reason = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _decide(_ApprovalStatus status) async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Informe a justificativa da decisão.');
      return;
    }
    setState(() => _saving = true);
    final result = await widget.onDecide(status, reason);
    if (!mounted) return;
    if (result == AgendaMutationResult.success) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = result == AgendaMutationResult.notAuthorized
          ? 'Você não tem permissão para decidir esta publicação.'
          : 'Não foi possível registrar a decisão. Tente novamente.';
    });
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    title: 'Decidir publicação',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${widget.item.title} · ${widget.item.context}'),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          key: const Key('agenda-approval-reason'),
          controller: _reason,
          labelText: 'Justificativa da decisão',
          prefixIcon: Icons.notes_rounded,
          maxLines: 4,
          errorText: _error,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: CoeloSpacing.space2),
        const Text('A decisão e sua justificativa ficam registradas no histórico da Agenda.'),
      ],
    ),
    secondaryAction: OutlinedButton(
      key: const Key('agenda-approval-confirm-reject'),
      onPressed: _saving ? null : () => _decide(_ApprovalStatus.rejected),
      child: const Text('Recusar publicação'),
    ),
    primaryAction: FilledButton(
      key: const Key('agenda-approval-confirm-approve'),
      onPressed: _saving ? null : () => _decide(_ApprovalStatus.approved),
      child: const Text('Aprovar publicação'),
    ),
  );
}

final class _ApprovalTable extends StatelessWidget {
  const _ApprovalTable({required this.items, required this.onDecide});

  final List<_AgendaApproval> items;
  final ValueChanged<_AgendaApproval> onDecide;

  Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<_AgendaApproval>(
    key: const Key('agenda-approvals-table'),
    items: items,
    rowKey: (item) => item.id,
    headerHeight: 56,
    rowHeight: 136,
    pinnedColumn: CoeloAdminTableColumn<_AgendaApproval>(
      id: 'event',
      label: 'Evento',
      initialWidth: 250,
      minWidth: 210,
      maxWidth: 360,
      cellBuilder: (context, item) => _cell(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(item.context, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
    columns: [
      CoeloAdminTableColumn<_AgendaApproval>(
        id: 'request',
        label: 'Solicitação',
        initialWidth: 230,
        minWidth: 190,
        maxWidth: 300,
        cellBuilder: (context, item) => _cell(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.requestedBy),
              Text(_formatDateTime(item.requestedAt), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      CoeloAdminTableColumn<_AgendaApproval>(
        id: 'status',
        label: 'Estado e histórico',
        initialWidth: 360,
        minWidth: 300,
        maxWidth: 480,
        cellBuilder: (context, item) => _cell(_StatusAndHistory(item: item)),
      ),
      CoeloAdminTableColumn<_AgendaApproval>(
        id: 'action',
        label: 'Ação',
        initialWidth: 200,
        minWidth: 180,
        maxWidth: 240,
        cellBuilder: (context, item) => _cell(
          item.status == _ApprovalStatus.pending
              ? FilledButton.tonal(
                  key: Key('agenda-approval-decide-${item.id}'),
                  onPressed: () => onDecide(item),
                  child: const Text('Decidir'),
                )
              : const Text('Decisão concluída'),
        ),
      ),
    ],
  );
}

final class _ApprovalCardList extends StatelessWidget {
  const _ApprovalCardList({required this.items, required this.onDecide});

  final List<_AgendaApproval> items;
  final ValueChanged<_AgendaApproval> onDecide;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('agenda-approvals-card-list'),
    children: [
      for (final item in items) ...[
        CoeloAdminInteractiveCard(
          semanticLabel: '${item.title}. ${item.status.label}',
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.space1),
                Text(item.context),
                Text(
                  'Solicitado por ${item.requestedBy} · ${_formatDateTime(item.requestedAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: CoeloSpacing.space3),
                _StatusAndHistory(item: item),
                if (item.status == _ApprovalStatus.pending) ...[
                  const SizedBox(height: CoeloSpacing.space3),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      key: Key('agenda-approval-decide-${item.id}'),
                      onPressed: () => onDecide(item),
                      child: const Text('Decidir'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
      ],
    ],
  );
}

final class _StatusAndHistory extends StatelessWidget {
  const _StatusAndHistory({required this.item});

  final _AgendaApproval item;

  @override
  Widget build(BuildContext context) {
    final history = item.history;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusChip(status: item.status),
        if (history != null) ...[
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            'Decisão registrada por ${history.actor}.',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(history.reason, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(_formatDateTime(history.decidedAt), style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

final class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final _ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      _ApprovalStatus.pending => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
      _ApprovalStatus.approved => (colors.secondaryContainer, colors.onSecondaryContainer),
      _ApprovalStatus.rejected => (colors.errorContainer, colors.onErrorContainer),
    };
    return Semantics(
      label: 'Estado: ${status.label}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(CoeloRadius.full),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space3,
            vertical: CoeloSpacing.space1,
          ),
          child: Text(status.label, style: TextStyle(color: foreground)),
        ),
      ),
    );
  }
}

final class _LocalFixtureNotice extends StatelessWidget {
  const _LocalFixtureNotice();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: const Padding(
      padding: EdgeInsets.all(CoeloSpacing.space3),
      child: Row(
        children: [
          Icon(Icons.science_outlined),
          SizedBox(width: CoeloSpacing.space2),
          Expanded(child: Text('Dados de demonstração locais; decisões não são persistidas.')),
        ],
      ),
    ),
  );
}

final class _UnavailableApprovals extends StatelessWidget {
  const _UnavailableApprovals();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth < CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space4
          : CoeloSpacing.space6;
      return ListView(
        key: const Key('agenda-approvals-unavailable'),
        padding: EdgeInsets.all(padding),
        children: [
          Text('Aprovações de publicação', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: CoeloSpacing.space1),
          const Text(
            'Revise itens enviados por pessoas sem permissão de publicação e registre a decisão.',
          ),
          const SizedBox(height: CoeloSpacing.space5),
          const CoeloStatePanel(
            key: Key('agenda-approvals-unavailable-content'),
            icon: Icons.lock_clock_outlined,
            title: 'Aprovações indisponíveis',
            message:
                'A fonte autorizada para consultar e decidir publicações ainda não está disponível. Nenhuma decisão foi registrada.',
          ),
        ],
      );
    },
  );
}

List<_AgendaApproval> _fixtureApprovals() => [
  _AgendaApproval(
    id: 'pending-1',
    title: 'Festival de esportes',
    context: 'Colégio Horizonte · Todas as unidades',
    requestedBy: 'Carolina Mendes',
    requestedAt: DateTime(2026, 8, 31, 14, 20),
    status: _ApprovalStatus.pending,
  ),
  _AgendaApproval(
    id: 'approved-1',
    title: 'Feira cultural 2026',
    context: 'Unidade Centro · Comunidade escolar',
    requestedBy: 'João Nogueira',
    requestedAt: DateTime(2026, 8, 29, 9, 15),
    status: _ApprovalStatus.approved,
    history: _ApprovalHistory(
      actor: 'Rafael Costa',
      reason: 'Escopo, período e audiência conferidos.',
      decidedAt: DateTime(2026, 8, 29, 11, 5),
    ),
  ),
  _AgendaApproval(
    id: 'rejected-1',
    title: 'Passeio pedagógico',
    context: 'Turma Girassol · Responsáveis e educadores',
    requestedBy: 'Lucas Ferreira',
    requestedAt: DateTime(2026, 8, 28, 16, 30),
    status: _ApprovalStatus.rejected,
    history: _ApprovalHistory(
      actor: 'Ana Ribeiro',
      reason: 'Período precisa ser revisto antes da publicação.',
      decidedAt: DateTime(2026, 8, 28, 17, 10),
    ),
  ),
];

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
