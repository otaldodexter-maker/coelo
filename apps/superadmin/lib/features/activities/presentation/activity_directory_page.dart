import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_directory_create_banner.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/activity_directory.dart';
import 'activity_directory_view_model.dart';

enum ActivityDirectoryDisplay { cards, table }

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

enum _ActivityStatusTab { all, active, draft, inactive }

double _activityCardWidth(double availableWidth) {
  final columns = math.max(1, (availableWidth / 340).floor());
  return (availableWidth - (columns - 1) * CoeloSpacing.space6) / columns;
}

Set<ActivityStatus> _statusesForTab(_ActivityStatusTab tab) => switch (tab) {
  _ActivityStatusTab.all => const {},
  _ActivityStatusTab.active => const {ActivityStatus.active},
  _ActivityStatusTab.draft => const {ActivityStatus.draft},
  _ActivityStatusTab.inactive => const {
    ActivityStatus.inactive,
    ActivityStatus.suspended,
    ActivityStatus.archived,
  },
};

_ActivityStatusTab _tabForStatuses(Set<ActivityStatus> statuses) {
  if (statuses.isEmpty) return _ActivityStatusTab.all;
  if (statuses.length == 1 && statuses.contains(ActivityStatus.active)) {
    return _ActivityStatusTab.active;
  }
  if (statuses.length == 1 && statuses.contains(ActivityStatus.draft)) {
    return _ActivityStatusTab.draft;
  }
  return _ActivityStatusTab.inactive;
}

final class _ActivityStatusTabs extends StatelessWidget {
  const _ActivityStatusTabs({required this.selected, required this.onSelected});

  final _ActivityStatusTab selected;
  final ValueChanged<_ActivityStatusTab> onSelected;

  @override
  Widget build(BuildContext context) => SuperadminUnderlineTabs<_ActivityStatusTab>(
    key: const Key('activity-status-tabs'),
    selected: selected,
    tabs: const [
      SuperadminUnderlineTab(value: _ActivityStatusTab.all, label: 'Todos'),
      SuperadminUnderlineTab(value: _ActivityStatusTab.active, label: 'Ativos'),
      SuperadminUnderlineTab(value: _ActivityStatusTab.draft, label: 'Rascunho'),
      SuperadminUnderlineTab(value: _ActivityStatusTab.inactive, label: 'Inativos'),
    ],
    onSelected: onSelected,
  );
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
  late final ActivityDirectoryViewModel _viewModel;
  late final SuperadminActivityController _activityController;
  late final TextEditingController _searchController;
  ActivityDirectoryDisplay _display = ActivityDirectoryDisplay.cards;
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
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _setDisplay(ActivityDirectoryDisplay display) {
    if (_display == display) return;
    setState(() => _display = display);
    _viewModel.setPageSize(display == ActivityDirectoryDisplay.cards ? 11 : 8);
  }

  void _setTableView(ActivityDirectoryTableView tableView) {
    setState(() {
      _display = ActivityDirectoryDisplay.table;
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
    this.onEdit,
    required this.onFooterHeightChanged,
    this.onExportRequested,
    this.onImportRequested,
    required this.repository,
    this.onCreateFromTemplate,
    this.onDuplicateTemplate,
    this.onCreateTemplate,
  });

  final ActivityDirectoryViewModel viewModel;
  final TextEditingController searchController;
  final ActivityDirectoryDisplay display;
  final ActivityDirectoryTableView tableView;
  final ValueChanged<ActivityDirectoryDisplay> onDisplayChanged;
  final ValueChanged<ActivityDirectoryTableView> onTableViewChanged;
  final VoidCallback? onCreate;
  final ValueChanged<String> onView;
  final ValueChanged<String>? onEdit;
  final ValueChanged<double> onFooterHeightChanged;
  final ActivityDirectoryExporter? onExportRequested;
  final ActivityDirectoryImportRequested? onImportRequested;
  final ActivityDirectoryRepository repository;
  final ActivityTemplateStarter? onCreateFromTemplate;
  final ActivityTemplateDuplicator? onDuplicateTemplate;
  final ActivityTemplateCreator? onCreateTemplate;

  @override
  State<_ActivityDirectoryContent> createState() => _ActivityDirectoryContentState();
}

final class _ActivityDirectoryContentState extends State<_ActivityDirectoryContent> {
  final GlobalKey _footerKey = GlobalKey();
  double _footerHeight = 0;
  bool _measurementScheduled = false;
  String? _fileActionLabel;
  ActivityTemplateOptions? _templateOptions;
  bool _templatesLoading = false;
  bool _templatesFailed = false;
  bool _templatesRequested = false;
  final Set<String> _selectedTemplateTaxonomyIds = {};
  final TextEditingController _templateSearchController = TextEditingController();
  _ActivityContentKind _content = _ActivityContentKind.templates;
  String _templateSearch = '';
  String _templateOrigin = 'Todas';
  _ActivityStatusTab _templateStatus = _ActivityStatusTab.all;
  int _templatePage = 0;

