import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../data/agenda_prototype_store.dart';

enum _RequestKind { rsvp, acknowledgement, authorization }

extension on _RequestKind {
  String get label => switch (this) {
    _RequestKind.rsvp => 'RSVP',
    _RequestKind.acknowledgement => 'Ciência',
    _RequestKind.authorization => 'Autorização',
  };
}

enum _RequestStatus { pending, answered, lostEligibility }

extension on _RequestStatus {
  String get label => switch (this) {
    _RequestStatus.pending => 'Pendente',
    _RequestStatus.answered => 'Respondido',
    _RequestStatus.lostEligibility => 'Perdeu elegibilidade',
  };
}

enum _GuardianPolicy { oneIsEnough, allRequired }

extension on _GuardianPolicy {
  String get label => switch (this) {
    _GuardianPolicy.oneIsEnough => 'Basta um responsável (padrão)',
    _GuardianPolicy.allRequired => 'Todos os responsáveis precisam responder',
  };
}

final class _RequestAnswer {
  const _RequestAnswer({required this.label, required this.actor, required this.answeredAt});

  final String label;
  final String actor;
  final DateTime answeredAt;
}

final class _ChildRequest {
  const _ChildRequest({
    required this.id,
    required this.title,
    required this.childContext,
    required this.kind,
    required this.policy,
    required this.status,
    required this.responseCount,
    required this.guardianCount,
    this.answer,
  });

  final String id;
  final String title;
  final String childContext;
  final _RequestKind kind;
  final _GuardianPolicy policy;
  final _RequestStatus status;
  final int responseCount;
  final int guardianCount;
  final _RequestAnswer? answer;

  _ChildRequest answered({required String label, required String actor}) {
    final nextCount = policy == _GuardianPolicy.allRequired ? guardianCount : 1;
    return _ChildRequest(
      id: id,
      title: title,
      childContext: childContext,
      kind: kind,
      policy: policy,
      status: _RequestStatus.answered,
      responseCount: nextCount,
      guardianCount: guardianCount,
      answer: _RequestAnswer(label: label, actor: actor, answeredAt: DateTime(2026, 8, 31, 17, 10)),
    );
  }
}

/// Retornos de RSVP, ciência e autorização associados a uma criança.
///
/// O construtor legado com [store] é preservado para a composição `/dev`, mas
/// esta superfície usa fixtures próprias e não grava no store. Produção deve
/// usar [AgendaRequestsPage.unavailable] até existir uma fonte autorizada.
final class AgendaRequestsPage extends StatefulWidget {
  const AgendaRequestsPage({required this.store, super.key}) : _available = true;

  const AgendaRequestsPage.localFixtures({super.key}) : store = null, _available = true;

  const AgendaRequestsPage.unavailable({super.key}) : store = null, _available = false;

  final AgendaPrototypeStore? store;
  final bool _available;

  @override
  State<AgendaRequestsPage> createState() => _AgendaRequestsPageState();
}

final class _AgendaRequestsPageState extends State<AgendaRequestsPage> {
  late final List<_ChildRequest> _items = _fixtureRequests();
  String? _notice;

  void _answer(_ChildRequest item, String answerLabel) {
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    if (index < 0 || item.status != _RequestStatus.pending) return;
    setState(() {
      _items[index] = item.answered(label: answerLabel, actor: 'Marina Oliveira');
      _notice = switch (item.policy) {
        _GuardianPolicy.oneIsEnough =>
          'Resposta registrada para ${_childName(item.childContext)}. Os demais responsáveis foram avisados e não precisam responder.',
        _GuardianPolicy.allRequired =>
          'Todos os responsáveis responderam por ${_childName(item.childContext)}.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget._available) return const _UnavailableRequests();
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final compact = constraints.maxWidth / textScale < CoeloBreakpoints.medium.minWidth;
        final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : compact
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        return ListView(
          key: const Key('agenda-requests-scroll'),
          padding: EdgeInsets.all(padding),
          children: [
            Text('Solicitações e retornos', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: CoeloSpacing.space1),
            const Text(
              'Acompanhe RSVP, ciência e autorização por criança, conforme a política de responsáveis.',
            ),
            const SizedBox(height: CoeloSpacing.space3),
            const _LocalFixtureNotice(),
            if (_notice != null) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Semantics(
                liveRegion: true,
                child: Text(_notice!, key: const Key('agenda-request-notice')),
              ),
            ],
            const SizedBox(height: CoeloSpacing.space5),
            if (compact)
              _RequestCardList(items: _items, onAnswer: _answer)
            else
              SizedBox(
                height: 700,
                child: _RequestTable(items: _items, onAnswer: _answer),
              ),
          ],
        );
      },
    );
  }
}

