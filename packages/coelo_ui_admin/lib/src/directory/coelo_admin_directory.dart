import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../listing/coelo_admin_create_action.dart';
import '../listing/coelo_admin_file_actions.dart';
import '../listing/coelo_admin_listing_toolbar.dart';
import '../listing/coelo_admin_pagination.dart';
import 'coelo_admin_directory_view_toggle.dart';
import 'coelo_admin_pagination_footer.dart';
import 'coelo_admin_underline_tabs.dart';

/// Modo de exibição do diretório administrativo.
enum CoeloAdminDirectoryDisplay { cards, table }

/// Estado de carga do diretório. `success` renderiza cards ou tabela; os
/// demais renderizam o card de estado, sempre precedido do Criar.
enum CoeloAdminDirectoryStatus { loading, failure, unauthorized, empty, noResults, success }

/// Abas de status aprovadas (TABS): Todos / Ativos / Rascunhos / Inativos.
enum CoeloAdminDirectoryStatusTab {
  all('Todos'),
  active('Ativos'),
  draft('Rascunhos'),
  inactive('Inativos');

  const CoeloAdminDirectoryStatusTab(this.label);

  final String label;
}

/// Ação Criar do diretório (CRIAR): card em grade, banner acima da tabela.
@immutable
final class CoeloAdminDirectoryCreate {
  const CoeloAdminDirectoryCreate({
    required this.label,
    required this.onPressed,
    this.description,
    this.icon = Icons.add,
    this.tileKey,
    this.tileSurfaceKey,
    this.bannerKey,
    this.bannerSurfaceKey,
  });

  final String label;

  /// `null` mantém o Criar visível e desabilitado (sem callback autorizado).
  final VoidCallback? onPressed;
  final String? description;
  final IconData icon;
  final Key? tileKey;
  final Key? tileSurfaceKey;
  final Key? bannerKey;
  final Key? bannerSurfaceKey;
}

/// Textos dos estados não vazios do diretório.
@immutable
final class CoeloAdminDirectoryMessages {
  const CoeloAdminDirectoryMessages({
    required this.empty,
    required this.noResults,
    required this.failure,
    required this.unauthorized,
    this.emptyIcon = Icons.inbox_outlined,
    this.noResultsIcon = Icons.search_off_outlined,
    this.failureIcon = Icons.error_outline,
    this.unauthorizedIcon = Icons.lock_outline,
    this.retryLabel = 'Tentar novamente',
  });

  final String empty;
  final String noResults;
  final String failure;
  final String unauthorized;
  final IconData emptyIcon;
  final IconData noResultsIcon;
  final IconData failureIcon;
  final IconData unauthorizedIcon;
  final String retryLabel;
}

/// Paginação do diretório. `currentPage` é 1-based.
@immutable
final class CoeloAdminDirectoryPagination {
  const CoeloAdminDirectoryPagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageSelected,
    this.pageSize,
    this.pageSizeOptions = const [],
    this.onPageSizeChanged,
    this.footerKey,
    this.surfaceKey,
  }) : assert(currentPage >= 1),
       assert(totalPages >= 1),
       assert(pageSize == null || pageSizeOptions.length > 0),
       assert(onPageSizeChanged == null || pageSize != null);

  final int currentPage;
  final int totalPages;

  /// Sem `pageSize` (paginação por cursor) o seletor de itens por página some.
  final int? pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<int>? onPageSizeChanged;
  final Key? footerKey;
  final Key? surfaceKey;

  bool get hasPrevious => currentPage > 1;
  bool get hasNext => currentPage < totalPages;
}

/// Larguras de grade aprovadas em Instituições.
abstract final class CoeloAdminDirectoryMetrics {
  static const cardMinWidth = 340.0;
  static const cardMinHeight = 216.0;
  static const cardGap = CoeloSpacing.space6;
  static const searchWidth = 300.0;
  static const searchWidthNarrow = 216.0;
  static const filterWidth = 160.0;
  static const narrowActionsMaxWidth = 1000.0;

  static double horizontalPadding(double maxWidth) => maxWidth >= CoeloBreakpoints.large.minWidth
      ? CoeloSpacing.space10
      : maxWidth >= CoeloBreakpoints.medium.minWidth
      ? CoeloSpacing.space6
      : CoeloSpacing.space4;

  static int columns(double maxWidth) => math.max(1, (maxWidth / cardMinWidth).floor());

  static double cardWidth(double maxWidth) {
    final count = columns(maxWidth);
    return (maxWidth - (count - 1) * cardGap) / count;
  }
}

