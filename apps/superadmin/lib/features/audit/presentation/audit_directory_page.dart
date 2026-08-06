import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/prototype/superadmin_prototype_store.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
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
    this.now,
    super.key,
  });

  final SuperadminPrototypeStore store;
  final LogoutAction logout;
  final AuditDirectoryState state;
  final ValueChanged<String>? onDestinationSelected;
  final DateTime Function()? now;

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
  var _pageSize = 8;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Auditoria',
    subtitle: 'Monitore eventos de auditoria do ambiente em tempo real.',
    showChatLauncher: false,
    currentDestination: 'audit',
    activityController: widget.store.activityController,
    onDestinationSelected: widget.onDestinationSelected,
    child: AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final allEvents = [...widget.store.auditEvents, ...auditFixtureEvents]
          ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
        final visible = _filter(allEvents);
        final lastUpdate = visible.isNotEmpty ? visible.first.occurredAt : null;
        return LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                ? CoeloSpacing.space10
                : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                ? CoeloSpacing.space6
                : CoeloSpacing.space4;
            return Padding(
              padding: EdgeInsets.all(padding),
              child: CoeloAdminWorkspaceLayout(
                toolbar: Padding(
                  padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
                  child: _toolbar(allEvents),
                ),
                body: _body(visible, hasSourceEvents: allEvents.isNotEmpty, lastUpdate: lastUpdate),
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
        );
      },
    ),
  );

  Widget _toolbar(List<PrototypeAuditEvent> events) {
    final latest = events.isNotEmpty ? events.first.occurredAt : null;
    List<String> strings(Iterable<String?> values) =>
        values.whereType<String>().toSet().toList()..sort();
    Widget filter<T>({
      required double width,
      required String label,
      required List<T> options,
      required Set<T> selected,
      required String Function(T) optionLabel,
      required ValueChanged<Set<T>> onChanged,
    }) => SizedBox(
      width: width,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final searchWidth = compact ? constraints.maxWidth : 280.0;
        final filterWidth = compact ? (constraints.maxWidth - CoeloSpacing.space3) / 2 : 176.0;
        return CoeloAdminListingToolbar(
          search: SizedBox(
            width: searchWidth,
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
            SizedBox(width: filterWidth, height: CoeloSize.touchMin, child: _realtimeBadge(latest)),
            filter(
              width: filterWidth,
              label: 'Período',
              options: _AuditPeriod.values,
              selected: _periods,
              optionLabel: _periodLabel,
              onChanged: (value) => _periods = value,
            ),
            filter(
              width: filterWidth,
              label: 'Módulo',
              options: strings(events.map((event) => event.module)),
              selected: _modules,
              optionLabel: (value) => value,
              onChanged: (value) => _modules = value,
            ),
            filter(
              width: filterWidth,
              label: 'Ação',
              options: strings(events.map((event) => event.action)),
              selected: _actions,
              optionLabel: (value) => value,
              onChanged: (value) => _actions = value,
            ),
            filter(
              width: filterWidth,
              label: 'Ator',
              options: strings(events.map((event) => event.actor)),
              selected: _actors,
              optionLabel: (value) => value,
              onChanged: (value) => _actors = value,
            ),
            filter(
              width: filterWidth,
              label: 'Contexto',
              options: strings(events.map((event) => event.context)),
              selected: _contexts,
              optionLabel: (value) => value,
              onChanged: (value) => _contexts = value,
            ),
            filter(
              width: filterWidth,
              label: 'Risco',
              options: PrototypeAuditRisk.values,
              selected: _risks,
              optionLabel: _riskLabel,
              onChanged: (value) => _risks = value,
            ),
          ],
          actions: const [],
        );
      },
    );
  }

  Widget _body(
    List<PrototypeAuditEvent> events, {
    required bool hasSourceEvents,
    required DateTime? lastUpdate,
  }) {
    switch (widget.state) {
      case AuditDirectoryState.loading:
        return const CoeloStatePanel(
          key: Key('audit-state-loading'),
          title: 'Carregando auditoria',
          message: 'Aguarde enquanto preparamos os eventos.',
          loading: true,
        );
      case AuditDirectoryState.empty:
        return const CoeloStatePanel(
          key: Key('audit-state-empty'),
          title: 'Nenhum evento registrado',
          message: 'As atividades aparecerão aqui.',
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
            final tableView = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
            final pageSizeOptions = tableView ? const [8, 20, 50, 100] : const [11, 20, 50, 100];
            final pageSize = pageSizeOptions.contains(_pageSize)
                ? _pageSize
                : pageSizeOptions.first;
            final totalPages = math.max(1, (events.length / pageSize).ceil());
            final page = _page.clamp(1, totalPages);
            final start = (page - 1) * pageSize;
            final pageEvents = events.skip(start).take(pageSize).toList(growable: false);
            final pagination = SuperadminListingPaginationFooter(
              horizontalPadding: 0,
              child: CoeloAdminPagination(
                currentPage: page,
                totalPages: totalPages,
                pageSize: pageSize,
                pageSizeOptions: pageSizeOptions,
                onPageSizeChanged: (value) => setState(() {
                  _pageSize = value;
                  _page = 1;
                }),
                onPrevious: page > 1 ? () => setState(() => _page = page - 1) : null,
                onNext: page < totalPages ? () => setState(() => _page = page + 1) : null,
                onPageSelected: (value) => setState(() => _page = value),
              ),
            );
            if (!tableView) {
              return ListView(
                key: const Key('audit-card-list'),
                children: [
                  _resultSummary(events.length, lastUpdate, compact: true),
                  const SizedBox(height: CoeloSpacing.space3),
                  for (final event in pageEvents) ...[
                    _auditCard(event),
                    const SizedBox(height: CoeloSpacing.space3),
                  ],
                  pagination,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _resultSummary(events.length, lastUpdate, compact: false),
                const SizedBox(height: CoeloSpacing.space3),
                Expanded(child: _table(pageEvents)),
                const SizedBox(height: CoeloSpacing.space3),
                pagination,
              ],
            );
          },
        );
    }
  }

  Widget _resultSummary(int count, DateTime? lastUpdate, {required bool compact}) {
    final countLabel = Text(count.toString() + (count == 1 ? ' evento' : ' eventos'));
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          countLabel,
          const SizedBox(height: CoeloSpacing.space1),
          _realtimeStatus(lastUpdate),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: countLabel),
        Flexible(child: _realtimeStatus(lastUpdate)),
      ],
    );
  }

  Widget _auditCard(PrototypeAuditEvent event) => CoeloAdminInteractiveCard(
    key: Key('audit-card-${event.id}'),
    semanticLabel: 'Abrir evento de auditoria ${event.id}',
    minHeight: 216,
    onPressed: () => setState(() => _selected = event),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(event.action, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: CoeloSpacing.space1),
          Text('${event.objectType}: ${event.objectId}'),
          const SizedBox(height: CoeloSpacing.space2),
          _AuditRiskLabel(risk: event.risk),
          const SizedBox(height: CoeloSpacing.space3),
          _AuditCardField(label: 'Data/hora', value: _formatCompact(event.occurredAt)),
          _AuditCardField(label: 'Ator', value: event.actor),
          _AuditCardField(label: 'Módulo', value: event.module),
          _AuditCardField(label: 'Contexto / Hierarquia', value: event.context ?? 'Global'),
          _AuditCardField(label: 'Origem', value: event.origin),
        ],
      ),
    ),
  );
  Widget _table(List<PrototypeAuditEvent> events) => LayoutBuilder(
    builder: (context, constraints) {
      const minTableWidth = 156 + 176 + 180 + 176 + 196 + 196 + 132 + 176 + 32;
      return SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: math.max(constraints.maxWidth, minTableWidth).toDouble(),
            ),
            child: CoeloAdminResizableTable<PrototypeAuditEvent>(
              key: const Key('audit-table'),
              items: events,
              rowKey: (event) => 'audit-row-${event.id}',
              headerHeight: 56,
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
                _column('module', 'Módulo', (event) => event.module, 180),
                _column('action', 'Ação', (event) => event.action, 176),
                _column(
                  'object',
                  'Recurso',
                  (event) => '${event.objectType}: ${event.objectId}',
                  196,
                ),
                _column(
                  'context',
                  'Contexto / Hierarquia',
                  (event) => event.context ?? 'Global',
                  196,
                ),
                _column('risk', 'Risco', (event) => _riskLabel(event.risk), 132),
                _column('origin', 'Origem', (event) => event.origin, 176),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _realtimeBadge(DateTime? lastUpdate) {
    final theme = Theme.of(context);
    final status = lastUpdate == null
        ? 'Ao vivo: aguardando evento'
        : 'Ao vivo • ${_timeAgo(_now().difference(lastUpdate.toLocal()))}';
    return Semantics(
      label: 'Status de atualização dos eventos da auditoria',
      child: Container(
        height: CoeloSize.touchMin,
        padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CoeloRadius.md),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        alignment: Alignment.centerLeft,
        child: Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }

  Widget _realtimeStatus(DateTime? lastUpdate) {
    final theme = Theme.of(context);
    final status = lastUpdate == null
        ? 'Última atualização: sem dados'
        : 'Atualizado: ${_timeAgo(_now().difference(lastUpdate.toLocal()))}';
    return Text(
      status,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  String _timeAgo(Duration elapsed) {
    final safe = elapsed.isNegative ? Duration.zero : elapsed;
    if (safe.inSeconds < 60) {
      return 'agora';
    }
    if (safe.inMinutes < 60) {
      return '${safe.inMinutes}m atrás';
    }
    if (safe.inMinutes < 60 * 24) {
      return '${safe.inHours}h atrás';
    }
    return '${safe.inDays}d atrás';
  }

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

final class _AuditCardField extends StatelessWidget {
  const _AuditCardField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
    child: Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          TextSpan(text: '$label: ', style: Theme.of(context).textTheme.labelMedium),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}

final class _AuditRiskLabel extends StatelessWidget {
  const _AuditRiskLabel({required this.risk});

  final PrototypeAuditRisk risk;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (risk) {
      PrototypeAuditRisk.low => ('Risco baixo', Icons.shield_outlined),
      PrototypeAuditRisk.medium => ('Risco médio', Icons.warning_amber_rounded),
      PrototypeAuditRisk.high => ('Risco alto', Icons.gpp_bad_outlined),
    };
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: CoeloSize.iconSm),
            const SizedBox(width: CoeloSpacing.space1),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );
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
