import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_placeholder_file_actions.dart';
import '../domain/meal_plan_repository.dart';

enum _MealPlanDirectorySection { mealPlans, models }

enum _DirectoryAction { edit, duplicate, publish, review, remove }

/// Recibo de escrita que nao corresponde ao cardapio solicitado.
///
/// E um estado proprio, e nao um [MealPlanRepositoryException]: a rejeicao do
/// servidor significa que nada foi escrito, enquanto um recibo divergente
/// significa que a escrita PODE ter ocorrido. Os dois casos nao podem
/// compartilhar tratamento.
final class _MealPlanReceiptMismatch implements Exception {
  const _MealPlanReceiptMismatch(this.message);

  final String message;
}

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
  static const _cardMinHeight = CoeloSize.touchMin * 5;

  final _search = TextEditingController();
  final _institution = TextEditingController();
  final _unit = TextEditingController();
  final _classId = TextEditingController();
  final _personId = TextEditingController();
  final _periodStart = TextEditingController();
  final _periodEnd = TextEditingController();

  CoeloAdminDirectoryDisplay _display = CoeloAdminDirectoryDisplay.cards;
  _MealPlanDirectorySection _section = _MealPlanDirectorySection.models;
  bool _loading = true;
  bool _unauthorized = false;
  bool _actionRunning = false;
  String? _errorMessage;
  int _page = 0;
  int _pageSize = 11;
  int _total = 0;
  int _requestedVersion = 1;
  int _actionGeneration = 0;

  /// Intencao de escrita por acao e revisao do item.
  ///
  /// Preservada entre tentativas para que o retry reenvie a MESMA intencao;
  /// so e removida quando o recibo confirma a escrita.
  final Map<String, String> _writeIntents = {};

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
    _writeIntents.clear();
    _search.clear();
    _institution.clear();
    _unit.clear();
    _classId.clear();
    _personId.clear();
    _periodStart.clear();
    _periodEnd.clear();
    setState(() {
      _display = CoeloAdminDirectoryDisplay.cards;
      _section = _MealPlanDirectorySection.models;
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
    if (_unauthorized) {
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: EdgeInsets.all(
            CoeloAdminDirectoryMetrics.horizontalPadding(constraints.maxWidth),
          ),
          children: const [
            CoeloStatePanel(
              key: Key('meal-plans-unauthorized'),
              title: 'Acesso não autorizado',
              message: 'Seu acesso a este escopo não está disponível.',
              icon: Icons.lock_outline_rounded,
            ),
          ],
        ),
      );
    }
    final models = _section == _MealPlanDirectorySection.models;
    final compactLargeText =
        MediaQuery.sizeOf(context).width < CoeloBreakpoints.medium.minWidth &&
        MediaQuery.textScalerOf(context).scale(1) >= 2;
    final onCreate = models
        ? widget.onCreateTemplate
        : widget.onCreate == null
        ? null
        : () => widget.onCreate!(null);
    return CoeloAdminDirectory<CoeloAdminDirectoryDisplay>(
      loadingKey: const Key('meal-plans-loading'),
      cardsKey: const Key('meal-plan-directory-view-cards'),
      tableKey: const Key('meal-plan-directory-view-table'),
      gridKey: const Key('meal-plan-directory-card-grid'),
      tabs: CoeloAdminUnderlineTabs<_MealPlanDirectorySection>(
        key: const Key('meal-plan-type-tabs'),
        selected: _section,
        tabs: const [
          CoeloAdminUnderlineTab(value: _MealPlanDirectorySection.models, label: 'Modelos'),
          CoeloAdminUnderlineTab(value: _MealPlanDirectorySection.mealPlans, label: 'Cardápios'),
        ],
        onSelected: _selectSection,
      ),
      status: _loading
          ? CoeloAdminDirectoryStatus.loading
          : _errorMessage != null
          ? CoeloAdminDirectoryStatus.failure
          : _items.isEmpty
          ? (_hasAnyFilter ? CoeloAdminDirectoryStatus.noResults : CoeloAdminDirectoryStatus.empty)
          : CoeloAdminDirectoryStatus.success,
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Nenhum card\u00e1pio',
        emptyIcon: Icons.restaurant_menu,
        noResults: 'Sem resultado',
        noResultsIcon: Icons.search_off_rounded,
        failure: 'N\u00e3o foi poss\u00edvel carregar',
        unauthorized: 'Acesso não autorizado',
      ),
      errorMessage:
          _errorMessage ??
          (!_loading && _items.isEmpty
              ? (_hasAnyFilter
                    ? 'Ajuste os filtros para encontrar card\u00e1pios.'
                    : 'Ainda n\u00e3o h\u00e1 card\u00e1pios cadastrados.')
              : null),
      onRetry: _loadFromState,
      search: CoeloSearchField(
        controller: _search,
        hintText: 'Buscar card\u00e1pio',
        semanticLabel: 'Buscar por nome ou origem',
        onChanged: (_) => _debouncedLoad(),
      ),
      searchWidth: 360,
      filters: [
        SizedBox(
          width: 200,
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
          width: 200,
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
          width: 170,
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
          width: 200,
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
      display: _display,
      onDisplayChanged: _setDisplay,
      groupedTableView: CoeloAdminDirectoryDisplay.table,
      selectedTableView: CoeloAdminDirectoryDisplay.table,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(
          value: CoeloAdminDirectoryDisplay.table,
          label: 'Agrupado',
        ),
      ],
      onTableViewSelected: (_) => _setDisplay(CoeloAdminDirectoryDisplay.table),
      fileActions: superadminPlaceholderFileActionList(context, 'cardápios'),
      create: CoeloAdminDirectoryCreate(
        label: models ? 'Criar modelo de cardápio' : 'Criar cardápio',
        description: compactLargeText
            ? null
            : models
            ? 'Monte uma base reutilizável simples ou completa.'
            : 'Defina modelo-base, período, público e refeições.',
        icon: models ? Icons.collections_bookmark_rounded : Icons.restaurant_menu_rounded,
        onPressed: onCreate,
        tileKey: const Key('meal-plan-directory-create-card'),
      ),
      cardMinHeight: _cardMinHeight,
      cards: [
        for (final item in _items)
          _MealPlanCard(
            item: item,
            minHeight: _cardMinHeight,
            scopeLabel: _scopeLabel(item.scopeLevel, item.scopeId),
            sourceLabel: _sourceLabel(item.sourceType),
            onOpen: _canEdit(item) ? () => _runAction(_DirectoryAction.edit, item) : null,
            canDuplicate: widget.onCreate != null,
            onAction: (action) => _runAction(action, item),
          ),
      ],
      table: _table(),
      pagination: _totalPages >= 1 && _items.isNotEmpty
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('meal-plans-pagination'),
              currentPage: _page + 1,
              totalPages: _totalPages,
              pageSize: _pageSize,
              pageSizeOptions: _display == CoeloAdminDirectoryDisplay.cards
                  ? const [11, 20, 50, 100]
                  : const [8, 20, 50, 100],
              onPageSelected: (value) => _setPage(value - 1),
              onPageSizeChanged: _setPageSize,
            )
          : null,
    );
  }

  Widget _table() => CoeloAdminResizableTable<MealPlan>(
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
      cellBuilder: (_, item) => Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
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
          icon: Icons.content_copy_rounded,
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
      action: (repository) => _runWrite(
        action: 'review',
        item: item,
        repository: repository,
        mismatchMessage:
            'A confirma\u00e7\u00e3o da revis\u00e3o n\u00e3o corresponde ao card\u00e1pio solicitado.',
        call: (repository, requestId) =>
            repository.submitForReview(item.id, requestId, item.revision),
      ),
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
      action: (repository) => _runWrite(
        action: 'publish',
        item: item,
        repository: repository,
        mismatchMessage:
            'A confirma\u00e7\u00e3o da publica\u00e7\u00e3o n\u00e3o corresponde ao card\u00e1pio solicitado.',
        isSettled: (receipt) =>
            receipt.status == MealPlanStatus.published &&
            !receipt.isDraft &&
            !receipt.requiresReview,
        call: (repository, requestId) => repository.publish(item.id, requestId, item.revision),
      ),
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

  /// Executa uma escrita reusando a mesma intencao enquanto ela nao for
  /// confirmada, e valida o recibo num unico ponto compartilhado.
  Future<MealPlan> _runWrite({
    required String action,
    required MealPlan item,
    required MealPlanRepository repository,
    required String mismatchMessage,
    required Future<MealPlan> Function(MealPlanRepository repository, String requestId) call,
    bool Function(MealPlan receipt)? isSettled,
  }) async {
    final key = '$action:${item.id}:${item.revision}:${item.tenantId}:${item.institutionId ?? ''}';
    final requestId = _writeIntents[key] ??= _requestId();
    final receipt = await call(repository, requestId);
    if (receipt.id != item.id ||
        receipt.tenantId != item.tenantId ||
        receipt.institutionId != item.institutionId ||
        !(isSettled?.call(receipt) ?? true)) {
      // A escrita pode ter ocorrido: manter a intencao para que o retry
      // reenvie o mesmo requestId em vez de criar uma segunda intencao.
      throw _MealPlanReceiptMismatch(mismatchMessage);
    }
    _writeIntents.remove(key);
    return receipt;
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
    } on _MealPlanReceiptMismatch catch (mismatch) {
      if (!_isCurrentAction(generation, repository)) return;
      _feedback(mismatch.message);
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
    } on Object {
      if (!_isCurrentLoad(requestVersion, repository)) return;
      setState(() {
        _items = const [];
        _total = 0;
        _errorMessage = 'Verifique sua conexão e tente novamente.';
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

  void _setDisplay(CoeloAdminDirectoryDisplay display) {
    if (_display == display) return;
    setState(() {
      _display = display;
      _pageSize = display == CoeloAdminDirectoryDisplay.cards ? 11 : 8;
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
    required this.minHeight,
    required this.scopeLabel,
    required this.sourceLabel,
    required this.onOpen,
    required this.canDuplicate,
    required this.onAction,
  });

  final MealPlan item;
  final double minHeight;
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
    minHeight: minHeight,
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
              // ARQUIVO (decisao do Owner de 10/09): duplicar segue o conceito do
              // card de modelo de atividade, como icone direto no cabecalho.
              if (canDuplicate)
                IconButton(
                  key: Key('meal-plan-card-duplicate-${item.id}'),
                  tooltip: item.isTemplate
                      ? 'Duplicar modelo ${item.name}'
                      : 'Duplicar cardápio ${item.name}',
                  onPressed: () => onAction(_DirectoryAction.duplicate),
                  icon: const Icon(Icons.content_copy_rounded),
                ),
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
