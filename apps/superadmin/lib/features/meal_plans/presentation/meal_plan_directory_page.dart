import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../domain/meal_plan_repository.dart';

enum _MealPlanDirectoryDisplay { cards, table }

enum _MealPlanDirectorySection { mealPlans, models }

enum _DirectoryAction { edit, duplicate, publish, review, remove }

bool _mealPlanCanPublish(MealPlan item) =>
    !item.conflictState &&
    (item.status == MealPlanStatus.inReview || item.status == MealPlanStatus.updated);

final class MealPlanDirectoryPage extends StatefulWidget {
  const MealPlanDirectoryPage({
    required this.repository,
    this.onCreate,
    this.onEdit,
    this.onCreateTemplate,
    this.onEditTemplate,
    super.key,
  });

  final MealPlanRepository repository;
  final ValueChanged<String?>? onCreate;
  final ValueChanged<String>? onEdit;
  final VoidCallback? onCreateTemplate;
  final ValueChanged<String>? onEditTemplate;

  @override
  State<MealPlanDirectoryPage> createState() => _MealPlanDirectoryPageState();
}

final class _MealPlanDirectoryPageState extends State<MealPlanDirectoryPage> {
  final _search = TextEditingController();
  final _institution = TextEditingController();
  final _unit = TextEditingController();
  final _classId = TextEditingController();
  final _personId = TextEditingController();
  final _periodStart = TextEditingController();
  final _periodEnd = TextEditingController();

  _MealPlanDirectoryDisplay _display = _MealPlanDirectoryDisplay.cards;
  _MealPlanDirectorySection _section = _MealPlanDirectorySection.mealPlans;
  bool _loading = true;
  bool _unauthorized = false;
  bool _actionRunning = false;
  String? _errorMessage;
  int _page = 0;
  int _pageSize = 11;
  int _total = 0;
  int _requestedVersion = 1;
  int _actionGeneration = 0;

  MealPlanStatus? _statusFilter;
  MealPlanSourceType? _sourceFilter;
  bool? _hasConflictFilter;
  bool? _requiresReviewFilter;