final class _RequestTable extends StatelessWidget {
  const _RequestTable({required this.items, required this.onAnswer});

  final List<_ChildRequest> items;
  final void Function(_ChildRequest item, String label) onAnswer;

  Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<_ChildRequest>(
    key: const Key('agenda-requests-table'),
    items: items,
    rowKey: (item) => item.id,
    headerHeight: 56,
    rowHeight: 156,
    pinnedColumn: CoeloAdminTableColumn<_ChildRequest>(
      id: 'request',
      label: 'Solicitação',
      initialWidth: 280,
      minWidth: 230,
      maxWidth: 380,
      cellBuilder: (context, item) => _cell(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(item.childContext, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ),
    columns: [
      CoeloAdminTableColumn<_ChildRequest>(
        id: 'policy',
        label: 'Tipo e política',
        initialWidth: 300,
        minWidth: 250,
        maxWidth: 380,
        cellBuilder: (context, item) => _cell(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.kind.label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: CoeloSpacing.space1),
              Text(item.policy.label),
              Text(_progressLabel(item), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      CoeloAdminTableColumn<_ChildRequest>(
        id: 'state',
        label: 'Estado',
        initialWidth: 330,
        minWidth: 280,
        maxWidth: 430,
        cellBuilder: (context, item) => _cell(_RequestState(item: item)),
      ),
      CoeloAdminTableColumn<_ChildRequest>(
        id: 'action',
        label: 'Retorno',
        initialWidth: 300,
        minWidth: 260,
        maxWidth: 380,
        cellBuilder: (context, item) =>
            _cell(_RequestActions(item: item, onAnswer: (label) => onAnswer(item, label))),
      ),
    ],
  );
}

final class _RequestCardList extends StatelessWidget {
  const _RequestCardList({required this.items, required this.onAnswer});

  final List<_ChildRequest> items;
  final void Function(_ChildRequest item, String label) onAnswer;

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('agenda-requests-card-list'),
    children: [
      for (final item in items) ...[
        CoeloAdminInteractiveCard(
          semanticLabel: '${item.title}. ${item.childContext}. ${item.status.label}',
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.space1),
                Text(item.childContext),
                Text('${item.kind.label} · ${item.policy.label}'),
                Text(_progressLabel(item), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: CoeloSpacing.space3),
                _RequestState(item: item),
                if (item.status == _RequestStatus.pending) ...[
                  const SizedBox(height: CoeloSpacing.space3),
                  _RequestActions(item: item, onAnswer: (label) => onAnswer(item, label)),
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

final class _RequestState extends StatelessWidget {
  const _RequestState({required this.item});

  final _ChildRequest item;

  @override
  Widget build(BuildContext context) {
    final answer = item.answer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StateChip(status: item.status),
        if (item.status == _RequestStatus.lostEligibility) ...[
          const SizedBox(height: CoeloSpacing.space1),
          const Text('O vínculo com a audiência terminou antes da resposta.'),
        ] else if (answer != null) ...[
          const SizedBox(height: CoeloSpacing.space1),
          Text('${answer.label} por ${answer.actor}.'),
          Text(_formatDateTime(answer.answeredAt), style: Theme.of(context).textTheme.bodySmall),
        ] else if (item.policy == _GuardianPolicy.oneIsEnough) ...[
          const SizedBox(height: CoeloSpacing.space1),
          const Text('O primeiro retorno válido encerra a pendência dos demais responsáveis.'),
        ],
      ],
    );
  }
}

final class _RequestActions extends StatelessWidget {
  const _RequestActions({required this.item, required this.onAnswer});

  final _ChildRequest item;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    if (item.status != _RequestStatus.pending) return const Text('Sem ação pendente');
    return Wrap(
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: switch (item.kind) {
        _RequestKind.authorization => [
          OutlinedButton(
            onPressed: () => onAnswer('Não autorizado'),
            child: const Text('Não autorizar'),
          ),
          FilledButton(
            key: Key('agenda-request-authorize-${item.id}'),
            onPressed: () => onAnswer('Autorizado'),
            child: const Text('Autorizar'),
          ),
        ],
        _RequestKind.rsvp => [
          OutlinedButton(
            onPressed: () => onAnswer('Não participará'),
            child: const Text('Não participará'),
          ),
          FilledButton(
            key: Key('agenda-request-rsvp-${item.id}'),
            onPressed: () => onAnswer('Presença confirmada'),
            child: const Text('Confirmar presença'),
          ),
        ],
        _RequestKind.acknowledgement => [
          FilledButton(
            key: Key('agenda-request-respond-${item.id}'),
            onPressed: () => onAnswer('Ciência confirmada'),
            child: const Text('Confirmar ciência'),
          ),
        ],
      },
    );
  }
}

final class _StateChip extends StatelessWidget {
  const _StateChip({required this.status});

  final _RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      _RequestStatus.pending => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
      _RequestStatus.answered => (colors.secondaryContainer, colors.onSecondaryContainer),
      _RequestStatus.lostEligibility => (colors.errorContainer, colors.onErrorContainer),
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
          Expanded(child: Text('Dados locais de demonstração; retornos não são persistidos.')),
        ],
      ),
    ),
  );
}

final class _UnavailableRequests extends StatelessWidget {
  const _UnavailableRequests();

