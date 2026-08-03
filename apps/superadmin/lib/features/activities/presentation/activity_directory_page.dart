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
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/activity_directory.dart';
import 'activity_directory_view_model.dart';

enum ActivityDirectoryDisplay { cards, table }

enum ActivityDirectoryTableView { grouped, units, groups }

final class ActivityDirectoryPage extends StatefulWidget {
  const ActivityDirectoryPage({
    required this.repository,
    required this.logout,
    required this.onView,
    this.onCreate,
    this.onEdit,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    super.key,
  });

  final ActivityDirectoryRepository repository;
  final LogoutAction logout;
  final ValueChanged<String> onView;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
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
    showChatLauncher: false,
    chatLauncherBottomInset: _footerHeight,
    onDestinationSelected: widget.onDestinationSelected,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    child: _ActivityDirectoryContent(
      viewModel: _viewModel,
      activityController: _activityController,
      searchController: _searchController,
      display: _display,
      tableView: _tableView,
      onDisplayChanged: _setDisplay,
      onTableViewChanged: _setTableView,
      onCreate: widget.onCreate ?? () {},
      onEdit: widget.onEdit ?? widget.onView,
      onView: widget.onView,
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
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onView,
    required this.onFooterHeightChanged,
  });

  final ActivityDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final ActivityDirectoryDisplay display;
  final ActivityDirectoryTableView tableView;
  final ValueChanged<ActivityDirectoryDisplay> onDisplayChanged;
  final ValueChanged<ActivityDirectoryTableView> onTableViewChanged;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;
  final ValueChanged<String> onView;
  final ValueChanged<double> onFooterHeightChanged;

  @override
  State<_ActivityDirectoryContent> createState() => _ActivityDirectoryContentState();
}

final class _ActivityDirectoryContentState extends State<_ActivityDirectoryContent> {
  final GlobalKey _footerKey = GlobalKey();
  double _footerHeight = 0;
  bool _measurementScheduled = false;

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
          final showFooter = widget.viewModel.state == ActivityDirectoryLoadState.success;
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
                  _ActivityToolbar(
                    viewModel: widget.viewModel,
                    activityController: widget.activityController,
                    searchController: widget.searchController,
                    display: widget.display,
                    tableView: widget.tableView,
                    onDisplayChanged: widget.onDisplayChanged,
                    onTableViewChanged: widget.onTableViewChanged,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _ActivityResults(
                    viewModel: widget.viewModel,
                    display: widget.display,
                    tableView: widget.tableView,
                    onCreate: widget.onCreate,
                    onEdit: widget.onEdit,
                    onView: widget.onView,
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
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
  });

  final ActivityDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final ActivityDirectoryDisplay display;
  final ActivityDirectoryTableView tableView;
  final ValueChanged<ActivityDirectoryDisplay> onDisplayChanged;
  final ValueChanged<ActivityDirectoryTableView> onTableViewChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.8;
      final filterWidth = compact && largeText
          ? constraints.maxWidth
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
        filter<ActivityHierarchyFilterOption>(
          key: const Key('activity-unit-filter'),
          label: 'Unidades',
          values: viewModel.unitOptions,
          selected: viewModel.unitOptions
              .where((option) => viewModel.selectedUnitIds.contains(option.id))
              .toSet(),
          optionLabel: (option) => option.label,
          onChanged: (value) => viewModel.setUnits(value.map((option) => option.id).toSet()),
        ),
        filter<ActivityHierarchyFilterOption>(
          key: const Key('activity-group-filter'),
          label: 'Grupos',
          values: viewModel.groupOptions,
          selected: viewModel.groupOptions
              .where((option) => viewModel.selectedGroupIds.contains(option.id))
              .toSet(),
          optionLabel: (option) => option.label,
          onChanged: (value) => viewModel.setGroups(value.map((option) => option.id).toSet()),
        ),
        filter<ActivityStatus>(
          key: const Key('activity-status-filter'),
          label: 'Status',
          values: ActivityStatus.values,
          selected: viewModel.query.statuses,
          optionLabel: (status) => status.label,
          onChanged: viewModel.setStatuses,
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
                label: 'Por Grupos',
              ),
            ],
            cardsKey: const Key('activity-view-cards'),
            tableKey: const Key('activity-view-table'),
            onCardsSelected: () => onDisplayChanged(ActivityDirectoryDisplay.cards),
            onTableViewSelected: onTableViewChanged,
          ),
          CoeloAdminFileActions(
            compact: compact,
            actions: [
              CoeloAdminFileAction(
                key: const Key('activity-files-export-xlsx'),
                label: 'Exportar XLSX',
                icon: Icons.grid_on_outlined,
                onPressed: () {
                  final viewLabel = display == ActivityDirectoryDisplay.cards
                      ? 'Cards'
                      : switch (tableView) {
                          ActivityDirectoryTableView.grouped => 'Agrupado',
                          ActivityDirectoryTableView.units => 'Por Unidades',
                          ActivityDirectoryTableView.groups => 'Por Grupos',
                        };
                  activityController.completeDemoExport(
                    SuperadminExportFormat.xlsx,
                    subject: 'Atividades · $viewLabel',
                    fileBaseName: 'atividades-${tableView.name}',
                  );
                  showSuperadminNotice(
                    context,
                    'Preview de exportação: $viewLabel. Nenhum arquivo real foi gerado.',
                    icon: Icons.download_outlined,
                  );
                },
              ),
            ],
          ),
        ],
      );
    },
  );
}

