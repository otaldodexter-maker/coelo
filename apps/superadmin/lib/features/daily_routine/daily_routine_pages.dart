import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/activity/superadmin_activity.dart';
import '../../app/shell/superadmin_shell.dart';
import '../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../auth/domain/logout_action.dart';
import 'daily_routine.dart';
import 'daily_routine_form_sections.dart';
import 'presentation/routine_directory_controller.dart';

enum _RoutineDisplay { cards, table }

enum _RoutineTableView { grouped }

class DailyRoutineDirectoryPage extends StatefulWidget {
  const DailyRoutineDirectoryPage({
    required this.repository,
    required this.logout,
    this.onCreate,
    this.onCreateEntry,
    this.onEdit,
    this.onImport,
    this.onExport,
    this.activityController,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final RoutineRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<RoutineEntryKind>? onCreateEntry;
  final ValueChanged<RoutineDirectoryItem>? onEdit;
  final VoidCallback? onImport;
  final VoidCallback? onExport;
  final SuperadminActivityController? activityController;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<DailyRoutineDirectoryPage> createState() => _DailyRoutineDirectoryPageState();
}

class _DailyRoutineDirectoryPageState extends State<DailyRoutineDirectoryPage> {
  bool get _canManage => _controller.state.page?.canManage ?? _lastCanManage;
  final _search = TextEditingController();
  late RoutineDirectoryController _controller;
  var _lastCanManage = false;
  var _display = _RoutineDisplay.cards;
  var _selectedType = RoutineEntryKind.model;

  @override
  void initState() {
    super.initState();
    _controller = RoutineDirectoryController(widget.repository)..addListener(_refresh);
    _controller.load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    final page = _controller.state.page;
    if (page != null) _lastCanManage = page.canManage;
    if (mounted) setState(() {});
  }

  void updateDirectory(VoidCallback update) {
    setState(update);
    _load();
  }

  void _load({int page = 1}) => _controller.load(
    query: RoutineDirectoryQuery(
      kind: _selectedType,
      search: _search.text.trim(),
      page: page,
      pageSize: _display == _RoutineDisplay.cards ? 11 : 8,
    ),
  );

  void clearFilters() {
    _search.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      currentDestination: 'daily-routine',
      title: 'Rotina diária',
      subtitle: 'Modelos, versões e alcances do registro cotidiano.',
      activityController: widget.activityController,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                ? CoeloSpacing.space10
                : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                ? CoeloSpacing.space6
                : CoeloSpacing.space4;
            final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final state = _controller.state;
            if (state.status == RoutineDirectoryStatus.unauthorized) {
              return ListView(
                key: const Key('daily-routine-content-scroll'),
                padding: EdgeInsets.all(horizontalPadding),
                children: [_content()],
              );
            }
            final page = state.status == RoutineDirectoryStatus.data ? state.page : null;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    key: const Key('daily-routine-content-scroll'),
                    padding: EdgeInsets.all(horizontalPadding),
                    children: [
                      _toolbar(compact, constraints.maxWidth, textScale > 1.3),
                      const SizedBox(height: CoeloSpacing.space4),
                      SuperadminUnderlineTabs<RoutineEntryKind>(
                        key: const Key('daily-routine-type-tabs'),
                        selected: _selectedType,
                        tabs: const [
                          SuperadminUnderlineTab(value: RoutineEntryKind.model, label: 'Modelos'),
                          SuperadminUnderlineTab(
                            value: RoutineEntryKind.application,
                            label: 'Rotinas',
                          ),
                          SuperadminUnderlineTab(
                            value: RoutineEntryKind.launch,
                            label: 'Lancamentos',
                          ),
                        ],
                        onSelected: (value) => updateDirectory(() => _selectedType = value),
                      ),
                      const SizedBox(height: CoeloSpacing.space4),
                      if (state.page != null && !_canManage) ...[
                        const Text('Modo somente leitura'),
                        const SizedBox(height: CoeloSpacing.space4),
                      ],
                      _content(),
                    ],
                  ),
                ),
                if (page != null && _totalPages(page) > 1)
                  _pagination(page, horizontalPadding: horizontalPadding),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _toolbar(bool compact, double availableWidth, bool amplifiedText) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: amplifiedText ? CoeloBreakpoints.compact.maxWidth : double.infinity,
      ),
      child: CoeloAdminListingToolbar(
        search: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: compact ? availableWidth : 280),
          child: CoeloSearchField(
            key: const Key('daily-routine-search'),
            controller: _search,
            semanticLabel: _selectedType == RoutineEntryKind.model
                ? 'Buscar modelos de rotina diária'
                : 'Buscar rotinas diárias',
            hintText: _selectedType == RoutineEntryKind.model ? 'Buscar modelos' : 'Buscar rotinas',
            onChanged: (_) => updateDirectory(() {}),
          ),
        ),
        filters: const [],
        actions: [
          SuperadminDirectoryViewToggle<_RoutineTableView>(
            cardsSelected: _display == _RoutineDisplay.cards,
            groupedView: _RoutineTableView.grouped,
            selectedTableView: _RoutineTableView.grouped,
            tableViews: const [
              SuperadminDirectoryTableViewOption(value: _RoutineTableView.grouped, label: 'Tabela'),
            ],
            cardsKey: const Key('daily-routine-view-cards'),
            tableKey: const Key('daily-routine-view-table'),
            onCardsSelected: () => updateDirectory(() => _display = _RoutineDisplay.cards),
            onTableViewSelected: (_) => updateDirectory(() => _display = _RoutineDisplay.table),
          ),
          if (widget.onImport != null || widget.onExport != null)
            CoeloAdminFileActions(
              compact: compact,
              actions: [
                if (widget.onImport != null)
                  CoeloAdminFileAction(
                    label: 'Importar configuracao',
                    icon: Icons.upload_file_outlined,
                    onPressed: widget.onImport!,
                  ),
                if (widget.onExport != null)
                  CoeloAdminFileAction(
                    label: 'Exportar configuracao',
                    icon: Icons.download_outlined,
                    onPressed: widget.onExport!,
                  ),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _content() {
    final state = _controller.state;
    return switch (state.status) {
      RoutineDirectoryStatus.loading => const CoeloStatePanel(
        key: Key('daily-routine-loading'),
        title: 'Carregando rotina diaria',
        message: 'Aguarde enquanto os dados autorizados sao carregados.',
        loading: true,
      ),
      RoutineDirectoryStatus.empty => _stateWithCreate(
        CoeloStatePanel(
          key: Key(
            _selectedType == RoutineEntryKind.launch
                ? 'daily-routine-launches-empty'
                : 'daily-routine-empty',
          ),
          title: 'Nenhum item criado',
          message: 'Nao ha itens neste escopo.',
          icon: Icons.event_note_outlined,
        ),
      ),
      RoutineDirectoryStatus.noResults => _stateWithCreate(
        CoeloStatePanel(
          key: const Key('daily-routine-no-results'),
          title: 'Nenhum resultado',
          message: 'Ajuste a busca.',
          icon: Icons.search_off_rounded,
          actionLabel: 'Limpar busca',
          onAction: clearFilters,
        ),
      ),
      RoutineDirectoryStatus.unauthorized => const CoeloStatePanel(
        key: Key('daily-routine-unauthorized'),
        title: 'Acesso nao autorizado',
        message: 'Seu acesso a este escopo nao esta disponivel.',
        icon: Icons.lock_outline_rounded,
      ),
      RoutineDirectoryStatus.notFound => const CoeloStatePanel(
        key: Key('daily-routine-not-found'),
        title: 'Conteudo nao encontrado',
        message: 'O recurso solicitado nao esta disponivel.',
        icon: Icons.search_off_rounded,
      ),
      RoutineDirectoryStatus.conflict || RoutineDirectoryStatus.failure => _stateWithCreate(
        CoeloStatePanel(
          key: const Key('daily-routine-error'),
          title: 'Nao foi possivel carregar a rotina diaria',
          message: state.message ?? 'Atualize para tentar novamente.',
          icon: Icons.error_outline_rounded,
          actionLabel: 'Tentar novamente',
          onAction: _load,
        ),
      ),
      RoutineDirectoryStatus.data =>
        _display == _RoutineDisplay.cards ? _cards(state.page!) : _table(state.page!),
    };
  }

  Widget _cards(RoutineDirectoryPage page) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1020
              ? 3
              : constraints.maxWidth >= 680
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
          return Wrap(
            key: const Key('daily-routine-cards'),
            spacing: CoeloSpacing.space6,
            runSpacing: CoeloSpacing.space6,
            children: [
              if (_canCreate)
                SizedBox(
                  width: width,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 216),
                    child: _createAction(key: const Key('daily-routine-create-tile')),
                  ),
                ),
              for (final item in page.items)
                SizedBox(
                  width: width,
                  child: CoeloAdminInteractiveCard(
                    key: Key('daily-routine-card-${item.id}'),
                    semanticLabel: 'Abrir ${item.name}',
                    onPressed: widget.onEdit == null ? null : () => widget.onEdit!(item),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 216),
                      child: Padding(
                        padding: const EdgeInsets.all(CoeloSpacing.space4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: CoeloSpacing.space3),
                            _RoutineStatusIndicator(status: item.status),
                            const SizedBox(height: CoeloSpacing.space2),
                            Text('Versao v${item.version}'),
                            if (item.originLabel != null) Text('Origem: ${item.originLabel}'),
                            if (item.effectiveLabel != null)
                              Text('Efetivo: ${item.effectiveLabel}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _table(RoutineDirectoryPage page) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloAdminResizableTable<RoutineDirectoryItem>(
        key: const Key('daily-routine-table'),
        items: page.items,
        rowKey: (item) => 'daily-routine-row-${item.id}',
        pinnedColumn: CoeloAdminTableColumn(
          id: 'name',
          label: 'Nome',
          initialWidth: 280,
          minWidth: 180,
          maxWidth: 420,
          cellBuilder: (_, item) => Text(item.name),
        ),
        columns: [
          CoeloAdminTableColumn(
            id: 'origin',
            label: 'Origem',
            initialWidth: 180,
            minWidth: 120,
            maxWidth: 260,
            cellBuilder: (_, item) => Text(item.originLabel ?? '-'),
          ),
          CoeloAdminTableColumn(
            id: 'status',
            label: 'Status',
            initialWidth: 140,
            minWidth: 110,
            maxWidth: 200,
            cellBuilder: (_, item) => _RoutineStatusIndicator(status: item.status),
          ),
          CoeloAdminTableColumn(
            id: 'version',
            label: 'Versao',
            initialWidth: 100,
            minWidth: 90,
            maxWidth: 140,
            cellBuilder: (_, item) => Text('v${item.version}'),
          ),
        ],
        headerHeight: 56,
        rowHeight: 64,
        onRowPressed: widget.onEdit == null ? null : (item) => widget.onEdit!(item),
      ),
    ],
  );

  int _totalPages(RoutineDirectoryPage page) =>
      (page.totalCount / page.pageSize).ceil().clamp(1, 999999);

  Widget _pagination(RoutineDirectoryPage page, {required double horizontalPadding}) {
    final totalPages = _totalPages(page);
    return SuperadminListingPaginationFooter(
      semanticKey: const Key('daily-routine-pagination-footer'),
      horizontalPadding: horizontalPadding,
      compactCurrentPage: page.page,
      compactTotalPages: totalPages,
      compactOnPrevious: page.page > 1 ? () => _load(page: page.page - 1) : null,
      compactOnNext: page.page < totalPages ? () => _load(page: page.page + 1) : null,
      child: CoeloAdminPagination(
        key: const Key('daily-routine-pagination'),
        currentPage: page.page,
        totalPages: totalPages,
        onPrevious: page.page > 1 ? () => _load(page: page.page - 1) : null,
        onNext: page.page < totalPages ? () => _load(page: page.page + 1) : null,
        onPageSelected: (value) => _load(page: value),
      ),
    );
  }

  bool get _canCreate =>
      _canManage &&
      _selectedType == RoutineEntryKind.model &&
      (widget.onCreateEntry != null || widget.onCreate != null);

  Widget _stateWithCreate(Widget state) {
    if (!_canCreate) return state;
    final createAction = _createAction(key: const Key('daily-routine-create-state'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_display == _RoutineDisplay.cards)
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, minHeight: 216),
              child: createAction,
            ),
          )
        else
          createAction,
        const SizedBox(height: CoeloSpacing.space4),
        state,
      ],
    );
  }

  Widget _createAction({required Key key}) => CoeloAdminCreateAction(
    key: key,
    label: 'Criar item',
    onPressed: _requestCreate,
    icon: Icons.add_task_rounded,
    variant: _display == _RoutineDisplay.cards
        ? CoeloAdminCreateActionVariant.tile
        : CoeloAdminCreateActionVariant.banner,
  );

  void _requestCreate() {
    final callback = widget.onCreateEntry;
    if (callback != null) {
      callback(_selectedType);
    } else {
      widget.onCreate?.call();
    }
  }
}