/// Abas de status compartilhadas (TABS). Instituições passa abas próprias
/// porque `Em Implantação` é exceção aprovada.
final class CoeloAdminDirectoryStatusTabs extends StatelessWidget {
  const CoeloAdminDirectoryStatusTabs({
    required this.selected,
    required this.onSelected,
    this.tabs = CoeloAdminDirectoryStatusTab.values,
    super.key,
  });

  final CoeloAdminDirectoryStatusTab selected;
  final ValueChanged<CoeloAdminDirectoryStatusTab> onSelected;
  final List<CoeloAdminDirectoryStatusTab> tabs;

  @override
  Widget build(BuildContext context) => CoeloAdminUnderlineTabs<CoeloAdminDirectoryStatusTab>(
    selected: selected,
    tabs: [for (final tab in tabs) CoeloAdminUnderlineTab(value: tab, label: tab.label)],
    onSelected: onSelected,
  );
}

/// Composto único de diretório administrativo (decisão do Owner de
/// 10/09/2026): toolbar com busca, filtros, toggle Cards/Tabela e Arquivos;
/// abas de status; grade com o card Criar primeiro em todos os estados;
/// tabela com o banner Criar acima; rodapé fixo de paginação; larguras
/// 375/768/1024/1440. As features fornecem apenas conteúdo de domínio:
/// campo de busca, filtros, cards, tabela e textos.
final class CoeloAdminDirectory<TView> extends StatefulWidget {
  const CoeloAdminDirectory({
    required this.status,
    required this.messages,
    required this.search,
    required this.display,
    required this.onDisplayChanged,
    required this.groupedTableView,
    required this.selectedTableView,
    required this.tableViews,
    required this.onTableViewSelected,
    this.filters = const [],
    this.trailing = const [],
    this.fileActions,
    this.fileActionsBusyLabel,
    this.leading = const [],
    this.tabs,
    this.beforeResults = const [],
    this.create,
    this.cards = const [],
    this.table,
    this.bodyOverride,
    this.pagination,
    this.errorMessage,
    this.onRetry,
    this.onClearFilters,
    this.refreshing = false,
    this.cardMinHeight = CoeloAdminDirectoryMetrics.cardMinHeight,
    this.onFooterHeightChanged,
    this.scrollKey,
    this.loadingKey,
    this.toolbarKey,
    this.filterControlsKey,
    this.actionsKey,
    this.toggleKey,
    this.cardsKey,
    this.tableKey,
    this.gridKey,
    this.searchWidth,
    super.key,
  });

  final CoeloAdminDirectoryStatus status;
  final CoeloAdminDirectoryMessages messages;

  /// Campo de busca sem largura; o composto aplica 300/216/100 %.
  final Widget search;

  /// Filtros sem largura; o composto aplica 160 px, metade no compacto e
  /// largura total a 200 % de texto.
  final List<Widget> filters;

  /// Controles depois dos filtros, como `Limpar filtros`.
  final List<Widget> trailing;

  /// `null` esconde o botão Arquivos (ARQUIVOS-CHAT: Conversas).
  final List<CoeloAdminFileAction>? fileActions;
  final String? fileActionsBusyLabel;

  /// Conteúdo acima da toolbar, como as abas Modelos/Atividades.
  final List<Widget> leading;

  /// Abas de status abaixo da toolbar (TABS).
  final Widget? tabs;

  /// Avisos ou notas entre as abas e os resultados (aviso de demonstração,
  /// texto de contexto).
  final List<Widget> beforeResults;

  final CoeloAdminDirectoryDisplay display;
  final ValueChanged<CoeloAdminDirectoryDisplay> onDisplayChanged;
  final TView groupedTableView;
  final TView selectedTableView;
  final List<CoeloAdminDirectoryTableViewOption<TView>> tableViews;

  /// Chamado ao escolher uma visão de tabela (inclusive ao clicar no segmento
  /// Tabela). O consumidor muda o display para tabela nesse callback.
  final ValueChanged<TView> onTableViewSelected;

  final CoeloAdminDirectoryCreate? create;

  /// Cards de domínio já construídos; o composto dá largura e o Criar.
  final List<Widget> cards;

  /// Tabela de domínio; o composto coloca o banner Criar acima.
  final Widget? table;

  /// Conteúdo que substitui cards/tabela no estado `success` (resumo
  /// minimizado, por exemplo), mantendo toolbar e abas.
  final Widget? bodyOverride;
  final CoeloAdminDirectoryPagination? pagination;

  /// Linha secundária do card de estado (mensagem do serviço ou orientação),
  /// abaixo do texto principal; omitida quando repete o principal.
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onClearFilters;