final class _ActivityResults extends StatelessWidget {
  const _ActivityResults({
    required this.viewModel,
    required this.display,
    required this.tableView,
    required this.onCreate,
    required this.onEdit,
    required this.onView,
  });

  final ActivityDirectoryViewModel viewModel;
  final ActivityDirectoryDisplay display;
  final ActivityDirectoryTableView tableView;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) {
    if (viewModel.state == ActivityDirectoryLoadState.failure) {
      return CoeloStatePanel(
        title: 'Não foi possível carregar as atividades',
        message: 'Tente novamente.',
        icon: Icons.cloud_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: viewModel.retry,
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
      return CoeloStatePanel(
        title: empty ? 'Nenhuma atividade cadastrada' : 'Nenhuma atividade encontrada',
        message: empty ? 'Crie a primeira atividade da plataforma.' : 'Ajuste ou limpe os filtros.',
        icon: Icons.local_activity_outlined,
        actionLabel: empty ? 'Criar atividade' : 'Limpar filtros',
        onAction: empty ? onCreate : viewModel.clearFilters,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.state == ActivityDirectoryLoadState.loading) const LinearProgressIndicator(),
        if (viewModel.state == ActivityDirectoryLoadState.loading)
          const SizedBox(height: CoeloSpacing.space4),
        if (viewModel.state == ActivityDirectoryLoadState.success)
          display == ActivityDirectoryDisplay.cards
              ? _ActivityCards(
                  items: viewModel.visibleItems,
                  onCreate: onCreate,
                  onEdit: onEdit,
                  onView: onView,
                )
              : Column(
                  children: [
                    SuperadminDirectoryCreateBanner(
                      label: 'Criar atividade',
                      description: 'Adicionar nova atividade ao sistema.',
                      onPressed: onCreate,
                      bannerKey: const Key('create-activity-banner'),
                      surfaceKey: const Key('create-activity-banner-surface'),
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    switch (tableView) {
                      ActivityDirectoryTableView.grouped => _ActivityTable(
                        items: viewModel.visibleItems,
                        viewModel: viewModel,
                        onView: onEdit,
                      ),
                      ActivityDirectoryTableView.units => _ActivityHierarchyTable(
                        key: const Key('activity-unit-directory-table'),
                        items: viewModel.visibleItems,
                        level: ActivityDirectoryTableView.units,
                        onEdit: onEdit,
                      ),
                      ActivityDirectoryTableView.groups => _ActivityHierarchyTable(
                        key: const Key('activity-group-directory-table'),
                        items: viewModel.visibleItems,
                        level: ActivityDirectoryTableView.groups,
                        onEdit: onEdit,
                      ),
                    },
                  ],
                ),
      ],
    );
  }
}

final class _ActivityCards extends StatelessWidget {
  const _ActivityCards({
    required this.items,
    required this.onCreate,
    required this.onEdit,
    required this.onView,
  });

  final List<ActivityDirectoryItem> items;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;
  final ValueChanged<String> onView;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    key: const Key('activity-card-grid'),
    builder: (context, constraints) {
      final columns = math.max(1, (constraints.maxWidth / 340).floor());
      final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
      return Wrap(
        spacing: CoeloSpacing.space6,
        runSpacing: CoeloSpacing.space6,
        children: [
          SizedBox(
            width: width,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 216),
              child: CoeloAdminCreateAction(
                label: 'Criar atividade',
                icon: Icons.local_activity_rounded,
                onPressed: onCreate,
              ),
            ),
          ),
          for (final item in items)
            SizedBox(
              width: width,
              child: _ActivityCard(
                item: item,
                onPressed: () => onView(item.id),
                onEdit: () => onEdit(item.id),
              ),
            ),
        ],
      );
    },
  );
}

final class _ActivityCard extends StatefulWidget {
  const _ActivityCard({required this.item, required this.onPressed, required this.onEdit});

