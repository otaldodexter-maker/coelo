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

enum _AgendaEventAction { open, edit, cancel, restore, deleteDraft }

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
                onCancel: (item) => _confirmLifecycle(item, _AgendaLifecycleAction.cancel),
                onRestore: (item) => _confirmLifecycle(item, _AgendaLifecycleAction.restore),
                onDeleteDraft: (item) =>
                    _confirmLifecycle(item, _AgendaLifecycleAction.deleteDraft),
              )
            else if (visible.isNotEmpty)
              _EventTable(
                items: visible,
                onOpen: widget.onOpen,
                onEdit: widget.onEdit,
                onCancel: (item) => _confirmLifecycle(item, _AgendaLifecycleAction.cancel),
                onRestore: (item) => _confirmLifecycle(item, _AgendaLifecycleAction.restore),
                onDeleteDraft: (item) =>
                    _confirmLifecycle(item, _AgendaLifecycleAction.deleteDraft),
              ),
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

  Future<void> _confirmLifecycle(AgendaItem item, _AgendaLifecycleAction action) async {
    final confirmed = await _showAgendaLifecycleConfirmation(context, item, action);
    if (confirmed != true || !mounted) return;
    final result = switch (action) {
      _AgendaLifecycleAction.cancel => widget.store.cancelItem(item.id, actorName: 'Owner Coelo'),
      _AgendaLifecycleAction.restore => widget.store.restoreItem(item.id, actorName: 'Owner Coelo'),
      _AgendaLifecycleAction.deleteDraft => widget.store.deleteDraft(item.id),
    };
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_mutationFeedback(action, result))));
  }
}

final class _EventCards extends StatelessWidget {
  const _EventCards({
    required this.items,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    required this.onCancel,
    required this.onRestore,
    required this.onDeleteDraft,
  });
  final List<AgendaItem> items;
  final VoidCallback onCreate;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onEdit;
  final ValueChanged<AgendaItem> onCancel;
  final ValueChanged<AgendaItem> onRestore;
  final ValueChanged<AgendaItem> onDeleteDraft;

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
                    onCancel: () => onCancel(item),
                    onRestore: () => onRestore(item),
                    onDeleteDraft: () => onDeleteDraft(item),
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
  const _EventTable({
    required this.items,
    required this.onOpen,
    required this.onEdit,
    required this.onCancel,
    required this.onRestore,
    required this.onDeleteDraft,
  });
  final List<AgendaItem> items;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onEdit;
  final ValueChanged<AgendaItem> onCancel;
  final ValueChanged<AgendaItem> onRestore;
  final ValueChanged<AgendaItem> onDeleteDraft;

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
            onCancel: () => onCancel(item),
            onRestore: () => onRestore(item),
            onDeleteDraft: () => onDeleteDraft(item),
          ),
        ),
      ),
    ],
  );
}