final class _RoutineStatusIndicator extends StatelessWidget {
  const _RoutineStatusIndicator({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final normalized = status.trim().toLowerCase();
    final colors = switch (normalized) {
      'active' ||
      'ativo' ||
      'published' ||
      'publicado' => (statusColors.successContainer, statusColors.onSuccessContainer),
      'draft' ||
      'rascunho' ||
      'in_review' ||
      'em revisao' => (statusColors.infoContainer, statusColors.onInfoContainer),
      _ => (theme.colorScheme.surfaceContainerHighest, theme.colorScheme.onSurfaceVariant),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: status,
      semanticLabel: 'Status: $status',
      backgroundColor: colors.$1,
      foregroundColor: colors.$2,
    );
  }
}

class DailyRoutineEditorPage extends StatefulWidget {
  const DailyRoutineEditorPage({
    required this.repository,
    required this.logout,
    this.modelId,
    this.entryType = RoutineEntryKind.model,
    this.activityController,
    super.key,
  });

  final RoutineRepository repository;
  final LogoutAction logout;
  final String? modelId;
  final RoutineEntryKind entryType;
  final SuperadminActivityController? activityController;

  @override
  State<DailyRoutineEditorPage> createState() => _DailyRoutineEditorPageState();
}

class _DailyRoutineEditorPageState extends State<DailyRoutineEditorPage> {
  @override
  Widget build(BuildContext context) => DailyRoutineWizardPage(
    repository: widget.repository,
    logout: widget.logout,
    entryId: widget.modelId,
    entryKind: widget.entryType,
    activityController: widget.activityController,
  );
}