  final ActivityDirectoryItem item;
  final VoidCallback onPressed;
  final VoidCallback onEdit;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

final class _ActivityCardState extends State<_ActivityCard> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = widget.item;
    final hierarchy = ActivityDirectoryHierarchy.from(item);
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.standard;
    return Semantics(
      button: true,
      label: 'Visualizar atividade ${item.name}',
      child: ConstrainedBox(
        key: Key('activity-card-${item.id}'),
        constraints: const BoxConstraints(minHeight: 216),
        child: MouseRegion(
          onEnter: (_) => setState(() => _highlighted = true),
          onExit: (_) => setState(() => _highlighted = false),
          child: FocusableActionDetector(
            onShowFocusHighlight: (value) => setState(() => _highlighted = value),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _highlighted ? 1 : 0),
              duration: duration,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Container(
                key: Key('activity-card-surface-${item.id}'),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                  border: Border.all(
                    color: Color.lerp(
                      colors.outlineVariant,
                      colors.primary.withValues(alpha: .5),
                      progress,
                    )!,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color.lerp(
                        colors.shadow.withValues(alpha: .03),
                        colors.primary.withValues(alpha: .15),
                        progress,
                      )!,
                      blurRadius: 8 + 4 * progress,
                      spreadRadius: 2 * progress,
                      offset: Offset(0, 2 + 2 * progress),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                  child: InkWell(
                    onTap: widget.onPressed,
                    borderRadius: BorderRadius.circular(CoeloRadius.lg),
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoeloSpacing.space6,
                        vertical: CoeloSpacing.space4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ActivityCardHeader(item: item, colors: colors, onEdit: widget.onEdit),
                          const SizedBox(height: CoeloSpacing.space4),
                          const Divider(height: 1),
                          const SizedBox(height: CoeloSpacing.space4),
                          _DetailRow(
                            first: _ActivityDetail(
                              icon: Icons.account_balance_outlined,
                              label: 'Instituição',
                              value: item.institutionName,
                            ),
                            second: _ActivityDetail(
                              icon: Icons.hub_outlined,
                              label: 'Origem',
                              value: item.origin.label,
                            ),
                          ),
                          const SizedBox(height: CoeloSpacing.space3),
                          _DetailRow(
                            first: _ActivityDetail(
                              icon: Icons.apartment_outlined,
                              label: 'Unidades vinculadas',
                              value: hierarchy.unit.label,
                            ),
                            second: _ActivityDetail(
                              icon: Icons.groups_outlined,
                              label: 'Grupos vinculados',
                              value: hierarchy.group.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _ActivityCardHeader extends StatelessWidget {
  const _ActivityCardHeader({required this.item, required this.colors, required this.onEdit});

  final ActivityDirectoryItem item;
  final ColorScheme colors;
  final VoidCallback onEdit;

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
            item.distribution.label,
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActivityStatusChip(status: item.status),
                _editButton(),
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: identity),
        const SizedBox(width: CoeloSpacing.space2),
        _ActivityStatusChip(status: item.status),
        _editButton(),
      ],
    );
  }

  Widget _editButton() => IconButton(
    key: Key('activity-card-edit-${item.id}'),
    tooltip: 'Editar atividade',
    onPressed: onEdit,
    icon: const Icon(Icons.edit_outlined),
  );
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
      cellBuilder: (context, item) =>
          Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
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
              column('groups', 'Grupos', (item) => '${item.activeGroupCount}', width: 132),
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
    required this.onEdit,
    super.key,
  });

  final List<ActivityDirectoryItem> items;
  final ActivityDirectoryTableView level;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    String hierarchyLabel(ActivityDirectoryItem item) {
      final hierarchy = ActivityDirectoryHierarchy.from(item);
      return level == ActivityDirectoryTableView.units
          ? hierarchy.unit.label
          : hierarchy.group.label;
    }

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
      cellBuilder: (context, item) =>
          Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        child: CoeloAdminResizableTable<ActivityDirectoryItem>(
          items: items,
          rowKey: (item) => 'activity-hierarchy-row-${item.id}',
          headerHeight: 56,
          rowHeight: 64,
          onRowPressed: (item) => onEdit(item.id),
          pinnedColumn: column(
            'hierarchy',
            level == ActivityDirectoryTableView.units ? 'Unidade' : 'Grupo',
            hierarchyLabel,
            width: 240,
          ),
          columns: [
            column('activity', 'Atividade', (item) => item.name, width: 240),
            column('institution', 'Instituição', (item) => item.institutionName, width: 240),
            column('origin', 'Origem', (item) => item.origin.label),
            column('status', 'Status', (item) => item.status.label),
          ],
        ),
      ),
    );
  }
}

final class _ActivityStatusChip extends StatelessWidget {
  const _ActivityStatusChip({required this.status});

  final ActivityStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final pair = switch (status) {
      ActivityStatus.active => (statusColors.successContainer, statusColors.onSuccessContainer),
      ActivityStatus.suspended => (statusColors.errorContainer, statusColors.onErrorContainer),
      ActivityStatus.draft => (statusColors.warningContainer, statusColors.onWarningContainer),
      ActivityStatus.inactive || ActivityStatus.archived => (
        theme.colorScheme.surfaceContainer,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return CoeloStatusChip(label: status.label, backgroundColor: pair.$1, foregroundColor: pair.$2);
  }
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
