import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/person_directory.dart';
import 'person_file_actions.dart';
import 'person_directory_view_model.dart';

final class PersonDirectoryPage extends StatefulWidget {
  const PersonDirectoryPage({
    required this.repository,
    required this.logout,
    this.onCreate,
    this.onEdit,
    this.onOpen,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.onImport,
    this.onExport,
    this.successMessage,
    super.key,
  });

  final PersonDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;

  /// Abre o detalhe (vinculos) da pessoa; sem ele, o card abre o editor.
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final VoidCallback? onImport;
  final PersonExportAction? onExport;
  final String? successMessage;

  @override
  State<PersonDirectoryPage> createState() => _PersonDirectoryPageState();
}

final class _PersonDirectoryPageState extends State<PersonDirectoryPage> {
  late PersonDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  double _paginationFooterHeight = 0;
  bool _noticeShown = false;

  @override
  void didUpdateWidget(covariant PersonDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _viewModel.dispose();
      _viewModel = PersonDirectoryViewModel(widget.repository);
      _searchController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _viewModel.load();
      });
    }
    if (oldWidget.successMessage != widget.successMessage) {
      _noticeShown = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _viewModel = PersonDirectoryViewModel(widget.repository);
    _searchController = TextEditingController();
    _activityController = SuperadminActivityController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _viewModel.load());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _searchController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: 'Pessoas',
    subtitle: 'Gerencie identidades globais e vínculos contextuais.',
    currentDestination: 'people',
    activityController: _activityController,
    showChatLauncher: widget.onConversationsOpen != null,
    chatLauncherBottomInset: _paginationFooterHeight,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    onOpenConversations: widget.onConversationsOpen,
    onDestinationSelected: widget.onDestinationSelected,
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
        return _PersonDirectoryContent(
          viewModel: _viewModel,
          searchController: _searchController,
          onImport: widget.onImport,
          onExport: widget.onExport,
          onCreate: widget.onCreate,
          onEdit: widget.onOpen ?? widget.onEdit,
          onFooterHeightChanged: (height) {
            if ((_paginationFooterHeight - height).abs() < .5) return;
            setState(() => _paginationFooterHeight = height);
          },
        );
      },
    ),
  );
}

/// Diretório de Pessoas: instância do `CoeloAdminDirectory` com o conteúdo de
/// domínio (busca, filtros dependentes, segmentos, cards e linhas da tabela).
final class _PersonDirectoryContent extends StatelessWidget {
  const _PersonDirectoryContent({
    required this.viewModel,
    required this.searchController,
    required this.onImport,
    required this.onExport,
    required this.onCreate,
    required this.onEdit,
    required this.onFooterHeightChanged,
  });

