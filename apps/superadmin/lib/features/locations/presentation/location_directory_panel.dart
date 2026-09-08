import 'dart:async';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../domain/location_catalog_reader.dart';
import 'location_directory_controller.dart';
import 'location_read_widgets.dart';

class LocationDirectoryPanel extends StatefulWidget {
  const LocationDirectoryPanel({
    required this.scope,
    required this.onOpen,
    this.reader = const UnavailableLocationCatalogReader(),
    this.sessionAvailable = false,
    this.contextRevision = 0,
    super.key,
  });
  final LocationScope scope;
  final ValueChanged<LocationCatalogEntry> onOpen;
  final LocationCatalogReader reader;
  final bool sessionAvailable;
  final int contextRevision;
  @override
  State<LocationDirectoryPanel> createState() => _LocationDirectoryPanelState();
}

class _LocationDirectoryPanelState extends State<LocationDirectoryPanel> {
  late final LocationDirectoryController _controller;
  final _search = TextEditingController();
  bool _cards = true;
  @override
  void initState() {
    super.initState();
    _controller = LocationDirectoryController(
      scope: widget.scope,
      reader: widget.reader,
      sessionAvailable: widget.sessionAvailable,
      contextRevision: widget.contextRevision,
    );
    unawaited(_controller.load());
  }