  /// Barra linear no topo dos resultados enquanto recarrega com dados.
  final bool refreshing;
  final double cardMinHeight;
  final ValueChanged<double>? onFooterHeightChanged;

  final Key? scrollKey;

  /// Chave do indicador de carregamento inicial.
  final Key? loadingKey;
  final Key? toolbarKey;
  final Key? filterControlsKey;
  final Key? actionsKey;
  final Key? toggleKey;
  final Key? cardsKey;
  final Key? tableKey;
  final Key? gridKey;
  final double? searchWidth;

  @override
  State<CoeloAdminDirectory<TView>> createState() => _CoeloAdminDirectoryState<TView>();
}

final class _CoeloAdminDirectoryState<TView> extends State<CoeloAdminDirectory<TView>> {
  final GlobalKey _footerKey = GlobalKey();
  double _footerHeight = 0;
  bool _measurementScheduled = false;

  bool get _showFooter =>
      widget.status == CoeloAdminDirectoryStatus.success && widget.pagination != null;

  void _scheduleFooterMeasurement(bool visible) {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      var next = 0.0;
      if (visible) {
        final box = _footerKey.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) return;
        next = box.size.height;
      }
      if ((next - _footerHeight).abs() < 0.5) return;
      setState(() => _footerHeight = next);
      widget.onFooterHeightChanged?.call(next);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = CoeloAdminDirectoryMetrics.horizontalPadding(constraints.maxWidth);
      if (widget.status == CoeloAdminDirectoryStatus.unauthorized) {
        _scheduleFooterMeasurement(false);
        return ListView(
          key: widget.scrollKey,
          padding: EdgeInsets.all(padding),
          children: [
            _StateCard(
              icon: widget.messages.unauthorizedIcon,
              message: widget.messages.unauthorized,
              detail: widget.errorMessage,
            ),
          ],
        );
      }
      final showFooter = _showFooter;
      _scheduleFooterMeasurement(showFooter);
      final footerInset = showFooter ? _footerHeight + CoeloSpacing.space4 : 0.0;
      return Stack(
        fit: StackFit.expand,
        children: [
          ListView(
            key: widget.scrollKey,
            padding: EdgeInsets.fromLTRB(padding, padding, padding, padding + footerInset),
            children: [
              for (final item in widget.leading) ...[
                item,
                const SizedBox(height: CoeloSpacing.space4),
              ],
              _Toolbar<TView>(directory: widget),
              if (widget.tabs case final tabs?) ...[
                const SizedBox(height: CoeloSpacing.space4),
                tabs,
              ],
              const SizedBox(height: CoeloSpacing.space4),
              for (final item in widget.beforeResults) ...[
                item,
                const SizedBox(height: CoeloSpacing.space4),
              ],
              _Results<TView>(directory: widget),
            ],
          ),
          if (showFooter)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  _scheduleFooterMeasurement(true);
                  return true;
                },
                child: SizeChangedLayoutNotifier(
                  key: _footerKey,
                  child: _Footer(pagination: widget.pagination!, horizontalPadding: padding),
                ),
              ),
            ),
        ],
      );
    },
  );
}

final class _Toolbar<TView> extends StatelessWidget {
  const _Toolbar({required this.directory});