final class _EventSummary extends StatelessWidget {
  const _EventSummary({
    required this.item,
    this.onOpen,
    this.onEdit,
    this.onCancel,
    this.onRestore,
    this.onDeleteDraft,
  });
  final AgendaItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onRestore;
  final VoidCallback? onDeleteDraft;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
          _AgendaEventStatusIndicator(item: item),
          if (onOpen != null || onEdit != null || onCancel != null) ...[
            const SizedBox(width: CoeloSpacing.space2),
            _AgendaEventActions(
              item: item,
              onOpen: onOpen,
              onEdit: onEdit,
              onCancel: onCancel,
              onRestore: onRestore,
              onDeleteDraft: onDeleteDraft,
            ),
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
  const _AgendaEventActions({
    required this.item,
    this.onOpen,
    this.onEdit,
    this.onCancel,
    this.onRestore,
    this.onDeleteDraft,
  });

  final AgendaItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onRestore;
  final VoidCallback? onDeleteDraft;

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
      if ((item.status == AgendaItemStatus.scheduled ||
              item.status == AgendaItemStatus.published) &&
          onCancel != null)
        const CoeloAdminFlyoutItem(
          value: _AgendaEventAction.cancel,
          icon: Icons.event_busy_outlined,
          label: 'Cancelar evento',
          startsGroup: true,
          tone: CoeloAdminFlyoutTone.negative,
        ),
      if (item.status == AgendaItemStatus.canceled && onRestore != null)
        const CoeloAdminFlyoutItem(
          value: _AgendaEventAction.restore,
          icon: Icons.restore_rounded,
          label: 'Restaurar evento',
          startsGroup: true,
        ),
      if (item.status == AgendaItemStatus.draft && onDeleteDraft != null)
        const CoeloAdminFlyoutItem(
          value: _AgendaEventAction.deleteDraft,
          icon: Icons.delete_outline_rounded,
          label: 'Excluir rascunho',
          startsGroup: true,
          tone: CoeloAdminFlyoutTone.negative,
        ),
    ];
    return CoeloAdminFlyout<_AgendaEventAction>(
      items: items,
      onSelected: (action) => switch (action) {
        _AgendaEventAction.open => onOpen?.call(),
        _AgendaEventAction.edit => onEdit?.call(),
        _AgendaEventAction.cancel => onCancel?.call(),
        _AgendaEventAction.restore => onRestore?.call(),
        _AgendaEventAction.deleteDraft => onDeleteDraft?.call(),
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

final class AgendaEventDetailPage extends StatefulWidget {
  const AgendaEventDetailPage({
    required this.store,
    required this.eventId,
    required this.onBack,
    required this.onEdit,
    this.unavailable = false,
    super.key,
  });

  final AgendaPrototypeStore store;
  final String eventId;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final bool unavailable;

  @override
  State<AgendaEventDetailPage> createState() => _AgendaEventDetailPageState();
}

final class _AgendaEventDetailPageState extends State<AgendaEventDetailPage> {
  static const _actorName = 'Owner Coelo';

  @override
  Widget build(BuildContext context) {
    if (widget.unavailable) {
      return ListView(
        key: const Key('agenda-event-detail'),
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Eventos'),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text('Detalhes do evento', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: CoeloSpacing.space6),
          const CoeloStatePanel(
            key: Key('agenda-event-unavailable'),
            title: 'Agenda indisponível',
            message: 'Não foi possível carregar este item agora. Nenhuma alteração foi aplicada.',
            icon: Icons.cloud_off_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          const _AgendaDetailSection(
            title: 'Descrição',
            child: Text('Conteúdo indisponível até existir uma fonte autorizada.'),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          const _AgendaDetailSection(
            title: 'Contexto e audiência',
            child: Text('Contexto e audiência não foram consultados.'),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          const _AgendaDetailSection(
            title: 'Agenda e respostas',
            child: Text('Período, recorrência e respostas não foram consultados.'),
          ),
          const SizedBox(height: CoeloSpacing.space6),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('agenda-event-edit-unavailable'),
              onPressed: null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar item'),
            ),
          ),
        ],
      );
    }
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final item = widget.store.itemById(widget.eventId);
        if (item == null) {
          return CoeloStatePanel(
            key: const Key('agenda-event-not-found'),
            title: 'Item não encontrado',
            message: 'O item solicitado não foi encontrado ou não pode ser revelado.',
            icon: Icons.event_busy_rounded,
            actionLabel: 'Voltar aos eventos',
            onAction: widget.onBack,
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
                ? CoeloSpacing.space4
                : CoeloSpacing.space6;
            return ListView(
              key: const Key('agenda-event-detail'),
              padding: EdgeInsets.all(horizontalPadding),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Eventos'),
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space3),
                _EventSummary(item: item),
                const SizedBox(height: CoeloSpacing.space6),
                _AgendaDetailSection(
                  title: 'Descrição',
                  child: Text(
                    item.description.trim().isEmpty
                        ? 'Nenhuma descrição informada.'
                        : item.description,
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _AgendaDetailSection(
                  title: 'Contexto e audiência',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AgendaDetailField(
                        label: 'Contexto principal',
                        value: _mainContextLabel(item),
                      ),
                      _AgendaDetailField(label: 'Audiência', value: _audienceLabel(item)),
                    ],
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _AgendaDetailSection(
                  title: 'Agenda e respostas',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AgendaDetailField(label: 'Fuso horário', value: item.timeZoneId),
                      _AgendaDetailField(
                        label: 'Recorrência',
                        value: _recurrenceLabel(item.recurrence),
                      ),
                      _AgendaDetailField(
                        label: 'Resposta esperada',
                        value: _responseModeLabel(item.responseMode),
                      ),
                      if (item.responseMode != AgendaResponseMode.none)
                        _AgendaDetailField(
                          label: 'Política dos responsáveis',
                          value: _guardianPolicyLabel(item.guardianResponsePolicy),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _AgendaDetailSection(
                  title: 'Histórico',
                  child: item.history.isEmpty
                      ? const Text('Nenhuma alteração registrada.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in item.history.reversed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
                                child: Text(_historyLabel(entry)),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: CoeloSpacing.space6),
                _actions(item),
              ],
            );
          },
        );
      },
    );
  }

  Widget _actions(AgendaItem item) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: CoeloSpacing.space3,
      runSpacing: CoeloSpacing.space3,
      children: [
        OutlinedButton.icon(
          onPressed: widget.onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar item'),
        ),
        if (item.status == AgendaItemStatus.scheduled || item.status == AgendaItemStatus.published)
          FilledButton.icon(
            key: const Key('agenda-event-cancel'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => _confirmLifecycle(item, _AgendaLifecycleAction.cancel),
            icon: const Icon(Icons.event_busy_outlined),
            label: const Text('Cancelar evento'),
          ),
        if (item.status == AgendaItemStatus.canceled)
          FilledButton.icon(
            key: const Key('agenda-event-restore'),
            onPressed: () => _confirmLifecycle(item, _AgendaLifecycleAction.restore),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restaurar evento'),
          ),
        if (item.status == AgendaItemStatus.draft)
          FilledButton.icon(
            key: const Key('agenda-event-delete-draft'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () => _confirmLifecycle(item, _AgendaLifecycleAction.deleteDraft),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir rascunho'),
          ),
      ],
    );
  }

  Future<void> _confirmLifecycle(AgendaItem item, _AgendaLifecycleAction action) async {
    final confirmed = await _showAgendaLifecycleConfirmation(context, item, action);
    if (confirmed != true || !mounted) return;

    final result = switch (action) {
      _AgendaLifecycleAction.cancel => widget.store.cancelItem(item.id, actorName: _actorName),
      _AgendaLifecycleAction.restore => widget.store.restoreItem(item.id, actorName: _actorName),
      _AgendaLifecycleAction.deleteDraft => widget.store.deleteDraft(item.id),
    };
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_mutationFeedback(action, result))));
  }

  String _contextName(String id) {
    for (final context in widget.store.contexts) {
      if (context.id == id) return context.name;
    }
    return id;
  }

  String _mainContextLabel(AgendaItem item) {
    final audience = item.audience;
    final id =
        audience.personIds.firstOrNull ??
        audience.activityIds.firstOrNull ??
        audience.groupIds.firstOrNull ??
        audience.unitIds.firstOrNull ??
        audience.institutionId;
    return _contextName(id);
  }

  String _audienceLabel(AgendaItem item) {
    final audience = item.audience;
    final ids = <String>[
      audience.institutionId,
      ...audience.unitIds,
      ...audience.groupIds,
      ...audience.activityIds,
      ...audience.personIds,
    ];
    return ids.map(_contextName).join(' · ');
  }
}

enum _AgendaLifecycleAction { cancel, restore, deleteDraft }

Future<bool?> _showAgendaLifecycleConfirmation(
  BuildContext context,
  AgendaItem item,
  _AgendaLifecycleAction action,
) => showDialog<bool>(
  context: context,
  builder: (dialogContext) {
    final destructive = action != _AgendaLifecycleAction.restore;
    return CoeloAdminDialogShell(
      title: switch (action) {
        _AgendaLifecycleAction.cancel => 'Cancelar evento?',
        _AgendaLifecycleAction.restore => 'Restaurar evento?',
        _AgendaLifecycleAction.deleteDraft => 'Excluir rascunho?',
      },
      body: Text(switch (action) {
        _AgendaLifecycleAction.cancel =>
          '“${item.title}” deixará de aparecer como ativo. O histórico será preservado.',
        _AgendaLifecycleAction.restore =>
          '“${item.title}” voltará ao status anterior ao cancelamento.',
        _AgendaLifecycleAction.deleteDraft =>
          '“${item.title}” será removido desta demonstração. Esta ação não pode ser desfeita.',
      }),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(dialogContext).pop(false),
        child: const Text('Voltar'),
      ),
      primaryAction: FilledButton(
        key: const Key('agenda-event-confirm-lifecycle'),
        style: destructive
            ? FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              )
            : null,
        onPressed: () => Navigator.of(dialogContext).pop(true),
        child: Text(switch (action) {
          _AgendaLifecycleAction.cancel => 'Confirmar cancelamento',
          _AgendaLifecycleAction.restore => 'Confirmar restauração',
          _AgendaLifecycleAction.deleteDraft => 'Excluir rascunho',
        }),
      ),
    );
  },
);