  final PersonDirectoryViewModel viewModel;
  final TextEditingController searchController;
  final VoidCallback? onImport;
  final PersonExportAction? onExport;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<double> onFooterHeightChanged;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: viewModel,
    builder: (context, _) {
      final page = viewModel.page;
      final onCreate = this.onCreate;
      final totalPages = math.max(1, (page.totalCount / viewModel.query.pageSize).ceil());
      return CoeloAdminDirectory<PersonDirectoryTableView>(
        scrollKey: const Key('people-directory-scroll'),
        toolbarKey: const Key('people-filter-toolbar'),
        cardsKey: const Key('people-view-cards'),
        tableKey: const Key('people-view-table'),
        gridKey: const Key('people-card-grid'),
        status: switch (viewModel.state) {
          PersonDirectoryLoadState.initial ||
          PersonDirectoryLoadState.loading => CoeloAdminDirectoryStatus.loading,
          PersonDirectoryLoadState.empty => CoeloAdminDirectoryStatus.empty,
          PersonDirectoryLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
          PersonDirectoryLoadState.failure => CoeloAdminDirectoryStatus.failure,
          PersonDirectoryLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
          PersonDirectoryLoadState.success => CoeloAdminDirectoryStatus.success,
        },
        refreshing: viewModel.state == PersonDirectoryLoadState.loading,
        messages: const CoeloAdminDirectoryMessages(
          empty: 'Nenhuma pessoa cadastrada',
          emptyIcon: Icons.people_outline_rounded,
          noResults: 'Nenhum resultado',
          noResultsIcon: Icons.search_off_rounded,
          failure: 'Não foi possível carregar as pessoas',
          failureIcon: Icons.error_outline_rounded,
          unauthorized: 'Acesso não autorizado',
          unauthorizedIcon: Icons.lock_outline_rounded,
        ),
        errorMessage: switch (viewModel.state) {
          PersonDirectoryLoadState.empty => 'Crie a primeira pessoa para começar.',
          PersonDirectoryLoadState.noResults => 'Revise a busca ou os filtros aplicados.',
          PersonDirectoryLoadState.failure => 'Tente novamente em instantes.',
          PersonDirectoryLoadState.unauthorized => 'Você não possui people.read.',
          _ => null,
        },
        onRetry: viewModel.retry,
        onClearFilters: () => clearPeopleFilters(searchController, viewModel),
        search: CoeloSearchField(
          controller: searchController,
          hintText: 'Buscar por nome',
          semanticLabel: 'Buscar pessoas por nome',
          onChanged: viewModel.setSearch,
        ),
        filters: personFilterControls(viewModel),
        trailing: [
          if (viewModel.query.hasActiveFilters)
            TextButton.icon(
              onPressed: () => clearPeopleFilters(searchController, viewModel),
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtros'),
            ),
        ],
        display: viewModel.layout == PersonDirectoryLayout.cards
            ? CoeloAdminDirectoryDisplay.cards
            : CoeloAdminDirectoryDisplay.table,
        onDisplayChanged: (value) => viewModel.setLayout(
          value == CoeloAdminDirectoryDisplay.cards
              ? PersonDirectoryLayout.cards
              : PersonDirectoryLayout.table,
        ),
        groupedTableView: PersonDirectoryTableView.grouped,
        selectedTableView: viewModel.tableView,
        tableViews: [
          for (final view in PersonDirectoryTableView.values)
            CoeloAdminDirectoryTableViewOption(value: view, label: view.label),
        ],
        onTableViewSelected: viewModel.setTableView,
        fileActions: viewModel.state == PersonDirectoryLoadState.success
            ? personFileActions(
                context,
                onImport: onImport,
                onExport: onExport,
                tableView: viewModel.tableView,
              )
            : null,
        tabs: CoeloAdminUnderlineTabs<PersonDirectorySegment>(
          key: const Key('people-segment-selector'),
          tabs: [
            for (final segment in PersonDirectorySegment.values)
              CoeloAdminUnderlineTab(value: segment, label: segment.label),
          ],
          selected: viewModel.query.segment,
          onSelected: viewModel.setSegment,
        ),
        create: onCreate == null
            ? null
            : CoeloAdminDirectoryCreate(
                label: 'Criar pessoa',
                description: 'Cadastre identidade e vínculos contextuais.',
                icon: Icons.person_add_alt_1_outlined,
                onPressed: onCreate,
                tileKey: const Key('create-person-card'),
                bannerKey: const Key('create-person-banner'),
              ),
        cards: [for (final item in page.items) _PersonCard(item: item, onEdit: onEdit)],
        table: _PersonTableRows(
          items: page.items,
          onEdit: onEdit,
          sortColumn: viewModel.query.sortColumn,
          sortAscending: viewModel.query.sortAscending,
          onSort: viewModel.setSort,
          tableView: viewModel.tableView,
        ),
        pagination: viewModel.state == PersonDirectoryLoadState.success
            ? CoeloAdminDirectoryPagination(
                footerKey: const Key('people-directory-pagination-footer'),
                currentPage: page.page + 1,
                totalPages: totalPages,
                pageSize: viewModel.query.pageSize,
                pageSizeOptions: viewModel.layout == PersonDirectoryLayout.cards
                    ? const [11, 20, 50, 100]
                    : const [8, 20, 50, 100],
                onPageSelected: (value) => viewModel.goToPage(value - 1),
                onPageSizeChanged: viewModel.setPageSize,
              )
            : null,
        onFooterHeightChanged: onFooterHeightChanged,
      );
    },
  );
}