  final CoeloAdminDirectory<TView> directory;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final narrowActions =
          compact || constraints.maxWidth < CoeloAdminDirectoryMetrics.narrowActionsMaxWidth;
      final searchWidth = compact
          ? constraints.maxWidth
          : directory.searchWidth ??
                (narrowActions
                    ? CoeloAdminDirectoryMetrics.searchWidthNarrow
                    : CoeloAdminDirectoryMetrics.searchWidth);
      final controls = LayoutBuilder(
        builder: (context, filterConstraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(1) >= 2;
          final filterWidth = largeText
              ? filterConstraints.maxWidth
              : compact
              ? math.max(0.0, (filterConstraints.maxWidth - CoeloSpacing.space3) / 2)
              : CoeloAdminDirectoryMetrics.filterWidth;
          return Wrap(
            key: directory.filterControlsKey,
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: searchWidth.clamp(0, filterConstraints.maxWidth),
                height: CoeloSize.touchMin,
                child: directory.search,
              ),
              for (final filter in directory.filters)
                // Um filtro entregue em SizedBox com largura própria (campo de
                // período, por exemplo) mantém sua largura; os demais usam a
                // largura padrão da família.
                if (filter case SizedBox(width: final width?))
                  SizedBox(width: width.clamp(0, filterConstraints.maxWidth), child: filter.child)
                else
                  SizedBox(width: filterWidth, child: filter),
              ...directory.trailing,
            ],
          );
        },
      );
      final fileActions = directory.fileActions;
      final actions = SizedBox(
        key: directory.actionsKey,
        height: CoeloSize.touchMin,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoeloAdminDirectoryViewToggle<TView>(
              key: directory.toggleKey,
              cardsKey: directory.cardsKey,
              tableKey: directory.tableKey,
              cardsSelected: directory.display == CoeloAdminDirectoryDisplay.cards,
              groupedView: directory.groupedTableView,
              selectedTableView: directory.selectedTableView,
              tableViews: directory.tableViews,
              onCardsSelected: () => directory.onDisplayChanged(CoeloAdminDirectoryDisplay.cards),
              // Quem recebe a visão de tabela troca o display para tabela; o
              // composto não dispara duas recargas.
              onTableViewSelected: directory.onTableViewSelected,
            ),
            if (directory.fileActionsBusyLabel case final busy?) ...[
              const SizedBox(width: CoeloSpacing.space2),
              Semantics(
                liveRegion: true,
                child: Text(busy, key: const Key('coelo-admin-directory-files-busy')),
              ),
            ] else if (fileActions != null) ...[
              const SizedBox(width: CoeloSpacing.space2),
              CoeloAdminFileActions(compact: narrowActions, actions: fileActions),
            ],
          ],
        ),
      );
      return CoeloAdminListingToolbar(
        key: directory.toolbarKey,
        search: controls,
        filters: const [],
        actions: [actions],
      );
    },
  );
}

final class _Results<TView> extends StatelessWidget {
  const _Results({required this.directory});

  final CoeloAdminDirectory<TView> directory;

  @override
  Widget build(BuildContext context) {
    final messages = directory.messages;
    final content = switch (directory.status) {
      CoeloAdminDirectoryStatus.loading => Padding(
        key: directory.loadingKey,
        padding: const EdgeInsets.all(CoeloSpacing.space8),
        child: const Center(child: CircularProgressIndicator()),
      ),
      CoeloAdminDirectoryStatus.unauthorized => _StateCard(
        icon: messages.unauthorizedIcon,
        message: messages.unauthorized,
        detail: directory.errorMessage,
      ),
      CoeloAdminDirectoryStatus.failure => _withCreate(
        _StateCard(
          icon: messages.failureIcon,
          message: messages.failure,
          detail: directory.errorMessage,
          actionLabel: directory.onRetry == null ? null : messages.retryLabel,
          onAction: directory.onRetry,
          actionKey: const Key('coelo-admin-directory-retry'),
        ),
      ),
      CoeloAdminDirectoryStatus.empty => _withCreate(
        _StateCard(
          icon: messages.emptyIcon,
          message: messages.empty,
          detail: directory.errorMessage,
        ),
      ),
      CoeloAdminDirectoryStatus.noResults => _withCreate(
        _StateCard(
          icon: messages.noResultsIcon,
          message: messages.noResults,
          detail: directory.errorMessage,
          actionLabel: directory.onClearFilters == null ? null : 'Limpar filtros',
          onAction: directory.onClearFilters,
          actionKey: const Key('coelo-admin-directory-clear-filters'),
        ),
      ),
      CoeloAdminDirectoryStatus.success => _success(),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (directory.refreshing) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        content,
      ],
    );
  }

  Widget _success() {
    if (directory.bodyOverride case final body?) return body;
    if (directory.display == CoeloAdminDirectoryDisplay.cards) {
      return _CardGrid(
        gridKey: directory.gridKey,
        create: directory.create,
        cards: directory.cards,
        cardMinHeight: directory.cardMinHeight,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (directory.create case final create?) ...[
          _CreateBanner(create: create),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        directory.table ?? const SizedBox.shrink(),
      ],
    );
  }

  /// CRIAR: o Criar existe também no vazio, sem resultados e na falha.
  Widget _withCreate(Widget stateContent) {
    final create = directory.create;
    if (create == null) return stateContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (directory.display == CoeloAdminDirectoryDisplay.cards)
          _CardGrid(
            gridKey: directory.gridKey,
            create: create,
            cards: const [],
            cardMinHeight: directory.cardMinHeight,
          )
        else
          _CreateBanner(create: create),
        const SizedBox(height: CoeloSpacing.space4),
        stateContent,
      ],
    );
  }
}

