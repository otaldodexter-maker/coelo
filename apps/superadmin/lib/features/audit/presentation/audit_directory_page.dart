import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/prototype/superadmin_prototype_store.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import 'audit_detail_panel.dart';

enum AuditDirectoryState { loading, content, empty, error, unauthorized }

enum _AuditPeriod { today, sevenDays, thirtyDays }

final class AuditDirectoryPage extends StatefulWidget {
  const AuditDirectoryPage({
    required this.store,
    required this.logout,
    this.state = AuditDirectoryState.content,
    this.onDestinationSelected,
    super.key,
  });

  final SuperadminPrototypeStore store;
  final LogoutAction logout;
  final AuditDirectoryState state;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<AuditDirectoryPage> createState() => _AuditDirectoryPageState();
}

final class _AuditDirectoryPageState extends State<AuditDirectoryPage> {
  final _searchController = TextEditingController();
  Set<String> _modules = {};
  Set<String> _actions = {};
  Set<String> _actors = {};
  Set<String> _contexts = {};
  Set<PrototypeAuditRisk> _risks = {};
  Set<_AuditPeriod> _periods = {};
  PrototypeAuditEvent? _selected;
  var _query = '';
  var _page = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Auditoria',
    subtitle: 'Consulte evidências fictícias e minimizadas da sessão.',
    currentDestination: 'audit',
    activityController: widget.store.activityController,
    onDestinationSelected: widget.onDestinationSelected,
    child: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final allEvents = [...widget.store.auditEvents, ...auditFixtureEvents]
          ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
        final visible = _filter(allEvents);
        return Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: CoeloAdminWorkspaceLayout(
            toolbar: Padding(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
              child: _toolbar(allEvents),
            ),
            body: _body(visible, hasSourceEvents: allEvents.isNotEmpty),
            detailVisible: _selected != null,
            detail: _selected == null
                ? null
                : AuditDetailPanel(
                    event: _selected!,
                    onClose: () => setState(() => _selected = null),
                  ),
          ),
        );
      },
    ),
  );

  Widget _toolbar(List<PrototypeAuditEvent> events) {
    List<String> strings(Iterable<String?> values) =>
        values.whereType<String>().toSet().toList()..sort();
    Widget filter<T>({
      required String label,
      required List<T> options,
      required Set<T> selected,
      required String Function(T) optionLabel,
      required ValueChanged<Set<T>> onChanged,
    }) => SizedBox(
      width: 176,
      child: CoeloAdminMultiSelectFilter<T>(
        label: label,
        options: options,
        selectedValues: selected,
        optionLabel: optionLabel,
        onChanged: (value) {
          setState(() {
            onChanged(value);
            _page = 1;
          });
        },
      ),
    );
    return CoeloAdminListingToolbar(
      search: SizedBox(
        width: 280,
        child: CoeloSearchField(
          key: const Key('audit-search'),
          controller: _searchController,
          semanticLabel: 'Buscar eventos de auditoria',
          hintText: 'ID, ator, ação ou objeto',
          onChanged: (value) => setState(() {
            _query = value;
            _page = 1;
          }),
        ),
      ),
      filters: [
        filter(
          label: 'Período',
          options: _AuditPeriod.values,
          selected: _periods,
          optionLabel: _periodLabel,
          onChanged: (value) => _periods = value,
        ),
        filter(
          label: 'Módulo',
          options: strings(events.map((event) => event.module)),
          selected: _modules,
          optionLabel: (value) => value,
          onChanged: (value) => _modules = value,
        ),
        filter(
          label: 'Ação',
          options: strings(events.map((event) => event.action)),
          selected: _actions,
          optionLabel: (value) => value,
          onChanged: (value) => _actions = value,
        ),
        filter(
          label: 'Ator',
          options: strings(events.map((event) => event.actor)),
          selected: _actors,
          optionLabel: (value) => value,
          onChanged: (value) => _actors = value,
        ),
        filter(
          label: 'Contexto',
          options: strings(events.map((event) => event.context)),
          selected: _contexts,
          optionLabel: (value) => value,
          onChanged: (value) => _contexts = value,
        ),
        filter(
          label: 'Risco',
          options: PrototypeAuditRisk.values,
          selected: _risks,
          optionLabel: _riskLabel,
          onChanged: (value) => _risks = value,
        ),
      ],
      actions: const [],
    );
  }

  Widget _body(List<PrototypeAuditEvent> events, {required bool hasSourceEvents}) {
    switch (widget.state) {
      case AuditDirectoryState.loading:
        return const Center(
          key: Key('audit-state-loading'),
          child: CircularProgressIndicator(semanticsLabel: 'Carregando auditoria'),
        );
      case AuditDirectoryState.empty:
        return const CoeloStatePanel(
          key: Key('audit-state-empty'),
          title: 'Nenhum evento registrado',
          message: 'As atividades da sessão aparecerão aqui.',
          icon: Icons.shield_outlined,
        );
      case AuditDirectoryState.error:
        return const CoeloStatePanel(
          key: Key('audit-state-error'),
          title: 'Não foi possível carregar',
          message: 'Tente novamente mais tarde.',
          icon: Icons.error_outline,
        );
      case AuditDirectoryState.unauthorized:
        return const CoeloStatePanel(
          key: Key('audit-state-unauthorized'),
          title: 'Acesso não autorizado',
          message: 'Seu perfil não permite consultar a auditoria.',
          icon: Icons.lock_outline,
        );
      case AuditDirectoryState.content:
        if (events.isEmpty) {
          return CoeloStatePanel(
            key: const Key('audit-state-no-results'),
            title: hasSourceEvents ? 'Nenhum resultado' : 'Nenhum evento registrado',
            message: hasSourceEvents
                ? 'Ajuste a busca ou os filtros.'
                : 'As atividades aparecerão aqui.',
            icon: Icons.search_off_rounded,
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
            final pageSize = wide ? 8 : 11;
            final totalPages = math.max(1, (events.length / pageSize).ceil());
            final page = _page.clamp(1, totalPages);
            final start = (page - 1) * pageSize;
            final pageEvents = events.skip(start).take(pageSize).toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${events.length} ${events.length == 1 ? 'evento' : 'eventos'}'),
                const SizedBox(height: CoeloSpacing.space3),
                Expanded(child: wide ? _table(pageEvents) : _cards(pageEvents)),
                const SizedBox(height: CoeloSpacing.space3),
                CoeloAdminPagination(
                  currentPage: page,
                  totalPages: totalPages,
                  onPrevious: page > 1 ? () => setState(() => _page = page - 1) : null,
                  onNext: page < totalPages ? () => setState(() => _page = page + 1) : null,
                  onPageSelected: (value) => setState(() => _page = value),
                ),
              ],
            );
          },
        );
    }
  }

  Widget _cards(List<PrototypeAuditEvent> events) => ListView.separated(
    itemCount: events.length,
    separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space3),
    itemBuilder: (context, index) {
      final event = events[index];
      return CoeloAdminInteractiveCard(
        key: Key('audit-card-${event.id}'),
        semanticLabel: 'Abrir evento ${event.id}, ${_riskLabel(event.risk)}',
        onPressed: () => setState(() => _selected = event),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${event.action} · ${event.module}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text('${event.objectType}: ${event.objectId}'),
              Text(event.context ?? 'Contexto global'),
              const SizedBox(height: CoeloSpacing.space2),
              Text(_riskLabel(event.risk)),
            ],
          ),
        ),
      );
    },
  );

  Widget _table(List<PrototypeAuditEvent> events) => SingleChildScrollView(
    child: CoeloAdminResizableTable<PrototypeAuditEvent>(
      key: const Key('audit-table'),
      items: events,
      rowKey: (event) => 'audit-row-${event.id}',
      headerHeight: 48,
      rowHeight: 64,
      onRowPressed: (event) => setState(() => _selected = event),
      isSelected: (event) => _selected?.id == event.id,
      pinnedColumn: _column(
        'instant',
        'Data/hora',
        (event) => _formatCompact(event.occurredAt),
        156,
      ),
      columns: [
        _column('actor', 'Ator', (event) => event.actor, 176),
        _column('module', 'Módulo', (event) => event.module, 144),
        _column('action', 'Ação', (event) => event.action, 176),
        _column('object', 'Objeto', (event) => event.objectId, 196),
        _column('context', 'Contexto', (event) => event.context ?? 'Global', 196),
        _column('risk', 'Risco', (event) => _riskLabel(event.risk), 132),
      ],
    ),
  );

  CoeloAdminTableColumn<PrototypeAuditEvent> _column(
    String id,
    String label,
    String Function(PrototypeAuditEvent) value,
    double width,
  ) => CoeloAdminTableColumn(
    id: id,
    label: label,
    initialWidth: width,
    minWidth: 112,
    maxWidth: width + 120,
    cellBuilder: (context, event) =>
        Text(value(event), maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  List<PrototypeAuditEvent> _filter(List<PrototypeAuditEvent> events) {
    final query = _query.trim().toLowerCase();
    final now = DateTime.now();
    return events
        .where((event) {
          final matchesPeriod =
              _periods.isEmpty ||
              _periods.any((period) {
                final days = switch (period) {
                  _AuditPeriod.today => 1,
                  _AuditPeriod.sevenDays => 7,
                  _AuditPeriod.thirtyDays => 30,
                };
                return event.occurredAt.isAfter(now.subtract(Duration(days: days)));
              });
          return (query.isEmpty || event.searchableText.contains(query)) &&
              (_modules.isEmpty || _modules.contains(event.module)) &&
              (_actions.isEmpty || _actions.contains(event.action)) &&
              (_actors.isEmpty || _actors.contains(event.actor)) &&
              (_contexts.isEmpty || _contexts.contains(event.context)) &&
              (_risks.isEmpty || _risks.contains(event.risk)) &&
              matchesPeriod;
        })
        .toList(growable: false);
  }
}

final auditFixtureEvents = List<PrototypeAuditEvent>.unmodifiable([
  _fixture(
    'audit-fixture-plan-updated',
    15,
    'Planos',
    'Atualizou',
    'plano',
    'coelo-essential',
    'Catálogo',
    PrototypeAuditRisk.medium,
    before: {'status': 'active'},
    after: {'status': 'active'},
  ),
  _fixture(
    'audit-fixture-plan-archived',
    14,
    'Planos',
    'Arquivou',
    'plano',
    'coelo-legacy',
    'Catálogo',
    PrototypeAuditRisk.high,
    before: {'status': 'active'},
    after: {'status': 'archived'},
  ),
  _fixture(
    'audit-fixture-import-completed',
    13,
    'Importações',
    'Concluiu',
    'importação',
    'import-104',
    'Instituição demo',
    PrototypeAuditRisk.medium,
    after: {'result': '24 criados, 2 rejeitados'},
  ),
  _fixture(
    'audit-fixture-import-rejected',
    12,
    'Importações',
    'Rejeitou',
    'importação',
    'import-103',
    'Instituição demo',
    PrototypeAuditRisk.high,
    after: {'result': 'Conflitos detectados'},
  ),
  _fixture(
    'audit-fixture-invite-sent',
    11,
    'Convites',
    'Enviou',
    'convite',
    'invite-204',
    'Unidade demo',
    PrototypeAuditRisk.low,
    after: {'status': 'pending'},
  ),
  _fixture(
    'audit-fixture-invite-resent',
    10,
    'Convites',
    'Reenviou',
    'convite',
    'invite-203',
    'Unidade demo',
    PrototypeAuditRisk.medium,
    before: {'status': 'expired'},
    after: {'status': 'pending'},
  ),
  _fixture(
    'audit-fixture-notice-dismissed',
    9,
    'Avisos',
    'Dispensou',
    'aviso',
    'notice-304',
    'Global',
    PrototypeAuditRisk.low,
    after: {'status': 'ended'},
  ),
  _fixture(
    'audit-fixture-notice-published',
    8,
    'Avisos',
    'Publicou',
    'aviso',
    'notice-303',
    'Global',
    PrototypeAuditRisk.high,
    before: {'status': 'draft'},
    after: {'status': 'active'},
  ),
]);

PrototypeAuditEvent _fixture(
  String id,
  int hour,
  String module,
  String action,
  String objectType,
  String objectId,
  String context,
  PrototypeAuditRisk risk, {
  Map<String, String> before = const {},
  Map<String, String> after = const {},
}) => PrototypeAuditEvent(
  id: id,
  occurredAt: DateTime.utc(2026, 8, 3, hour),
  actor: 'Operadora Coelo',
  module: module,
  action: action,
  objectType: objectType,
  objectId: objectId,
  scope: 'Superadmin',
  reason: 'Ação operacional simulada',
  origin: 'Preview local',
  mfa: true,
  risk: risk,
  before: before,
  after: after,
  context: context,
  relatedReference: '$module · $objectId',
);

String _periodLabel(_AuditPeriod value) => switch (value) {
  _AuditPeriod.today => 'Hoje',
  _AuditPeriod.sevenDays => 'Últimos 7 dias',
  _AuditPeriod.thirtyDays => 'Últimos 30 dias',
};

String _riskLabel(PrototypeAuditRisk risk) => switch (risk) {
  PrototypeAuditRisk.low => 'Risco baixo',
  PrototypeAuditRisk.medium => 'Risco médio',
  PrototypeAuditRisk.high => 'Risco alto',
};

String _formatCompact(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