  @override
  void didUpdateWidget(covariant LocationDirectoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameLocationScope(oldWidget.scope, widget.scope) ||
        !identical(oldWidget.reader, widget.reader) ||
        oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.contextRevision != widget.contextRevision) {
      _search.clear();
      unawaited(
        _controller.load(
          scope: widget.scope,
          reader: widget.reader,
          sessionAvailable: widget.sessionAvailable,
          contextRevision: widget.contextRevision,
        ),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _view(bool cards) {
    if (_cards == cards) return;
    setState(() => _cards = cards);
    unawaited(_controller.setPageSize(cards ? 11 : 8));
  }

  void _open(LocationCatalogEntry item) {
    if (mounted && widget.sessionAvailable && _controller.data?.items.contains(item) == true) {
      widget.onOpen(item);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final padding = compact ? CoeloSpacing.space4 : CoeloSpacing.space6;
        final data = _controller.data;
        final allowed = widget.sessionAvailable && _controller.state != LocationReadState.denied;
        final previous = data != null && _controller.page > 0
            ? () => unawaited(_controller.goToPage(_controller.page - 1))
            : null;
        final next = data != null && _controller.page + 1 < _controller.totalPages
            ? () => unawaited(_controller.goToPage(_controller.page + 1))
            : null;
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  key: const Key('location-directory-content'),
                  padding: EdgeInsets.all(padding),
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Locais', style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    Text(
                      locationScopeLabel(widget.scope),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    if (allowed) ...[
                      CoeloAdminListingToolbar(
                        search: CoeloSearchField(
                          key: const Key('location-search'),
                          controller: _search,
                          hintText: 'Buscar locais',
                          semanticLabel: 'Buscar locais',
                          onChanged: (value) => unawaited(_controller.setSearch(value)),
                        ),
                        filters: const [],
                        actions: [
                          SuperadminDirectoryViewToggle<bool>(
                            cardsSelected: _cards,
                            groupedView: false,
                            selectedTableView: false,
                            tableViews: const [
                              SuperadminDirectoryTableViewOption(value: false, label: 'Agrupado'),
                            ],
                            onCardsSelected: () => _view(true),
                            onTableViewSelected: (_) => _view(false),
                            cardsKey: const Key('location-view-cards'),
                            tableKey: const Key('location-view-table'),
                          ),
                          CoeloAdminFileActions(
                            key: const Key('location-files'),
                            compact: compact,
                            actions: [
                              for (final (name, label, icon) in [
                                ('import', 'Importar', Icons.upload_file_outlined),
                                ('csv', 'Exportar CSV', Icons.table_rows_outlined),
                                ('xlsx', 'Exportar XLSX', Icons.grid_on_outlined),
                              ])
                                CoeloAdminFileAction(
                                  key: Key('location-files-$name'),
                                  label: label,
                                  icon: icon,
                                  onPressed: () => showSuperadminNotice(
                                    context,
                                    'Disponível depois do MVP',
                                    icon: Icons.info_outline_rounded,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: CoeloSpacing.space4),
                    ],
                    if (data != null) ...[
                      Text(
                        '${data.totalCount} locais',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_controller.windowLimited)
                        const Text('Refine a busca para consultar resultados além desta janela.'),
                      const SizedBox(height: CoeloSpacing.space4),
                    ],
                    if (_controller.state == LocationReadState.ready && data != null)
                      _cards
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                final columns = (constraints.maxWidth / 340).floor().clamp(1, 4);
                                final width =
                                    (constraints.maxWidth - (columns - 1) * CoeloSpacing.space4) /
                                    columns;
                                return Wrap(
                                  spacing: CoeloSpacing.space4,
                                  runSpacing: CoeloSpacing.space4,
                                  children: [
                                    for (final item in data.items)
                                      SizedBox(
                                        width: width,
                                        child: CoeloAdminInteractiveCard(
                                          key: Key('location-card-${item.id}'),
                                          minHeight: 216,
                                          semanticLabel: 'Abrir local ${item.name}',
                                          onPressed: () => _open(item),
                                          child: Padding(
                                            padding: const EdgeInsets.all(CoeloSpacing.space4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: Theme.of(context).textTheme.titleLarge,
                                                ),
                                                const SizedBox(height: CoeloSpacing.space4),
                                                Text(locationKindLabel(item.kind)),
                                                Text('Andar: ${locationOptionalText(item.floor)}'),
                                                Text(
                                                  'Visibilidade: ${locationVisibilityLabel(item.visibility)}',
                                                ),
                                                const SizedBox(height: CoeloSpacing.space4),
                                                locationStatusIndicator(context, item),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            )
                          : CoeloAdminResizableTable<LocationCatalogEntry>(
                              key: const Key('location-table'),
                              items: data.items,
                              rowKey: (item) => item.id,
                              onRowPressed: _open,
                              headerHeight: 56 * MediaQuery.textScalerOf(context).scale(1),
                              rowHeight: 64 * MediaQuery.textScalerOf(context).scale(1),
                              pinnedColumn: _column('name', 'Nome', 220, (item) => item.name),
                              columns: [
                                _column(
                                  'kind',
                                  'Tipo',
                                  190,
                                  (item) => locationKindLabel(item.kind),
                                ),
                                _column(
                                  'floor',
                                  'Andar',
                                  190,
                                  (item) => locationOptionalText(item.floor),
                                ),
                                _column(
                                  'visibility',
                                  'Visibilidade',
                                  190,
                                  (item) => locationVisibilityLabel(item.visibility),
                                ),
                                _column(
                                  'status',
                                  'Status',
                                  150,
                                  (item) => locationStatusLabel(item.status),
                                ),
                              ],
                            )
                    else
                      LocationReadStatePanel(
                        state: _controller.state,
                        prefix: 'location-directory',
                      ),
                    if (_controller.state == LocationReadState.unavailable)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: const Key('location-directory-reload'),
                          onPressed: () => unawaited(_controller.load()),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Recarregar'),
                        ),
                      ),
                  ],
                ),
              ),
              if (data != null && _controller.page < _controller.totalPages)
                SuperadminListingPaginationFooter(
                  horizontalPadding: padding,
                  compactCurrentPage: _controller.page + 1,
                  compactTotalPages: _controller.totalPages,
                  compactOnPrevious: previous,
                  compactOnNext: next,
                  child: CoeloAdminPagination(
                    currentPage: _controller.page + 1,
                    totalPages: _controller.totalPages,
                    onPrevious: previous,
                    onNext: next,
                    onPageSelected: (value) => unawaited(_controller.goToPage(value - 1)),
                    pageSize: _controller.pageSize,
                    pageSizeOptions: _cards ? const [11, 20, 50, 100] : const [8, 20, 50, 100],
                    onPageSizeChanged: (value) => unawaited(_controller.setPageSize(value)),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

CoeloAdminTableColumn<LocationCatalogEntry> _column(
  String id,
  String label,
  double width,
  String Function(LocationCatalogEntry) value,
) => CoeloAdminTableColumn(
  id: id,
  label: label,
  initialWidth: width,
  minWidth: width - 40,
  maxWidth: 600,
  cellBuilder: (context, item) => Align(
    alignment: Alignment.centerLeft,
    child: Text(value(item), maxLines: 2, overflow: TextOverflow.ellipsis),
  ),
);