  @override
  Widget build(BuildContext context) => Center(
    key: const Key('agenda-requests-unavailable'),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_clock_outlined,
              size: CoeloSize.iconLg,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Text(
              'Solicitações indisponíveis',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            const Text(
              'A fonte autorizada de RSVP, ciência e autorização ainda não está disponível. Nenhum retorno foi consultado ou registrado.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

List<_ChildRequest> _fixtureRequests() => [
  const _ChildRequest(
    id: 'authorization-lia',
    title: 'Autorização para passeio pedagógico',
    childContext: 'Lia · Turma Girassol',
    kind: _RequestKind.authorization,
    policy: _GuardianPolicy.oneIsEnough,
    status: _RequestStatus.pending,
    responseCount: 0,
    guardianCount: 2,
  ),
  const _ChildRequest(
    id: 'rsvp-noah',
    title: 'Presença na reunião de responsáveis',
    childContext: 'Noah · Turma Estrelas',
    kind: _RequestKind.rsvp,
    policy: _GuardianPolicy.allRequired,
    status: _RequestStatus.pending,
    responseCount: 1,
    guardianCount: 2,
  ),
  _ChildRequest(
    id: 'science-bia',
    title: 'Ciência sobre alteração de horário',
    childContext: 'Bia · Turma Ipê',
    kind: _RequestKind.acknowledgement,
    policy: _GuardianPolicy.oneIsEnough,
    status: _RequestStatus.answered,
    responseCount: 1,
    guardianCount: 2,
    answer: _RequestAnswer(
      label: 'Ciência confirmada',
      actor: 'Paulo Almeida',
      answeredAt: DateTime(2026, 8, 30, 10, 15),
    ),
  ),
  const _ChildRequest(
    id: 'science-lost',
    title: 'Ciência sobre atividade extracurricular',
    childContext: 'Maya · Turma Sol',
    kind: _RequestKind.acknowledgement,
    policy: _GuardianPolicy.oneIsEnough,
    status: _RequestStatus.lostEligibility,
    responseCount: 0,
    guardianCount: 2,
  ),
];

String _progressLabel(_ChildRequest item) =>
    '${item.responseCount} de ${item.guardianCount} responsáveis responderam';

String _childName(String childContext) => childContext.split(' · ').first;

String _formatDateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
