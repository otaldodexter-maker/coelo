import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../principal_circulars/domain/circular.dart';

enum CircularDirectoryViewState { content, loading, error, forbidden }

enum _CircularDirectoryTab { all, drafts, scheduled, published, closed }

extension on _CircularDirectoryTab {
  String get label => switch (this) {
    _CircularDirectoryTab.all => 'Todas',
    _CircularDirectoryTab.drafts => 'Rascunhos',
    _CircularDirectoryTab.scheduled => 'Agendadas',
    _CircularDirectoryTab.published => 'Publicadas',
    _CircularDirectoryTab.closed => 'Encerradas',
  };

  CircularStatus? get status => switch (this) {
    _CircularDirectoryTab.all => null,
    _CircularDirectoryTab.drafts => CircularStatus.draft,
    _CircularDirectoryTab.scheduled => CircularStatus.scheduled,
    _CircularDirectoryTab.published => CircularStatus.published,
    _CircularDirectoryTab.closed => CircularStatus.closed,
  };
}

@immutable
final class CircularDirectoryItem {
  const CircularDirectoryItem({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.authorName,
    required this.contextLabel,
    required this.status,
    required this.effectiveAt,
    required this.attachmentCount,
    required this.questionCount,
    required this.responseCount,
  });

  final String id;
  final String title;
  final String excerpt;
  final String authorName;
  final String contextLabel;
  final CircularStatus status;
  final DateTime effectiveAt;
  final int attachmentCount;
  final int questionCount;
  final int responseCount;
}

final class CircularDirectoryPage extends StatefulWidget {
  const CircularDirectoryPage({
    required this.items,
    required this.onOpen,
    this.onCreate,
    this.onImport,
    this.onExport,
    this.onRetry,
    this.viewState = CircularDirectoryViewState.content,
    super.key,
  });

  final List<CircularDirectoryItem> items;
  final ValueChanged<String> onOpen;
  final VoidCallback? onCreate;
  final VoidCallback? onImport;
  final VoidCallback? onExport;
  final VoidCallback? onRetry;
  final CircularDirectoryViewState viewState;

  @override
  State<CircularDirectoryPage> createState() => _CircularDirectoryPageState();
}

final class _CircularDirectoryPageState extends State<CircularDirectoryPage> {
  final _search = TextEditingController();
  _CircularDirectoryTab _tab = _CircularDirectoryTab.all;

