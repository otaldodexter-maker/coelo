import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/activity_directory.dart';
import 'activity_directory_view_model.dart';

enum ActivityDirectoryTableView { grouped, units, groups }

enum ActivityDirectoryExportFormat { csv, xlsx }

final class ActivityDirectoryExportRequest {
  const ActivityDirectoryExportRequest({
    required this.format,
    required this.tableView,
    required this.query,
  });

  final ActivityDirectoryExportFormat format;
  final ActivityDirectoryTableView tableView;
  final ActivityDirectoryQuery query;
}

final class ActivityDirectoryExportResult {
  const ActivityDirectoryExportResult({required this.fileName});

  final String fileName;
}

typedef ActivityDirectoryExporter =
    Future<ActivityDirectoryExportResult> Function(ActivityDirectoryExportRequest request);
typedef ActivityDirectoryImportRequested = Future<void> Function();
typedef ActivityTemplateStarter = void Function(ActivityTemplateOption template);
typedef ActivityTemplateDuplicator =
    Future<void> Function(
      ActivityTemplateOption template,
      String institutionId,
      String? unitId,
      String newName,
    );
typedef ActivityTemplateCreator = Future<void> Function(ActivityTemplateCreateDraft draft);

final class ActivityTemplateCreateDraft {
  const ActivityTemplateCreateDraft({
    required this.institutionId,
    this.unitId,
    required this.name,
    required this.description,
    required this.taxonomyId,
    required this.governance,
  });

  final String institutionId;
  final String? unitId;
  final String name;
  final String description;
  final String taxonomyId;
  final ActivityGovernance governance;
}

enum _ActivityContentKind { activities, templates }

Set<ActivityStatus> _statusesForTab(CoeloAdminDirectoryStatusTab tab) => switch (tab) {
  CoeloAdminDirectoryStatusTab.all => const {},
  CoeloAdminDirectoryStatusTab.active => const {ActivityStatus.active},
  CoeloAdminDirectoryStatusTab.draft => const {ActivityStatus.draft},
  CoeloAdminDirectoryStatusTab.inactive => const {
    ActivityStatus.inactive,
    ActivityStatus.suspended,
    ActivityStatus.archived,
  },
};

CoeloAdminDirectoryStatusTab _tabForStatuses(Set<ActivityStatus> statuses) {
  if (statuses.isEmpty) return CoeloAdminDirectoryStatusTab.all;
  if (statuses.length == 1 && statuses.contains(ActivityStatus.active)) {
    return CoeloAdminDirectoryStatusTab.active;
  }
  if (statuses.length == 1 && statuses.contains(ActivityStatus.draft)) {
    return CoeloAdminDirectoryStatusTab.draft;
  }
  return CoeloAdminDirectoryStatusTab.inactive;
}

final class ActivityDirectoryPage extends StatefulWidget {
  const ActivityDirectoryPage({
    required this.repository,
    required this.logout,
    required this.onView,
    this.onCreate,
    this.onEdit,
    this.onExportRequested,
    this.onImportRequested,
    this.onCreateFromTemplate,
    this.onDuplicateTemplate,
    this.onCreateTemplate,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    super.key,
  });

  final ActivityDirectoryRepository repository;
  final LogoutAction logout;
  final ValueChanged<String> onView;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ActivityDirectoryExporter? onExportRequested;
  final ActivityDirectoryImportRequested? onImportRequested;
  final ActivityTemplateStarter? onCreateFromTemplate;
  final ActivityTemplateDuplicator? onDuplicateTemplate;
  final ActivityTemplateCreator? onCreateTemplate;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;

  @override
  State<ActivityDirectoryPage> createState() => _ActivityDirectoryPageState();
}

final class _ActivityDirectoryPageState extends State<ActivityDirectoryPage> {
  late ActivityDirectoryViewModel _viewModel;
  late final SuperadminActivityController _activityController;
  late final TextEditingController _searchController;
  CoeloAdminDirectoryDisplay _display = CoeloAdminDirectoryDisplay.cards;
  ActivityDirectoryTableView _tableView = ActivityDirectoryTableView.grouped;
  double _footerHeight = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = ActivityDirectoryViewModel(widget.repository);
    _activityController = SuperadminActivityController();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void didUpdateWidget(covariant ActivityDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository)) return;
    final previous = _viewModel;
    final replacement = ActivityDirectoryViewModel(widget.repository);
    _viewModel = replacement;
    _searchController.clear();
    previous.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(replacement, _viewModel)) return;
      replacement.setPageSize(_display == CoeloAdminDirectoryDisplay.cards ? 11 : 8);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _setDisplay(CoeloAdminDirectoryDisplay display) {
    if (_display == display) return;
    setState(() => _display = display);
    _viewModel.setPageSize(display == CoeloAdminDirectoryDisplay.cards ? 11 : 8);
  }

  void _setTableView(ActivityDirectoryTableView tableView) {
    setState(() {
      _display = CoeloAdminDirectoryDisplay.table;
      _tableView = tableView;
    });
    _viewModel.setPageSize(8);
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    activityController: _activityController,
    title: 'Atividades',
    subtitle: 'Consulte as atividades da plataforma.',
    currentDestination: 'activities',
    chatLauncherBottomInset: _footerHeight,
    onDestinationSelected: widget.onDestinationSelected,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    child: _ActivityDirectoryContent(
      viewModel: _viewModel,
      searchController: _searchController,
      display: _display,
      tableView: _tableView,
      onDisplayChanged: _setDisplay,
      onTableViewChanged: _setTableView,
      onCreate: widget.onCreate,
      onView: widget.onView,
      onEdit: widget.onEdit,
      onExportRequested: widget.onExportRequested,
      onImportRequested: widget.onImportRequested,
      repository: widget.repository,
      onCreateFromTemplate: widget.onCreateFromTemplate,
      onDuplicateTemplate: widget.onDuplicateTemplate,
      onCreateTemplate: widget.onCreateTemplate,
      onFooterHeightChanged: (height) {
        if ((_footerHeight - height).abs() >= .5) {
          setState(() => _footerHeight = height);
        }
      },
    ),
  );
}

final class _ActivityDirectoryContent extends StatefulWidget {
  const _ActivityDirectoryContent({
    required this.viewModel,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
    required this.onCreate,
    required this.onView,
    required this.onEdit,
    required this.onExportRequested,
    required this.onImportRequested,
    required this.repository,
    required this.onCreateFromTemplate,
    required this.onDuplicateTemplate,
    required this.onCreateTemplate,
    required this.onFooterHeightChanged,
  });