/// Filtros de domínio de Pessoas, sem largura: o composto aplica a largura da
/// família. Unidade, turma, atividade e papel dependem da instituição;
/// município e bairro dependem da UF.
List<Widget> personFilterControls(PersonDirectoryViewModel viewModel) {
  Widget filter<T>({
    required Key key,
    required String label,
    required List<T> options,
    required Set<T> selected,
    required String Function(T) optionLabel,
    required ValueChanged<Set<T>> changed,
    String? searchHintText,
  }) => CoeloAdminMultiSelectFilter<T>(
    key: key,
    label: label,
    options: options,
    selectedValues: selected,
    optionLabel: optionLabel,
    onChanged: changed,
    searchHintText: searchHintText,
  );
  final selectedInstitutions = viewModel.query.institutionIds;
  final visibleUnits = viewModel.visibleUnits;
  final visibleGroups = viewModel.visibleGroups;
  final visibleActivities = viewModel.visibleActivities;
  final visibleMunicipalities = viewModel.visibleMunicipalities;
  final visibleNeighborhoods = viewModel.visibleNeighborhoods;
  final visibleRoles = viewModel.filterOptions.roles
      .where((option) => selectedInstitutions.contains(option.institutionId))
      .toList(growable: false);
  return [
    filter<PersonType>(
      key: const Key('people-type-filter'),
      label: 'Tipo',
      options: PersonType.values,
      selected: viewModel.query.types,
      optionLabel: (value) => value.label,
      changed: viewModel.setTypes,
    ),
    filter<PersonStatus>(
      key: const Key('people-status-filter'),
      label: 'Status',
      options: PersonStatus.values,
      selected: viewModel.query.statuses,
      optionLabel: (value) => value.label,
      changed: viewModel.setStatuses,
    ),
    filter<PersonFilterOption>(
      key: const Key('people-institution-filter'),
      label: 'Instituição',
      options: viewModel.filterOptions.institutions,
      selected: viewModel.filterOptions.institutions
          .where((item) => viewModel.query.institutionIds.contains(item.id))
          .toSet(),
      optionLabel: (value) => value.label,
      changed: (values) => viewModel.setInstitutions(values.map((item) => item.id).toSet()),
      searchHintText: 'Buscar instituição',
    ),
    if (selectedInstitutions.isNotEmpty)
      filter<PersonFilterOption>(
        key: const Key('people-unit-filter'),
        label: 'Unidade',
        options: visibleUnits,
        selected: visibleUnits.where((item) => viewModel.query.unitIds.contains(item.id)).toSet(),
        optionLabel: (value) => value.label,
        changed: (values) => viewModel.setUnits(values.map((item) => item.id).toSet()),
        searchHintText: 'Buscar unidade',
      ),
    if (viewModel.query.unitIds.isNotEmpty)
      filter<PersonFilterOption>(
        key: const Key('people-group-filter'),
        label: 'Turma',
        options: visibleGroups,
        selected: visibleGroups.where((item) => viewModel.query.groupIds.contains(item.id)).toSet(),
        optionLabel: (value) => value.label,
        changed: (values) => viewModel.setGroups(values.map((item) => item.id).toSet()),
        searchHintText: 'Buscar grupo',
      ),
    if (viewModel.query.groupIds.isNotEmpty)
      filter<PersonFilterOption>(
        key: const Key('people-activity-filter'),
        label: 'Atividade',
        options: visibleActivities,
        selected: visibleActivities
            .where((item) => viewModel.query.activityIds.contains(item.id))
            .toSet(),
        optionLabel: (value) => value.label,
        changed: (values) => viewModel.setActivities(values.map((item) => item.id).toSet()),
        searchHintText: 'Buscar atividade',
      ),
    if (selectedInstitutions.isNotEmpty)
      filter<PersonFilterOption>(
        key: const Key('people-role-filter'),
        label: 'Papel',
        options: visibleRoles,
        selected: visibleRoles
            .where((item) => viewModel.query.contextualRoles.contains(item.id))
            .toSet(),
        optionLabel: (value) => value.label,
        changed: (values) => viewModel.setRoles(values.map((item) => item.id).toSet()),
        searchHintText: 'Buscar papel',
      ),
    filter<PersonFilterOption>(
      key: const Key('people-state-filter'),
      label: 'UF',
      options: viewModel.filterOptions.states,
      selected: viewModel.filterOptions.states
          .where((item) => viewModel.query.stateCodes.contains(item.id))
          .toSet(),
      optionLabel: (value) => value.label,
      changed: (values) => viewModel.setStates(values.map((item) => item.id).toSet()),
    ),
    if (viewModel.query.stateCodes.isNotEmpty)
      filter<PersonFilterOption>(
        key: const Key('people-municipality-filter'),
        label: 'Município',
        options: visibleMunicipalities,
        selected: visibleMunicipalities
            .where((item) => viewModel.query.municipalityIds.contains(item.id))
            .toSet(),
        optionLabel: (value) => value.label,
        changed: (values) => viewModel.setMunicipalities(values.map((item) => item.id).toSet()),
      ),
    if (viewModel.query.municipalityIds.isNotEmpty)
      filter<PersonFilterOption>(
        key: const Key('people-neighborhood-filter'),
        label: 'Bairro',
        options: visibleNeighborhoods,
        selected: visibleNeighborhoods
            .where((item) => viewModel.query.neighborhoodIds.contains(item.id))
            .toSet(),
        optionLabel: (value) => value.label,
        changed: (values) => viewModel.setNeighborhoods(values.map((item) => item.id).toSet()),
      ),
    filter<AuthLinkStatus>(
      key: const Key('people-auth-filter'),
      label: 'Auth',
      options: AuthLinkStatus.values,
      selected: viewModel.query.authLinks,
      optionLabel: (value) => value.label,
      changed: viewModel.setAuthLinks,
    ),
  ];
}