  /// Sem escolha do usuario, compacto abre em cards e tablet/desktop em tabela.
  CoeloAdminDirectoryDisplay? _displayOverride;
  String _context = 'Todos';
  var _page = 1;
  int? _pageSizeOverride;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final pageSize = _pageSizeOverride ?? (compact ? 11 : 8);
      if (widget.viewState == CircularDirectoryViewState.forbidden) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: const Padding(
            padding: EdgeInsets.all(CoeloSpacing.space6),
            child: CoeloStatePanel(
              title: 'Sem permissão',
              message: 'Você não tem permissão para consultar Circulares.',
              icon: Icons.lock_outline_rounded,
            ),
          ),
        );
      }
      final filtered = _filteredItems();
      final pageCount = (filtered.length / pageSize).ceil().clamp(1, 9999);
      final safePage = _page.clamp(1, pageCount);
      final start = (safePage - 1) * pageSize;
      final visible = filtered.skip(start).take(pageSize).toList(growable: false);
      final showPagination =
          widget.viewState == CircularDirectoryViewState.content && filtered.isNotEmpty;
      final queried =
          _search.text.trim().isNotEmpty ||
          _tab != _CircularDirectoryTab.all ||
          _context != 'Todos';
      final contexts = {'Todos', ...widget.items.map((item) => item.contextLabel)}.toList();
      final display =
          _displayOverride ??
          (compact ? CoeloAdminDirectoryDisplay.cards : CoeloAdminDirectoryDisplay.table);
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: CoeloAdminDirectory<CoeloAdminDirectoryDisplay>(
          key: const Key('circular-directory-content-inset'),
          gridKey: const Key('circular-directory-card-list'),
          status: switch (widget.viewState) {
            CircularDirectoryViewState.loading => CoeloAdminDirectoryStatus.loading,
            CircularDirectoryViewState.error => CoeloAdminDirectoryStatus.failure,
            CircularDirectoryViewState.forbidden => CoeloAdminDirectoryStatus.unauthorized,
            CircularDirectoryViewState.content when filtered.isEmpty =>
              queried ? CoeloAdminDirectoryStatus.noResults : CoeloAdminDirectoryStatus.empty,
            CircularDirectoryViewState.content => CoeloAdminDirectoryStatus.success,
          },
          messages: const CoeloAdminDirectoryMessages(
            empty: 'Nenhuma Circular',
            emptyIcon: Icons.description_outlined,
            noResults: 'Nenhum resultado',
            noResultsIcon: Icons.search_off_rounded,
            failure: 'Não foi possível carregar',
            unauthorized: 'Sem permissão',
          ),
          errorMessage: switch (widget.viewState) {
            CircularDirectoryViewState.error => 'Não foi possível carregar as Circulares.',
            CircularDirectoryViewState.content when filtered.isEmpty =>
              queried
                  ? 'Nenhuma Circular corresponde aos filtros aplicados.'
                  : 'Ainda não existem Circulares neste contexto.',
            _ => null,
          },
          onRetry: widget.onRetry,
          onClearFilters: queried
              ? () => setState(() {
                  _search.clear();
                  _tab = _CircularDirectoryTab.all;
                  _context = 'Todos';
                  _page = 1;
                })
              : null,
          search: CoeloSearchField(
            controller: _search,
            hintText: 'Buscar circular',
            semanticLabel: 'Buscar Circular por título, conteúdo ou autoria',
            onChanged: (_) => setState(() => _page = 1),
          ),
          filters: [
            SizedBox(
              width: 240,
              child: CoeloAdminSingleSelectField<String>(
                isFilter: true,
                unselectedValue: 'Todos',
                value: _context,
                label: 'Contexto',
                options: contexts,
                optionLabel: (value) => value,
                prefixIcon: Icons.apartment_outlined,
                onChanged: (value) => setState(() {
                  _context = value;
                  _page = 1;
                }),
              ),
            ),
          ],
          display: display,
          onDisplayChanged: (value) => setState(() => _displayOverride = value),
          groupedTableView: CoeloAdminDirectoryDisplay.table,
          selectedTableView: CoeloAdminDirectoryDisplay.table,
          tableViews: const [
            CoeloAdminDirectoryTableViewOption(
              value: CoeloAdminDirectoryDisplay.table,
              label: 'Tabela',
            ),
          ],
          onTableViewSelected: (_) =>
              setState(() => _displayOverride = CoeloAdminDirectoryDisplay.table),
          fileActions: _fileActions(),
          tabs: CoeloAdminUnderlineTabs<_CircularDirectoryTab>(
            tabs: [
              for (final tab in _CircularDirectoryTab.values)
                CoeloAdminUnderlineTab(value: tab, label: tab.label),
            ],
            selected: _tab,
            onSelected: (tab) => setState(() {
              _tab = tab;
              _page = 1;
            }),
          ),
          create: widget.onCreate == null
              ? null
              : CoeloAdminDirectoryCreate(
                  label: 'Nova circular',
                  description: 'Criar uma Circular privada para o público autorizado.',
                  icon: Icons.note_add_outlined,
                  onPressed: widget.onCreate!,
                  tileKey: const Key('create-circular-card'),
                  bannerKey: const Key('create-circular-banner'),
                ),
          cards: [for (final item in visible) _CircularCard(item: item, onOpen: widget.onOpen)],
          table: _CircularTableRows(items: visible, onOpen: widget.onOpen),
          pagination: showPagination
              ? CoeloAdminDirectoryPagination(
                  footerKey: const Key('circular-directory-pagination'),
                  currentPage: safePage,
                  totalPages: pageCount,
                  pageSize: pageSize,
                  pageSizeOptions: compact ? const [11, 20, 50, 100] : const [8, 20, 50, 100],
                  onPageSelected: (page) => setState(() => _page = page),
                  onPageSizeChanged: (size) => setState(() {
                    _pageSizeOverride = size;
                    _page = 1;
                  }),
                )
              : null,
        ),
      );
    },
  );

  List<CoeloAdminFileAction> _fileActions() => [
    CoeloAdminFileAction(
      label: 'Importar circulares',
      icon: Icons.upload_file_outlined,
      onPressed: widget.onImport ?? () => _showFileActionUnavailable('Importação'),
    ),
    CoeloAdminFileAction(
      label: 'Exportar circulares',
      icon: Icons.download_outlined,
      onPressed: widget.onExport ?? () => _showFileActionUnavailable('Exportação'),
    ),
  ];

  void _showFileActionUnavailable(String action) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$action de Circulares ainda não está disponível.')));
  }

  List<CircularDirectoryItem> _filteredItems() {
    final query = _search.text.trim().toLowerCase();
    return widget.items
        .where((item) {
          if (_tab.status case final status? when item.status != status) return false;
          if (_context != 'Todos' && item.contextLabel != _context) return false;
          if (query.isEmpty) return true;
          return '${item.title} ${item.excerpt} ${item.authorName} ${item.contextLabel}'
              .toLowerCase()
              .contains(query);
        })
        .toList(growable: false);
  }
}

