import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/activity/superadmin_activity.dart';
import '../../app/shell/superadmin_shell.dart';
import '../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../auth/domain/logout_action.dart';
import 'daily_routine.dart';
import 'daily_routine_form_sections.dart';

enum _RoutineDisplay { cards, table }

enum _RoutineTableView { grouped }

class DailyRoutineDirectoryPage extends StatefulWidget {
  const DailyRoutineDirectoryPage({
    required this.repository,
    required this.permissions,
    required this.logout,
    this.onCreate,
    this.onCreateEntry,
    this.onEdit,
    this.activityController,
    this.loading = false,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final InMemoryDailyRoutineRepository repository;
  final DailyRoutinePermissions permissions;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<DailyRoutineEntryType>? onCreateEntry;
  final ValueChanged<String>? onEdit;
  final SuperadminActivityController? activityController;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<DailyRoutineDirectoryPage> createState() => _DailyRoutineDirectoryPageState();
}

class _DailyRoutineDirectoryPageState extends State<DailyRoutineDirectoryPage> {
  final _search = TextEditingController();
  var _display = _RoutineDisplay.cards;
  var _origin = 'Todas';
  var _selectedType = DailyRoutineEntryType.model;
  var _page = 1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void updateDirectory(VoidCallback update) {
    setState(() {
      update();
      _page = 1;
    });
  }

  void clearFilters() {
    _search.clear();
    updateDirectory(() => _origin = 'Todas');
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filteredModels = widget.repository.models
        .where((model) {
          final matchesSearch = model.name.toLowerCase().contains(query);
          final matchesOrigin =
              _origin == 'Todas' ||
              (_origin == 'Instituição' && model.origin == DailyRoutineOrigin.institution) ||
              (_origin == 'Unidade' && model.origin == DailyRoutineOrigin.unit);
          return matchesSearch && matchesOrigin && model.type == _selectedType;
        })
        .toList(growable: false);
    final hasSelectedType = widget.repository.models.any((model) => model.type == _selectedType);
    final pageSize = _display == _RoutineDisplay.cards ? 11 : 8;
    final totalPages = math.max(1, (filteredModels.length / pageSize).ceil());
    final currentPage = math.min(_page, totalPages);
    final first = (currentPage - 1) * pageSize;
    final visibleModels = filteredModels.skip(first).take(pageSize).toList(growable: false);

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
            final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            return ListView(
              padding: const EdgeInsets.all(CoeloSpacing.space5),
              children: [
                if (!widget.permissions.canManage) ...[
                  const Text('Modo somente leitura'),
                  const SizedBox(height: CoeloSpacing.space4),
                ],
                SuperadminUnderlineTabs<DailyRoutineEntryType>(
                  key: const Key('daily-routine-type-tabs'),
                  selected: _selectedType,
                  tabs: const [
                    SuperadminUnderlineTab(value: DailyRoutineEntryType.model, label: 'Modelos'),
                    SuperadminUnderlineTab(value: DailyRoutineEntryType.routine, label: 'Rotinas'),
                  ],
                  onSelected: (value) => updateDirectory(() => _selectedType = value),
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _toolbar(compact, constraints.maxWidth, textScale > 1.3),
                const SizedBox(height: CoeloSpacing.space5),
                if (widget.loading)
                  const CoeloStatePanel(
                    key: Key('daily-routine-loading'),
                    title: 'Carregando rotinas',
                    message: 'Aguarde enquanto os modelos são preparados.',
                    loading: true,
                  )
                else if (widget.errorMessage case final message?)
                  CoeloStatePanel(
                    key: const Key('daily-routine-error'),
                    title: 'Não foi possível carregar as rotinas',
                    message: message,
                    icon: Icons.error_outline_rounded,
                    actionLabel: widget.onRetry == null ? null : 'Tentar novamente',
                    onAction: widget.onRetry,
                  )
                else if (widget.repository.models.isEmpty)
                  CoeloStatePanel(
                    key: const Key('daily-routine-empty'),
                    title: 'Nenhuma rotina criada',
                    message: widget.permissions.canManage
                        ? 'Crie o primeiro modelo para organizar o registro cotidiano.'
                        : 'Não há modelos disponíveis para consulta.',
                    icon: Icons.event_note_outlined,
                    actionLabel: widget.permissions.canManage
                        ? _selectedType == DailyRoutineEntryType.model
                              ? 'Criar modelo'
                              : 'Nova rotina'
                        : null,
                    onAction: widget.permissions.canManage ? _requestCreate : null,
                  )
                else if (!hasSelectedType)
                  CoeloStatePanel(
                    key: const Key('daily-routine-category-empty'),
                    title: _selectedType == DailyRoutineEntryType.model
                        ? 'Nenhum modelo criado'
                        : 'Nenhuma rotina criada',
                    message: _selectedType == DailyRoutineEntryType.model
                        ? 'Crie uma base reutilizável para começar.'
                        : 'Crie uma rotina do zero ou use um modelo como ponto de partida.',
                    icon: Icons.event_note_outlined,
                    actionLabel: widget.permissions.canManage
                        ? _selectedType == DailyRoutineEntryType.model
                              ? 'Criar modelo'
                              : 'Nova rotina'
                        : null,
                    onAction: widget.permissions.canManage ? _requestCreate : null,
                  )
                else if (filteredModels.isEmpty)
                  CoeloStatePanel(
                    key: const Key('daily-routine-no-results'),
                    title: 'Nenhum resultado',
                    message: 'Ajuste a busca ou o filtro de origem.',
                    icon: Icons.search_off_rounded,
                    actionLabel: 'Limpar filtros',
                    onAction: clearFilters,
                  )
                else if (_display == _RoutineDisplay.cards)
                  _cards(visibleModels, currentPage, totalPages)
                else
                  _table(visibleModels, currentPage, totalPages),
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
            semanticLabel: _selectedType == DailyRoutineEntryType.model
                ? 'Buscar modelos de rotina diária'
                : 'Buscar rotinas diárias',
            hintText: _selectedType == DailyRoutineEntryType.model
                ? 'Buscar modelos'
                : 'Buscar rotinas',
            onChanged: (_) => updateDirectory(() {}),
          ),
        ),
        filters: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? availableWidth : 168),
            child: CoeloAdminSingleSelectField<String>(
              key: const Key('daily-routine-origin-filter'),
              label: 'Origem',
              value: _origin,
              options: const ['Todas', 'Instituição', 'Unidade'],
              optionLabel: (value) => value,
              searchable: false,
              onChanged: (value) => updateDirectory(() => _origin = value),
            ),
          ),
        ],
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
          if (widget.permissions.canManage)
            FilledButton.icon(
              onPressed: _requestCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                _selectedType == DailyRoutineEntryType.model ? 'Criar modelo' : 'Nova rotina',
              ),
            ),
        ],
      ),
    ),
  );

  Widget _cards(List<DailyRoutineModel> models, int currentPage, int totalPages) => Column(
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1020
              ? 3
              : constraints.maxWidth >= 680
              ? 2
              : 1;
          final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space4) / columns;
          return Wrap(
            key: const Key('daily-routine-cards'),
            spacing: CoeloSpacing.space4,
            runSpacing: CoeloSpacing.space4,
            children: [
              if (widget.permissions.canManage)
                SizedBox(
                  width: width,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 216),
                    child: CoeloAdminCreateAction(
                      key: const Key('daily-routine-create-tile'),
                      label: _selectedType == DailyRoutineEntryType.model
                          ? 'Criar modelo'
                          : 'Nova rotina',
                      onPressed: _requestCreate,
                      icon: Icons.add_task_rounded,
                    ),
                  ),
                ),
              for (final model in models)
                SizedBox(
                  width: width,
                  child: CoeloAdminInteractiveCard(
                    key: Key('daily-routine-card-${model.id}'),
                    semanticLabel: widget.permissions.canManage
                        ? 'Editar ${model.name}'
                        : 'Consultar ${model.name}',
                    onPressed: widget.onEdit == null ? null : () => widget.onEdit!(model.id),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 184),
                      child: Padding(
                        padding: const EdgeInsets.all(CoeloSpacing.space4),
                        child: _RoutineSummary(
                          model: model,
                          canManage: widget.permissions.canManage,
                          onDuplicate: () => _confirmDuplicate(model),
                          onCreateRoutine: model.type == DailyRoutineEntryType.model
                              ? () => _createRoutineFromModel(model)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      if (totalPages > 1) ...[
        const SizedBox(height: CoeloSpacing.space5),
        _pagination(currentPage, totalPages),
      ],
    ],
  );

  Widget _table(List<DailyRoutineModel> models, int currentPage, int totalPages) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.permissions.canManage) ...[
        CoeloAdminCreateAction(
          key: const Key('daily-routine-create-banner'),
          label: _selectedType == DailyRoutineEntryType.model ? 'Criar modelo' : 'Nova rotina',
          description: _selectedType == DailyRoutineEntryType.model
              ? 'Configure uma base reutilizável em quatro etapas.'
              : 'Configure o registro cotidiano em quatro etapas.',
          onPressed: _requestCreate,
          icon: Icons.add_task_rounded,
          variant: CoeloAdminCreateActionVariant.banner,
        ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      CoeloAdminResizableTable<DailyRoutineModel>(
        key: const Key('daily-routine-table'),
        items: models,
        rowKey: (model) => 'daily-routine-row-${model.id}',
        pinnedColumn: CoeloAdminTableColumn(
          id: 'name',
          label: _selectedType == DailyRoutineEntryType.model ? 'Modelo' : 'Rotina',
          initialWidth: 260,
          minWidth: 180,
          maxWidth: 420,
          cellBuilder: (_, model) => Text(model.name),
        ),
        columns: [
          CoeloAdminTableColumn(
            id: 'origin',
            label: 'Origem',
            initialWidth: 160,
            minWidth: 120,
            maxWidth: 240,
            cellBuilder: (_, model) => Text(model.origin.label),
          ),
          CoeloAdminTableColumn(
            id: 'version',
            label: 'Versão',
            initialWidth: 120,
            minWidth: 100,
            maxWidth: 180,
            cellBuilder: (_, model) => Text('v${model.version}'),
          ),
          CoeloAdminTableColumn(
            id: 'actions',
            label: 'Ações',
            initialWidth: 144,
            minWidth: 120,
            maxWidth: 180,
            cellBuilder: (_, model) => widget.permissions.canManage
                ? Row(
                    children: [
                      IconButton(
                        tooltip: 'Duplicar ${model.name}',
                        onPressed: () => _confirmDuplicate(model),
                        icon: const Icon(Icons.content_copy_rounded),
                      ),
                      if (model.type == DailyRoutineEntryType.model)
                        IconButton(
                          tooltip: 'Criar rotina de ${model.name}',
                          onPressed: () => _createRoutineFromModel(model),
                          icon: const Icon(Icons.playlist_add_rounded),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
        headerHeight: 56,
        rowHeight: 64,
        onRowPressed: widget.onEdit == null ? null : (model) => widget.onEdit!(model.id),
      ),
      if (totalPages > 1) ...[
        const SizedBox(height: CoeloSpacing.space5),
        _pagination(currentPage, totalPages),
      ],
    ],
  );

  void _requestCreate() {
    final callback = widget.onCreateEntry;
    if (callback != null) {
      callback(_selectedType);
    } else {
      widget.onCreate?.call();
    }
  }

  Future<void> _confirmDuplicate(DailyRoutineModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        title: 'Duplicar ${model.type == DailyRoutineEntryType.model ? 'modelo' : 'rotina'}?',
        body: Text(
          'Uma cópia editável de ${model.name} será criada com o próximo sufixo disponível.',
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          key: const Key('daily-routine-confirm-duplicate'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Duplicar'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.repository.duplicate(model.id);
    setState(() => _page = 1);
  }

  void _createRoutineFromModel(DailyRoutineModel model) {
    final routine = widget.repository.createRoutineFromModel(model.id);
    setState(() {
      _selectedType = DailyRoutineEntryType.routine;
      _page = 1;
    });
    widget.onEdit?.call(routine.id);
  }

  Widget _pagination(int currentPage, int totalPages) => CoeloAdminPagination(
    key: const Key('daily-routine-pagination'),
    currentPage: currentPage,
    totalPages: totalPages,
    onPrevious: currentPage > 1 ? () => setState(() => _page = currentPage - 1) : null,
    onNext: currentPage < totalPages ? () => setState(() => _page = currentPage + 1) : null,
    onPageSelected: (page) => setState(() => _page = page),
  );
}

class _RoutineSummary extends StatelessWidget {
  const _RoutineSummary({
    required this.model,
    required this.canManage,
    required this.onDuplicate,
    this.onCreateRoutine,
  });

  final DailyRoutineModel model;
  final bool canManage;
  final VoidCallback onDuplicate;
  final VoidCallback? onCreateRoutine;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(model.name, style: Theme.of(context).textTheme.titleMedium)),
          if (canManage)
            IconButton(
              key: Key('daily-routine-duplicate-${model.id}'),
              tooltip: 'Duplicar ${model.name}',
              onPressed: onDuplicate,
              icon: const Icon(Icons.content_copy_rounded),
            ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(model.description),
      const SizedBox(height: CoeloSpacing.space3),
      if (model.isCoeloProvided) const Text('Modelo Coelo • Somente leitura'),
      Text('${model.origin.label} • v${model.version} • ${model.status.label}'),
      if (model.updateAvailable) const Text('Atualização opcional disponível'),
      if (canManage && onCreateRoutine != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: Key('daily-routine-use-model-${model.id}'),
            onPressed: onCreateRoutine,
            icon: const Icon(Icons.playlist_add_rounded),
            label: const Text('Criar rotina deste modelo'),
          ),
        ),
    ],
  );
}

class DailyRoutineEditorPage extends StatefulWidget {
  const DailyRoutineEditorPage({
    required this.repository,
    required this.permissions,
    required this.logout,
    this.modelId,
    this.entryType = DailyRoutineEntryType.model,
    this.activityController,
    super.key,
  });

  final InMemoryDailyRoutineRepository repository;
  final DailyRoutinePermissions permissions;
  final LogoutAction logout;
  final String? modelId;
  final DailyRoutineEntryType entryType;
  final SuperadminActivityController? activityController;

  @override
  State<DailyRoutineEditorPage> createState() => _DailyRoutineEditorPageState();
}

class _DailyRoutineEditorPageState extends State<DailyRoutineEditorPage> {
  @override
  Widget build(BuildContext context) => DailyRoutineWizardPage(
    repository: widget.repository,
    permissions: widget.permissions,
    logout: widget.logout,
    modelId: widget.modelId,
    entryType: widget.entryType,
    activityController: widget.activityController,
  );
}

extension on DailyRoutineOrigin {
  String get label => switch (this) {
    DailyRoutineOrigin.institution => 'Instituição',
    DailyRoutineOrigin.unit => 'Unidade',
  };
}

extension on DailyRoutineStatus {
  String get label => switch (this) {
    DailyRoutineStatus.draft => 'Rascunho',
    DailyRoutineStatus.active => 'Ativo',
  };
}