  final ActivityDirectoryViewModel viewModel;
  final TextEditingController searchController;
  final CoeloAdminDirectoryDisplay display;
  final ActivityDirectoryTableView tableView;
  final ValueChanged<CoeloAdminDirectoryDisplay> onDisplayChanged;
  final ValueChanged<ActivityDirectoryTableView> onTableViewChanged;
  final VoidCallback? onCreate;
  final ValueChanged<String> onView;
  final ValueChanged<String>? onEdit;
  final ActivityDirectoryExporter? onExportRequested;
  final ActivityDirectoryImportRequested? onImportRequested;
  final ActivityDirectoryRepository repository;
  final ActivityTemplateStarter? onCreateFromTemplate;
  final ActivityTemplateDuplicator? onDuplicateTemplate;
  final ActivityTemplateCreator? onCreateTemplate;
  final ValueChanged<double> onFooterHeightChanged;

  @override
  State<_ActivityDirectoryContent> createState() => _ActivityDirectoryContentState();
}

final class _ActivityDirectoryContentState extends State<_ActivityDirectoryContent> {
  static const _templatePageSize = 12;

  String? _fileActionLabel;
  ActivityTemplateOptions? _templateOptions;
  bool _templatesFailed = false;
  bool _templatesRequested = false;
  final Set<String> _selectedTemplateTaxonomyIds = {};
  final TextEditingController _templateSearchController = TextEditingController();
  _ActivityContentKind _content = _ActivityContentKind.templates;
  String _templateSearch = '';
  String _templateOrigin = 'Todas';
  CoeloAdminDirectoryStatusTab _templateStatus = CoeloAdminDirectoryStatusTab.all;
  int _templatePage = 0;
  int _templateLoadGeneration = 0;

  bool get _templatesEnabled =>
      widget.onCreateFromTemplate != null || widget.onDuplicateTemplate != null;