/// One definition of what "Limpar filtros" means, because the screen offers it
/// twice and the two used to differ: the toolbar cleared the search field and
/// the no-results panel did not, so the same label produced two results and one
/// of them left a term visible in a box that no longer filtered anything.
void clearPeopleFilters(
  TextEditingController searchController,
  PersonDirectoryViewModel viewModel,
) {
  searchController.clear();
  viewModel.clearFilters();
}

final class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.item, required this.onEdit});
  final PersonDirectoryItem item;
  final ValueChanged<String>? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metrics = <Widget>[
      _PersonDetail(
        icon: Icons.account_balance_outlined,
        label: 'Instituições',
        value: '${item.institutionCount}',
      ),
      _PersonDetail(icon: Icons.apartment_outlined, label: 'Unidades', value: '${item.unitCount}'),
      _PersonDetail(icon: Icons.groups_outlined, label: 'Turmas', value: '${item.groupCount}'),
      _PersonDetail(
        icon: Icons.local_activity_outlined,
        label: 'Atividades',
        value: '${item.activityCount}',
      ),
      if (item.linkedChildrenCount > 0)
        _PersonDetail(
          icon: Icons.family_restroom_outlined,
          label: 'Crianças vinculadas',
          value: '${item.linkedChildrenCount}',
        ),
      if (item.accompaniedStudentsCount > 0)
        _PersonDetail(
          icon: Icons.school_outlined,
          label: 'Alunos acompanhados',
          value: '${item.accompaniedStudentsCount}',
        ),
      if (item.linkedGuardiansCount > 0)
        _PersonDetail(
          icon: Icons.supervisor_account_outlined,
          label: 'Responsáveis vinculados',
          value: '${item.linkedGuardiansCount}',
        ),
    ];
    return CoeloAdminInteractiveCard(
      surfaceKey: Key('person-card-${item.id}'),
      minHeight: 216,
      semanticLabel: '${item.displayName}. ${item.type.label}. Status: ${item.status.label}',
      onPressed: onEdit == null ? null : () => onEdit!(item.id),
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
                  child: FittedBox(
                    child: CoeloAvatar(
                      initials: item.initials,
                      semanticLabel: 'Avatar de ${item.displayName}',
                      size: CoeloAvatarSize.large,
                    ),
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        [
                          item.type.label,
                          item.authLink.label,
                          if (!item.isEditable) 'Somente leitura',
                        ].join(' • '),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                _PersonStatusIndicator(item: item),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space4),
            for (var index = 0; index < metrics.length; index += 2) ...[
              _PersonDetails(
                first: metrics[index],
                second: index + 1 < metrics.length ? metrics[index + 1] : const SizedBox.shrink(),
              ),
              if (index + 2 < metrics.length) const SizedBox(height: CoeloSpacing.space3),
            ],
          ],
        ),
      ),
    );
  }
}