/// Card de domínio de uma Circular; largura, grade e o Criar vêm do composto.
final class _CircularCard extends StatelessWidget {
  const _CircularCard({required this.item, required this.onOpen});

  final CircularDirectoryItem item;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    semanticLabel: 'Abrir Circular ${item.title}',
    onPressed: () => onOpen(item.id),
    minHeight: CoeloAdminDirectoryMetrics.cardMinHeight,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _status(context, item.status),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text(item.excerpt, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: CoeloSpacing.space3),
          Text('${item.contextLabel} · ${item.authorName}'),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            '${item.attachmentCount} anexos · ${item.questionCount} perguntas · ${item.responseCount} respostas',
          ),
        ],
      ),
    ),
  );
}

/// Linhas e colunas de domínio das Circulares sobre a tabela compartilhada.
final class _CircularTableRows extends StatelessWidget {
  const _CircularTableRows({required this.items, required this.onOpen});

  final List<CircularDirectoryItem> items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<CircularDirectoryItem>(
    items: items,
    rowKey: (item) => 'circular-row-${item.id}',
    pinnedColumn: CoeloAdminTableColumn(
      id: 'title',
      label: 'Circular',
      initialWidth: 300,
      minWidth: 240,
      maxWidth: 420,
      cellBuilder: (context, item) => Semantics(
        label: '${item.title}. ${item.excerpt}',
        excludeSemantics: true,
        child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ),
    columns: [
      _textColumn('context', 'Público e contexto', 210, (item) => item.contextLabel),
      _textColumn('author', 'Autoria', 170, (item) => item.authorName),
      _textColumn('date', 'Publicação', 150, (item) => _date(item.effectiveAt)),
      _textColumn(
        'content',
        'Conteúdo',
        160,
        (item) => '${item.attachmentCount} anexos · ${item.questionCount} perguntas',
      ),
      _textColumn('responses', 'Respostas', 120, (item) => '${item.responseCount}'),
      CoeloAdminTableColumn(
        id: 'status',
        label: 'Status',
        initialWidth: 150,
        minWidth: 130,
        maxWidth: 180,
        cellBuilder: (context, item) =>
            Align(alignment: Alignment.centerLeft, child: _status(context, item.status)),
      ),
    ],
    headerHeight: 56,
    rowHeight: 64,
    onRowPressed: (item) => onOpen(item.id),
  );

  CoeloAdminTableColumn<CircularDirectoryItem> _textColumn(
    String id,
    String label,
    double width,
    String Function(CircularDirectoryItem) value,
  ) => CoeloAdminTableColumn(
    id: id,
    label: label,
    initialWidth: width,
    minWidth: width - 30,
    maxWidth: width + 100,
    cellBuilder: (_, item) => Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

Widget _status(BuildContext context, CircularStatus status) {
  final colors = Theme.of(context).colorScheme;
  final statusColors = Theme.of(context).extension<CoeloStatusColors>();
  final (label, background, foreground) = switch (status) {
    CircularStatus.draft => ('Rascunho', colors.surfaceContainerHighest, colors.onSurface),
    CircularStatus.scheduled => (
      'Agendada',
      colors.secondaryContainer,
      colors.onSecondaryContainer,
    ),
    CircularStatus.published => (
      'Publicada',
      statusColors?.successContainer ?? colors.primaryContainer,
      statusColors?.onSuccessContainer ?? colors.onPrimaryContainer,
    ),
    CircularStatus.closed => ('Encerrada', colors.tertiaryContainer, colors.onTertiaryContainer),
    CircularStatus.archived => ('Arquivada', colors.errorContainer, colors.onErrorContainer),
  };
  return CoeloStatusChip(label: label, backgroundColor: background, foregroundColor: foreground);
}

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}
