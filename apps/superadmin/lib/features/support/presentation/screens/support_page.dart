import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_notice.dart';
import '../../../../app/shell/superadmin_bug_report_dialog.dart';
import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../domain/support_team_member.dart';
import '../../domain/support_ticket.dart';
import '../view_models/support_prototype_controller.dart';
import '../widgets/support_kanban.dart';
import '../widgets/support_ticket_detail.dart';
import '../widgets/support_ticket_filters.dart';
import '../widgets/support_ticket_rows.dart';

final class SupportPage extends StatefulWidget {
  const SupportPage({
    required this.controller,
    required this.logout,
    required this.onInstitutionsOpen,
    required this.onCatalogOpen,
    this.onHomeOpen,
    this.onUnitsOpen,
    this.onConversationsOpen,
    super.key,
  });
  final SupportPrototypeController controller;
  final LogoutAction logout;
  final VoidCallback onInstitutionsOpen;
  final VoidCallback onCatalogOpen;
  final VoidCallback? onHomeOpen;
  final VoidCallback? onUnitsOpen;
  final VoidCallback? onConversationsOpen;
  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final _search = TextEditingController();
  final _readFilterFocusScopeNode = FocusScopeNode(
    debugLabel: 'support-read-filter',
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  final _detailFocusNode = FocusNode(debugLabel: 'support-detail');
  SupportFocusRestoreCallback? _restoreDetailOriginFocus;
  CoeloAdminDirectoryDisplay _display = CoeloAdminDirectoryDisplay.cards;
  int _controllerGeneration = 0;
  DialogRoute<void>? _fullscreenDetailRoute;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_surfaceCommandError);
  }

  /// Falha de resposta/status no repositório produtivo vira aviso na tela em
  /// vez de sumir em silêncio (o controller já recarregou o diretório).
  void _surfaceCommandError() {
    final error = widget.controller.consumeCommandError();
    if (error == null || !mounted) return;
    showSuperadminNotice(context, error, icon: Icons.error_outline_rounded);
  }

  @override
  void didUpdateWidget(covariant SupportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.removeListener(_surfaceCommandError);
      widget.controller.addListener(_surfaceCommandError);
      _controllerGeneration++;
      _restoreDetailOriginFocus = null;
      _search.text = widget.controller.filters.search;
      _invalidateFullscreenDetail();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_surfaceCommandError);
    _controllerGeneration++;
    _invalidateFullscreenDetail();
    _search.dispose();
    _readFilterFocusScopeNode.dispose();
    _detailFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    title: 'Suporte e implantação',
    subtitle: 'Acompanhe os chamados e solicitações da operação.',
    logout: widget.logout,
    currentDestination: 'support',
    chatLauncherBottomInset: MediaQuery.textScalerOf(context).scale(CoeloSpacing.space20),
    onBugReportSubmitted: widget.controller.submitReportToBackend,
    onDestinationSelected: (d) {
      if (d == 'home') widget.onHomeOpen?.call();
      if (d == 'institutions') widget.onInstitutionsOpen();
      if (d == 'units') widget.onUnitsOpen?.call();
      if (d == 'catalog') widget.onCatalogOpen();
      if (d == 'conversations') widget.onConversationsOpen?.call();
    },
    child: AnimatedBuilder(animation: widget.controller, builder: (_, _) => _content(context)),
  );
  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final isMobileOrTabletSurface =
        theme.brightness == Brightness.light &&
        MediaQuery.sizeOf(context).width < CoeloBreakpoints.expanded.minWidth;
    final content = KeyedSubtree(
      key: const Key('support-page-content'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Decisão do Owner (support_detail_light_1024 = R, 10/09/2026): no
          // desktop com menu, a toolbar do composto continua visível e o
          // detalhe ocupa o lugar dos resultados quando o corpo é estreito;
          // sem menu (768/375) o detalhe segue tomando o corpo inteiro (A).
          final stackedDetail =
              widget.controller.selectedTicket != null &&
              MediaQuery.sizeOf(context).width >= CoeloBreakpoints.expanded.minWidth &&
              constraints.maxWidth < CoeloBreakpoints.expanded.minWidth;
          return CoeloAdminWorkspaceLayout(
            toolbar: const SizedBox.shrink(),
            body: _directory(
              context,
              constraints,
              stackedDetail: stackedDetail
                  ? SizedBox(height: _bodyHeight(context, constraints), child: _details())
                  : null,
            ),
            detail: Padding(
              padding: EdgeInsets.all(
                CoeloAdminDirectoryMetrics.horizontalPadding(constraints.maxWidth),
              ),
              child: _details(),
            ),
            detailVisible: widget.controller.selectedTicket != null && !stackedDetail,
          );
        },
      ),
    );
    if (!isMobileOrTabletSurface) {
      return content;
    }
    return ColoredBox(color: theme.colorScheme.surface, child: content);
  }

  /// Diretório de Suporte sobre o composto `CoeloAdminDirectory` (decisão do
  /// Owner de 10/09/2026): a feature entrega busca, filtros, Limpar filtros,
  /// Arquivos, o Criar, as linhas da tabela, o quadro kanban e a paginação;
  /// toolbar, toggle, banner/card Criar, card de estado e rodapé são do
  /// composto e aparecem em todos os estados, inclusive vazio e falha.
  Widget _directory(BuildContext context, BoxConstraints constraints, {Widget? stackedDetail}) {
    final controller = widget.controller;
    final table = _display == CoeloAdminDirectoryDisplay.table;
    final tickets = table ? controller.visibleTickets : controller.filteredTickets;
    // Rota normal contra o repositório produtivo: carga e falha honestas,
    // sem chamados fictícios (regra do MVP, ADR 0034).
    // Sem resultados, o kanban continua montado com colunas vazias honestas
    // (preserva o foco dos cards e a composição aprovada); a tabela usa o
    // card de estado do composto com Limpar filtros.
    final status = switch (controller.loadState) {
      SupportLoadState.failure => CoeloAdminDirectoryStatus.failure,
      SupportLoadState.loading when tickets.isEmpty => CoeloAdminDirectoryStatus.loading,
      _ when controller.tickets.isEmpty => CoeloAdminDirectoryStatus.empty,
      _ when table && tickets.isEmpty => CoeloAdminDirectoryStatus.noResults,
      _ => CoeloAdminDirectoryStatus.success,
    };
    final filters = SupportTicketFilters(
      controller: controller,
      searchController: _search,
      readFilterFocusScopeNode: _readFilterFocusScopeNode,
    );
    return CoeloAdminDirectory<CoeloAdminDirectoryDisplay>(
      key: const Key('support-directory'),
      scrollKey: const Key('support-directory-scroll'),
      toolbarKey: const Key('support-filter-toolbar'),
      filterControlsKey: const Key('support-filter-controls'),
      toggleKey: const Key('support-view-toggle'),
      cardsKey: const Key('support-view-toggle-cards'),
      tableKey: const Key('support-view-toggle-table'),
      loadingKey: const Key('support-state-loading'),
      status: status,
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Ainda não há chamados na operação.',
        emptyIcon: Icons.support_agent_outlined,
        noResults: 'Nenhum chamado corresponde aos filtros aplicados.',
        failure: 'Suporte indisponível',
        failureIcon: Icons.cloud_off_outlined,
        unauthorized: 'Você não tem permissão para consultar os chamados.',
      ),
      errorMessage: switch (controller.loadState) {
        SupportLoadState.failure => 'Não foi possível carregar os chamados. Tente novamente.',
        _ => null,
      },
      onRetry: () => unawaited(controller.loadFromRepository()),
      onClearFilters: filters.clear,
      search: filters.search,
      filters: filters.filters,
      trailing: filters.trailing,
      display: _display,
      onDisplayChanged: (display) => setState(() => _display = display),
      groupedTableView: CoeloAdminDirectoryDisplay.table,
      selectedTableView: CoeloAdminDirectoryDisplay.table,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(
          value: CoeloAdminDirectoryDisplay.table,
          label: 'Tabela',
        ),
      ],
      onTableViewSelected: (_) => setState(() => _display = CoeloAdminDirectoryDisplay.table),
      // Exportação geral adiada (ADR 0034): botão visível e honesto.
      fileActions: [
        CoeloAdminFileAction(
          key: const Key('support-files-export-csv'),
          label: 'Exportar CSV',
          icon: Icons.table_rows_outlined,
          onPressed: () => _showUnavailableExport(context),
        ),
        CoeloAdminFileAction(
          key: const Key('support-files-export-xlsx'),
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: () => _showUnavailableExport(context),
        ),
      ],
      // CRIAR (Owner, 10/09): card na grade dos estados, banner acima da
      // tabela; no kanban o card Criar abre a primeira coluna.
      create: CoeloAdminDirectoryCreate(
        label: 'Criar suporte',
        icon: Icons.add,
        onPressed: _createSupport,
        tileKey: const Key('support-create-state'),
        bannerKey: const Key('support-create-table'),
      ),
      bodyOverride: stackedDetail ?? (table ? null : _kanban(context, constraints, tickets)),
      table: SupportTicketRows(
        tickets: tickets,
        teamMembers: controller.teamMembers,
        selectedTicketId: controller.selectedTicket?.id,
        onTicketPressed: _open,
        statusBuilder: _statusMenu,
        sortColumn: controller.sortColumn,
        sortAscending: controller.sortAscending,
        onSort: controller.setSort,
      ),
      pagination: table && stackedDetail == null
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('support-pagination'),
              currentPage: controller.currentPage.clamp(1, controller.totalPages),
              totalPages: controller.totalPages,
              pageSize: controller.pageSize,
              pageSizeOptions: const [9, 20, 50, 100],
              onPageSizeChanged: controller.setPageSize,
              onPageSelected: controller.setPage,
            )
          : null,
    );
  }

  /// O quadro kanban rola por coluna e precisa de altura limitada dentro da
  /// rolagem do composto: ocupa a viewport menos o recuo e a toolbar
  /// (uma linha em largura média; busca, pares de filtros e ações empilhados
  /// no compacto), nunca abaixo de quatro alvos de toque por coluna.
  double _bodyHeight(BuildContext context, BoxConstraints constraints) {
    final padding = CoeloAdminDirectoryMetrics.horizontalPadding(constraints.maxWidth);
    final control = MediaQuery.textScalerOf(context).scale(CoeloSize.touchMin);
    // Uma linha no desktop largo; três em largura média (busca + Status,
    // Menu + Responsável, Leitura); cinco no compacto.
    final toolbarRows = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
        ? 5
        : constraints.maxWidth < CoeloBreakpoints.expanded.minWidth
        ? 3
        : 1;
    final toolbar = toolbarRows * (control + CoeloSpacing.space2) + CoeloSpacing.space4;
    return math.max(
      CoeloSize.touchMin * 4 + CoeloSpacing.space3 * 4,
      constraints.maxHeight - padding * 2 - toolbar,
    );
  }

  Widget _kanban(BuildContext context, BoxConstraints constraints, List<SupportTicket> tickets) {
    return SizedBox(
      height: _bodyHeight(context, constraints),
      child: SupportKanban(
        tickets: tickets,
        teamMembers: widget.controller.teamMembers,
        selectedTicketId: widget.controller.selectedTicket?.id,
        onTicketPressed: _open,
        onTicketDoublePressed: _openFullscreen,
        onStatusChanged: _requestStatus,
        onAssigneesChanged: (ticket, memberIds) =>
            widget.controller.setAssignees(ticket.id, memberIds),
        onCreate: _createSupport,
      ),
    );
  }

  void _open(SupportTicket ticket, SupportFocusRestoreCallback restoreFocus) {
    _restoreDetailOriginFocus = restoreFocus;
    widget.controller.selectTicket(ticket.id);
    // O painel lateral recebe o foco de fato: a toolbar do composto pode ser
    // reconstruída quando o painel abre (Row -> Column), e o `autofocus` do
    // detalhe é ignorado enquanto um filtro ainda detém o foco.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _fullscreenDetailRoute != null) return;
      if (widget.controller.selectedTicket?.id != ticket.id) return;
      _detailFocusNode.requestFocus();
    });
  }

  Future<void> _openFullscreen(
    SupportTicket ticket,
    SupportFocusRestoreCallback restoreFocus,
  ) async {
    if (_fullscreenDetailRoute != null) return;
    final generation = _controllerGeneration;
    final controller = widget.controller;
    if (!_isCurrentController(generation, controller)) return;
    _restoreDetailOriginFocus = restoreFocus;
    controller.selectTicket(ticket.id);
    bool isCurrent() => _isCurrentController(generation, controller);
    final navigator = Navigator.of(context, rootNavigator: true);
    late final DialogRoute<void> route;
    route = DialogRoute<void>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      animationStyle: MediaQuery.disableAnimationsOf(context) ? AnimationStyle.noAnimation : null,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      barrierDismissible: false,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (_) {
        if (!isCurrent()) return const SizedBox.shrink();
        return _DraggableSupportDialog(
          builder: (onDragUpdate, onMoveRequested, onResetRequested) => AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              if (!isCurrent()) return const SizedBox.shrink();
              return _details(
                compact: true,
                fallbackTicket: ticket,
                boundController: controller,
                boundGeneration: generation,
                onClose: () => route.navigator?.removeRoute(route),
                onHeaderDragUpdate: onDragUpdate,
                onHeaderMoveRequested: onMoveRequested,
                onHeaderResetRequested: onResetRequested,
              );
            },
          ),
        );
      },
    );
    _fullscreenDetailRoute = route;
    try {
      await navigator.push(route);
    } finally {
      if (identical(_fullscreenDetailRoute, route)) {
        _fullscreenDetailRoute = null;
      }
    }
    if (isCurrent()) {
      _closeDetails();
    }
  }

  Widget _details({
    bool compact = false,
    SupportTicket? fallbackTicket,
    SupportPrototypeController? boundController,
    int? boundGeneration,
    VoidCallback? onClose,
    GestureDragUpdateCallback? onHeaderDragUpdate,
    ValueChanged<Offset>? onHeaderMoveRequested,
    VoidCallback? onHeaderResetRequested,
  }) {
    final controller = boundController ?? widget.controller;
    bool isCurrent() =>
        boundController == null || _isCurrentController(boundGeneration!, boundController);
    if (!isCurrent()) return const SizedBox.shrink();
    final ticket = controller.selectedTicket ?? fallbackTicket;
    if (ticket == null) {
      return const CoeloStatePanel(
        title: 'Selecione um chamado',
        message: 'Abra um chamado para ver os detalhes.',
        icon: Icons.support_agent_outlined,
      );
    }
    return SupportTicketDetail(
      ticket: ticket,
      teamMembers: controller.teamMembers,
      statusBuilder: (ticket) =>
          _statusMenu(ticket, boundController: boundController, boundGeneration: boundGeneration),
      onAssigneesChanged: (memberIds) {
        if (isCurrent()) controller.setAssignees(ticket.id, memberIds);
      },
      onExpand: compact
          ? null
          : () => _openFullscreen(ticket, _restoreDetailOriginFocus ?? () => false),
      onSend: (message) {
        if (isCurrent()) controller.sendReply(ticket.id, message);
      },
      onClose: onClose ?? _closeDetails,
      focusNode: compact ? null : _detailFocusNode,
      onHeaderDragUpdate: onHeaderDragUpdate,
      onHeaderMoveRequested: onHeaderMoveRequested,
      onHeaderResetRequested: onHeaderResetRequested,
    );
  }

  void _closeDetails() {
    widget.controller.selectTicket(null);
    final restoreFocus = _restoreDetailOriginFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final restored = restoreFocus?.call() ?? false;
      if (!restored && widget.controller.filters.unreadOnly) {
        _readFilterFocusScopeNode.requestFocus();
        // O gatilho do filtro pode ter sido recriado com a toolbar do
        // composto; sem memória no escopo, avança ao primeiro focável dele.
        if (_readFilterFocusScopeNode.focusedChild == null) {
          _readFilterFocusScopeNode.nextFocus();
        }
      }
    });
  }

  Future<void> _requestStatus(
    SupportTicket ticket,
    SupportTicketStatus status, {
    SupportPrototypeController? boundController,
    int? boundGeneration,
  }) async {
    final generation = boundGeneration ?? _controllerGeneration;
    final controller = boundController ?? widget.controller;
    if (!_isCurrentController(generation, controller)) return;
    if (status == SupportTicketStatus.inProgress && ticket.assigneeIds.isEmpty) {
      final ownerId = await _chooseOwner();
      if (!_isCurrentController(generation, controller) || ownerId == null) {
        return;
      }
      controller.setAssignees(ticket.id, {ownerId});
    }
    if (_isCurrentController(generation, controller)) {
      controller.changeStatus(ticket.id, status);
    }
  }

  bool _isCurrentController(int generation, SupportPrototypeController controller) =>
      mounted && generation == _controllerGeneration && identical(controller, widget.controller);

  Future<void> _createSupport() async {
    final draft = await showSuperadminBugReportDialog(
      context,
      dialogTitle: 'Novo chamado',
      currentScreen: 'Suporte e implantação',
      sections: const {
        'Suporte e implantação': ['Chamados', 'Outro'],
        'Outros': [],
      },
    );
    if (draft == null || !mounted) {
      return;
    }
    widget.controller.submitReport(draft);
    showSuperadminNotice(
      context,
      'Chamado criado com sucesso.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  void _invalidateFullscreenDetail() {
    final route = _fullscreenDetailRoute;
    _fullscreenDetailRoute = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  Future<String?> _chooseOwner() {
    return showDialog<String>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        title: 'Escolha o responsável',
        body: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.controller.teamMembers.length,
            separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space1),
            itemBuilder: (context, index) {
              final member = widget.controller.teamMembers[index];
              return TextButton(
                onPressed: () => Navigator.of(context).pop(member.id),
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(CoeloSize.touchMin)),
                  alignment: Alignment.centerLeft,
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                  ),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
                child: Text(_memberLabel(member)),
              );
            },
          ),
        ),
        primaryAction: FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ),
    );
  }

  void _showUnavailableExport(BuildContext noticeContext) {
    showSuperadminNotice(
      noticeContext,
      'Indisponível nesta etapa',
      icon: Icons.info_outline_rounded,
    );
  }

  Widget _chip(SupportTicketStatus status) {
    final c = Theme.of(context).extension<CoeloStatusColors>()!;
    final colors = switch (status) {
      SupportTicketStatus.newRequest => (c.infoContainer, c.onInfoContainer),
      SupportTicketStatus.inProgress => (c.warningContainer, c.onWarningContainer),
      SupportTicketStatus.waitingRequester => (c.errorContainer, c.onErrorContainer),
      SupportTicketStatus.completed => (c.successContainer, c.onSuccessContainer),
    };
    return CoeloStatusChip(
      label: _statusLabel(status),
      backgroundColor: colors.$1,
      foregroundColor: colors.$2,
    );
  }

  Widget _statusMenu(
    SupportTicket ticket, {
    SupportPrototypeController? boundController,
    int? boundGeneration,
  }) => CoeloAdminFlyout<SupportTicketStatus>(
    itemWidth: 220,
    alignmentOffset: const Offset(0, CoeloSpacing.space1),
    items: [
      for (final status in SupportTicketStatus.values)
        CoeloAdminFlyoutItem(
          value: status,
          label: _statusLabel(status),
          selected: ticket.status == status,
          icon: switch (status) {
            SupportTicketStatus.newRequest => Icons.info_outlined,
            SupportTicketStatus.inProgress => Icons.construction_outlined,
            SupportTicketStatus.waitingRequester => Icons.hourglass_empty_rounded,
            SupportTicketStatus.completed => Icons.check_circle_outline_rounded,
          },
        ),
    ],
    onSelected: (status) => _requestStatus(
      ticket,
      status,
      boundController: boundController,
      boundGeneration: boundGeneration,
    ),
    builder: (_, controller) {
      void open() => controller.isOpen ? controller.close() : controller.open();
      return Semantics(
        key: Key('support-status-${ticket.id}'),
        button: true,
        child: Focus(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(
              onPressed: open,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
                overlayColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
              ),
              child: Tooltip(
                message: 'Alterar status de ${ticket.id}',
                child: _chip(ticket.status),
              ),
            ),
          ),
        ),
      );
    },
  );
}