  @override
  void didUpdateWidget(covariant _ActivityDirectoryContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository)) return;
    _templateLoadGeneration++;
    _templateOptions = null;
    _templatesFailed = false;
    _templatesRequested = false;
    _selectedTemplateTaxonomyIds.clear();
    _templateSearchController.clear();
    _templateSearch = '';
    _templateOrigin = 'Todas';
    _templateStatus = CoeloAdminDirectoryStatusTab.all;
    _templatePage = 0;
  }

  @override
  void dispose() {
    _templateLoadGeneration++;
    _templateSearchController.dispose();
    super.dispose();
  }

  Future<bool> _loadTemplates({String? institutionId}) async {
    final generation = ++_templateLoadGeneration;
    final repository = widget.repository;
    _templatesRequested = true;
    setState(() => _templatesFailed = false);
    try {
      final options = await repository.fetchTemplateOptions(institutionId: institutionId);
      if (!_isCurrentTemplateLoad(generation, repository)) return false;
      setState(() => _templateOptions = options);
      return true;
    } catch (_) {
      if (_isCurrentTemplateLoad(generation, repository)) {
        setState(() => _templatesFailed = true);
      }
      return false;
    }
  }

  bool _isCurrentTemplateLoad(int generation, ActivityDirectoryRepository repository) =>
      mounted && generation == _templateLoadGeneration && identical(repository, widget.repository);

  Future<void> _duplicateTemplate(
    ActivityTemplateOption template,
    String institutionId,
    String? unitId,
    String newName,
  ) async {
    await widget.onDuplicateTemplate!(template, institutionId, unitId, newName);
    if (!mounted) return;
    showSuperadminNotice(
      context,
      'Modelo duplicado com sucesso.',
      icon: Icons.content_copy_rounded,
    );
    final refreshed = await _loadTemplates(institutionId: institutionId);
    if (!refreshed && mounted) {
      showSuperadminNotice(
        context,
        'A cópia foi criada, mas os modelos não puderam ser atualizados.',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _requestDuplicate(ActivityTemplateOption template) async {
    final options = _templateOptions;
    if (options == null || widget.onDuplicateTemplate == null) return;
    await showDialog<void>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => _ActivityTemplateCopyDialog(
        template: template,
        institutions: options.institutions,
        units: options.units,
        onDuplicate: _duplicateTemplate,
      ),
    );
  }

  Future<void> _requestCreateTemplate() async {
    final creator = widget.onCreateTemplate;
    final current = _templateOptions;
    if (creator == null || current == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (context) => _ActivityTemplateCreatePage(
          institutions: current.institutions,
          taxonomy: current.taxonomy,
          onCreate: creator,
        ),
      ),
    );
    if (created == true && mounted) {
      showSuperadminNotice(context, 'Modelo criado com sucesso.', icon: Icons.add_task_rounded);
    }
  }

  Future<void> _export(ActivityDirectoryExportFormat format) async {
    final exporter = widget.onExportRequested;
    if (_fileActionLabel != null) return;
    if (exporter == null) {
      showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
      return;
    }
    setState(() => _fileActionLabel = 'Exportando atividades...');
    try {
      final result = await exporter(
        ActivityDirectoryExportRequest(
          format: format,
          tableView: widget.tableView,
          query: widget.viewModel.query,
        ),
      );
      if (!mounted) return;
      showSuperadminNotice(
        context,
        'Arquivo ${result.fileName} exportado.',
        icon: Icons.download_done_outlined,
      );
    } catch (_) {
      if (!mounted) return;
      showSuperadminNotice(
        context,
        'Não foi possível exportar as atividades.',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _fileActionLabel = null);
    }
  }

  Future<void> _openImport() async {
    final openImport = widget.onImportRequested;
    if (_fileActionLabel != null) return;
    if (openImport == null) {
      showSuperadminNotice(context, 'Indisponível nesta etapa', icon: Icons.info_outline_rounded);
      return;
    }
    setState(() => _fileActionLabel = 'Abrindo importação...');
    try {
      await openImport();
    } catch (_) {
      if (!mounted) return;
      showSuperadminNotice(
        context,
        'Não foi possível abrir a importação de atividades.',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _fileActionLabel = null);
    }
  }

  void _clearTemplateFilters() => setState(() {
    _templateSearchController.clear();
    _templateSearch = '';
    _templateOrigin = 'Todas';
    _templateStatus = CoeloAdminDirectoryStatusTab.all;
    _selectedTemplateTaxonomyIds.clear();
    _templatePage = 0;
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (context, _) {
      final state = widget.viewModel.state;
      final directoryUnauthorized = state == ActivityDirectoryLoadState.unauthorized;
      final directoryPending =
          state == ActivityDirectoryLoadState.initial ||
          state == ActivityDirectoryLoadState.loading;
      final showingActivities = !_templatesEnabled || _content == _ActivityContentKind.activities;
      final showTemplates =
          _templatesEnabled && !showingActivities && !directoryPending && !directoryUnauthorized;
      if (showTemplates && !_templatesRequested) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_templatesRequested) _loadTemplates();
        });
      }
      final leading = <Widget>[
        if (_templatesEnabled && !directoryUnauthorized)
          CoeloAdminUnderlineTabs<_ActivityContentKind>(
            key: const Key('activity-type-tabs'),
            selected: _content,
            tabs: const [
              CoeloAdminUnderlineTab(value: _ActivityContentKind.templates, label: 'Modelos'),
              CoeloAdminUnderlineTab(value: _ActivityContentKind.activities, label: 'Atividades'),
            ],
            onSelected: (value) => setState(() => _content = value),
          ),
      ];
      return showTemplates
          ? _templatesDirectory(context, leading)
          : _activitiesDirectory(context, leading);
    },
  );

  Widget _activitiesDirectory(BuildContext context, List<Widget> leading) {
    final viewModel = widget.viewModel;
    final options = viewModel.filterOptions;
    final onCreate = widget.onCreate;
    final onView = widget.onEdit ?? widget.onView;
    final opensEdit = widget.onEdit != null;
    final hasFilters =
        viewModel.query.hasActiveFilters ||
        viewModel.selectedUnitIds.isNotEmpty ||
        viewModel.selectedGroupIds.isNotEmpty;

    Widget filter<T>({
      required Key key,
      required String label,
      required List<T> values,
      required Set<T> selected,
      required String Function(T) optionLabel,
      required ValueChanged<Set<T>> onChanged,
    }) => CoeloAdminMultiSelectFilter<T>(
      key: key,
      label: label,
      options: values,
      selectedValues: selected,
      optionLabel: optionLabel,
      onChanged: onChanged,
    );

    return CoeloAdminDirectory<ActivityDirectoryTableView>(
      scrollKey: const Key('activity-directory-scroll'),
      loadingKey: const Key('activity-directory-loading'),
      toolbarKey: const Key('activity-filter-toolbar'),
      filterControlsKey: const Key('activity-filter-controls'),
      cardsKey: const Key('activity-view-cards'),
      tableKey: const Key('activity-view-table'),
      gridKey: const Key('activity-card-grid'),
      leading: leading,
      status: switch (viewModel.state) {
        ActivityDirectoryLoadState.initial ||
        ActivityDirectoryLoadState.loading => CoeloAdminDirectoryStatus.loading,
        ActivityDirectoryLoadState.failure => CoeloAdminDirectoryStatus.failure,
        ActivityDirectoryLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
        ActivityDirectoryLoadState.empty => CoeloAdminDirectoryStatus.empty,
        ActivityDirectoryLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
        ActivityDirectoryLoadState.success => CoeloAdminDirectoryStatus.success,
      },
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Nenhuma atividade cadastrada',
        emptyIcon: Icons.local_activity_outlined,
        noResults: 'Nenhuma atividade encontrada',
        failure: 'Não foi possível carregar as atividades',
        failureIcon: Icons.cloud_off_outlined,
        unauthorized: 'Acesso não autorizado',
        unauthorizedIcon: Icons.lock_outline_rounded,
      ),
      onRetry: viewModel.retry,
      onClearFilters: () {
        widget.searchController.clear();
        viewModel.clearFilters();
      },
      search: CoeloSearchField(
        controller: widget.searchController,
        hintText: 'Buscar por nome ou descrição',
        semanticLabel: 'Buscar atividade por nome ou descrição',
        onChanged: viewModel.setSearch,
      ),
      filters: [
        filter<ActivityFilterOption>(
          key: const Key('activity-institution-filter'),
          label: 'Instituições',
          values: options.institutions,
          selected: options.institutions
              .where((option) => viewModel.query.institutionIds.contains(option.id))
              .toSet(),
          optionLabel: (option) => option.label,
          onChanged: (value) => viewModel.setInstitutions(value.map((option) => option.id).toSet()),
        ),
        filter<ActivityFilterOption>(
          key: const Key('activity-unit-filter'),
          label: 'Unidades',
          values: viewModel.unitOptions,
          selected: viewModel.unitOptions
              .where((option) => viewModel.selectedUnitIds.contains(option.id))
              .toSet(),
          optionLabel: (option) => option.label,
          onChanged: (value) => viewModel.setUnits(value.map((option) => option.id).toSet()),
        ),
        filter<ActivityFilterOption>(
          key: const Key('activity-group-filter'),
          label: 'Turmas',
          values: viewModel.groupOptions,
          selected: viewModel.groupOptions
              .where((option) => viewModel.selectedGroupIds.contains(option.id))
              .toSet(),
          optionLabel: (option) => option.label,
          onChanged: (value) => viewModel.setGroups(value.map((option) => option.id).toSet()),
        ),
        filter<ActivityOrigin>(
          key: const Key('activity-origin-filter'),
          label: 'Origem',
          values: ActivityOrigin.values,
          selected: viewModel.query.origins,
          optionLabel: (origin) => origin.label,
          onChanged: viewModel.setOrigins,
        ),
      ],
      trailing: [
        if (hasFilters)
          TextButton.icon(
            onPressed: () {
              widget.searchController.clear();
              viewModel.clearFilters();
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpar filtros'),
          ),
      ],
      display: widget.display,
      onDisplayChanged: widget.onDisplayChanged,
      groupedTableView: ActivityDirectoryTableView.grouped,
      selectedTableView: widget.tableView,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(
          value: ActivityDirectoryTableView.grouped,
          label: 'Agrupado',
        ),
        CoeloAdminDirectoryTableViewOption(
          value: ActivityDirectoryTableView.units,
          label: 'Por Unidades',
        ),
        CoeloAdminDirectoryTableViewOption(
          value: ActivityDirectoryTableView.groups,
          label: 'Por Turmas',
        ),
      ],
      onTableViewSelected: widget.onTableViewChanged,
      fileActionsBusyLabel: _fileActionLabel,
      fileActions: [
        CoeloAdminFileAction(
          key: const Key('activity-files-import'),
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: _openImport,
        ),
        CoeloAdminFileAction(
          key: const Key('activity-files-export-csv'),
          label: 'Exportar CSV',
          icon: Icons.table_rows_outlined,
          onPressed: () => _export(ActivityDirectoryExportFormat.csv),
        ),
        CoeloAdminFileAction(
          key: const Key('activity-files-export-xlsx'),
          label: 'Exportar XLSX',
          icon: Icons.grid_on_outlined,
          onPressed: () => _export(ActivityDirectoryExportFormat.xlsx),
        ),
      ],
      tabs: CoeloAdminDirectoryStatusTabs(
        key: const Key('activity-status-tabs'),
        selected: _tabForStatuses(viewModel.query.statuses),
        onSelected: (value) => viewModel.setStatuses(_statusesForTab(value)),
      ),
      create: onCreate == null
          ? null
          : CoeloAdminDirectoryCreate(
              label: 'Criar atividade',
              description: 'Adicionar nova atividade ao sistema.',
              icon: Icons.local_activity_rounded,
              onPressed: onCreate,
              tileKey: const Key('create-activity-tile'),
              bannerKey: const Key('create-activity-banner'),
              bannerSurfaceKey: const Key('create-activity-banner-surface'),
            ),
      cards: [
        for (final item in viewModel.visibleItems)
          _ActivityCard(item: item, onPressed: () => onView(item.id), opensEdit: opensEdit),
      ],
      table: switch (widget.tableView) {
        ActivityDirectoryTableView.grouped => _ActivityTableRows(
          items: viewModel.visibleItems,
          viewModel: viewModel,
          onView: onView,
        ),
        ActivityDirectoryTableView.units => _ActivityHierarchyRows(
          key: const Key('activity-unit-directory-table'),
          items: viewModel.visibleItems,
          level: ActivityDirectoryTableView.units,
          onView: onView,
        ),
        ActivityDirectoryTableView.groups => _ActivityHierarchyRows(
          key: const Key('activity-group-directory-table'),
          items: viewModel.visibleItems,
          level: ActivityDirectoryTableView.groups,
          onView: onView,
        ),
      },
      pagination: viewModel.state == ActivityDirectoryLoadState.success
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('activity-directory-pagination-footer'),
              currentPage: viewModel.page.page + 1,
              totalPages: viewModel.page.totalPages,
              pageSize: viewModel.query.pageSize,
              pageSizeOptions: widget.display == CoeloAdminDirectoryDisplay.cards
                  ? const [11, 20, 50, 100]
                  : const [8, 20, 50, 100],
              onPageSelected: (page) => viewModel.setPage(page - 1),
              onPageSizeChanged: viewModel.setPageSize,
            )
          : null,
      onFooterHeightChanged: widget.onFooterHeightChanged,
    );
  }

  Widget _templatesDirectory(BuildContext context, List<Widget> leading) {
    final options = _templateOptions;
    final templates = options == null
        ? const <ActivityTemplateOption>[]
        : _visibleTemplates(options);
    final pageCount = (templates.length / _templatePageSize).ceil();
    final safePage = pageCount == 0 ? 0 : _templatePage.clamp(0, pageCount - 1);
    final pageTemplates = templates
        .skip(safePage * _templatePageSize)
        .take(_templatePageSize)
        .toList(growable: false);
    final status = options == null
        ? (_templatesFailed ? CoeloAdminDirectoryStatus.failure : CoeloAdminDirectoryStatus.loading)
        : templates.isEmpty
        ? CoeloAdminDirectoryStatus.noResults
        : CoeloAdminDirectoryStatus.success;
    final hasFilters =
        _selectedTemplateTaxonomyIds.isNotEmpty ||
        _templateSearch.isNotEmpty ||
        _templateOrigin != 'Todas';
    final canDuplicate =
        widget.onDuplicateTemplate != null && (options?.institutions.isNotEmpty ?? false);
    final onCreate = widget.onCreateTemplate;

    return CoeloAdminDirectory<ActivityDirectoryTableView>(
      key: const Key('activity-template-section'),
      scrollKey: const Key('activity-directory-scroll'),
      loadingKey: const Key('activity-templates-loading'),
      toolbarKey: const Key('activity-template-toolbar'),
      cardsKey: const Key('activity-template-view-cards'),
      tableKey: const Key('activity-template-view-table'),
      leading: leading,
      status: status,
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Nenhum modelo encontrado',
        noResults: 'Nenhum modelo encontrado',
        noResultsIcon: Icons.search_off_rounded,
        failure: 'Não foi possível carregar os modelos',
        failureIcon: Icons.cloud_off_outlined,
        unauthorized: 'Você não tem permissão para visualizar os modelos.',
      ),
      onRetry: _loadTemplates,
      onClearFilters: hasFilters ? _clearTemplateFilters : null,
      search: CoeloSearchField(
        key: const Key('activity-template-search'),
        controller: _templateSearchController,
        hintText: 'Buscar modelo',
        semanticLabel: 'Buscar modelo de atividade',
        onChanged: (value) => setState(() {
          _templateSearch = value.trim();
          _templatePage = 0;
        }),
      ),
      filters: [
        CoeloAdminSingleSelectField<String>(
          key: const Key('activity-template-origin-filter'),
          label: 'Origem',
          value: _templateOrigin,
          options: const ['Todas', 'Coelo', 'Institucional'],
          optionLabel: (value) => value,
          searchable: false,
          onChanged: (value) => setState(() {
            _templateOrigin = value;
            _templatePage = 0;
          }),
        ),
        if (options != null)
          CoeloAdminMultiSelectFilter<ActivityTaxonomyOption>(
            key: const Key('activity-template-taxonomy-filter'),
            label: 'Categorias',
            options: options.taxonomy,
            selectedValues: options.taxonomy
                .where((item) => _selectedTemplateTaxonomyIds.contains(item.id))
                .toSet(),
            optionLabel: (item) => item.label,
            searchHintText: 'Buscar categoria',
            onChanged: (items) => setState(() {
              _selectedTemplateTaxonomyIds
                ..clear()
                ..addAll(items.map((item) => item.id));
              _templatePage = 0;
            }),
          ),
      ],
      display: widget.display,
      onDisplayChanged: widget.onDisplayChanged,
      groupedTableView: ActivityDirectoryTableView.grouped,
      selectedTableView: ActivityDirectoryTableView.grouped,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(
          value: ActivityDirectoryTableView.grouped,
          label: 'Tabela',
        ),
      ],
      onTableViewSelected: (_) => widget.onDisplayChanged(CoeloAdminDirectoryDisplay.table),
      fileActionsBusyLabel: _fileActionLabel,
      fileActions: [
        CoeloAdminFileAction(
          key: const Key('activity-template-files-import'),
          label: 'Importar',
          icon: Icons.upload_file_outlined,
          onPressed: _openImport,
        ),
        CoeloAdminFileAction(
          key: const Key('activity-template-files-export'),
          label: 'Exportar',
          icon: Icons.download_outlined,
          onPressed: () => _export(ActivityDirectoryExportFormat.xlsx),
        ),
      ],
      tabs: CoeloAdminDirectoryStatusTabs(
        key: const Key('activity-template-status-tabs'),
        selected: _templateStatus,
        onSelected: (value) => setState(() {
          _templateStatus = value;
          _templatePage = 0;
        }),
      ),
      create: onCreate == null
          ? null
          : CoeloAdminDirectoryCreate(
              label: 'Criar modelo',
              description: 'Adicionar um modelo institucional de atividade.',
              icon: Icons.add_task_rounded,
              onPressed: options == null ? _loadTemplates : _requestCreateTemplate,
              tileKey: const Key('create-activity-template-tile'),
              bannerKey: const Key('create-activity-template-banner'),
              bannerSurfaceKey: const Key('create-activity-template-banner-surface'),
            ),
      cards: [
        if (options != null)
          for (final template in pageTemplates)
            _ActivityTemplateCard(
              template: template,
              taxonomy: options.taxonomy,
              onStart: widget.onCreateFromTemplate,
              onDuplicate: canDuplicate ? _requestDuplicate : null,
            ),
      ],
      table: options == null
          ? null
          : _ActivityTemplateRows(
              templates: pageTemplates,
              taxonomy: options.taxonomy,
              onStart: widget.onCreateFromTemplate,
              onDuplicate: canDuplicate ? _requestDuplicate : null,
            ),
      pagination: pageCount > 1
          ? CoeloAdminDirectoryPagination(
              currentPage: safePage + 1,
              totalPages: pageCount,
              pageSize: _templatePageSize,
              pageSizeOptions: const [_templatePageSize],
              onPageSelected: (page) => setState(() => _templatePage = page - 1),
              onPageSizeChanged: (_) {},
            )
          : null,
      onFooterHeightChanged: widget.onFooterHeightChanged,
    );
  }

  List<ActivityTemplateOption> _visibleTemplates(ActivityTemplateOptions current) {
    final taxonomyTemplates = _selectedTemplateTaxonomyIds.isEmpty
        ? current.templates
        : current.templates
              .where((template) => _selectedTemplateTaxonomyIds.contains(template.taxonomyId))
              .toList(growable: false);
    final originTemplates = taxonomyTemplates.where(
      (template) => switch (_templateOrigin) {
        'Coelo' => template.scopeKind == ActivityTemplateScopeKind.platform,
        'Institucional' => template.scopeKind == ActivityTemplateScopeKind.institution,
        _ => true,
      },
    );
    final statuses = _statusesForTab(_templateStatus);
    final statusTemplates = originTemplates.where(
      (template) => statuses.isEmpty || statuses.contains(template.status),
    );
    final normalizedSearch = _templateSearch.toLowerCase();
    return normalizedSearch.isEmpty
        ? statusTemplates.toList(growable: false)
        : statusTemplates
              .where(
                (template) =>
                    template.name.toLowerCase().contains(normalizedSearch) ||
                    template.description.toLowerCase().contains(normalizedSearch),
              )
              .toList(growable: false);
  }
}

