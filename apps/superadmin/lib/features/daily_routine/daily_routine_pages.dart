import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/shell/superadmin_notice.dart';

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
    this.onDuplicateModel,
    this.onCreateFromModel,
    this.onPublishLaunch,
    this.onCreateLaunch,
    this.onArchive,
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
  final ValueChanged<RoutineDirectoryItem>? onDuplicateModel;
  final ValueChanged<RoutineDirectoryItem>? onCreateFromModel;

  /// D7: Lançamentos no MVP é uma tela mínima sobre o comando
  /// `daily-routine.publish`, que já existe. Publicar não é editar, então a
  /// ação vive aqui, no item, e não dentro do editor.
  final Future<bool> Function(RoutineDirectoryItem item)? onPublishLaunch;

  /// D7: cria o rascunho do lançamento de hoje para uma rotina aplicada; o
  /// servidor recalcula escopo e capacidade (routine.record).
  final Future<bool> Function(RoutineDirectoryItem application)? onCreateLaunch;

  /// V-15: arquivar modelo ou rotina (status archived pelo save existente).
  final Future<bool> Function(RoutineDirectoryItem item)? onArchive;
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

  /// Publicação em voo, por item: o botão do próprio item fica desabilitado
  /// enquanto o comando não volta, para um toque repetido não virar duas
  /// publicações da mesma rotina.
  final _publishing = <String>{};

  @override
  void initState() {
    super.initState();
    _controller = RoutineDirectoryController(widget.repository)..addListener(_refresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant DailyRoutineDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository)) return;
    _controller
      ..removeListener(_refresh)
      ..dispose();
    _search.clear();
    _lastCanManage = false;
    _selectedType = RoutineEntryKind.model;
    _controller = RoutineDirectoryController(widget.repository)..addListener(_refresh);
    _load();
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

  /// D7: publicar um lançamento é o comando `daily-routine.publish`, e nada
  /// mais. Confirma antes porque publicar entrega a rotina às famílias e não
  /// tem desfazer nesta tela; a correção é um comando próprio, com
  /// justificativa. A lista é recarregada do servidor depois, para a tela
  /// mostrar o estado que o servidor confirma e não o que ela supôs.
  Future<void> _publishLaunch(RoutineDirectoryItem item) async {
    final publish = widget.onPublishLaunch;
    if (publish == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        dialogKey: const Key('daily-routine-publish-dialog'),
        title: 'Publicar este lançamento?',
        body: const Text(
          'As famílias autorizadas passam a ver a rotina deste dia. '
          'Depois de publicado, ajustes exigem uma correção com justificativa.',
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          key: const Key('daily-routine-publish-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Publicar'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _publishing.add(item.id));
    try {
      final published = await publish(item);
      if (!mounted) return;
      if (published) _load(page: _controller.state.page?.page ?? 1);
    } finally {
      if (mounted) setState(() => _publishing.remove(item.id));
    }
  }

  Future<void> _archive(RoutineDirectoryItem item) async {
    final archive = widget.onArchive;
    if (archive == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('daily-routine-archive-dialog'),
        title: Text('Arquivar ${item.name}?'),
        content: const Text('O item sai das listas ativas; o histórico é preservado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('daily-routine-archive-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _publishing.add(item.id));
    try {
      final archived = await archive(item);
      if (!mounted) return;
      if (archived) _load(page: _controller.state.page?.page ?? 1);
    } finally {
      if (mounted) setState(() => _publishing.remove(item.id));
    }
  }

  Future<void> _createLaunch(RoutineDirectoryItem application) async {
    final create = widget.onCreateLaunch;
    if (create == null) return;
    setState(() => _publishing.add(application.id));
    try {
      final created = await create(application);
      if (!mounted || !created) return;
      updateDirectory(() => _selectedType = RoutineEntryKind.launch);
    } finally {
      if (mounted) setState(() => _publishing.remove(application.id));
    }
  }

  /// V-15 (Owner, 11/09): o card Criar existe em toda aba. Rotina nasce de um
  /// modelo e lançamento nasce de uma rotina, então o card abre um seletor da
  /// origem e segue pelo mesmo caminho das ações do card.
  Future<void> _pickOriginAndCreate(RoutineEntryKind originKind) async {
    final RoutineDirectoryPage origins;
    try {
      origins = await widget.repository.fetchPage(
        RoutineDirectoryQuery(kind: originKind, pageSize: 50),
      );
    } on RoutineRepositoryException catch (error) {
      if (mounted) showSuperadminNotice(context, error.message, icon: Icons.error_outline_rounded);
      return;
    }
    if (!mounted) return;
    final isModel = originKind == RoutineEntryKind.model;
    final picked = await showDialog<RoutineDirectoryItem>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        key: const Key('daily-routine-origin-picker'),
        title: Text(isModel ? 'Criar rotina a partir de qual modelo?' : 'Lançar qual rotina hoje?'),
        children: [
          if (origins.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Text(
                isModel
                    ? 'Crie um modelo antes de criar uma rotina.'
                    : 'Crie uma rotina antes de lançar.',
              ),
            ),
          for (final item in origins.items)
            SimpleDialogOption(
              key: Key('daily-routine-origin-${item.id}'),
              onPressed: () => Navigator.of(dialogContext).pop(item),
              child: Text(item.name),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    if (isModel) {
      widget.onCreateFromModel?.call(picked);
    } else {
      await _createLaunch(picked);
    }
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
                            label: 'Lançamentos',
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
          CoeloAdminFileActions(
            compact: compact,
            actions: [
              CoeloAdminFileAction(
                key: const Key('daily-routine-files-import'),
                label: 'Importar configuração',
                icon: Icons.upload_file_outlined,
                onPressed: widget.onImport ?? () => _showUnavailable(context),
              ),
              CoeloAdminFileAction(
                key: const Key('daily-routine-files-export'),
                label: 'Exportar configuração',
                icon: Icons.download_outlined,
                onPressed: widget.onExport ?? () => _showUnavailable(context),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _showUnavailable(BuildContext context) {
    showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
  }

  Widget _content() {
    final state = _controller.state;
    return switch (state.status) {
      RoutineDirectoryStatus.loading => const CoeloStatePanel(
        key: Key('daily-routine-loading'),
        title: 'Carregando rotina diária',
        message: 'Aguarde enquanto os dados autorizados são carregados.',
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
          message: 'Não há itens neste escopo.',
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
        title: 'Acesso não autorizado',
        message: 'Seu acesso a este escopo não está disponível.',
        icon: Icons.lock_outline_rounded,
      ),
      RoutineDirectoryStatus.notFound => const CoeloStatePanel(
        key: Key('daily-routine-not-found'),
        title: 'Conteúdo não encontrado',
        message: 'O recurso solicitado não está disponível.',
        icon: Icons.search_off_rounded,
      ),
      RoutineDirectoryStatus.unavailable => _stateWithCreate(
        CoeloStatePanel(
          key: const Key('daily-routine-unavailable'),
          title: 'Rotina diária indisponível',
          message: 'A rotina diária não está disponível neste ambiente.',
          icon: Icons.cloud_off_outlined,
        ),
      ),
      RoutineDirectoryStatus.conflict || RoutineDirectoryStatus.failure => _stateWithCreate(
        CoeloStatePanel(
          key: const Key('daily-routine-error'),
          title: 'Não foi possível carregar a rotina diária',
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
                            Text('Versão v${item.version}'),
                            if (item.originLabel != null) Text('Origem: ${item.originLabel}'),
                            if (item.effectiveLabel != null)
                              Text('Efetivo: ${item.effectiveLabel}'),
                            if (_itemActions(item) case final actions when actions.isNotEmpty) ...[
                              const SizedBox(height: CoeloSpacing.space3),
                              Wrap(
                                spacing: CoeloSpacing.space2,
                                runSpacing: CoeloSpacing.space2,
                                children: actions,
                              ),
                            ],
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
      // V-15: o card Criar aparece também na tabela, mesmo com dados.
      if (_canCreate) ...[
        _createAction(key: const Key('daily-routine-create-banner')),
        const SizedBox(height: CoeloSpacing.space4),
      ],
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
            cellBuilder: (_, item) =>
                _RoutineStatusIndicator(status: item.status, expandable: false),
          ),
          CoeloAdminTableColumn(
            id: 'version',
            label: 'Versão',
            initialWidth: 100,
            minWidth: 90,
            maxWidth: 140,
            cellBuilder: (_, item) => Text('v${item.version}'),
          ),
          // V-15: a tabela oferece as mesmas ações do card.
          if (_canManage)
            CoeloAdminTableColumn(
              id: 'actions',
              label: 'Ações',
              initialWidth: 168,
              minWidth: 150,
              maxWidth: 240,
              cellBuilder: (_, item) =>
                  Row(mainAxisSize: MainAxisSize.min, children: _itemActions(item, tableRow: true)),
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

  /// Ações do item (card e tabela): modelo duplica ou vira rotina; rotina é
  /// lançada hoje; lançamento em rascunho é publicado. Arquivar ainda não
  /// tem comando no servidor e fica registrado como pendência.
  List<Widget> _itemActions(RoutineDirectoryItem item, {bool tableRow = false}) {
    if (!_canManage) return const [];
    final busy = _publishing.contains(item.id);
    Widget action(String id, String label, IconData icon, VoidCallback? onPressed) {
      final key = Key('daily-routine-$id-${item.id}${tableRow ? '-row' : ''}');
      return tableRow
          ? IconButton(key: key, tooltip: label, onPressed: onPressed, icon: Icon(icon))
          : TextButton.icon(key: key, onPressed: onPressed, icon: Icon(icon), label: Text(label));
    }

    return switch (item.kind) {
      RoutineEntryKind.model => [
        if (widget.onDuplicateModel != null)
          action(
            'duplicate',
            'Duplicar modelo',
            Icons.content_copy_rounded,
            () => widget.onDuplicateModel!(item),
          ),
        if (widget.onCreateFromModel != null)
          action(
            'apply',
            'Criar rotina por este modelo',
            Icons.playlist_add_rounded,
            () => widget.onCreateFromModel!(item),
          ),
        if (widget.onArchive != null && item.status != 'archived')
          action('archive', 'Arquivar', Icons.archive_outlined, busy ? null : () => _archive(item)),
      ],
      RoutineEntryKind.application => [
        if (widget.onCreateLaunch != null)
          action(
            'launch',
            busy ? 'Lançando…' : 'Lançar hoje',
            Icons.today_rounded,
            busy ? null : () => _createLaunch(item),
          ),
        if (widget.onArchive != null && item.status != 'archived')
          action('archive', 'Arquivar', Icons.archive_outlined, busy ? null : () => _archive(item)),
      ],
      RoutineEntryKind.launch => [
        if (item.status == 'draft' && widget.onPublishLaunch != null)
          action(
            'publish',
            busy ? 'Publicando…' : 'Publicar lançamento',
            Icons.publish_rounded,
            busy ? null : () => _publishLaunch(item),
          ),
      ],
    };
  }

  bool get _canCreate =>
      _canManage &&
      switch (_selectedType) {
        RoutineEntryKind.model => widget.onCreateEntry != null || widget.onCreate != null,
        RoutineEntryKind.application => widget.onCreateFromModel != null,
        RoutineEntryKind.launch => widget.onCreateLaunch != null,
      };

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
    label: switch (_selectedType) {
      RoutineEntryKind.model => 'Criar modelo',
      RoutineEntryKind.application => 'Criar rotina',
      RoutineEntryKind.launch => 'Criar lançamento',
    },
    onPressed: _requestCreate,
    icon: Icons.add_task_rounded,
    variant: _display == _RoutineDisplay.cards
        ? CoeloAdminCreateActionVariant.tile
        : CoeloAdminCreateActionVariant.banner,
  );

  void _requestCreate() {
    switch (_selectedType) {
      case RoutineEntryKind.model:
        final callback = widget.onCreateEntry;
        if (callback != null) {
          callback(_selectedType);
        } else {
          widget.onCreate?.call();
        }
      case RoutineEntryKind.application:
        _pickOriginAndCreate(RoutineEntryKind.model);
      case RoutineEntryKind.launch:
        _pickOriginAndCreate(RoutineEntryKind.application);
    }
  }
}

final class _RoutineStatusIndicator extends StatelessWidget {
  const _RoutineStatusIndicator({required this.status, this.expandable = true});

  final String status;
  final bool expandable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final normalized = status.trim().toLowerCase();
    final label = routineStatusLabel(status);
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
    if (!expandable) {
      return CoeloStatusChip(label: label, backgroundColor: colors.$1, foregroundColor: colors.$2);
    }
    return CoeloAdminExpandableStatusIndicator(
      label: label,
      semanticLabel: 'Status: $label',
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
    this.duplicateFromModelId,
    this.applicationFromModelId,
    this.activityController,
    this.onDestinationSelected,
    super.key,
  }) : assert(duplicateFromModelId == null || applicationFromModelId == null);

  final RoutineRepository repository;
  final LogoutAction logout;
  final String? modelId;
  final RoutineEntryKind entryType;
  final String? duplicateFromModelId;
  final String? applicationFromModelId;
  final SuperadminActivityController? activityController;
  final ValueChanged<String>? onDestinationSelected;

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
    duplicateFromModelId: widget.duplicateFromModelId,
    applicationFromModelId: widget.applicationFromModelId,
    activityController: widget.activityController,
    onDestinationSelected: widget.onDestinationSelected,
  );
}