  bool get _templatesEnabled =>
      widget.onCreateFromTemplate != null || widget.onDuplicateTemplate != null;

  @override
  void dispose() {
    _templateSearchController.dispose();
    super.dispose();
  }

  Future<bool> _loadTemplates({String? institutionId}) async {
    _templatesRequested = true;
    setState(() {
      _templatesLoading = true;
      _templatesFailed = false;
    });
    try {
      final options = await widget.repository.fetchTemplateOptions(institutionId: institutionId);
      if (!mounted) return false;
      setState(() => _templateOptions = options);
      return true;
    } catch (_) {
      if (mounted) setState(() => _templatesFailed = true);
      return false;
    } finally {
      if (mounted) setState(() => _templatesLoading = false);
    }
  }

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

  void _measureFooter(bool visible) {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      var height = 0.0;
      if (visible) {
        final box = _footerKey.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.hasSize) return;
        height = box.size.height;
      }
      if ((height - _footerHeight).abs() < .5) return;
      setState(() => _footerHeight = height);
      widget.onFooterHeightChanged(height);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space6
          : CoeloSpacing.space4;
      return AnimatedBuilder(
        animation: widget.viewModel,
        builder: (context, _) {
          final directoryUnauthorized =
              widget.viewModel.state == ActivityDirectoryLoadState.unauthorized;
          final directoryPending =
              widget.viewModel.state == ActivityDirectoryLoadState.initial ||
              widget.viewModel.state == ActivityDirectoryLoadState.loading;
          final showingActivities =
              !_templatesEnabled || _content == _ActivityContentKind.activities;
          final showFooter =
              showingActivities && widget.viewModel.state == ActivityDirectoryLoadState.success;
          final showTemplates =
              _templatesEnabled &&
              !showingActivities &&
              widget.viewModel.state != ActivityDirectoryLoadState.initial &&
              widget.viewModel.state != ActivityDirectoryLoadState.loading &&
              widget.viewModel.state != ActivityDirectoryLoadState.unauthorized;
          if (showTemplates && !_templatesRequested) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_templatesRequested) _loadTemplates();
            });
          }
          _measureFooter(showFooter);
          return Stack(
            fit: StackFit.expand,
            children: [
              ListView(
                key: const Key('activity-directory-scroll'),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  padding,
                  padding,
                  padding + (showFooter ? _footerHeight + CoeloSpacing.space4 : 0),
                ),
                children: [
                  if (_templatesEnabled && !directoryUnauthorized) ...[
                    SuperadminUnderlineTabs<_ActivityContentKind>(
                      key: const Key('activity-type-tabs'),
                      selected: _content,
                      tabs: const [
                        SuperadminUnderlineTab(
                          value: _ActivityContentKind.templates,
                          label: 'Modelos',
                        ),
                        SuperadminUnderlineTab(
                          value: _ActivityContentKind.activities,
                          label: 'Atividades',
                        ),
                      ],
                      onSelected: (value) => setState(() => _content = value),
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                  ],
                  if (directoryUnauthorized)
                    const SizedBox.shrink()
                  else if (showingActivities)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ActivityToolbar(
                          viewModel: widget.viewModel,
                          searchController: widget.searchController,
                          display: widget.display,
                          tableView: widget.tableView,
                          onDisplayChanged: widget.onDisplayChanged,
                          onTableViewChanged: widget.onTableViewChanged,
                          fileActionLabel: _fileActionLabel,
                          onExport: _export,
                          onImport: _openImport,
                        ),
                        const SizedBox(height: CoeloSpacing.space3),
                        _ActivityStatusTabs(
                          selected: _tabForStatuses(widget.viewModel.query.statuses),
                          onSelected: (value) =>
                              widget.viewModel.setStatuses(_statusesForTab(value)),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CoeloAdminListingToolbar(
                          key: const Key('activity-template-toolbar'),
                          search: SizedBox(
                            width: 300,
                            height: CoeloSize.touchMin,
                            child: CoeloSearchField(
                              key: const Key('activity-template-search'),
                              controller: _templateSearchController,
                              hintText: 'Buscar modelo',
                              semanticLabel: 'Buscar modelo de atividade',
                              onChanged: (value) => setState(() {
                                _templateSearch = value.trim();
                                _templatePage = 0;
                              }),
                            ),
                          ),
                          filters: [
                            SizedBox(
                              width: 168,
                              child: CoeloAdminSingleSelectField<String>(
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
                            ),
                            if (_templateOptions case final options?)
                              SizedBox(
                                width: 196,
                                child: CoeloAdminMultiSelectFilter<ActivityTaxonomyOption>(
                                  key: const Key('activity-template-taxonomy-filter'),
                                  label: 'Categorias',
                                  options: options.taxonomy,
                                  selectedValues: options.taxonomy
                                      .where(
                                        (item) => _selectedTemplateTaxonomyIds.contains(item.id),
                                      )
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
                              ),
                          ],
                          actions: [
                            SuperadminDirectoryViewToggle<ActivityDirectoryTableView>(
                              cardsSelected: widget.display == ActivityDirectoryDisplay.cards,
                              groupedView: ActivityDirectoryTableView.grouped,
                              selectedTableView: ActivityDirectoryTableView.grouped,
                              tableViews: const [
                                SuperadminDirectoryTableViewOption(
                                  value: ActivityDirectoryTableView.grouped,
                                  label: 'Tabela',
                                ),
                              ],
                              cardsKey: const Key('activity-template-view-cards'),
                              tableKey: const Key('activity-template-view-table'),
                              onCardsSelected: () =>
                                  widget.onDisplayChanged(ActivityDirectoryDisplay.cards),
                              onTableViewSelected: (_) =>
                                  widget.onDisplayChanged(ActivityDirectoryDisplay.table),
                            ),
                            CoeloAdminFileActions(
                              actions: [
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
                            ),
                          ],
                        ),
                        const SizedBox(height: CoeloSpacing.space3),
                        _ActivityStatusTabs(
                          selected: _templateStatus,
                          onSelected: (value) => setState(() {
                            _templateStatus = value;
                            _templatePage = 0;
                          }),
                        ),
                      ],
                    ),

                  if (!directoryUnauthorized) const SizedBox(height: CoeloSpacing.space4),
                  if (showTemplates) ...[
                    _ActivityTemplateSection(
                      options: _templateOptions,
                      loading: _templatesLoading,
                      failed: _templatesFailed,
                      onRetry: () => _loadTemplates(),
                      selectedTaxonomyIds: _selectedTemplateTaxonomyIds,
                      onTaxonomyChanged: (value) => setState(() {
                        _selectedTemplateTaxonomyIds
                          ..clear()
                          ..addAll(value);
                        _templatePage = 0;
                      }),
                      search: _templateSearch,
                      origin: _templateOrigin,
                      status: _templateStatus,
                      page: _templatePage,
                      onPageChanged: (value) => setState(() => _templatePage = value),
                      onClearFilters: () => setState(() {
                        _templateSearchController.clear();
                        _templateSearch = '';
                        _templateOrigin = 'Todas';
                        _templateStatus = _ActivityStatusTab.all;
                        _selectedTemplateTaxonomyIds.clear();
                        _templatePage = 0;
                      }),
                      display: widget.display,
                      onStart: widget.onCreateFromTemplate,
                      onDuplicate: widget.onDuplicateTemplate == null ? null : _duplicateTemplate,
                      onCreate: widget.onCreateTemplate,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                  ],
                  if (showingActivities || directoryPending || directoryUnauthorized)
                    _ActivityResults(
                      viewModel: widget.viewModel,
                      display: widget.display,
                      tableView: widget.tableView,
                      onCreate: widget.onCreate,
                      onView: widget.onEdit ?? widget.onView,
                      opensEdit: widget.onEdit != null,
                    ),
                ],
              ),
              if (showFooter)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SizeChangedLayoutNotifier(
                    key: _footerKey,
                    child: NotificationListener<SizeChangedLayoutNotification>(
                      onNotification: (_) {
                        _measureFooter(true);
                        return true;
                      },
                      child: _ActivityPaginationFooter(
                        viewModel: widget.viewModel,
                        display: widget.display,
                        horizontalPadding: padding,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

final class _ActivityToolbar extends StatelessWidget {
  const _ActivityToolbar({
    required this.viewModel,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
    required this.fileActionLabel,
    this.onExport,
    this.onImport,
  });

  final ActivityDirectoryViewModel viewModel;
  final TextEditingController searchController;
  final ActivityDirectoryDisplay display;
  final ActivityDirectoryTableView tableView;
  final ValueChanged<ActivityDirectoryDisplay> onDisplayChanged;
  final ValueChanged<ActivityDirectoryTableView> onTableViewChanged;
  final String? fileActionLabel;
  final Future<void> Function(ActivityDirectoryExportFormat format)? onExport;
  final Future<void> Function()? onImport;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final largeText = MediaQuery.textScalerOf(context).scale(1) >= 2;
      final filterWidth = largeText
          ? double.infinity
          : compact
          ? (constraints.maxWidth - CoeloSpacing.space3) / 2
          : 168.0;
      final searchWidth = compact ? constraints.maxWidth : 300.0;
      final options = viewModel.filterOptions;

      Widget filter<T>({
        required Key key,
        required String label,
        required List<T> values,
        required Set<T> selected,
        required String Function(T) optionLabel,
        required ValueChanged<Set<T>> onChanged,
      }) => SizedBox(
        key: key,
        width: filterWidth,
        child: CoeloAdminMultiSelectFilter<T>(
          label: label,
          options: values,
          selectedValues: selected,
          optionLabel: optionLabel,
          onChanged: onChanged,
        ),
      );

      final controls = <Widget>[
        SizedBox(
          width: searchWidth,
          height: CoeloSize.touchMin,
          child: CoeloSearchField(
            controller: searchController,
            hintText: 'Buscar por nome ou descrição',
            semanticLabel: 'Buscar atividade por nome ou descrição',
            onChanged: viewModel.setSearch,
          ),
        ),
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
        if (viewModel.query.hasActiveFilters ||
            viewModel.selectedUnitIds.isNotEmpty ||
            viewModel.selectedGroupIds.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              searchController.clear();
              viewModel.clearFilters();
            },
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpar filtros'),
          ),
      ];
      return CoeloAdminListingToolbar(
        key: const Key('activity-filter-toolbar'),
        search: Wrap(
          key: const Key('activity-filter-controls'),
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: controls,
        ),
        filters: const [],
        actions: [
          SuperadminDirectoryViewToggle<ActivityDirectoryTableView>(
            cardsSelected: display == ActivityDirectoryDisplay.cards,
            groupedView: ActivityDirectoryTableView.grouped,
            selectedTableView: tableView,
            tableViews: const [
              SuperadminDirectoryTableViewOption(
                value: ActivityDirectoryTableView.grouped,
                label: 'Agrupado',
              ),
              SuperadminDirectoryTableViewOption(
                value: ActivityDirectoryTableView.units,
                label: 'Por Unidades',
              ),
              SuperadminDirectoryTableViewOption(
                value: ActivityDirectoryTableView.groups,
                label: 'Por Turmas',
              ),
            ],
            cardsKey: const Key('activity-view-cards'),
            tableKey: const Key('activity-view-table'),
            onCardsSelected: () => onDisplayChanged(ActivityDirectoryDisplay.cards),
            onTableViewSelected: onTableViewChanged,
          ),
          if (fileActionLabel != null)
            Semantics(
              liveRegion: true,
              child: Text(fileActionLabel!, key: const Key('activity-file-action-loading')),
            )
          else
            CoeloAdminFileActions(
              compact: compact,
              actions: [
                CoeloAdminFileAction(
                  key: const Key('activity-files-import'),
                  label: 'Importar',
                  icon: Icons.upload_file_outlined,
                  onPressed: onImport!,
                ),
                CoeloAdminFileAction(
                  key: const Key('activity-files-export-csv'),
                  label: 'Exportar CSV',
                  icon: Icons.table_rows_outlined,
                  onPressed: () => onExport!(ActivityDirectoryExportFormat.csv),
                ),
                CoeloAdminFileAction(
                  key: const Key('activity-files-export-xlsx'),
                  label: 'Exportar XLSX',
                  icon: Icons.grid_on_outlined,
                  onPressed: () => onExport!(ActivityDirectoryExportFormat.xlsx),
                ),
              ],
            ),
        ],
      );
    },
  );
}

final class _ActivityTemplateSection extends StatelessWidget {
  const _ActivityTemplateSection({
    required this.options,
    required this.loading,
    required this.failed,
    required this.onRetry,
    required this.selectedTaxonomyIds,
    required this.onTaxonomyChanged,
    required this.search,
    required this.origin,
    required this.status,
    required this.page,
    required this.onPageChanged,
    required this.onClearFilters,
    required this.display,
    this.onStart,
    this.onDuplicate,
    this.onCreate,
  });

  final ActivityTemplateOptions? options;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;
  final Set<String> selectedTaxonomyIds;
  final ValueChanged<Set<String>> onTaxonomyChanged;
  final String search;
  final String origin;
  final _ActivityStatusTab status;
  final int page;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onClearFilters;
  final ActivityDirectoryDisplay display;
  final ActivityTemplateStarter? onStart;
  final ActivityTemplateDuplicator? onDuplicate;
  final ActivityTemplateCreator? onCreate;

  Future<void> _requestDuplicate(BuildContext context, ActivityTemplateOption template) async {
    await showDialog<void>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => _ActivityTemplateCopyDialog(
        template: template,
        institutions: options!.institutions,
        units: options!.units,
        onDuplicate: onDuplicate!,
      ),
    );
  }

  Future<void> _requestCreate(BuildContext context) async {
    final creator = onCreate;
    if (creator == null) return;
    final current = options;
    if (current == null) return;
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
    if (created == true && context.mounted) {
      showSuperadminNotice(context, 'Modelo criado com sucesso.', icon: Icons.add_task_rounded);
    }
  }

  Widget _withCreateAction(BuildContext context, Widget child) {
    if (onCreate == null) return child;
    final create = options == null ? onRetry : () => _requestCreate(context);
    if (display == ActivityDirectoryDisplay.table) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SuperadminDirectoryCreateBanner(
            label: 'Criar modelo',
            description: 'Adicionar um modelo institucional de atividade.',
            onPressed: create,
            bannerKey: const Key('create-activity-template-banner'),
            surfaceKey: const Key('create-activity-template-banner-surface'),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          child,
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: _activityCardWidth(constraints.maxWidth),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 216),
                child: CoeloAdminCreateAction(
                  key: const Key('create-activity-template-tile'),
                  label: 'Criar modelo',
                  onPressed: create,
                  icon: Icons.add_task_rounded,
                ),
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space6),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading && options == null) {
      return _withCreateAction(
        context,
        const Column(
          key: Key('activity-templates-loading'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Modelos de atividades'),
            SizedBox(height: CoeloSpacing.space2),
            LinearProgressIndicator(),
          ],
        ),
      );
    }
    if (failed && options == null) {
      return _withCreateAction(
        context,
        CoeloStatePanel(
          key: const Key('activity-templates-failure'),
          title: 'Não foi possível carregar os modelos',
          message: 'Tente novamente sem interromper a consulta de atividades.',
          icon: Icons.cloud_off_outlined,
          actionLabel: 'Tentar novamente',
          onAction: onRetry,
        ),
      );
    }
    final current = options;
    if (current == null) return const SizedBox.shrink();
    final taxonomyTemplates = selectedTaxonomyIds.isEmpty
        ? current.templates
        : current.templates
              .where((template) => selectedTaxonomyIds.contains(template.taxonomyId))
              .toList(growable: false);
    final originTemplates = taxonomyTemplates.where(
      (template) => switch (origin) {
        'Coelo' => template.scopeKind == ActivityTemplateScopeKind.platform,
        'Institucional' => template.scopeKind == ActivityTemplateScopeKind.institution,
        _ => true,
      },
    );
    final statusTemplates = originTemplates.where(
      (template) =>
          _statusesForTab(status).isEmpty || _statusesForTab(status).contains(template.status),
    );
    final normalizedSearch = search.toLowerCase();
    final visibleTemplates = normalizedSearch.isEmpty
        ? statusTemplates.toList(growable: false)
        : statusTemplates
              .where(
                (template) =>
                    template.name.toLowerCase().contains(normalizedSearch) ||
                    template.description.toLowerCase().contains(normalizedSearch),
              )
              .toList(growable: false);
    const pageSize = 12;
    final pageCount = (visibleTemplates.length / pageSize).ceil();
    final safePage = pageCount == 0 ? 0 : page.clamp(0, pageCount - 1);
    final pageTemplates = visibleTemplates
        .skip(safePage * pageSize)
        .take(pageSize)
        .toList(growable: false);
    return Column(
      key: const Key('activity-template-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (display == ActivityDirectoryDisplay.table && onCreate != null) ...[
          SuperadminDirectoryCreateBanner(
            label: 'Criar modelo',
            description: 'Adicionar um modelo institucional de atividade.',
            onPressed: () => _requestCreate(context),
            bannerKey: const Key('create-activity-template-banner'),
            surfaceKey: const Key('create-activity-template-banner-surface'),
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        if (visibleTemplates.isEmpty)
          _withCreateAction(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CoeloStatePanel(
                  title: 'Nenhum modelo encontrado',
                  message: 'Ajuste a busca, a origem ou as categorias.',
                  icon: Icons.search_off_rounded,
                ),
                if (selectedTaxonomyIds.isNotEmpty || search.isNotEmpty || origin != 'Todas')
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      key: const Key('activity-template-clear-filters'),
                      onPressed: onClearFilters,
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Limpar filtros'),
                    ),
                  ),
              ],
            ),
          )
        else if (display == ActivityDirectoryDisplay.table)
          CoeloAdminResizableTable<ActivityTemplateOption>(
            key: const Key('activity-template-table'),
            items: pageTemplates,
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
                cellBuilder: (_, template) => Text(
                  template.scopeKind == ActivityTemplateScopeKind.platform
                      ? 'Modelo Coelo'
                      : 'Modelo institucional',
                ),
              ),
              CoeloAdminTableColumn(
                id: 'category',
                label: 'Categoria',
                initialWidth: 180,
                minWidth: 140,
                maxWidth: 260,
                cellBuilder: (_, template) => Text(
                  current.taxonomy
                          .where((item) => item.id == template.taxonomyId)
                          .firstOrNull
                          ?.label ??
                      'Categoria não informada',
                ),
              ),
              CoeloAdminTableColumn(
                id: 'actions',
                label: 'Ações',
                initialWidth: 180,
                minWidth: 144,
                maxWidth: 220,
                cellBuilder: (context, template) => Row(
                  children: [
                    if (onDuplicate != null && current.institutions.isNotEmpty)
                      IconButton(
                        key: Key('activity-template-table-duplicate-${template.id}'),
                        tooltip: 'Duplicar ${template.name}',
                        onPressed: () => _requestDuplicate(context, template),
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
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = _activityCardWidth(constraints.maxWidth);
              return Wrap(
                spacing: CoeloSpacing.space6,
                runSpacing: CoeloSpacing.space6,
                children: [
                  if (onCreate != null)
                    SizedBox(
                      width: width,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 216),
                        child: CoeloAdminCreateAction(
                          key: const Key('create-activity-template-tile'),
                          label: 'Criar modelo',
                          onPressed: () => _requestCreate(context),
                          icon: Icons.add_task_rounded,
                        ),
                      ),
                    ),
                  for (final template in pageTemplates)
                    SizedBox(
                      width: width,
                      child: CoeloAdminInteractiveCard(
                        key: Key('activity-template-${template.id}'),
                        semanticLabel: 'Começar atividade a partir de ${template.name}',
                        onPressed: onStart == null ? null : () => onStart!(template),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 216),
                          child: Padding(
                            padding: const EdgeInsets.all(CoeloSpacing.space4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        template.name,
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ),
                                    if (onDuplicate != null && current.institutions.isNotEmpty)
                                      IconButton(
                                        key: Key('activity-template-duplicate-${template.id}'),
                                        tooltip: 'Duplicar ${template.name}',
                                        onPressed: () => _requestDuplicate(context, template),
                                        icon: const Icon(Icons.content_copy_rounded),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: CoeloSpacing.space2),
                                Text(
                                  template.scopeKind == ActivityTemplateScopeKind.platform
                                      ? 'Modelo Coelo'
                                      : 'Modelo institucional',
                                ),
                                if (template.description.trim().isNotEmpty) ...[
                                  const SizedBox(height: CoeloSpacing.space1),
                                  Text(template.description),
                                ],
                                const SizedBox(height: CoeloSpacing.space1),
                                Text(
                                  current.taxonomy
                                          .where((item) => item.id == template.taxonomyId)
                                          .firstOrNull
                                          ?.label ??
                                      'Categoria não informada',
                                ),
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
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        if (pageCount > 1) ...[
          const SizedBox(height: CoeloSpacing.space4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: const Key('activity-template-page-previous'),
                tooltip: 'Página anterior de modelos',
                onPressed: safePage == 0 ? null : () => onPageChanged(safePage - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text('Página ${safePage + 1} de $pageCount'),
              IconButton(
                key: const Key('activity-template-page-next'),
                tooltip: 'Próxima página de modelos',
                onPressed: safePage >= pageCount - 1 ? null : () => onPageChanged(safePage + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }
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

final class _ActivityResults extends StatelessWidget {
  const _ActivityResults({
    required this.viewModel,
    required this.display,
    required this.tableView,
    required this.onCreate,
    required this.onView,
    required this.opensEdit,
  });

  final ActivityDirectoryViewModel viewModel;
  final ActivityDirectoryDisplay display;
  final ActivityDirectoryTableView tableView;
  final VoidCallback? onCreate;
  final ValueChanged<String> onView;
  final bool opensEdit;

  @override
  Widget build(BuildContext context) {
    if (viewModel.state == ActivityDirectoryLoadState.initial ||
        viewModel.state == ActivityDirectoryLoadState.loading) {
      return const CoeloStatePanel(
        key: Key('activity-directory-loading'),
        title: 'Carregando atividades',
        message: 'Aguarde enquanto o diretório é preparado.',
        loading: true,
      );
    }
    if (viewModel.state == ActivityDirectoryLoadState.failure) {
      return _withCreateAction(
        CoeloStatePanel(
          title: 'Não foi possível carregar as atividades',
          message: 'Tente novamente.',
          icon: Icons.cloud_off_outlined,
          actionLabel: 'Tentar novamente',
          onAction: viewModel.retry,
        ),
      );
    }
    if (viewModel.state == ActivityDirectoryLoadState.unauthorized) {
      return const CoeloStatePanel(
        title: 'Acesso não autorizado',
        message: 'Você não tem permissão para visualizar as atividades.',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (viewModel.state == ActivityDirectoryLoadState.empty ||
        viewModel.state == ActivityDirectoryLoadState.noResults) {
      final empty = viewModel.state == ActivityDirectoryLoadState.empty;
      return _withCreateAction(
        CoeloStatePanel(
          title: empty ? 'Nenhuma atividade cadastrada' : 'Nenhuma atividade encontrada',
          message: empty
              ? 'Crie a primeira atividade da plataforma.'
              : 'Ajuste ou limpe os filtros.',
          icon: Icons.local_activity_outlined,
          actionLabel: empty ? null : 'Limpar filtros',
          onAction: empty ? null : viewModel.clearFilters,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.state == ActivityDirectoryLoadState.success)
          display == ActivityDirectoryDisplay.cards
              ? _ActivityCards(
                  items: viewModel.visibleItems,
                  onCreate: onCreate,
                  onView: onView,
                  opensEdit: opensEdit,
                )
              : Column(
                  children: [
                    if (onCreate != null) ...[
                      SuperadminDirectoryCreateBanner(
                        label: 'Criar atividade',
                        description: 'Adicionar nova atividade ao sistema.',
                        onPressed: onCreate!,
                        bannerKey: const Key('create-activity-banner'),
                        surfaceKey: const Key('create-activity-banner-surface'),
                      ),
                      const SizedBox(height: CoeloSpacing.space4),
                    ],
                    switch (tableView) {
                      ActivityDirectoryTableView.grouped => _ActivityTable(
                        items: viewModel.visibleItems,
                        viewModel: viewModel,
                        onView: onView,
                      ),
                      ActivityDirectoryTableView.units => _ActivityHierarchyTable(
                        key: const Key('activity-unit-directory-table'),
                        items: viewModel.visibleItems,
                        level: ActivityDirectoryTableView.units,
                        onView: onView,
                      ),
                      ActivityDirectoryTableView.groups => _ActivityHierarchyTable(
                        key: const Key('activity-group-directory-table'),
                        items: viewModel.visibleItems,
                        level: ActivityDirectoryTableView.groups,
                        onView: onView,
                      ),
                    },
                  ],
                ),
      ],
    );
  }

  Widget _withCreateAction(Widget stateContent) {
    if (onCreate == null) return stateContent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (display == ActivityDirectoryDisplay.table)
          SuperadminDirectoryCreateBanner(
            label: 'Criar atividade',
            description: 'Adicionar nova atividade ao sistema.',
            onPressed: onCreate!,
            bannerKey: const Key('create-activity-banner'),
            surfaceKey: const Key('create-activity-banner-surface'),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                  ? 3
                  : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                  ? 2
                  : 1;
              final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space4) / columns;
              return Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: width,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 216),
                    child: CoeloAdminCreateAction(
                      key: const Key('create-activity-tile'),
                      label: 'Criar atividade',
                      onPressed: onCreate!,
                      icon: Icons.add_rounded,
                    ),
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: CoeloSpacing.space4),
        stateContent,
      ],
    );
  }
}

final class _ActivityCards extends StatelessWidget {
  const _ActivityCards({
    required this.items,
    required this.onCreate,
    required this.onView,
    required this.opensEdit,
  });

  final List<ActivityDirectoryItem> items;
  final VoidCallback? onCreate;
  final ValueChanged<String> onView;
  final bool opensEdit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: const Key('activity-card-grid'),
    builder: (context, constraints) {
      final width = _activityCardWidth(constraints.maxWidth);
      return Wrap(
        spacing: CoeloSpacing.space6,
        runSpacing: CoeloSpacing.space6,
        children: [
          if (onCreate != null)
            SizedBox(
              width: width,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 216),
                child: CoeloAdminCreateAction(
                  key: const Key('create-activity-tile'),
                  label: 'Criar atividade',
                  icon: Icons.local_activity_rounded,
                  onPressed: onCreate!,
                ),
              ),
            ),
          for (final item in items)
            SizedBox(
              width: width,
              child: _ActivityCard(
                item: item,
                onPressed: () => onView(item.id),
                opensEdit: opensEdit,
              ),
            ),
        ],
      );
    },
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

final class _ActivityTable extends StatelessWidget {
  const _ActivityTable({required this.items, required this.viewModel, required this.onView});

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

final class _ActivityHierarchyTable extends StatelessWidget {
  const _ActivityHierarchyTable({
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

final class _ActivityPaginationFooter extends StatelessWidget {
  const _ActivityPaginationFooter({
    required this.viewModel,
    required this.display,
    required this.horizontalPadding,
  });

  final ActivityDirectoryViewModel viewModel;
  final ActivityDirectoryDisplay display;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) => SuperadminListingPaginationFooter(
    semanticKey: const Key('activity-directory-pagination-footer'),
    compactCurrentPage: viewModel.page.page + 1,
    compactTotalPages: viewModel.page.totalPages,
    compactOnPrevious: viewModel.page.page == 0
        ? null
        : () => viewModel.setPage(viewModel.page.page - 1),
    compactOnNext: viewModel.page.page + 1 >= viewModel.page.totalPages
        ? null
        : () => viewModel.setPage(viewModel.page.page + 1),
    horizontalPadding: horizontalPadding,
    child: CoeloAdminPagination(
      currentPage: viewModel.page.page + 1,
      totalPages: viewModel.page.totalPages,
      pageSize: viewModel.query.pageSize,
      pageSizeOptions: display == ActivityDirectoryDisplay.cards
          ? const [11, 20, 50, 100]
          : const [8, 20, 50, 100],
      onPageSelected: (page) => viewModel.setPage(page - 1),
      onPageSizeChanged: viewModel.setPageSize,
      onPrevious: viewModel.page.page == 0
          ? null
          : () => viewModel.setPage(viewModel.page.page - 1),
      onNext: viewModel.page.page + 1 >= viewModel.page.totalPages
          ? null
          : () => viewModel.setPage(viewModel.page.page + 1),
    ),
  );
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
