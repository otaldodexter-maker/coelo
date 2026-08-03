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
import '../domain/group_directory.dart';
import 'group_directory_view_model.dart';

enum GroupDirectoryDisplay { cards, table }

enum GroupDirectoryTableView { grouped, activities }

final class GroupDirectoryPage extends StatefulWidget {
  const GroupDirectoryPage({
    required this.repository,
    required this.logout,
    this.onCreate,
    this.onEdit,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.successMessage,
    super.key,
  });

  final GroupDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final String? successMessage;

  @override
  State<GroupDirectoryPage> createState() => _GroupDirectoryPageState();
}

final class _GroupDirectoryPageState extends State<GroupDirectoryPage> {
  late final GroupDirectoryViewModel _viewModel;
  late final SuperadminActivityController _activityController;
  late final TextEditingController _searchController;
  GroupDirectoryDisplay _display = GroupDirectoryDisplay.cards;
  GroupDirectoryTableView _tableView = GroupDirectoryTableView.grouped;
  double _footerHeight = 0;
  bool _noticeShown = false;

  @override
  void initState() {
    super.initState();
    _viewModel = GroupDirectoryViewModel(widget.repository);
    _activityController = SuperadminActivityController();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void didUpdateWidget(covariant GroupDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.successMessage != widget.successMessage) _noticeShown = false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _setDisplay(GroupDirectoryDisplay display) {
    if (_display == display) return;
    setState(() => _display = display);
    _viewModel.setPageSize(display == GroupDirectoryDisplay.cards ? 11 : 8);
  }

  void _setTableView(GroupDirectoryTableView tableView) {
    setState(() {
      _display = GroupDirectoryDisplay.table;
      _tableView = tableView;
    });
    _viewModel.setPageSize(8);
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      activityController: _activityController,
      title: 'Grupos',
      subtitle: 'Gerencie os grupos da plataforma.',
      currentDestination: 'groups',
      showChatLauncher: false,
      chatLauncherBottomInset: _footerHeight,
      onDestinationSelected: widget.onDestinationSelected,
      onBugReportSubmitted: widget.onBugReportSubmitted,
      child: Builder(
        builder: (context) {
          final message = widget.successMessage;
          if (message != null && !_noticeShown) {
            _noticeShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showSuperadminNotice(context, message, icon: Icons.check_circle_outline_rounded);
              }
            });
          }
          return _GroupDirectoryContent(
            viewModel: _viewModel,
            activityController: _activityController,
            searchController: _searchController,
            display: _display,
            tableView: _tableView,
            onDisplayChanged: _setDisplay,
            onTableViewChanged: _setTableView,
            onCreate: widget.onCreate ?? () {},
            onEdit: widget.onEdit ?? (_) {},
            onFooterHeightChanged: (height) {
              if ((_footerHeight - height).abs() >= .5) {
                setState(() => _footerHeight = height);
              }
            },
          );
        },
      ),
    );
  }
}

final class _GroupDirectoryContent extends StatefulWidget {
  const _GroupDirectoryContent({
    required this.viewModel,
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onFooterHeightChanged,
  });

  final GroupDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final GroupDirectoryDisplay display;
  final GroupDirectoryTableView tableView;
  final ValueChanged<GroupDirectoryDisplay> onDisplayChanged;
  final ValueChanged<GroupDirectoryTableView> onTableViewChanged;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;
  final ValueChanged<double> onFooterHeightChanged;

  @override
  State<_GroupDirectoryContent> createState() => _GroupDirectoryContentState();
}