  List<MealPlan> _items = const [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant MealPlanDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository)) return;
    _requestedVersion += 1;
    _actionGeneration += 1;
    _search.clear();
    _institution.clear();
    _unit.clear();
    _classId.clear();
    _personId.clear();
    _periodStart.clear();
    _periodEnd.clear();
    setState(() {
      _display = _MealPlanDirectoryDisplay.cards;
      _section = _MealPlanDirectorySection.mealPlans;
      _loading = true;
      _unauthorized = false;
      _actionRunning = false;
      _errorMessage = null;
      _page = 0;
      _pageSize = 11;
      _total = 0;
      _statusFilter = null;
      _sourceFilter = null;
      _hasConflictFilter = null;
      _requiresReviewFilter = null;
      _items = const [];
    });
    _load(reset: true);
  }

  @override
  void dispose() {
    _requestedVersion += 1;
    _actionGeneration += 1;
    _search.dispose();
    _institution.dispose();
    _unit.dispose();
    _classId.dispose();
    _personId.dispose();
    _periodStart.dispose();
    _periodEnd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final horizontalPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : compact
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        if (_unauthorized) {
          return ListView(
            padding: EdgeInsets.all(horizontalPadding),
            children: const [
              CoeloStatePanel(
                key: Key('meal-plans-unauthorized'),
                title: 'Acesso não autorizado',
                message: 'Seu acesso a este escopo não está disponível.',
                icon: Icons.lock_outline_rounded,
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  horizontalPadding,
                  horizontalPadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _toolbar(compact: compact),
                    const SizedBox(height: CoeloSpacing.space4),
                    SuperadminUnderlineTabs<_MealPlanDirectorySection>(
                      key: const Key('meal-plan-type-tabs'),
                      selected: _section,
                      tabs: const [
                        SuperadminUnderlineTab(
                          value: _MealPlanDirectorySection.mealPlans,
                          label: 'Cardápios',
                        ),
                        SuperadminUnderlineTab(
                          value: _MealPlanDirectorySection.models,
                          label: 'Modelos',
                        ),
                      ],
                      onSelected: _selectSection,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) =>
                            _content(constraints: contentConstraints),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_totalPages >= 1 && _items.isNotEmpty)
              SuperadminListingPaginationFooter(
                semanticKey: const Key('meal-plans-pagination'),
                horizontalPadding: horizontalPadding,
                child: CoeloAdminPagination(
                  currentPage: _page + 1,
                  totalPages: _totalPages,
                  pageSize: _pageSize,
                  pageSizeOptions: _display == _MealPlanDirectoryDisplay.cards
                      ? const [11, 20, 50, 100]
                      : const [8, 20, 50, 100],
                  onPrevious: _page == 0 ? null : () => _setPage(_page - 1),
                  onNext: _page + 1 < _totalPages ? () => _setPage(_page + 1) : null,
                  onPageSelected: (value) => _setPage(value - 1),
                  onPageSizeChanged: _setPageSize,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _toolbar({required bool compact}) => CoeloAdminListingToolbar(
    search: SizedBox(
      width: compact ? double.infinity : 360,
      height: CoeloSize.touchMin,
      child: CoeloSearchField(
        controller: _search,
        hintText: 'Buscar card\u00e1pio',
        semanticLabel: 'Buscar por nome ou origem',
        onChanged: (_) => _debouncedLoad(),
      ),
    ),
    filters: [
      SizedBox(
        width: compact ? double.infinity : 200,
        child: CoeloAdminSingleSelectField<MealPlanStatus?>(
          value: _statusFilter,
          label: 'Status',
          options: const [null, ...MealPlanStatus.values],
          optionLabel: (value) => switch (value) {
            null => 'Todos',
            MealPlanStatus.draft => 'Rascunho',
            MealPlanStatus.inReview => 'Em revis\u00e3o',
            MealPlanStatus.scheduled => 'Agendado',
            MealPlanStatus.published => 'Publicado',
            MealPlanStatus.updated => 'Atualizado',
            MealPlanStatus.ended => 'Encerrado',
            MealPlanStatus.archived => 'Arquivado',
          },
          onChanged: (value) => setState(() {
            _statusFilter = value;
            _load(reset: true);
          }),
          prefixIcon: Icons.rule_folder_outlined,
        ),
      ),
      SizedBox(
        width: compact ? double.infinity : 200,
        child: CoeloAdminSingleSelectField<MealPlanSourceType?>(
          value: _sourceFilter,
          label: 'Origem',
          options: const [null, ...MealPlanSourceType.values],
          optionLabel: (value) => value == null ? 'Todos' : _sourceLabel(value),
          onChanged: (value) => setState(() {
            _sourceFilter = value;
            _load(reset: true);
          }),
          prefixIcon: Icons.source_outlined,
        ),
      ),
      SizedBox(
        width: compact ? double.infinity : 170,
        child: CoeloAdminSingleSelectField<bool?>(
          value: _hasConflictFilter,
          label: 'Conflito',
          options: const [null, true, false],
          optionLabel: (value) => value == null
              ? 'Todos'
              : value
              ? 'Com conflito'
              : 'Sem conflito',
          onChanged: (value) => setState(() {
            _hasConflictFilter = value;
            _load(reset: true);
          }),
          prefixIcon: Icons.warning_amber_rounded,
        ),
      ),
      SizedBox(
        width: compact ? double.infinity : 200,
        child: CoeloAdminSingleSelectField<bool?>(
          value: _requiresReviewFilter,
          label: 'Revis\u00e3o',
          options: const [null, true, false],
          optionLabel: (value) => value == null
              ? 'Todos'
              : value
              ? 'Requer revis\u00e3o'
              : 'Sem revis\u00e3o pendente',
          onChanged: (value) => setState(() {
            _requiresReviewFilter = value;
            _load(reset: true);
          }),
          prefixIcon: Icons.checklist_rtl,
        ),
      ),
    ],
    actions: [
      SuperadminDirectoryViewToggle<_MealPlanDirectoryDisplay>(
        cardsKey: const Key('meal-plan-directory-view-cards'),
        tableKey: const Key('meal-plan-directory-view-table'),
        cardsSelected: _display == _MealPlanDirectoryDisplay.cards,
        groupedView: _MealPlanDirectoryDisplay.table,
        selectedTableView: _MealPlanDirectoryDisplay.table,
        tableViews: const [
          SuperadminDirectoryTableViewOption(
            value: _MealPlanDirectoryDisplay.table,
            label: 'Agrupado',
          ),
        ],
        onCardsSelected: () => _setDisplay(_MealPlanDirectoryDisplay.cards),
        onTableViewSelected: (_) => _setDisplay(_MealPlanDirectoryDisplay.table),
      ),
    ],
  );

  Widget _content({required BoxConstraints constraints}) => switch (_loading) {
    true => const CoeloStatePanel(
      key: Key('meal-plans-loading'),
      title: 'Carregando card\u00e1pios',
      message: 'Sincronizando card\u00e1pios, status e revis\u00e3o.',
      loading: true,
    ),
    false when _errorMessage != null => _stateWithCreate(
      state: CoeloStatePanel(
        title: 'N\u00e3o foi poss\u00edvel carregar',
        message: _errorMessage!,
        actionLabel: 'Tentar novamente',
        onAction: _loadFromState,
      ),
    ),
    false when _items.isEmpty && !_hasAnyFilter => _stateWithCreate(
      state: const CoeloStatePanel(
        title: 'Nenhum card\u00e1pio',
        message: 'Ainda n\u00e3o h\u00e1 card\u00e1pios cadastrados.',
        icon: Icons.restaurant_menu,
      ),
    ),
    false when _items.isEmpty => _stateWithCreate(
      state: const CoeloStatePanel(
        title: 'Sem resultado',
        message: 'Ajuste os filtros para encontrar card\u00e1pios.',
        icon: Icons.search_off_rounded,
      ),
    ),
    _ =>
      _display == _MealPlanDirectoryDisplay.cards
          ? _cards(constraints: constraints)
          : _table(constraints: constraints),
  };

  Widget _stateWithCreate({required Widget state}) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: math.min(constraints.maxWidth, 420),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 216),
              child: _createAction(),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        state,
      ],
    ),
  );

  Widget _createAction() {
    final models = _section == _MealPlanDirectorySection.models;
    final compactLargeText =
        MediaQuery.sizeOf(context).width < CoeloBreakpoints.medium.minWidth &&
        MediaQuery.textScalerOf(context).scale(1) >= 2;
    return CoeloAdminCreateAction(
      label: models ? 'Criar modelo de cardápio' : 'Criar cardápio',
      description: compactLargeText
          ? null
          : models
          ? 'Monte uma base reutilizável simples ou completa.'
          : 'Defina modelo-base, período, público e refeições.',
      icon: models ? Icons.collections_bookmark_rounded : Icons.restaurant_menu_rounded,
      variant: _display == _MealPlanDirectoryDisplay.table
          ? CoeloAdminCreateActionVariant.banner
          : CoeloAdminCreateActionVariant.tile,
      onPressed: models
          ? widget.onCreateTemplate
          : widget.onCreate == null
          ? null
          : () => widget.onCreate!(null),
    );
  }

  Widget _cards({required BoxConstraints constraints}) {
    final columns = constraints.maxWidth >= 1020
        ? 3
        : constraints.maxWidth >= 680
        ? 2
        : 1;
    final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
      child: Wrap(
        key: const Key('meal-plan-directory-card-grid'),
        spacing: CoeloSpacing.space6,
        runSpacing: CoeloSpacing.space6,
        children: [
          SizedBox(
            width: width,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 216),
              child: _createAction(),
            ),
          ),
          for (final item in _items)
            SizedBox(
              width: width,
              child: _MealPlanCard(
                item: item,
                scopeLabel: _scopeLabel(item.scopeLevel, item.scopeId),
                sourceLabel: _sourceLabel(item.sourceType),
                onOpen: _canEdit(item) ? () => _runAction(_DirectoryAction.edit, item) : null,
                canDuplicate: widget.onCreate != null,
                onAction: (action) => _runAction(action, item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _table({required BoxConstraints constraints}) => SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _createAction(),
        const SizedBox(height: CoeloSpacing.space4),
        SizedBox(
          height: math.max(160, constraints.maxHeight - CoeloSpacing.space24),
          child: CoeloAdminResizableTable<MealPlan>(
            items: _items,
            rowKey: (meal) => meal.id,
            headerHeight: 56,
            rowHeight: MediaQuery.textScalerOf(context).scale(1) >= 1.75 ? 88 : 66,
            pinnedColumn: CoeloAdminTableColumn(
              id: 'name',
              label: _section == _MealPlanDirectorySection.models ? 'Modelo' : 'Card\u00e1pio',
              initialWidth: 260,
              minWidth: 200,
              maxWidth: 360,
              cellBuilder: (_, item) =>
                  Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            columns: [
              CoeloAdminTableColumn(
                id: 'scope',
                label: 'Abrang\u00eancia',
                initialWidth: 220,
                minWidth: 160,
                maxWidth: 320,
                cellBuilder: (_, item) => Text(_scopeLabel(item.scopeLevel, item.scopeId)),
              ),
              CoeloAdminTableColumn(
                id: 'status',
                label: 'Status',
                initialWidth: 180,
                minWidth: 140,
                maxWidth: 220,
                cellBuilder: (_, item) => _MealPlanStatusChip(status: item.status),
              ),
              CoeloAdminTableColumn(
                id: 'period',
                label: 'Per\u00edodo',
                initialWidth: 220,
                minWidth: 180,
                maxWidth: 280,
                cellBuilder: (_, item) => Text(
                  '${_dateLabel(item.startDate)} a ${_dateLabel(item.endDate)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CoeloAdminTableColumn(
                id: 'origin',
                label: 'Origem',
                initialWidth: 150,
                minWidth: 120,
                maxWidth: 200,
                cellBuilder: (_, item) => Text(_sourceLabel(item.sourceType)),
              ),
              CoeloAdminTableColumn(
                id: 'conflict',
                label: 'Conflito',
                initialWidth: 120,
                minWidth: 110,
                maxWidth: 160,
                cellBuilder: (_, item) => Text(
                  item.conflictState ? 'Com conflito' : 'Sem conflito',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              CoeloAdminTableColumn(
                id: 'actions',
                label: '',
                initialWidth: 120,
                minWidth: 100,
                maxWidth: 140,
                cellBuilder: (_, item) => _rowActionMenu(item),
              ),
            ],
            onRowPressed: _canEditSection ? _openItem : null,
          ),
        ),
      ],
    ),
  );

  Widget _rowActionMenu(MealPlan item) {
    final items = <CoeloAdminFlyoutItem<_DirectoryAction>>[
      if (_canEdit(item))
        const CoeloAdminFlyoutItem(
          value: _DirectoryAction.edit,
          icon: Icons.edit_outlined,
          label: 'Editar',
        ),
      if (widget.onCreate != null)
        CoeloAdminFlyoutItem(
          value: _DirectoryAction.duplicate,
          icon: Icons.copy_all_outlined,
          label: item.isTemplate ? 'Duplicar modelo' : 'Duplicar card\u00e1pio',
        ),
      if (item.status == MealPlanStatus.draft)
        const CoeloAdminFlyoutItem(
          value: _DirectoryAction.review,
          icon: Icons.rule_folder_outlined,
          label: 'Enviar revis\u00e3o',
        ),
      if (_canPublish(item))
        const CoeloAdminFlyoutItem(
          value: _DirectoryAction.publish,
          icon: Icons.publish_outlined,
          label: 'Publicar',
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return CoeloAdminFlyout<_DirectoryAction>(
      items: items,
      onSelected: (action) => _runAction(action, item),
      builder: (context, controller) => IconButton(
        tooltip: 'A\u00e7\u00f5es',
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz_rounded),
      ),
    );
  }

  Future<void> _runAction(_DirectoryAction action, MealPlan item) => switch (action) {
    _DirectoryAction.edit => _goEdit(item.id),
    _DirectoryAction.duplicate => _duplicate(item),
    _DirectoryAction.review => _requestReview(item),
    _DirectoryAction.publish => _publish(item),
    _DirectoryAction.remove => _remove(item),
  };

  Future<void> _goEdit(String id) async {
    if (_section == _MealPlanDirectorySection.models) {
      widget.onEditTemplate?.call(id);
    } else {
      widget.onEdit?.call(id);
    }
  }

  bool get _canEditSection => _section == _MealPlanDirectorySection.models
      ? widget.onEditTemplate != null
      : widget.onEdit != null;

  bool _canEdit(MealPlan item) =>
      item.isTemplate ? widget.onEditTemplate != null : widget.onEdit != null;

  void _openItem(MealPlan item) {
    if (item.isTemplate) {
      widget.onEditTemplate?.call(item.id);
    } else {
      widget.onEdit?.call(item.id);
    }
  }

  Future<void> _duplicate(MealPlan item) async {
    widget.onCreate?.call(item.id);
  }

  Future<void> _requestReview(MealPlan item) async {
    await _runActionWithFeedback(
      action: (repository) => repository.submitForReview(item.id, _requestId(), item.revision),
      successMessage: 'Revis\u00e3o solicitada com sucesso.',
      refresh: true,
    );
  }

  Future<void> _publish(MealPlan item) async {
    await _runActionWithFeedback(
      preflight: (repository) async {
        final conflicts = await _resolveLocalConflicts(repository, item);
        return conflicts.isEmpty;
      },
      preflightFailureMessage:
          'N\u00e3o \u00e9 poss\u00edvel publicar com conflito n\u00e3o resolvido.',
      action: (repository) => repository.publish(item.id, _requestId(), item.revision),
      successMessage: 'Card\u00e1pio publicado.',
      refresh: true,
    );
  }

  Future<List<MealPlanConflict>> _resolveLocalConflicts(
    MealPlanRepository repository,
    MealPlan item,
  ) async {
    return repository.checkConflicts(
      scopeLevel: item.scopeLevel.name,
      scopeId: item.scopeId,
      startDate: item.startDate,
      endDate: item.endDate,
      recurrence: item.recurrence,
      menu: item.menu,
    );
  }

  Future<void> _remove(MealPlan item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        title: 'Remover card\u00e1pio',
        onClose: () => Navigator.pop(dialogContext, false),
        body: Text(
          'A exclus\u00e3o de card\u00e1pio n\u00e3o est\u00e1 dispon\u00edvel nesta vers\u00e3o.\n'
          'Abra uma solicita\u00e7\u00e3o de bloqueio e revis\u00e3o para revisar essa a\u00e7\u00e3o.',
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Fechar'),
        ),
        primaryAction: TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Confirmar'),
        ),
      ),
    );
    if (shouldDelete != true) return;
    _feedback('A a\u00e7\u00e3o ainda n\u00e3o foi implementada no backend.');
  }

  Future<void> _runActionWithFeedback({
    Future<bool> Function(MealPlanRepository repository)? preflight,
    String? preflightFailureMessage,
    required Future<MealPlan> Function(MealPlanRepository repository) action,
    required String successMessage,
    required bool refresh,
  }) async {
    if (_actionRunning) return;
    final repository = widget.repository;
    final generation = ++_actionGeneration;
    setState(() => _actionRunning = true);
    try {
      final canContinue = await preflight?.call(repository) ?? true;
      if (!_isCurrentAction(generation, repository)) return;
      if (!canContinue) {
        if (preflightFailureMessage != null) _feedback(preflightFailureMessage);
        return;
      }
      await action(repository);
      if (!_isCurrentAction(generation, repository)) return;
      _feedback(successMessage);
      if (refresh) {
        await _load(reset: true);
      }
    } on MealPlanRepositoryException catch (error) {
      if (!_isCurrentAction(generation, repository)) return;
      _feedback(error.message);
    } finally {
      if (_isCurrentAction(generation, repository)) {
        setState(() => _actionRunning = false);
      }
    }
  }

  bool _isCurrentAction(int generation, MealPlanRepository repository) =>
      mounted && generation == _actionGeneration && identical(repository, widget.repository);

  bool _canPublish(MealPlan item) => _mealPlanCanPublish(item);

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    if (reset) {
      _page = 0;
    }
    final requestVersion = ++_requestedVersion;
    final repository = widget.repository;
    setState(() => _loading = true);
    final filter = _query;
    try {
      final page = _section == _MealPlanDirectorySection.models
          ? await repository.fetchTemplatePage(filter)
          : await repository.fetchPage(filter);
      if (!_isCurrentLoad(requestVersion, repository)) return;
      setState(() {
        _items = page.items;
        _total = page.total;
        _errorMessage = null;
        _unauthorized = false;
        _loading = false;
      });
    } on MealPlanUnauthorizedException {
      if (!_isCurrentLoad(requestVersion, repository)) return;
      setState(() {
        _items = const [];
        _total = 0;
        _errorMessage = null;
        _unauthorized = true;
        _loading = false;
      });
    } on MealPlanRepositoryException catch (error) {
      if (!_isCurrentLoad(requestVersion, repository)) return;
      setState(() {
        _items = const [];
        _errorMessage = error.message;
        _unauthorized = false;
        _loading = false;
      });
    }
  }

  bool _isCurrentLoad(int requestVersion, MealPlanRepository repository) =>
      mounted && requestVersion == _requestedVersion && identical(repository, widget.repository);

  Future<void> _loadFromState() => _load(reset: true);

  void _setPage(int value) {
    if (value < 0) return;
    setState(() => _page = value);
    _load();
  }

  void _setPageSize(int value) {
    setState(() {
      _pageSize = value;
      _page = 0;
    });
    _load();
  }

  void _setDisplay(_MealPlanDirectoryDisplay display) {
    if (_display == display) return;
    setState(() {
      _display = display;
      _pageSize = display == _MealPlanDirectoryDisplay.cards ? 11 : 8;
      _page = 0;
    });
    _load(reset: true);
  }

  void _debouncedLoad() => _load(reset: true);

  void _selectSection(_MealPlanDirectorySection value) {
    _search.clear();
    setState(() {
      _section = value;
      _page = 0;
      _statusFilter = null;
      _sourceFilter = null;
      _hasConflictFilter = null;
      _requiresReviewFilter = null;
    });
    _load(reset: true);
  }

  int get _totalPages {
    if (_total <= 0) return 1;
    return math.max(1, (_total / _pageSize).ceil());
  }

  bool get _hasAnyFilter =>
      _statusFilter != null ||
      _sourceFilter != null ||
      _hasConflictFilter != null ||
      _requiresReviewFilter != null ||
      _institution.text.trim().isNotEmpty ||
      _unit.text.trim().isNotEmpty ||
      _classId.text.trim().isNotEmpty ||
      _personId.text.trim().isNotEmpty ||
      _periodStart.text.trim().isNotEmpty ||
      _periodEnd.text.trim().isNotEmpty ||
      _search.text.trim().isNotEmpty;

  MealPlanListFilter get _query {
    final startDate = _parseDate(_periodStart.text);
    final endDate = _parseDate(_periodEnd.text);
    return MealPlanListFilter(
      search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      institutionId: _institution.text.trim().isEmpty ? null : _institution.text.trim(),
      unitId: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      classId: _classId.text.trim().isEmpty ? null : _classId.text.trim(),
      personId: _personId.text.trim().isEmpty ? null : _personId.text.trim(),
      periodStart: startDate,
      periodEnd: endDate,
      statuses: _statusFilter == null ? const {} : {_statusFilter!},
      sources: _section == _MealPlanDirectorySection.models
          ? const {MealPlanSourceType.global}
          : _sourceFilter == null
          ? const {
              MealPlanSourceType.institution,
              MealPlanSourceType.unit,
              MealPlanSourceType.classLevel,
              MealPlanSourceType.person,
              MealPlanSourceType.exception,
            }
          : {_sourceFilter!},
      hasConflict: _hasConflictFilter,
      requiresReview: _requiresReviewFilter,
      page: _page,
      pageSize: _pageSize,
    );
  }

  DateTime? _parseDate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    try {
      return DateTime(year, month, day);
    } on FormatException {
      return null;
    }
  }

  String _sourceLabel(MealPlanSourceType value) => switch (value) {
    MealPlanSourceType.global => 'Modelo global',
    MealPlanSourceType.institution => 'Institui\u00e7\u00e3o',
    MealPlanSourceType.unit => 'Unidade',
    MealPlanSourceType.classLevel => 'Turma',
    MealPlanSourceType.person => 'Aluno',
    MealPlanSourceType.exception => 'Exce\u00e7\u00e3o',
  };

  String _scopeLabel(MealPlanScopeLevel value, String _) => switch (value) {
    MealPlanScopeLevel.global => 'Global',
    MealPlanScopeLevel.institution => 'Institui\u00e7\u00e3o',
    MealPlanScopeLevel.unit => 'Unidade',
    MealPlanScopeLevel.classLevel => 'Turma',
    MealPlanScopeLevel.activity => 'Atividade',
    MealPlanScopeLevel.person => 'Pessoa',
  };

  String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _requestId() {
    final random = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(32, '0');
    return '${random.substring(0, 8)}-${random.substring(8, 12)}-${random.substring(12, 16)}-'
        '${random.substring(16, 20)}-${random.substring(20, 32)}';
  }

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _MealPlanCard extends StatelessWidget {
  const _MealPlanCard({
    required this.item,
    required this.scopeLabel,
    required this.sourceLabel,
    required this.onOpen,
    required this.canDuplicate,
    required this.onAction,
  });

  final MealPlan item;
  final String scopeLabel;
  final String sourceLabel;
  final VoidCallback? onOpen;
  final bool canDuplicate;
  final ValueChanged<_DirectoryAction> onAction;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    key: Key('meal-plan-card-${item.id}'),
    surfaceKey: Key('meal-plan-card-surface-${item.id}'),
    onPressed: onOpen,
    minHeight: 216,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space6,
        vertical: CoeloSpacing.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              _MealPlanStatusIndicator(item: item),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(
            'Abrang\u00eancia: $scopeLabel',
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            'Per\u00edodo: ${_dateLabel(item.startDate)} a ${_dateLabel(item.endDate)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: CoeloSpacing.space1),
          Text('Origem: $sourceLabel', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            item.conflictState ? 'Com conflito pendente' : 'Sem conflito pendente',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Revis\u00e3o: ${item.requiresReview ? 'Pendente' : 'OK'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (onOpen != null ||
                  canDuplicate ||
                  item.status == MealPlanStatus.draft ||
                  _mealPlanCanPublish(item))
                CoeloAdminFlyout<_DirectoryAction>(
                  items: [
                    if (onOpen != null)
                      const CoeloAdminFlyoutItem(
                        value: _DirectoryAction.edit,
                        label: 'Editar',
                        icon: Icons.edit_outlined,
                      ),
                    if (canDuplicate)
                      CoeloAdminFlyoutItem(
                        value: _DirectoryAction.duplicate,
                        label: item.isTemplate ? 'Duplicar modelo' : 'Duplicar card\u00e1pio',
                        icon: Icons.copy_all_outlined,
                      ),
                    if (item.status == MealPlanStatus.draft)
                      const CoeloAdminFlyoutItem(
                        value: _DirectoryAction.review,
                        label: 'Enviar revis\u00e3o',
                        icon: Icons.rate_review_outlined,
                      ),
                    if (_mealPlanCanPublish(item))
                      const CoeloAdminFlyoutItem(
                        value: _DirectoryAction.publish,
                        label: 'Publicar',
                        icon: Icons.publish_outlined,
                      ),
                  ],
                  onSelected: onAction,
                  builder: (context, controller) => IconButton(
                    tooltip: 'A\u00e7\u00f5es',
                    onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  static String _dateLabel(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}

final class _MealPlanStatusChip extends StatelessWidget {
  const _MealPlanStatusChip({required this.status});

  final MealPlanStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _statusColors(context, status);
    return CoeloStatusChip(
      label: _mealPlanStatusLabel(status),
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }
}

final class _MealPlanStatusIndicator extends StatelessWidget {
  const _MealPlanStatusIndicator({required this.item});

  final MealPlan item;

  @override
  Widget build(BuildContext context) {
    final label = _mealPlanStatusLabel(item.status);
    final (background, foreground) = _statusColors(context, item.status);
    return CoeloAdminExpandableStatusIndicator(
      label: label,
      semanticLabel: 'Status: $label',
      surfaceKey: Key('meal-plan-card-status-${item.id}'),
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }
}

(Color, Color) _statusColors(BuildContext context, MealPlanStatus status) {
  final colors =
      Theme.of(context).extension<CoeloStatusColors>() ??
      (Theme.brightnessOf(context) == Brightness.dark
          ? CoeloStatusColors.dark
          : CoeloStatusColors.light);
  return switch (status) {
    MealPlanStatus.draft => (colors.historyContainer, colors.onHistoryContainer),
    MealPlanStatus.inReview => (colors.warningContainer, colors.onWarningContainer),
    MealPlanStatus.scheduled => (colors.warningContainer, colors.onWarningContainer),
    MealPlanStatus.published => (colors.successContainer, colors.onSuccessContainer),
    MealPlanStatus.updated => (colors.infoContainer, colors.onInfoContainer),
    MealPlanStatus.ended => (colors.historyContainer, colors.onHistoryContainer),
    MealPlanStatus.archived => (colors.historyContainer, colors.onHistoryContainer),
  };
}

String _mealPlanStatusLabel(MealPlanStatus value) => switch (value) {
  MealPlanStatus.draft => 'Rascunho',
  MealPlanStatus.inReview => 'Em revis\u00e3o',
  MealPlanStatus.scheduled => 'Agendado',
  MealPlanStatus.published => 'Publicado',
  MealPlanStatus.updated => 'Atualizado',
  MealPlanStatus.ended => 'Encerrado',
  MealPlanStatus.archived => 'Arquivado',
};