final class _AgendaDetailSection extends StatelessWidget {
  const _AgendaDetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space3),
          child,
        ],
      ),
    ),
  );
}

final class _AgendaDetailField extends StatelessWidget {
  const _AgendaDetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: CoeloSpacing.space1),
        SelectableText(value),
      ],
    ),
  );
}

String _recurrenceLabel(AgendaRecurrence? recurrence) {
  if (recurrence == null) return 'Evento único';
  final frequency = switch (recurrence.frequency) {
    AgendaRecurrenceFrequency.daily => 'Diária',
    AgendaRecurrenceFrequency.weekly => 'Semanal',
    AgendaRecurrenceFrequency.monthly => 'Mensal',
  };
  final interval = recurrence.interval == 1 ? '' : ' a cada ${recurrence.interval} períodos';
  final end = recurrence.occurrenceCount != null
      ? '${recurrence.occurrenceCount} ocorrências'
      : 'até ${_date(recurrence.until!)}';
  final exceptions = recurrence.exceptions.isEmpty
      ? ''
      : ' · ${recurrence.exceptions.length} exceção(ões)';
  return '$frequency$interval · $end$exceptions';
}

String _responseModeLabel(AgendaResponseMode mode) => switch (mode) {
  AgendaResponseMode.none => 'Nenhuma resposta',
  AgendaResponseMode.rsvp => 'Confirmação de presença',
  AgendaResponseMode.acknowledgement => 'Ciência',
  AgendaResponseMode.authorization => 'Autorização',
};