String _taxonomyLabel(List<ActivityTaxonomyOption> taxonomy, String taxonomyId) =>
    taxonomy.where((item) => item.id == taxonomyId).firstOrNull?.label ?? 'Categoria não informada';

String _templateScopeLabel(ActivityTemplateOption template) =>
    template.scopeKind == ActivityTemplateScopeKind.platform
    ? 'Modelo Coelo'
    : 'Modelo institucional';

/// Card de domínio de um modelo de atividade; largura e grade vêm do composto.
final class _ActivityTemplateCard extends StatelessWidget {
  const _ActivityTemplateCard({
    required this.template,
    required this.taxonomy,
    required this.onStart,
    required this.onDuplicate,
  });

  final ActivityTemplateOption template;
  final List<ActivityTaxonomyOption> taxonomy;
  final ActivityTemplateStarter? onStart;
  final ValueChanged<ActivityTemplateOption>? onDuplicate;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    key: Key('activity-template-${template.id}'),
    semanticLabel: 'Começar atividade a partir de ${template.name}',
    onPressed: onStart == null ? null : () => onStart!(template),
    minHeight: CoeloAdminDirectoryMetrics.cardMinHeight,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(template.name, style: Theme.of(context).textTheme.titleMedium)),
              if (onDuplicate != null)
                IconButton(
                  key: Key('activity-template-duplicate-${template.id}'),
                  tooltip: 'Duplicar ${template.name}',
                  onPressed: () => onDuplicate!(template),
                  icon: const Icon(Icons.content_copy_rounded),
                ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text(_templateScopeLabel(template)),
          if (template.description.trim().isNotEmpty) ...[
            const SizedBox(height: CoeloSpacing.space1),
            Text(template.description),
          ],
          const SizedBox(height: CoeloSpacing.space1),
          Text(_taxonomyLabel(taxonomy, template.taxonomyId)),
          if (onStart != null)
            TextButton.icon(
              key: Key('activity-template-start-${template.id}'),
              onPressed: () => onStart!(template),
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Começar a partir deste modelo'),
            ),
        ],
      ),
    ),
  );
}