final class _GroupDirectoryContentState extends State<_GroupDirectoryContent> {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
            ? CoeloSpacing.space10
            : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space6
            : CoeloSpacing.space4;
        return AnimatedBuilder(
          animation: widget.viewModel,
          builder: (context, _) {
            final showFooter = widget.viewModel.state == GroupDirectoryLoadState.success;
            _measureFooter(showFooter);
            return Stack(
              fit: StackFit.expand,
              children: [
                ListView(
                  key: const Key('group-directory-scroll'),
                  padding: EdgeInsets.fromLTRB(
                    padding,
                    padding,
                    padding,
                    padding + (showFooter ? _footerHeight + CoeloSpacing.space4 : 0),
                  ),
                  children: [
                    _GroupToolbar(
                      viewModel: widget.viewModel,
                      activityController: widget.activityController,
                      searchController: widget.searchController,
                      display: widget.display,
                      tableView: widget.tableView,
                      onDisplayChanged: widget.onDisplayChanged,
                      onTableViewChanged: widget.onTableViewChanged,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _GroupResults(
                      viewModel: widget.viewModel,
                      display: widget.display,
                      tableView: widget.tableView,
                      onCreate: widget.onCreate,
                      onEdit: widget.onEdit,
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
                        child: _GroupPaginationFooter(
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
}

final class _GroupToolbar extends StatelessWidget {
  const _GroupToolbar({
    required this.viewModel,
    required this.activityController,
    required this.searchController,
    required this.display,
    required this.tableView,
    required this.onDisplayChanged,
    required this.onTableViewChanged,
  });

  final GroupDirectoryViewModel viewModel;
  final SuperadminActivityController activityController;
  final TextEditingController searchController;
  final GroupDirectoryDisplay display;
  final GroupDirectoryTableView tableView;
  final ValueChanged<GroupDirectoryDisplay> onDisplayChanged;
  final ValueChanged<GroupDirectoryTableView> onTableViewChanged;

  @override
  Widget build(BuildContext context) {
    Widget filter<T>({
      required Key key,
      required String label,
      required List<T> options,
      required Set<T> selected,
      required String Function(T) optionLabel,
      required ValueChanged<Set<T>> onChanged,
      required double width,
      String? searchHintText,
    }) => SizedBox(
      key: key,
      width: width,
      child: CoeloAdminMultiSelectFilter<T>(
        label: label,
        options: options,
        selectedValues: selected,
        optionLabel: optionLabel,
        onChanged: onChanged,
        searchHintText: searchHintText,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        final compactFileAction = compact || constraints.maxWidth < 1000;
        final filterWidth = compact
            ? (constraints.maxWidth - CoeloSpacing.space3) / 2
            : constraints.maxWidth >= 1000
            ? 136.0
            : 160.0;
        final searchWidth = compact ? constraints.maxWidth : 216.0;
        final options = viewModel.filterOptions;
        final controls = <Widget>[
          SizedBox(
            width: searchWidth,
            height: CoeloSize.touchMin,
            child: CoeloSearchField(
              controller: searchController,
              hintText: 'Buscar por nome',
              semanticLabel: 'Buscar grupo por nome',
              onChanged: viewModel.setSearch,
            ),
          ),
          filter<GroupDirectoryFilterOption>(
            key: const Key('group-institution-filter'),
            label: 'Instituições',
            options: options.institutions,
            selected: options.institutions
                .where((option) => viewModel.query.institutionIds.contains(option.id))
                .toSet(),
            optionLabel: (option) => option.label,
            onChanged: (value) => viewModel.setInstitutions(value.map((item) => item.id).toSet()),
            width: filterWidth,
            searchHintText: 'Buscar instituição',
          ),
          filter<GroupDirectoryFilterOption>(
            key: const Key('group-unit-filter'),
            label: 'Unidades',
            options: options.units,
            selected: options.units
                .where((option) => viewModel.query.unitIds.contains(option.id))
                .toSet(),
            optionLabel: (option) => option.label,
            onChanged: (value) => viewModel.setUnits(value.map((item) => item.id).toSet()),
            width: filterWidth,
            searchHintText: 'Buscar unidade',
          ),
          filter<GroupDirectoryFilterOption>(
            key: const Key('group-type-filter'),
            label: 'Tipos',
            options: options.types,
            selected: options.types
                .where((option) => viewModel.query.typeIds.contains(option.id))
                .toSet(),
            optionLabel: (option) => option.label,
            onChanged: (value) => viewModel.setTypes(value.map((item) => item.id).toSet()),
            width: filterWidth,
          ),
          filter<GroupStatus>(
            key: const Key('group-status-filter'),
            label: 'Status',
            options: GroupStatus.values,
            selected: viewModel.query.statuses,
            optionLabel: (status) => status.label,
            onChanged: viewModel.setStatuses,
            width: filterWidth,
          ),
          if (viewModel.query.hasActiveFilters)
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
          key: const Key('group-filter-toolbar'),
          search: Wrap(
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: controls,
          ),
          filters: const [],
          actions: [
            SizedBox(
              key: const Key('group-toolbar-actions'),
              height: CoeloSize.touchMin,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SuperadminDirectoryViewToggle<GroupDirectoryTableView>(
                    cardsSelected: display == GroupDirectoryDisplay.cards,
                    groupedView: GroupDirectoryTableView.grouped,
                    selectedTableView: tableView,
                    tableViews: const [
                      SuperadminDirectoryTableViewOption(
                        value: GroupDirectoryTableView.grouped,
                        label: 'Agrupado',
                      ),
                      SuperadminDirectoryTableViewOption(
                        value: GroupDirectoryTableView.activities,
                        label: 'Detalhado por Atividades',
                      ),
                    ],
                    cardsKey: const Key('group-view-cards'),
                    tableKey: const Key('group-view-table'),
                    onCardsSelected: () => onDisplayChanged(GroupDirectoryDisplay.cards),
                    onTableViewSelected: onTableViewChanged,
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  CoeloAdminFileActions(
                    compact: compactFileAction,
                    actions: [
                      CoeloAdminFileAction(
                        key: const Key('group-import-action'),
                        label: 'Importar grupos',
                        icon: Icons.upload_file_outlined,
                        onPressed: () {
                          activityController.startDemoImport(
                            subject: 'Grupos',
                            fileName: 'grupos-demonstracao.xlsx',
                            progressSummary: 'Importando grupos',
                            completedSummary: 'Importação de grupos demonstrada',
                          );
                          showSuperadminNotice(
                            context,
                            'Importação local demonstrada. Nenhum dado remoto foi alterado.',
                            icon: Icons.info_outline_rounded,
                          );
                        },
                      ),
                      CoeloAdminFileAction(
                        key: const Key('group-export-action'),
                        label: 'Exportar grupos',
                        icon: Icons.download_outlined,
                        onPressed: () {
                          final viewLabel = display == GroupDirectoryDisplay.cards
                              ? 'Cards'
                              : switch (tableView) {
                                  GroupDirectoryTableView.grouped => 'Agrupado',
                                  GroupDirectoryTableView.activities => 'Detalhado por Atividades',
                                };
                          activityController.completeDemoExport(
                            SuperadminExportFormat.xlsx,
                            subject: 'Grupos',
                            fileBaseName: 'grupos',
                          );
                          showSuperadminNotice(
                            context,
                            'Exportação local de grupos preparada (visão: $viewLabel). '
                            'Nenhum arquivo real foi gerado.',
                            icon: Icons.check_circle_outline_rounded,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _GroupResults extends StatelessWidget {
  const _GroupResults({
    required this.viewModel,
    required this.display,
    required this.tableView,
    required this.onCreate,
    required this.onEdit,
  });

  final GroupDirectoryViewModel viewModel;
  final GroupDirectoryDisplay display;
  final GroupDirectoryTableView tableView;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    if (viewModel.state == GroupDirectoryLoadState.failure) {
      return CoeloStatePanel(
        title: 'Não foi possível carregar os grupos',
        message: 'Tente novamente.',
        icon: Icons.cloud_off_outlined,
        actionLabel: 'Tentar novamente',
        onAction: viewModel.retry,
      );
    }
    if (viewModel.state == GroupDirectoryLoadState.unauthorized) {
      return const CoeloStatePanel(
        title: 'Acesso não autorizado',
        message: 'Você não tem permissão para ver os grupos.',
        icon: Icons.lock_outline_rounded,
      );
    }
    if (viewModel.state == GroupDirectoryLoadState.empty ||
        viewModel.state == GroupDirectoryLoadState.noResults) {
      final empty = viewModel.state == GroupDirectoryLoadState.empty;
      return CoeloStatePanel(
        title: empty ? 'Nenhum grupo cadastrado' : 'Nenhum grupo encontrado',
        message: empty ? 'Crie o primeiro grupo da plataforma.' : 'Ajuste ou limpe os filtros.',
        icon: Icons.groups_outlined,
        actionLabel: empty ? 'Criar grupo' : 'Limpar filtros',
        onAction: empty ? onCreate : viewModel.clearFilters,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.isLoading) const LinearProgressIndicator(),
        if (viewModel.isLoading) const SizedBox(height: CoeloSpacing.space4),
        if (viewModel.state == GroupDirectoryLoadState.success)
          display == GroupDirectoryDisplay.cards
              ? _GroupCards(items: viewModel.page.items, onCreate: onCreate, onEdit: onEdit)
              : Column(
                  children: [
                    SuperadminDirectoryCreateBanner(
                      label: 'Criar grupo',
                      description: 'Adicionar novo grupo ao sistema.',
                      onPressed: onCreate,
                      bannerKey: const Key('group-create-banner'),
                      surfaceKey: const Key('group-create-banner-surface'),
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    tableView == GroupDirectoryTableView.grouped
                        ? _GroupTable(
                            items: viewModel.page.items,
                            viewModel: viewModel,
                            onEdit: onEdit,
                          )
                        : _GroupActivityTable(items: viewModel.page.items, onEdit: onEdit),
                  ],
                ),
      ],
    );
  }
}

final class _GroupCards extends StatelessWidget {
  const _GroupCards({required this.items, required this.onCreate, required this.onEdit});

  final List<GroupDirectoryItem> items;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      CoeloAdminCreateAction(label: 'Criar grupo', icon: Icons.groups_rounded, onPressed: onCreate),
      for (final item in items) _GroupCard(item: item, onPressed: () => onEdit(item.id)),
    ];
    return LayoutBuilder(
      key: const Key('group-card-grid'),
      builder: (context, constraints) {
        final columns = math.max(1, (constraints.maxWidth / 340).floor());
        final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
        return Wrap(
          spacing: CoeloSpacing.space6,
          runSpacing: CoeloSpacing.space6,
          children: [
            for (final child in children)
              SizedBox(
                width: width,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 216),
                  child: child,
                ),
              ),
          ],
        );
      },
    );
  }
}

final class _GroupCard extends StatefulWidget {
  const _GroupCard({required this.item, required this.onPressed});

  final GroupDirectoryItem item;
  final VoidCallback onPressed;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

final class _GroupCardState extends State<_GroupCard> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = widget.item;
    final prototype = _GroupPrototype.from(item);
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.standard;
    return ConstrainedBox(
      key: Key('group-card-${item.id}'),
      constraints: const BoxConstraints(minHeight: 216),
      child: MouseRegion(
        onEnter: (_) => setState(() => _highlighted = true),
        onExit: (_) => setState(() => _highlighted = false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) => setState(() => _highlighted = value),
          child: TweenAnimationBuilder<double>(
            key: Key('group-card-surface-${item.id}'),
            tween: Tween(begin: 0, end: _highlighted ? 1 : 0),
            duration: duration,
            curve: Curves.easeOutCubic,
            builder: (context, progress, child) => Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                border: Border.all(
                  color: Color.lerp(
                    colors.outlineVariant,
                    colors.primary.withValues(alpha: .5),
                    progress,
                  )!,
                  width: 1 + .5 * progress,
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
                        Row(
                          children: [
                            SizedBox.square(
                              dimension: 44,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colors.secondaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.groups_rounded,
                                  color: colors.onSecondaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: CoeloSpacing.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  _CardContextLine(label: 'Unidade', value: item.unitName),
                                  _CardContextLine(
                                    label: 'Instituição',
                                    value: item.institutionName,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: CoeloSpacing.space2),
                            _GroupStatusChip(status: item.status),
                          ],
                        ),
                        const SizedBox(height: CoeloSpacing.space4),
                        const Divider(height: 1),
                        const SizedBox(height: CoeloSpacing.space4),
                        _DetailRow(
                          first: _GroupDetail(
                            icon: Icons.badge_outlined,
                            label: 'Equipe institucional',
                            value: prototype.team,
                          ),
                          second: _GroupDetail(
                            icon: Icons.local_activity_outlined,
                            label: 'Atividades',
                            value: '${prototype.activities.length}',
                          ),
                        ),
                        const SizedBox(height: CoeloSpacing.space3),
                        _DetailRow(
                          first: _GroupDetail(
                            icon: Icons.supervisor_account_outlined,
                            label: 'Responsáveis',
                            value: '${prototype.guardianCount}',
                          ),
                          second: _GroupDetail(
                            icon: Icons.child_care_outlined,
                            label: 'Crianças',
                            value: '${prototype.childCount}',
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
    );
  }
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

final class _CardContextLine extends StatelessWidget {
  const _CardContextLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        TextSpan(text: value),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall,
  );
}

final class _GroupPrototype {
  const _GroupPrototype({
    required this.team,
    required this.activities,
    required this.guardianCount,
    required this.childCount,
  });

  factory _GroupPrototype.from(GroupDirectoryItem item) {
    final index = int.tryParse(RegExp(r'\d+').firstMatch(item.id)?.group(0) ?? '') ?? 1;
    const activitySets = [
      ['Música', 'Leitura'],
      ['Artes visuais', 'Teatro'],
      ['Movimento', 'Horta'],
    ];
    return _GroupPrototype(
      team: index.isEven ? 'Equipe da unidade' : 'Equipe institucional',
      activities: activitySets[index % activitySets.length],
      guardianCount: 12 + index % 9,
      childCount: 14 + index % 11,
    );
  }

  final String team;
  final List<String> activities;
  final int guardianCount;
  final int childCount;
}

final class _GroupDetail extends StatelessWidget {
  const _GroupDetail({required this.icon, required this.label, required this.value});
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

final class _GroupTable extends StatelessWidget {
  const _GroupTable({required this.items, required this.viewModel, required this.onEdit});

  final List<GroupDirectoryItem> items;
  final GroupDirectoryViewModel viewModel;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    CoeloAdminTableColumn<GroupDirectoryItem> column(
      String id,
      String label,
      String Function(GroupDirectoryItem) value, {
      double width = 180,
    }) => CoeloAdminTableColumn(
      id: id,
      label: label,
      initialWidth: width,
      minWidth: 100,
      maxWidth: 360,
      sortable: true,
      cellBuilder: (context, item) => Align(
        alignment: Alignment.centerLeft,
        child: Text(value(item), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        key: const Key('group-directory-table-viewport'),
        width: constraints.maxWidth,
        child: CoeloAdminResizableTable<GroupDirectoryItem>(
          key: const Key('group-directory-table'),
          items: items,
          rowKey: (item) => 'group-table-row-${item.id}',
          headerHeight: 56,
          rowHeight: 64,
          onRowPressed: (item) => onEdit(item.id),
          sortColumnId: switch (viewModel.query.sortColumn) {
            GroupDirectorySortColumn.name => 'group',
            GroupDirectorySortColumn.institutionName => 'institution',
            GroupDirectorySortColumn.unitName => 'unit',
            GroupDirectorySortColumn.groupType => 'type',
            GroupDirectorySortColumn.status => 'status',
          },
          sortAscending: viewModel.query.sortAscending,
          onSort: (columnId) {
            final column = switch (columnId) {
              'institution' => GroupDirectorySortColumn.institutionName,
              'unit' => GroupDirectorySortColumn.unitName,
              'type' => GroupDirectorySortColumn.groupType,
              'status' => GroupDirectorySortColumn.status,
              _ => GroupDirectorySortColumn.name,
            };
            viewModel.setSort(
              column,
              viewModel.query.sortColumn == column ? !viewModel.query.sortAscending : true,
            );
          },
          pinnedColumn: CoeloAdminTableColumn(
            id: 'group',
            label: 'Grupo',
            initialWidth: 260,
            minWidth: 180,
            maxWidth: 600,
            sortable: true,
            cellBuilder: (context, item) {
              final colors = Theme.of(context).colorScheme;
              return Row(
                children: [
                  Container(
                    width: CoeloSpacing.space8,
                    height: CoeloSpacing.space8,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.groups_rounded,
                      size: CoeloSize.iconSm,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              );
            },
          ),
          columns: [
            column('institution', 'Instituição', (item) => item.institutionName, width: 250),
            column('unit', 'Unidade', (item) => item.unitName, width: 230),
            column('type', 'Tipo', (item) => item.groupTypeLabel),
            CoeloAdminTableColumn(
              id: 'status',
              label: 'Status',
              initialWidth: 176,
              minWidth: 120,
              maxWidth: 600,
              sortable: true,
              cellBuilder: (context, item) => Align(
                alignment: Alignment.centerLeft,
                child: _GroupStatusChip(status: item.status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _GroupActivityRow {
  const _GroupActivityRow({required this.group, required this.activity, required this.prototype});

  final GroupDirectoryItem group;
  final String activity;
  final _GroupPrototype prototype;
}

final class _GroupActivityTable extends StatelessWidget {
  const _GroupActivityTable({required this.items, required this.onEdit});

  final List<GroupDirectoryItem> items;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final item in items)
        for (final activity in _GroupPrototype.from(item).activities)
          _GroupActivityRow(group: item, activity: activity, prototype: _GroupPrototype.from(item)),
    ];

    CoeloAdminTableColumn<_GroupActivityRow> column(
      String id,
      String label,
      String Function(_GroupActivityRow) value, {
      double width = 180,
    }) => CoeloAdminTableColumn(
      id: id,
      label: label,
      initialWidth: width,
      minWidth: 120,
      maxWidth: 360,
      cellBuilder: (context, row) => Align(
        alignment: Alignment.centerLeft,
        child: Text(value(row), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        key: const Key('group-activity-directory-table-viewport'),
        width: constraints.maxWidth,
        child: CoeloAdminResizableTable<_GroupActivityRow>(
          key: const Key('group-activity-directory-table'),
          items: rows,
          rowKey: (row) => 'group-activity-row-${row.group.id}-${row.activity}',
          headerHeight: 56,
          rowHeight: 64,
          onRowPressed: (row) => onEdit(row.group.id),
          pinnedColumn: column('activity', 'Atividade', (row) => row.activity, width: 240),
          columns: [
            column('group', 'Grupo', (row) => row.group.name, width: 240),
            column('unit', 'Unidade', (row) => row.group.unitName, width: 220),
            column('institution', 'Instituição', (row) => row.group.institutionName, width: 240),
            column('team', 'Equipe institucional', (row) => row.prototype.team, width: 220),
            column('guardians', 'Responsáveis', (row) => '${row.prototype.guardianCount}'),
            column('children', 'Crianças', (row) => '${row.prototype.childCount}'),
            CoeloAdminTableColumn(
              id: 'status',
              label: 'Status',
              initialWidth: 176,
              minWidth: 120,
              maxWidth: 260,
              cellBuilder: (context, row) => Align(
                alignment: Alignment.centerLeft,
                child: _GroupStatusChip(status: row.group.status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _GroupStatusChip extends StatelessWidget {
  const _GroupStatusChip({required this.status});
  final GroupStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final pair = switch (status) {
      GroupStatus.active => (colors.successContainer, colors.onSuccessContainer),
      GroupStatus.suspended => (colors.errorContainer, colors.onErrorContainer),
      GroupStatus.draft => (colors.warningContainer, colors.onWarningContainer),
      GroupStatus.inactive || GroupStatus.archived => (
        theme.colorScheme.surfaceContainer,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return CoeloStatusChip(label: status.label, backgroundColor: pair.$1, foregroundColor: pair.$2);
  }
}

final class _GroupPaginationFooter extends StatelessWidget {
  const _GroupPaginationFooter({
    required this.viewModel,
    required this.display,
    required this.horizontalPadding,
  });

  final GroupDirectoryViewModel viewModel;
  final GroupDirectoryDisplay display;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final totalPages = (viewModel.page.totalCount / viewModel.query.pageSize).ceil().clamp(
      1,
      999999,
    );
    return SuperadminListingPaginationFooter(
      semanticKey: const Key('group-directory-pagination-footer'),
      horizontalPadding: horizontalPadding,
      child: CoeloAdminPagination(
        currentPage: viewModel.page.page + 1,
        totalPages: totalPages,
        pageSize: viewModel.query.pageSize,
        pageSizeOptions: display == GroupDirectoryDisplay.cards
            ? const [11, 20, 50, 100]
            : const [8, 20, 50, 100],
        onPageSelected: (page) => viewModel.setPage(page - 1),
        onPageSizeChanged: viewModel.setPageSize,
        onPrevious: viewModel.page.page == 0
            ? null
            : () => viewModel.setPage(viewModel.page.page - 1),
        onNext: viewModel.page.page + 1 >= totalPages
            ? null
            : () => viewModel.setPage(viewModel.page.page + 1),
      ),
    );
  }
}