String _guardianPolicyLabel(GuardianResponsePolicy policy) => switch (policy) {
  GuardianResponsePolicy.oneIsEnough => 'Uma resposta por criança é suficiente',
  GuardianResponsePolicy.allMustRespond => 'Todos os responsáveis devem responder',
};

String _historyLabel(AgendaHistoryEntry entry) {
  final action = switch (entry.action) {
    AgendaHistoryAction.canceled => 'Cancelado',
    AgendaHistoryAction.restored => 'Restaurado',
    AgendaHistoryAction.occurrenceEdited => 'Ocorrência editada',
    AgendaHistoryAction.reservationConflictOverridden => 'Conflito de reserva sobrescrito',
  };
  final scope = switch (entry.occurrenceEditScope) {
    AgendaOccurrenceEditScope.occurrence => ' · Somente esta ocorrência',
    AgendaOccurrenceEditScope.thisAndFollowing => ' · Esta e as seguintes',
    AgendaOccurrenceEditScope.series => ' · Série inteira',
    null => '',
  };
  final reason = entry.reason == null ? '' : ' · Motivo: ${entry.reason}';
  return '$action por ${entry.actorName} em ${_dateTime(entry.occurredAt)}$scope$reason';
}

String _mutationFeedback(_AgendaLifecycleAction action, AgendaMutationResult result) {
  if (result == AgendaMutationResult.success) {
    return switch (action) {
      _AgendaLifecycleAction.cancel => 'Evento cancelado e histórico atualizado.',
      _AgendaLifecycleAction.restore => 'Evento restaurado e histórico atualizado.',
      _AgendaLifecycleAction.deleteDraft => 'Rascunho excluído.',
    };
  }
  return switch (result) {
    AgendaMutationResult.notFound => 'O item não foi encontrado. Nenhuma alteração foi aplicada.',
    AgendaMutationResult.invalidLifecycle =>
      'Esta ação não é permitida no status atual. Nenhuma alteração foi aplicada.',
    AgendaMutationResult.notAuthorized =>
      'Você não tem permissão para esta ação. Nenhuma alteração foi aplicada.',
    AgendaMutationResult.reservationConflict =>
      'Há um conflito de horário. Nenhuma alteração foi aplicada.',
    AgendaMutationResult.reasonRequired =>
      'Informe um motivo para continuar. Nenhuma alteração foi aplicada.',
    AgendaMutationResult.success => throw StateError('success handled above'),
  };
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

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