/// Linhas de domínio dos modelos sobre a tabela compartilhada.
final class _ActivityTemplateRows extends StatelessWidget {
  const _ActivityTemplateRows({
    required this.templates,
    required this.taxonomy,
    required this.onStart,
    required this.onDuplicate,
  });

  final List<ActivityTemplateOption> templates;
  final List<ActivityTaxonomyOption> taxonomy;
  final ActivityTemplateStarter? onStart;
  final ValueChanged<ActivityTemplateOption>? onDuplicate;

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<ActivityTemplateOption>(
    key: const Key('activity-template-table'),
    items: templates,
    rowKey: (template) => 'activity-template-row-${template.id}',
    pinnedColumn: CoeloAdminTableColumn(
      id: 'name',
      label: 'Modelo',
      initialWidth: 280,
      minWidth: 180,
      maxWidth: 420,
      cellBuilder: (_, template) => Text(template.name),
    ),
    columns: [
      CoeloAdminTableColumn(
        id: 'scope',
        label: 'Origem',
        initialWidth: 180,
        minWidth: 140,
        maxWidth: 240,
        cellBuilder: (_, template) => Text(_templateScopeLabel(template)),
      ),
      CoeloAdminTableColumn(
        id: 'category',
        label: 'Categoria',
        initialWidth: 180,
        minWidth: 140,
        maxWidth: 260,
        cellBuilder: (_, template) => Text(_taxonomyLabel(taxonomy, template.taxonomyId)),
      ),
      CoeloAdminTableColumn(
        id: 'actions',
        label: 'Ações',
        initialWidth: 180,
        minWidth: 144,
        maxWidth: 220,
        cellBuilder: (context, template) => Row(
          children: [
            if (onDuplicate != null)
              IconButton(
                key: Key('activity-template-table-duplicate-${template.id}'),
                tooltip: 'Duplicar ${template.name}',
                onPressed: () => onDuplicate!(template),
                icon: const Icon(Icons.content_copy_rounded),
              ),
            if (onStart != null)
              IconButton(
                key: Key('activity-template-table-start-${template.id}'),
                tooltip: 'Começar atividade de ${template.name}',
                onPressed: () => onStart!(template),
                icon: const Icon(Icons.playlist_add_rounded),
              ),
          ],
        ),
      ),
    ],
    headerHeight: 56,
    rowHeight: 64,
  );
}