final class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.gridKey,
    required this.create,
    required this.cards,
    required this.cardMinHeight,
  });

  final Key? gridKey;
  final CoeloAdminDirectoryCreate? create;
  final List<Widget> cards;
  final double cardMinHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = CoeloAdminDirectoryMetrics.columns(constraints.maxWidth);
      final children = <Widget>[
        if (create case final create?)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: cardMinHeight),
            child: KeyedSubtree(
              key: create.tileSurfaceKey,
              child: CoeloAdminCreateAction(
                key: create.tileKey,
                label: create.label,
                icon: create.icon,
                onPressed: create.onPressed,
              ),
            ),
          ),
        for (final card in cards)
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: cardMinHeight),
            child: card,
          ),
      ];
      // Cards da mesma linha têm a mesma altura, como na referência de
      // Instituições. Table com alinhamento intrinsicHeight mede os filhos por
      // layout real, o que funciona com cards que usam LayoutBuilder
      // (IntrinsicHeight não suporta esses filhos).
      final width = CoeloAdminDirectoryMetrics.cardWidth(constraints.maxWidth);
      return Column(
        key: gridKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var start = 0; start < children.length; start += columns) ...[
            if (start > 0) const SizedBox(height: CoeloAdminDirectoryMetrics.cardGap),
            Table(
              defaultColumnWidth: FixedColumnWidth(width),
              defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
              columnWidths: {
                for (var gap = 1; gap < columns * 2 - 1; gap += 2)
                  gap: const FixedColumnWidth(CoeloAdminDirectoryMetrics.cardGap),
              },
              children: [
                TableRow(
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox.shrink(),
                      start + column < children.length
                          ? _RowStretch(child: children[start + column])
                          : const SizedBox.shrink(),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

/// Estica o card até a altura da linha sem impor altura máxima: o conteúdo
/// que cresce um fio (hover do indicador de status) não estoura o layout.
final class _RowStretch extends StatelessWidget {
  const _RowStretch({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.hasBoundedHeight
        ? OverflowBox(
            alignment: Alignment.topLeft,
            minHeight: constraints.maxHeight,
            maxHeight: double.infinity,
            child: child,
          )
        : child,
  );
}

final class _CreateBanner extends StatelessWidget {
  const _CreateBanner({required this.create});

  final CoeloAdminDirectoryCreate create;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: create.bannerKey,
    child: KeyedSubtree(
      key: create.bannerSurfaceKey,
      // O banner da tabela usa o "+" neutro da referência de Instituições; o
      // ícone de domínio fica no card da grade.
      child: CoeloAdminCreateAction(
        label: create.label,
        description: create.description,
        variant: CoeloAdminCreateActionVariant.banner,
        onPressed: create.onPressed,
      ),
    ),
  );
}

final class _Footer extends StatelessWidget {
  const _Footer({required this.pagination, required this.horizontalPadding});

  final CoeloAdminDirectoryPagination pagination;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) => CoeloAdminPaginationFooter(
    semanticKey: pagination.footerKey,
    horizontalPadding: horizontalPadding,
    compactCurrentPage: pagination.currentPage,
    compactTotalPages: pagination.totalPages,
    compactOnPrevious: pagination.hasPrevious
        ? () => pagination.onPageSelected(pagination.currentPage - 1)
        : null,
    compactOnNext: pagination.hasNext
        ? () => pagination.onPageSelected(pagination.currentPage + 1)
        : null,
    // Sem surfaceKey o rodape recebe a paginacao diretamente, para que quem
    // inspeciona `child` encontre o `CoeloAdminPagination`.
    child: _maybeKeyed(
      pagination.surfaceKey,
      CoeloAdminPagination(
        currentPage: pagination.currentPage,
        totalPages: pagination.totalPages,
        pageSize: pagination.pageSize,
        pageSizeOptions: pagination.pageSizeOptions,
        onPageSelected: pagination.onPageSelected,
        onPageSizeChanged: pagination.onPageSizeChanged,
        onPrevious: pagination.hasPrevious
            ? () => pagination.onPageSelected(pagination.currentPage - 1)
            : null,
        onNext: pagination.hasNext
            ? () => pagination.onPageSelected(pagination.currentPage + 1)
            : null,
      ),
    ),
  );

  static Widget _maybeKeyed(Key? key, Widget child) =>
      key == null ? child : KeyedSubtree(key: key, child: child);
}

/// Card de estado aprovado em Instituições (vazio, sem resultados, falha e
/// não autorizado).
final class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.message,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  });

  final IconData icon;
  final String message;

  /// Linha secundária (mensagem do serviço); omitida quando repete a principal.
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: CoeloSize.iconLg),
            const SizedBox(height: CoeloSpacing.space3),
            Text(message, textAlign: TextAlign.center),
            if (detail case final detail? when detail != message) ...[
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: CoeloSpacing.space3),
              OutlinedButton(key: actionKey, onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}
