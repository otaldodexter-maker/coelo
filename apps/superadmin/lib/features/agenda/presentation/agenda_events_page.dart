import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../data/agenda_prototype_store.dart';
import '../domain/agenda_models.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';

enum _AgendaEventsDisplay { cards, table }

enum _AgendaEventsTableView { all }

enum _AgendaEventAction { open, edit }

final class AgendaEventsPage extends StatefulWidget {
  const AgendaEventsPage({
    required this.store,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    super.key,
  });

  final AgendaPrototypeStore store;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onEdit;

  @override
  State<AgendaEventsPage> createState() => _AgendaEventsPageState();
}

final class _AgendaEventsPageState extends State<AgendaEventsPage> {
  final _search = TextEditingController();
  AgendaItemType? _type;
  AgendaItemStatus? _status;
  _AgendaEventsDisplay _display = _AgendaEventsDisplay.cards;
  int _page = 1;
  int _pageSize = 11;

  @override
  void didUpdateWidget(covariant AgendaEventsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.store, widget.store)) return;
    _search.clear();
    _type = null;
    _status = null;
    _page = 1;
    _pageSize = _display == _AgendaEventsDisplay.cards ? 11 : 8;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : compact
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        final filtered = widget.store.items.where((item) {
          final query = _search.text.trim().toLowerCase();
          return (query.isEmpty ||
                  item.title.toLowerCase().contains(query) ||
                  item.location.toLowerCase().contains(query)) &&
              (_type == null || item.type == _type) &&
              (_status == null || item.status == _status);
        }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
        final pages = math.max(1, (filtered.length / _pageSize).ceil());
        final safePage = math.min(_page, pages);
        final start = (safePage - 1) * _pageSize;
        final visible = filtered.skip(start).take(_pageSize).toList(growable: false);
        return ListView(
          key: const Key('agenda-events-scroll'),
          padding: EdgeInsets.all(padding),
          children: [
            Text('Eventos', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: CoeloSpacing.space1),
            Text(
              'Busque, compare e revise os itens da agenda.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: CoeloSpacing.space6),
            CoeloAdminListingToolbar(
              key: Key('agenda-events-page-$safePage'),
              search: SizedBox(
                width: compact ? constraints.maxWidth - padding * 2 : 300,
                height: CoeloSize.touchMin,
                child: CoeloSearchField(
                  controller: _search,
                  hintText: 'Buscar por título ou local',
                  semanticLabel: 'Buscar eventos',
                  onChanged: (_) => setState(() => _page = 1),
                ),
              ),
              filters: [
                SizedBox(
                  width: compact ? 164 : 190,
                  child: CoeloAdminSingleSelectField<AgendaItemType?>(
                    label: 'Tipo',
                    value: _type,
                    options: <AgendaItemType?>[null, ...AgendaItemType.values],
                    optionLabel: (value) => value?.label ?? 'Todos os tipos',
                    onChanged: (value) => setState(() {
                      _type = value;
                      _page = 1;
                    }),
                  ),
                ),
                SizedBox(
                  width: compact ? 164 : 180,
                  child: CoeloAdminSingleSelectField<AgendaItemStatus?>(
                    label: 'Status',
                    value: _status,
                    options: <AgendaItemStatus?>[null, ...AgendaItemStatus.values],
                    optionLabel: (value) =>
                        value == null ? 'Todos os status' : _enumLabel(value.name),
                    onChanged: (value) => setState(() {
                      _status = value;
                      _page = 1;
                    }),
                  ),
                ),
              ],
              actions: [
                SuperadminDirectoryViewToggle<_AgendaEventsTableView>(
                  key: const Key('agenda-events-display-toggle'),
                  cardsKey: const Key('agenda-events-view-cards'),
                  tableKey: const Key('agenda-events-view-table'),
                  cardsSelected: _display == _AgendaEventsDisplay.cards,
                  groupedView: _AgendaEventsTableView.all,
                  selectedTableView: _AgendaEventsTableView.all,
                  tableViews: const [
                    SuperadminDirectoryTableViewOption(
                      value: _AgendaEventsTableView.all,
                      label: 'Todos os eventos',
                    ),
                  ],
                  onCardsSelected: () => _changeDisplay(_AgendaEventsDisplay.cards),
                  onTableViewSelected: (_) => _changeDisplay(_AgendaEventsDisplay.table),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            if (_display == _AgendaEventsDisplay.table) ...[
              CoeloAdminCreateAction(
                key: const Key('agenda-events-create-banner'),
                label: 'Criar item',
                description: 'Cadastre um evento, rotina, prazo ou alteração operacional.',
                icon: Icons.event_available_outlined,
                variant: CoeloAdminCreateActionVariant.banner,
                onPressed: widget.onCreate,
              ),
              const SizedBox(height: CoeloSpacing.space4),
            ],
            if (_display == _AgendaEventsDisplay.cards)
              _EventCards(
                items: visible,
                onCreate: widget.onCreate,
                onOpen: widget.onOpen,
                onEdit: widget.onEdit,
              )
            else if (visible.isNotEmpty)
              _EventTable(items: visible, onOpen: widget.onOpen, onEdit: widget.onEdit),
            if (visible.isEmpty) ...[
              if (_display == _AgendaEventsDisplay.cards)
                const SizedBox(height: CoeloSpacing.space4),
              CoeloStatePanel(
                key: const Key('agenda-events-no-results'),
                title: 'Nenhum item encontrado',
                message: 'Ajuste a busca ou os filtros para ver outros itens.',
                icon: Icons.search_off_rounded,
                actionLabel: 'Limpar filtros',
                onAction: _clearFilters,
              ),
            ],
            if (visible.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space4),
              Center(
                child: CoeloAdminPagination(
                  currentPage: safePage,
                  totalPages: pages,
                  pageSize: _pageSize,
                  pageSizeOptions: _display == _AgendaEventsDisplay.cards
                      ? const [11, 20, 50, 100]
                      : const [8, 20, 50, 100],
                  onPrevious: safePage > 1 ? () => setState(() => _page = safePage - 1) : null,
                  onNext: safePage < pages ? () => setState(() => _page = safePage + 1) : null,
                  onPageSelected: (value) => setState(() => _page = value),
                  onPageSizeChanged: (value) => setState(() {
                    _pageSize = value;
                    _page = 1;
                  }),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  void _changeDisplay(_AgendaEventsDisplay display) {
    if (_display == display) return;
    setState(() {
      _display = display;
      _page = 1;
      _pageSize = display == _AgendaEventsDisplay.cards ? 11 : 8;
    });
  }

  void _clearFilters() => setState(() {
    _search.clear();
    _type = null;
    _status = null;
    _page = 1;
  });
}

final class _EventCards extends StatelessWidget {
  const _EventCards({
    required this.items,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
  });
  final List<AgendaItem> items;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 340).floor().clamp(1, 99);
      final cardWidth = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
      return Wrap(
        key: const Key('agenda-event-card-grid'),
        spacing: CoeloSpacing.space6,
        runSpacing: CoeloSpacing.space6,
        children: [
          SizedBox(
            width: cardWidth,
            child: ConstrainedBox(
              key: const Key('agenda-events-create-card'),
              constraints: const BoxConstraints(minHeight: 216),
              child: CoeloAdminCreateAction(
                label: 'Criar item',
                description: 'Cadastre um evento, rotina, prazo ou alteração operacional.',
                icon: Icons.event_available_outlined,
                onPressed: onCreate,
              ),
            ),
          ),
          for (final item in items)
            SizedBox(
              width: cardWidth,
              child: CoeloAdminInteractiveCard(
                key: Key('agenda-event-card-${item.id}'),
                surfaceKey: Key('agenda-event-card-surface-${item.id}'),
                minHeight: 216,
                onPressed: () => onOpen(item.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoeloSpacing.space6,
                    vertical: CoeloSpacing.space4,
                  ),
                  child: _EventSummary(
                    item: item,
                    onOpen: () => onOpen(item.id),
                    onEdit: () => onEdit(item.id),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

final class _EventTable extends StatelessWidget {
  const _EventTable({required this.items, required this.onOpen, required this.onEdit});
  final List<AgendaItem> items;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onEdit;

  Widget _cell(String value) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );

  Widget _widgetCell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<AgendaItem>(
    items: items,
    rowKey: (item) => item.id,
    onRowPressed: (item) => onOpen(item.id),
    headerHeight: CoeloSize.touchMin,
    rowHeight: 64,
    pinnedColumn: CoeloAdminTableColumn(
      id: 'title',
      label: 'Título',
      initialWidth: 240,
      minWidth: 180,
      maxWidth: 360,
      cellBuilder: (_, item) => _cell(item.title),
    ),
    columns: [
      CoeloAdminTableColumn(
        id: 'type',
        label: 'Tipo',
        initialWidth: 180,
        minWidth: 140,
        maxWidth: 260,
        cellBuilder: (_, item) => _cell(item.type.label),
      ),
      CoeloAdminTableColumn(
        id: 'date',
        label: 'Início e fim',
        initialWidth: 230,
        minWidth: 190,
        maxWidth: 320,
        cellBuilder: (_, item) => _cell('${_dateTime(item.startsAt)} — ${_dateTime(item.endsAt)}'),
      ),
      CoeloAdminTableColumn(
        id: 'place',
        label: 'Local',
        initialWidth: 190,
        minWidth: 140,
        maxWidth: 280,
        cellBuilder: (_, item) => _cell(item.location),
      ),
      CoeloAdminTableColumn(
        id: 'status',
        label: 'Status',
        initialWidth: 190,
        minWidth: 160,
        maxWidth: 260,
        cellBuilder: (_, item) => _widgetCell(_AgendaEventStatusChip(status: item.status)),
      ),
      CoeloAdminTableColumn(
        id: 'actions',
        label: 'Ações',
        initialWidth: 80,
        minWidth: 72,
        maxWidth: 100,
        cellBuilder: (_, item) => _widgetCell(
          _AgendaEventActions(
            item: item,
            onOpen: () => onOpen(item.id),
            onEdit: () => onEdit(item.id),
          ),
        ),
      ),
    ],
  );
}

final class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.item, this.onOpen, this.onEdit});
  final AgendaItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
          _AgendaEventStatusIndicator(item: item),
          if (onOpen != null || onEdit != null) ...[
            const SizedBox(width: CoeloSpacing.space2),
            _AgendaEventActions(item: item, onOpen: onOpen, onEdit: onEdit),
          ],
        ],
      ),
      Text('${item.type.label} · ${_enumLabel(item.prominence.name)}'),
      const SizedBox(height: CoeloSpacing.space2),
      Text('${_dateTime(item.startsAt)} — ${_dateTime(item.endsAt)}'),
      Text('${_duration(item.duration)} · ${item.location}'),
      const SizedBox(height: CoeloSpacing.space2),
      Text('Prioridade ${_enumLabel(item.priority.name)}'),
    ],
  );
}

final class _AgendaEventActions extends StatelessWidget {
  const _AgendaEventActions({required this.item, this.onOpen, this.onEdit});

  final AgendaItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final items = <CoeloAdminFlyoutItem<_AgendaEventAction>>[
      if (onOpen != null)
        const CoeloAdminFlyoutItem(
          value: _AgendaEventAction.open,
          icon: Icons.visibility_outlined,
          label: 'Ver detalhes',
        ),
      if (onEdit != null)
        const CoeloAdminFlyoutItem(
          value: _AgendaEventAction.edit,
          icon: Icons.edit_outlined,
          label: 'Editar',
        ),
    ];
    return CoeloAdminFlyout<_AgendaEventAction>(
      items: items,
      onSelected: (action) => switch (action) {
        _AgendaEventAction.open => onOpen?.call(),
        _AgendaEventAction.edit => onEdit?.call(),
      },
      builder: (context, controller) => IconButton(
        key: Key('agenda-event-actions-${item.id}'),
        tooltip: 'Ações de ${item.title}',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}

final class _AgendaEventStatusIndicator extends StatelessWidget {
  const _AgendaEventStatusIndicator({required this.item});

  final AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _statusColors(context, item.status);
    final label = _statusLabel(item.status);
    return CoeloAdminExpandableStatusIndicator(
      label: label,
      backgroundColor: background,
      foregroundColor: foreground,
      semanticLabel: 'Status: $label',
      surfaceKey: Key('agenda-event-status-${item.id}'),
    );
  }
}

final class _AgendaEventStatusChip extends StatelessWidget {
  const _AgendaEventStatusChip({required this.status});

  final AgendaItemStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _statusColors(context, status);
    return CoeloStatusChip(
      label: _statusLabel(status),
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }
}

(Color, Color) _statusColors(BuildContext context, AgendaItemStatus status) {
  final colors =
      Theme.of(context).extension<CoeloStatusColors>() ??
      (Theme.brightnessOf(context) == Brightness.dark
          ? CoeloStatusColors.dark
          : CoeloStatusColors.light);
  return switch (status) {
    AgendaItemStatus.draft => (colors.historyContainer, colors.onHistoryContainer),
    AgendaItemStatus.scheduled => (colors.warningContainer, colors.onWarningContainer),
    AgendaItemStatus.published => (colors.successContainer, colors.onSuccessContainer),
    AgendaItemStatus.canceled => (colors.errorContainer, colors.onErrorContainer),
  };
}

String _statusLabel(AgendaItemStatus status) => switch (status) {
  AgendaItemStatus.draft => 'Rascunho',
  AgendaItemStatus.scheduled => 'Agendado',
  AgendaItemStatus.published => 'Publicado',
  AgendaItemStatus.canceled => 'Cancelado',
};

final class AgendaEventDetailPage extends StatelessWidget {
  const AgendaEventDetailPage({
    required this.store,
    required this.eventId,
    required this.onBack,
    required this.onEdit,
    super.key,
  });

  final AgendaPrototypeStore store;
  final String eventId;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final item = store.itemById(eventId);
    if (item == null) {
      return CoeloStatePanel(
        title: 'Item não encontrado',
        message: 'O item solicitado não foi encontrado.',
        icon: Icons.event_busy_rounded,
        actionLabel: 'Voltar aos eventos',
        onAction: onBack,
      );
    }
    return ListView(
      key: const Key('agenda-event-detail'),
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Eventos'),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _EventSummary(item: item),
        const SizedBox(height: CoeloSpacing.space6),
        Text('Descrição', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        Text(item.description),
        const SizedBox(height: CoeloSpacing.space6),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar item'),
        ),
      ],
    );
  }
}

String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}min';
}

String _enumLabel(String value) {
  final spaced = value.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}');
  return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
}