final class _PersonDetails extends StatelessWidget {
  const _PersonDetails({required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: first),
      const SizedBox(width: CoeloSpacing.space3),
      Expanded(child: second),
    ],
  );
}

final class _PersonStatusIndicator extends StatefulWidget {
  const _PersonStatusIndicator({required this.item});

  final PersonDirectoryItem item;

  @override
  State<_PersonStatusIndicator> createState() => _PersonStatusIndicatorState();
}

final class _PersonStatusIndicatorState extends State<_PersonStatusIndicator> {
  bool _hovered = false;
  bool _focused = false;
  bool _expandedByTap = false;

  bool get _expanded => _hovered || _focused || _expandedByTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _personStatusColors(context, widget.item.status);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        // It announces itself as a button, so Enter and Space have to work.
        // Without this the chip was a keyboard stop that lit up, claimed to be
        // pressable, and did nothing when pressed - which reads as a broken
        // product to someone navigating by keyboard and is invisible to anyone
        // using a mouse. Same defect, same fix, as the institution status chip.
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              setState(() => _expandedByTap = !_expandedByTap);
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          label: 'Status: ${widget.item.status.label}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expandedByTap = !_expandedByTap),
            child: TweenAnimationBuilder<double>(
              key: Key('person-status-${widget.item.id}'),
              tween: Tween(begin: 0, end: _expanded ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : CoeloMotion.standard,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: CoeloSize.touchMin,
                  minHeight: CoeloSize.touchMin,
                ),
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Container(
                    width:
                        24 +
                        (math.max(56, 24 + widget.item.status.label.length * 6.5) - 24) * progress,
                    height: CoeloSpacing.space6,
                    padding: EdgeInsets.symmetric(horizontal: CoeloSpacing.space2 * progress),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(CoeloRadius.full),
                      border: Border.all(
                        color: foreground.withValues(alpha: _focused ? .48 : .28),
                        width: _focused ? 2 : 1,
                      ),
                    ),
                    child: progress == 0
                        ? null
                        : Opacity(
                            opacity: progress,
                            child: Text(
                              widget.item.status.label,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w600,
                              ),
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

(Color, Color) _personStatusColors(BuildContext context, PersonStatus status) {
  final theme = Theme.of(context);
  final colors = theme.colorScheme;
  final statusColors =
      theme.extension<CoeloStatusColors>() ??
      (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
  return switch (status) {
    PersonStatus.active => (statusColors.successContainer, statusColors.onSuccessContainer),
    PersonStatus.inactive => (statusColors.errorContainer, statusColors.onErrorContainer),
    PersonStatus.suspended => (statusColors.warningContainer, statusColors.onWarningContainer),
    PersonStatus.draft ||
    PersonStatus.archived => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
  };
}

final class _PersonDetail extends StatelessWidget {
  const _PersonDetail({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: CoeloSpacing.space8,
          height: CoeloSpacing.space8,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.sm),
          ),
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
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Linhas e colunas de domínio de Pessoas sobre a tabela compartilhada.
final class _PersonTableRows extends StatelessWidget {
  const _PersonTableRows({
    required this.items,
    required this.onEdit,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.tableView,
  });
  final List<PersonDirectoryItem> items;
  final ValueChanged<String>? onEdit;
  final PersonDirectorySortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<PersonDirectorySortColumn> onSort;
  final PersonDirectoryTableView tableView;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('people-table-viewport'),
    child: Align(
      alignment: Alignment.topCenter,
      child: CoeloAdminResizableTable<PersonDirectoryItem>(
        key: const Key('people-table'),
        items: items,
        rowKey: (item) => 'people-table-row-${item.id}',
        headerHeight: 56,
        rowHeight: 64,
        showHorizontalScrollbar: true,
        onRowPressed: onEdit == null ? null : (item) => onEdit!(item.id),
        pinnedColumn: CoeloAdminTableColumn(
          id: 'display_name',
          label: 'Pessoa',
          initialWidth: 240,
          minWidth: 180,
          maxWidth: 360,
          sortable: true,
          cellBuilder: (context, item) => Row(
            children: [
              CoeloAvatar(
                initials: item.initials,
                semanticLabel: 'Avatar de ${item.displayName}',
                size: CoeloAvatarSize.small,
              ),
              const SizedBox(width: CoeloSpacing.space2),
              Expanded(child: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        sortColumnId: sortColumn.databaseValue,
        sortAscending: sortAscending,
        onSort: (id) {
          final column = PersonDirectorySortColumn.values
              .where((item) => item.databaseValue == id)
              .firstOrNull;
          if (column != null) onSort(column);
        },
        columns: [
          if (tableView == PersonDirectoryTableView.grouped)
            CoeloAdminTableColumn(
              id: 'type',
              label: 'Tipo',
              initialWidth: 128,
              minWidth: 112,
              maxWidth: 180,
              sortable: true,
              cellBuilder: (context, item) => Text(item.type.label),
            ),
          if (tableView == PersonDirectoryTableView.grouped)
            CoeloAdminTableColumn(
              id: 'status',
              label: 'Status',
              initialWidth: 128,
              minWidth: 112,
              maxWidth: 180,
              sortable: true,
              cellBuilder: (context, item) {
                final (background, foreground) = _personStatusColors(context, item.status);
                return CoeloStatusChip(
                  label: item.status.label,
                  backgroundColor: background,
                  foregroundColor: foreground,
                );
              },
            ),
          CoeloAdminTableColumn(
            id: PersonDirectorySortColumn.institution.databaseValue,
            label: 'Instituição',
            initialWidth: 220,
            minWidth: 160,
            maxWidth: 360,
            sortable: true,
            cellBuilder: (context, item) => Text(
              item.institutionSummary.isEmpty ? 'Não informado' : item.institutionSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (tableView != PersonDirectoryTableView.institutions)
            CoeloAdminTableColumn(
              id: PersonDirectorySortColumn.unit.databaseValue,
              label: 'Unidade',
              initialWidth: 180,
              minWidth: 140,
              maxWidth: 280,
              sortable: true,
              cellBuilder: (context, item) => Text(
                item.unitSummary.isEmpty ? 'Não informado' : item.unitSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (tableView == PersonDirectoryTableView.grouped ||
              tableView == PersonDirectoryTableView.groups ||
              tableView == PersonDirectoryTableView.activities)
            CoeloAdminTableColumn(
              id: PersonDirectorySortColumn.group.databaseValue,
              label: 'Turma',
              initialWidth: 180,
              minWidth: 140,
              maxWidth: 280,
              sortable: true,
              cellBuilder: (context, item) => Text(
                item.groupSummary.isEmpty ? 'Não informado' : item.groupSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (tableView == PersonDirectoryTableView.grouped)
            CoeloAdminTableColumn(
              id: PersonDirectorySortColumn.role.databaseValue,
              label: 'Papel contextual',
              initialWidth: 180,
              minWidth: 140,
              maxWidth: 280,
              sortable: true,
              cellBuilder: (context, item) => Text(item.roleSummary),
            ),
          if (tableView == PersonDirectoryTableView.grouped)
            CoeloAdminTableColumn(
              id: PersonDirectorySortColumn.authLink.databaseValue,
              label: 'Auth',
              initialWidth: 140,
              minWidth: 112,
              maxWidth: 180,
              sortable: true,
              cellBuilder: (context, item) =>
                  Text(item.isEditable ? item.authLink.label : 'Somente leitura'),
            ),
          if (tableView == PersonDirectoryTableView.grouped ||
              tableView == PersonDirectoryTableView.activities)
            CoeloAdminTableColumn(
              id: 'activity',
              label: 'Atividades',
              initialWidth: 180,
              minWidth: 140,
              maxWidth: 280,
              cellBuilder: (context, item) => Text(
                item.activitySummary.isEmpty ? 'Não informado' : item.activitySummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    ),
  );
}
