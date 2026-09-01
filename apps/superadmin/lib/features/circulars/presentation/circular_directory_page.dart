import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
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
      final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : compact
          ? CoeloSpacing.space4
          : CoeloSpacing.space6;
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
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                key: const Key('circular-directory-content-inset'),
                padding: EdgeInsets.fromLTRB(inset, inset, inset, showPagination ? 0 : inset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _toolbar(compact),
                    const SizedBox(height: CoeloSpacing.space4),
                    SuperadminUnderlineTabs<_CircularDirectoryTab>(
                      tabs: [
                        for (final tab in _CircularDirectoryTab.values)
                          SuperadminUnderlineTab(value: tab, label: tab.label),
                      ],
                      selected: _tab,
                      onSelected: (tab) => setState(() {
                        _tab = tab;
                        _page = 1;
                      }),
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    Expanded(
                      child: _body(compact: compact, items: visible, filtered: filtered),
                    ),
                  ],
                ),
              ),
            ),
            if (showPagination)
              SuperadminListingPaginationFooter(
                horizontalPadding: inset,
                semanticKey: const Key('circular-directory-pagination'),
                child: CoeloAdminPagination(
                  currentPage: safePage,
                  totalPages: pageCount,
                  pageSize: pageSize,
                  pageSizeOptions: compact ? const [11, 20, 50, 100] : const [8, 20, 50, 100],
                  onPrevious: safePage > 1 ? () => setState(() => _page--) : null,
                  onNext: safePage < pageCount ? () => setState(() => _page++) : null,
                  onPageSelected: (page) => setState(() => _page = page),
                  onPageSizeChanged: (size) => setState(() {
                    _pageSizeOverride = size;
                    _page = 1;
                  }),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _toolbar(bool compact) {
    final contexts = {'Todos', ...widget.items.map((item) => item.contextLabel)}.toList();
    return CoeloAdminListingToolbar(
      search: SizedBox(
        width: compact ? double.infinity : CoeloSpacing.space20 * 4,
        height: CoeloSize.touchMin,
        child: CoeloSearchField(
          controller: _search,
          hintText: 'Buscar circular',
          semanticLabel: 'Buscar Circular por título, conteúdo ou autoria',
          onChanged: (_) => setState(() => _page = 1),
        ),
      ),
      filters: [
        SizedBox(
          width: compact ? double.infinity : 240,
          child: CoeloAdminSingleSelectField<String>(
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
      actions: [
        CoeloAdminFileActions(
          compact: compact,
          actions: [
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
          ],
        ),
      ],
    );
  }

  void _showFileActionUnavailable(String action) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$action de Circulares ainda não está disponível.')));
  }

  Widget _body({
    required bool compact,
    required List<CircularDirectoryItem> items,
    required List<CircularDirectoryItem> filtered,
  }) => switch (widget.viewState) {
    CircularDirectoryViewState.loading => const CoeloStatePanel(
      title: 'Carregando Circulares',
      message: 'Aguarde enquanto as Circulares são carregadas.',
      loading: true,
    ),
    CircularDirectoryViewState.error => CoeloStatePanel(
      title: 'Não foi possível carregar',
      message: 'Não foi possível carregar as Circulares.',
      actionLabel: widget.onRetry == null ? null : 'Tentar novamente',
      onAction: widget.onRetry,
    ),
    CircularDirectoryViewState.forbidden => const SizedBox.shrink(),
    CircularDirectoryViewState.content when filtered.isEmpty => _empty(compact),
    CircularDirectoryViewState.content => compact ? _cards(items) : _table(items),
  };

  Widget _empty(bool compact) {
    final queried =
        _search.text.trim().isNotEmpty || _tab != _CircularDirectoryTab.all || _context != 'Todos';
    final state = CoeloStatePanel(
      title: queried ? 'Nenhum resultado' : 'Nenhuma Circular',
      message: queried
          ? 'Nenhuma Circular corresponde aos filtros aplicados.'
          : 'Ainda não existem Circulares neste contexto.',
      icon: queried ? Icons.search_off_rounded : Icons.description_outlined,
    );
    final children = [if (widget.onCreate != null) _createCard(), state];
    return ListView.separated(
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space6),
      itemBuilder: (_, index) => children[index],
    );
  }

  Widget _cards(List<CircularDirectoryItem> items) => ListView.separated(
    key: const Key('circular-directory-card-list'),
    itemCount: items.length + (widget.onCreate == null ? 0 : 1),
    separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space6),
    itemBuilder: (context, index) {
      if (widget.onCreate != null && index == 0) return _createCard();
      final item = items[index - (widget.onCreate == null ? 0 : 1)];
      return CoeloAdminInteractiveCard(
        semanticLabel: 'Abrir Circular ${item.title}',
        onPressed: () => widget.onOpen(item.id),
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
    },
  );

  Widget _createCard() => ConstrainedBox(
    key: const Key('create-circular-card'),
    constraints: const BoxConstraints(minHeight: 216),
    child: CoeloAdminCreateAction(
      label: 'Nova circular',
      description: 'Criar uma Circular privada para o público autorizado.',
      icon: Icons.note_add_outlined,
      onPressed: widget.onCreate,
    ),
  );

  Widget _table(List<CircularDirectoryItem> items) => Column(
    children: [
      if (widget.onCreate != null) ...[
        CoeloAdminCreateAction(
          key: const Key('create-circular-banner'),
          label: 'Nova circular',
          description: 'Criar uma Circular privada para o público autorizado.',
          icon: Icons.note_add_outlined,
          variant: CoeloAdminCreateActionVariant.banner,
          onPressed: widget.onCreate,
        ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      Expanded(
        child: SingleChildScrollView(
          child: CoeloAdminResizableTable<CircularDirectoryItem>(
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
            onRowPressed: (item) => widget.onOpen(item.id),
          ),
        ),
      ),
    ],
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