typedef _DraggableSupportDialogBuilder =
    Widget Function(
      GestureDragUpdateCallback onDragUpdate,
      ValueChanged<Offset> onMoveRequested,
      VoidCallback onResetRequested,
    );

final class _DraggableSupportDialog extends StatefulWidget {
  const _DraggableSupportDialog({required this.builder});

  final _DraggableSupportDialogBuilder builder;

  @override
  State<_DraggableSupportDialog> createState() => _DraggableSupportDialogState();
}

final class _DraggableSupportDialogState extends State<_DraggableSupportDialog> {
  Offset _offset = Offset.zero;
  Rect _movementBounds = Rect.zero;

  Offset _clamp(Offset value) => Offset(
    value.dx.clamp(_movementBounds.left, _movementBounds.right).toDouble(),
    value.dy.clamp(_movementBounds.top, _movementBounds.bottom).toDouble(),
  );

  void _moveBy(Offset delta) {
    setState(() => _offset = _clamp(_offset + delta));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final margin = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth
            ? CoeloSpacing.space20
            : CoeloSpacing.space4;
        final safeWidth = constraints.maxWidth - media.padding.left - media.padding.right;
        final safeHeight = constraints.maxHeight - media.padding.top - media.padding.bottom;
        final availableWidth = (safeWidth - (margin * 2)).clamp(0, double.infinity);
        final availableHeight = (safeHeight - (margin * 2)).clamp(0, double.infinity);
        final panelWidth = availableWidth.clamp(0, CoeloBreakpoints.expanded.maxWidth).toDouble();
        final panelHeight = availableHeight.toDouble();
        final maxDx = ((safeWidth - panelWidth) / 2).clamp(0, double.infinity).toDouble();
        final maxDy = ((safeHeight - panelHeight) / 2).clamp(0, double.infinity).toDouble();
        _movementBounds = Rect.fromLTRB(-maxDx, -maxDy, maxDx, maxDy);
        _offset = _clamp(_offset);

        final initialLeft = media.padding.left + ((safeWidth - panelWidth) / 2);
        final initialTop = media.padding.top + ((safeHeight - panelHeight) / 2);
        return Stack(
          children: [
            Positioned(
              left: initialLeft + _offset.dx,
              top: initialTop + _offset.dy,
              width: panelWidth,
              height: panelHeight,
              child: Material(
                key: const Key('support-expanded-detail'),
                color: colors.surface,
                surfaceTintColor: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: widget.builder(
                  (details) => _moveBy(details.delta),
                  _moveBy,
                  () => setState(() => _offset = Offset.zero),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _statusLabel(SupportTicketStatus s) => switch (s) {
  SupportTicketStatus.newRequest => 'Novo',
  SupportTicketStatus.inProgress => 'Em andamento',
  SupportTicketStatus.waitingRequester => 'Aguardando solicitante',
  SupportTicketStatus.completed => 'Concluído',
};

String _memberLabel(SupportTeamMember member) => '${member.name} · ${_roleLabel(member.role)}';

String _roleLabel(SupportTeamRole role) => switch (role) {
  SupportTeamRole.support => 'Suporte',
  SupportTeamRole.development => 'Desenvolvimento',
  SupportTeamRole.customerSuccess => 'Sucesso do cliente',
  SupportTeamRole.qualityAssurance => 'Qualidade',
};