final class _ActivityTemplateCreatePage extends StatefulWidget {
  const _ActivityTemplateCreatePage({
    required this.institutions,
    required this.taxonomy,
    required this.onCreate,
  });

  final List<ActivityFormInstitutionOption> institutions;
  final List<ActivityTaxonomyOption> taxonomy;
  final ActivityTemplateCreator onCreate;

  @override
  State<_ActivityTemplateCreatePage> createState() => _ActivityTemplateCreatePageState();
}

final class _ActivityTemplateCreatePageState extends State<_ActivityTemplateCreatePage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String? _institutionId;
  String? _taxonomyId;
  ActivityGovernance _governance = ActivityGovernance.optional;
  String? _error;
  bool _submitting = false;
  int _step = 0;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (_institutionId == null || name.isEmpty || _taxonomyId == null) {
      setState(() => _error = 'Preencha instituição, nome e categoria.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onCreate(
        ActivityTemplateCreateDraft(
          institutionId: _institutionId!,
          name: name,
          description: _description.text.trim(),
          taxonomyId: _taxonomyId!,
          governance: _governance,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Não foi possível criar o modelo. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _advance() {
    if (_step == 0 && (_institutionId == null || _taxonomyId == null)) {
      setState(() => _error = 'Preencha instituição e categoria.');
      return;
    }
    if (_step == 1 && _name.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome do modelo.');
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('activity-template-create-page'),
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Voltar para modelos',
        onPressed: _submitting ? null : Navigator.of(context).pop,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Criar modelo de atividade'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Configure o contexto e a identidade do modelo.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space6),
                  SuperadminFormStepNavigation(
                    steps: [
                      SuperadminFormStep(
                        label: 'Contexto',
                        status: _step == 0
                            ? SuperadminFormStepStatus.current
                            : SuperadminFormStepStatus.complete,
                      ),
                      SuperadminFormStep(
                        label: 'Identidade do modelo',
                        status: _step == 1
                            ? SuperadminFormStepStatus.current
                            : _step > 1
                            ? SuperadminFormStepStatus.complete
                            : SuperadminFormStepStatus.incomplete,
                      ),
                      SuperadminFormStep(
                        label: 'Revisão',
                        status: _step == 2
                            ? SuperadminFormStepStatus.current
                            : SuperadminFormStepStatus.incomplete,
                      ),
                    ],
                    currentIndex: _step,
                    onStepSelected: (index) {
                      if (index < _step) setState(() => _step = index);
                    },
                  ),
                  const SizedBox(height: CoeloSpacing.space6),
                  if (_step == 0) ...[
                    CoeloAdminSingleSelectField<String?>(
                      key: const Key('activity-template-create-institution'),
                      label: 'Instituição',
                      value: _institutionId,
                      options: [null, ...widget.institutions.map((item) => item.id)],
                      optionLabel: (id) => id == null
                          ? 'Selecione uma instituição'
                          : widget.institutions.firstWhere((item) => item.id == id).name,
                      onChanged: (value) => setState(() {
                        _institutionId = value;
                        _error = null;
                      }),
                      prefixIcon: Icons.apartment_outlined,
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    CoeloAdminSingleSelectField<String?>(
                      key: const Key('activity-template-create-taxonomy'),
                      label: 'Categoria',
                      value: _taxonomyId,
                      options: [null, ...widget.taxonomy.map((item) => item.id)],
                      optionLabel: (id) => id == null
                          ? 'Selecione uma categoria'
                          : widget.taxonomy.firstWhere((item) => item.id == id).label,
                      onChanged: (value) => setState(() {
                        _taxonomyId = value;
                        _error = null;
                      }),
                      prefixIcon: Icons.category_outlined,
                    ),
                  ] else if (_step == 1) ...[
                    CoeloFormTextField(
                      fieldKey: const Key('activity-template-create-name'),
                      controller: _name,
                      labelText: 'Nome',
                      prefixIcon: Icons.local_activity_outlined,
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    CoeloFormTextField(
                      fieldKey: const Key('activity-template-create-description'),
                      controller: _description,
                      labelText: 'Descrição',
                      prefixIcon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    CoeloAdminSingleSelectField<ActivityGovernance>(
                      key: const Key('activity-template-create-governance'),
                      label: 'Tipo de atividade',
                      value: _governance,
                      options: const [ActivityGovernance.optional, ActivityGovernance.mandatory],
                      optionLabel: (value) => value.label,
                      onChanged: (value) => setState(() => _governance = value),
                      prefixIcon: Icons.rule_rounded,
                    ),
                  ] else ...[
                    Text('Revise o modelo', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: CoeloSpacing.space2),
                    Text(_name.text.trim()),
                    Text(
                      widget.institutions.firstWhere((item) => item.id == _institutionId).name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    const CoeloStatePanel(
                      title: 'Sem vínculos nesta etapa',
                      message:
                          'O modelo será criado sem unidades, turmas, alunos ou profissionais vinculados.',
                      icon: Icons.link_off_rounded,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: CoeloSpacing.space2),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                  const SizedBox(height: CoeloSpacing.space8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: CoeloSpacing.space3,
                    runSpacing: CoeloSpacing.space2,
                    children: [
                      OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : _step == 0
                            ? Navigator.of(context).pop
                            : () => setState(() => _step--),
                        child: Text(_step == 0 ? 'Cancelar' : 'Anterior'),
                      ),
                      FilledButton(
                        key: Key(
                          _step < 2
                              ? 'activity-template-create-next'
                              : 'activity-template-create-submit',
                        ),
                        onPressed: _submitting ? null : (_step < 2 ? _advance : _submit),
                        child: Text(
                          _step < 2 ? 'Continuar' : (_submitting ? 'Criando...' : 'Criar modelo'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _ActivityTemplateCopyDialog extends StatefulWidget {
  const _ActivityTemplateCopyDialog({
    required this.template,
    required this.institutions,
    required this.units,
    required this.onDuplicate,
  });

  final ActivityTemplateOption template;
  final List<ActivityFormInstitutionOption> institutions;
  final List<ActivityFormUnitOption> units;
  final ActivityTemplateDuplicator onDuplicate;

  @override
  State<_ActivityTemplateCopyDialog> createState() => _ActivityTemplateCopyDialogState();
}

final class _ActivityTemplateCopyDialogState extends State<_ActivityTemplateCopyDialog> {
  final TextEditingController _name = TextEditingController();
  String? _institutionId;
  String? _unitId;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final match = RegExp(r'^(.*) \((\d+)\)$').firstMatch(widget.template.name.trim());
    final base = match?.group(1) ?? widget.template.name.trim();
    final sequence = (int.tryParse(match?.group(2) ?? '') ?? 0) + 1;
    _name.text = '$base ($sequence)';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final institutionId = _institutionId;
    final newName = _name.text.trim();
    if (newName.isEmpty) {
      setState(() => _error = 'Informe o novo nome do modelo.');
      return;
    }
    if (institutionId == null) {
      setState(() => _error = 'Selecione a instituição da cópia.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onDuplicate(widget.template, institutionId, _unitId, newName);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Não foi possível duplicar o modelo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    dialogKey: const Key('activity-template-copy-dialog'),
    title: 'Duplicar',
    closeTooltip: 'Fechar duplicação de modelo',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.template.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space3),
        CoeloFormTextField(
          fieldKey: const Key('activity-template-copy-name'),
          controller: _name,
          labelText: 'Novo nome',
          prefixIcon: Icons.drive_file_rename_outline_rounded,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: CoeloSpacing.space3),
        CoeloAdminSingleSelectField<String?>(
          key: const Key('activity-template-copy-institution'),
          label: 'Instituição',
          value: _institutionId,
          options: [null, ...widget.institutions.map((item) => item.id)],
          optionLabel: (id) => id == null
              ? 'Selecione uma instituição'
              : widget.institutions.firstWhere((item) => item.id == id).name,
          onChanged: (value) => setState(() {
            _institutionId = value;
            _unitId = null;
            _error = null;
          }),
          prefixIcon: Icons.apartment_outlined,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        CoeloAdminSingleSelectField<String?>(
          key: const Key('activity-template-copy-unit'),
          label: 'Unidade (opcional)',
          value: _unitId,
          options: [
            null,
            ...widget.units
                .where((item) => item.institutionId == _institutionId)
                .map((item) => item.id),
          ],
          optionLabel: (id) => id == null
              ? 'Todas as unidades da instituição'
              : widget.units.firstWhere((item) => item.id == id).name,
          onChanged: (value) {
            if (_institutionId == null) return;
            setState(() {
              _unitId = value;
              _error = null;
            });
          },
          prefixIcon: Icons.business_outlined,
        ),
        if (_error != null) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: _submitting ? null : Navigator.of(context).pop,
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      key: const Key('activity-template-copy-submit'),
      onPressed: _submitting ? null : _submit,
      child: Text(_submitting ? 'Duplicando...' : 'Duplicar modelo'),
    ),
  );
}

final class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item, required this.onPressed, required this.opensEdit});

  final ActivityDirectoryItem item;
  final VoidCallback onPressed;
  final bool opensEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      key: Key('activity-card-${item.id}'),
      constraints: const BoxConstraints(minHeight: 216),
      child: CoeloAdminInteractiveCard(
        surfaceKey: Key('activity-card-surface-${item.id}'),
        semanticLabel: '${opensEdit ? 'Editar' : 'Visualizar'} atividade ${item.name}',
        onPressed: onPressed,
        minHeight: 216,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space6,
            vertical: CoeloSpacing.space4,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActivityCardHeader(item: item, colors: colors),
              const SizedBox(height: CoeloSpacing.space4),
              const Divider(height: 1),
              const SizedBox(height: CoeloSpacing.space4),
              _DetailRow(
                first: _ActivityDetail(
                  icon: Icons.apartment_outlined,
                  label: 'Unidades',
                  value: '${item.activeUnitCount}',
                ),
                second: _ActivityDetail(
                  icon: Icons.groups_outlined,
                  label: 'Turmas',
                  value: '${item.activeGroupCount}',
                ),
              ),
              const SizedBox(height: CoeloSpacing.space3),
              _DetailRow(
                first: _ActivityDetail(
                  icon: Icons.apartment_outlined,
                  label: 'Instituição',
                  value: item.institutionName,
                ),
                second: _ActivityDetail(
                  icon: Icons.rule_rounded,
                  label: 'Tipo',
                  value: item.governance.label,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ActivityCardHeader extends StatelessWidget {
  const _ActivityCardHeader({required this.item, required this.colors});

  final ActivityDirectoryItem item;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            item.institutionName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
    final identity = Row(
      children: [
        _ActivityIcon(colors: colors),
        const SizedBox(width: CoeloSpacing.space3),
        title,
      ],
    );
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.8) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          identity,
          const SizedBox(height: CoeloSpacing.space2),
          Align(
            alignment: Alignment.centerRight,
            child: _ActivityExpandableStatusIndicator(itemId: item.id, status: item.status),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: identity),
        const SizedBox(width: CoeloSpacing.space2),
        _ActivityExpandableStatusIndicator(itemId: item.id, status: item.status),
      ],
    );
  }
}

final class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 44,
    child: DecoratedBox(
      decoration: BoxDecoration(color: colors.secondaryContainer, shape: BoxShape.circle),
      child: Icon(Icons.local_activity_rounded, color: colors.onSecondaryContainer),
    ),
  );
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: first),
      const SizedBox(width: CoeloSpacing.space3),
      Expanded(child: second),
    ],
  );
}

final class _ActivityDetail extends StatelessWidget {
  const _ActivityDetail({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: CoeloSpacing.space8,
          height: CoeloSpacing.space8,
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.sm),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: CoeloSize.iconSm, color: colors.onSurfaceVariant),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(height: CoeloSpacing.spaceHalf),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Linhas e colunas de domínio das atividades sobre a tabela compartilhada.
final class _ActivityTableRows extends StatelessWidget {
  const _ActivityTableRows({required this.items, required this.viewModel, required this.onView});

  final List<ActivityDirectoryItem> items;
  final ActivityDirectoryViewModel viewModel;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) {
    CoeloAdminTableColumn<ActivityDirectoryItem> column(
      String id,
      String label,
      String Function(ActivityDirectoryItem) value, {
      double width = 180,
    }) => CoeloAdminTableColumn(
      id: id,
      label: label,
      initialWidth: width,
      minWidth: 100,
      maxWidth: 360,
      cellBuilder: (context, item) => Align(
        alignment: Alignment.centerLeft,
        child: Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        key: const Key('activity-directory-table-viewport'),
        width: constraints.maxWidth,
        child: Semantics(
          label: 'Tabela de atividades. Selecione uma linha para visualizar a atividade.',
          child: CoeloAdminResizableTable<ActivityDirectoryItem>(
            key: const Key('activity-directory-table'),
            items: items,
            rowKey: (item) => 'activity-table-row-${item.id}',
            headerHeight: 56,
            rowHeight: 64,
            onRowPressed: (item) => onView(item.id),
            sortColumnId: 'activity',
            sortAscending: viewModel.query.sortAscending,
            onSort: (_) => viewModel.setSort(!viewModel.query.sortAscending),
            pinnedColumn: CoeloAdminTableColumn(
              id: 'activity',
              label: 'Atividade',
              initialWidth: 280,
              minWidth: 180,
              maxWidth: 600,
              sortable: true,
              cellBuilder: (context, item) => Row(
                children: [
                  _ActivityIcon(colors: Theme.of(context).colorScheme),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
            columns: [
              column('institution', 'Instituição', (item) => item.institutionName, width: 240),
              column('units', 'Unidades', (item) => '${item.activeUnitCount}', width: 132),
              column('groups', 'Turmas', (item) => '${item.activeGroupCount}', width: 132),
              column('origin', 'Origem', (item) => item.origin.label),
              column('distribution', 'Distribuição', (item) => item.distribution.label, width: 210),
              column('governance', 'Governança', (item) => item.governance.label, width: 176),
              CoeloAdminTableColumn(
                id: 'status',
                label: 'Status',
                initialWidth: 176,
                minWidth: 120,
                maxWidth: 260,
                cellBuilder: (context, item) => Align(
                  alignment: Alignment.centerLeft,
                  child: _ActivityStatusChip(status: item.status),
                ),
              ),
              column('updated', 'Atualização', (item) => _formatDate(item.updatedAt), width: 164),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ActivityHierarchyRows extends StatelessWidget {
  const _ActivityHierarchyRows({
    required this.items,
    required this.level,
    required this.onView,
    super.key,
  });

  final List<ActivityDirectoryItem> items;
  final ActivityDirectoryTableView level;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) {
    CoeloAdminTableColumn<ActivityDirectoryItem> column(
      String id,
      String label,
      String Function(ActivityDirectoryItem) value, {
      double width = 190,
    }) => CoeloAdminTableColumn(
      id: id,
      label: label,
      initialWidth: width,
      minWidth: 120,
      maxWidth: 380,
      cellBuilder: (context, item) => Align(
        alignment: Alignment.centerLeft,
        child: Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: CoeloAdminResizableTable<ActivityDirectoryItem>(
          items: items,
          rowKey: (item) => 'activity-hierarchy-row-${item.id}',
          headerHeight: 56,
          rowHeight: 64,
          onRowPressed: (item) => onView(item.id),
          pinnedColumn: column(
            'hierarchy',
            level == ActivityDirectoryTableView.units ? 'Unidades vinculadas' : 'Turmas vinculadas',
            (item) => level == ActivityDirectoryTableView.units
                ? item.linkedUnits.map((unit) => unit.name).join(', ')
                : item.linkedGroups.map((group) => group.name).join(', '),
            width: 240,
          ),
          columns: [
            column('activity', 'Atividade', (item) => item.name, width: 240),
            column('institution', 'Instituição', (item) => item.institutionName, width: 240),
            column('origin', 'Origem', (item) => item.origin.label),
            CoeloAdminTableColumn(
              id: 'status',
              label: 'Status',
              initialWidth: 176,
              minWidth: 120,
              maxWidth: 260,
              cellBuilder: (context, item) => Align(
                alignment: Alignment.centerLeft,
                child: _ActivityStatusChip(
                  key: Key('activity-detail-status-${item.id}'),
                  status: item.status,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ActivityExpandableStatusIndicator extends StatelessWidget {
  const _ActivityExpandableStatusIndicator({required this.itemId, required this.status});

  final String itemId;
  final ActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _activityStatusColors(context, status);
    return CoeloAdminExpandableStatusIndicator(
      surfaceKey: Key('activity-card-status-$itemId'),
      label: status.label,
      semanticLabel: 'Status da atividade: ${status.label}',
      backgroundColor: colors.$1,
      foregroundColor: colors.$2,
    );
  }
}

final class _ActivityStatusChip extends StatelessWidget {
  const _ActivityStatusChip({required this.status, super.key});

  final ActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = _activityStatusColors(context, status);
    return CoeloStatusChip(
      label: status.label,
      backgroundColor: colors.$1,
      foregroundColor: colors.$2,
    );
  }
}

(Color, Color) _activityStatusColors(BuildContext context, ActivityStatus status) {
  final theme = Theme.of(context);
  final statusColors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  return switch (status) {
    ActivityStatus.active => (statusColors.successContainer, statusColors.onSuccessContainer),
    ActivityStatus.suspended => (statusColors.errorContainer, statusColors.onErrorContainer),
    ActivityStatus.draft => (statusColors.warningContainer, statusColors.onWarningContainer),
    ActivityStatus.inactive || ActivityStatus.archived => (
      theme.colorScheme.surfaceContainer,
      theme.colorScheme.onSurfaceVariant,
    ),
  };
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
