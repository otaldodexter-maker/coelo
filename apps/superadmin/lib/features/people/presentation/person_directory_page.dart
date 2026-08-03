import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_notice.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
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
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.successMessage,
    super.key,
  });

  final PersonDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final String? successMessage;

  @override
  State<PersonDirectoryPage> createState() => _PersonDirectoryPageState();
}

final class _PersonDirectoryPageState extends State<PersonDirectoryPage> {
  late final PersonDirectoryViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  double _paginationFooterHeight = 0;
  bool _noticeShown = false;

  @override
  void didUpdateWidget(covariant PersonDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
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
          activityController: _activityController,
          onCreate: widget.onCreate ?? () {},
          onEdit: widget.onEdit ?? (_) {},
          onFooterHeightChanged: (height) {
            if ((_paginationFooterHeight - height).abs() < .5) return;
            setState(() => _paginationFooterHeight = height);
          },
        );
      },
    ),
  );
}

final class _PersonDirectoryContent extends StatefulWidget {
  const _PersonDirectoryContent({
    required this.viewModel,
    required this.searchController,
    required this.activityController,
    required this.onCreate,
    required this.onEdit,
    required this.onFooterHeightChanged,
  });

  final PersonDirectoryViewModel viewModel;
  final TextEditingController searchController;
  final SuperadminActivityController activityController;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;
  final ValueChanged<double> onFooterHeightChanged;

  @override
  State<_PersonDirectoryContent> createState() => _PersonDirectoryContentState();
}

final class _PersonDirectoryContentState extends State<_PersonDirectoryContent> {
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
        final renderObject = _footerKey.currentContext?.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) return;
        height = renderObject.size.height;
      }
      if ((height - _footerHeight).abs() < .5) return;
      setState(() => _footerHeight = height);
      widget.onFooterHeightChanged(height);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontalPadding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space6
          : CoeloSpacing.space4;
      return AnimatedBuilder(
        animation: widget.viewModel,
        builder: (context, child) {
          final showPagination = widget.viewModel.state == PersonDirectoryLoadState.success;
          _measureFooter(showPagination);
          final footerInset = showPagination ? _footerHeight + CoeloSpacing.space4 : 0.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              ListView(
                key: const Key('people-directory-scroll'),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  horizontalPadding,
                  horizontalPadding,
                  horizontalPadding + footerInset,
                ),
                children: [
                  _PersonToolbar(
                    viewModel: widget.viewModel,
                    searchController: widget.searchController,
                    activityController: widget.activityController,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _PersonSegmentSelector(viewModel: widget.viewModel),
                  const SizedBox(height: CoeloSpacing.space4),
                  _PersonResults(
                    viewModel: widget.viewModel,
                    onCreate: widget.onCreate,
                    onEdit: widget.onEdit,
                  ),
                ],
              ),
              if (showPagination)
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
                      child: _PersonPaginationFooter(
                        viewModel: widget.viewModel,
                        horizontalPadding: horizontalPadding,
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

final class _PersonSegmentSelector extends StatelessWidget {
  const _PersonSegmentSelector({required this.viewModel});

  final PersonDirectoryViewModel viewModel;

  @override
  Widget build(BuildContext context) => SuperadminUnderlineTabs<PersonDirectorySegment>(
    key: const Key('people-segment-selector'),
    tabs: [
      for (final segment in PersonDirectorySegment.values)
        SuperadminUnderlineTab(value: segment, label: segment.label),
    ],
    selected: viewModel.query.segment,
    onSelected: viewModel.setSegment,
  );
}

final class _PersonToolbar extends StatelessWidget {
  const _PersonToolbar({
    required this.viewModel,
    required this.searchController,
    required this.activityController,
  });
  final PersonDirectoryViewModel viewModel;
  final TextEditingController searchController;
  final SuperadminActivityController activityController;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final compactFileAction = compact || constraints.maxWidth < 1000;
      final filterWidth = compact
          ? (constraints.maxWidth - CoeloSpacing.space3) / 2
          : CoeloSpacing.space20 * 2;
      final searchWidth = compact ? constraints.maxWidth : 216.0;
      Widget filter<T>({
        required Key key,
        required String label,
        required List<T> options,
        required Set<T> selected,
        required String Function(T) optionLabel,
        required ValueChanged<Set<T>> changed,
        String? searchHintText,
      }) => SizedBox(
        key: key,
        width: filterWidth,
        child: CoeloAdminMultiSelectFilter<T>(
          label: label,
          options: options,
          selectedValues: selected,
          optionLabel: optionLabel,
          onChanged: changed,
          searchHintText: searchHintText,
        ),
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
      final filters = <Widget>[
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
            selected: visibleUnits
                .where((item) => viewModel.query.unitIds.contains(item.id))
                .toSet(),
            optionLabel: (value) => value.label,
            changed: (values) => viewModel.setUnits(values.map((item) => item.id).toSet()),
            searchHintText: 'Buscar unidade',
          ),
        if (viewModel.query.unitIds.isNotEmpty)
          filter<PersonFilterOption>(
            key: const Key('people-group-filter'),
            label: 'Grupo',
            options: visibleGroups,
            selected: visibleGroups
                .where((item) => viewModel.query.groupIds.contains(item.id))
                .toSet(),
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
        key: const Key('people-filter-toolbar'),
        search: SizedBox(
          width: searchWidth,
          height: CoeloSize.touchMin,
          child: CoeloSearchField(
            controller: searchController,
            hintText: 'Buscar por nome',
            semanticLabel: 'Buscar pessoas por nome',
            onChanged: viewModel.setSearch,
          ),
        ),
        filters: filters,
        actions: [
          SizedBox(
            height: CoeloSize.touchMin,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SuperadminDirectoryViewToggle<PersonDirectoryTableView>(
                  cardsSelected: viewModel.layout == PersonDirectoryLayout.cards,
                  groupedView: PersonDirectoryTableView.grouped,
                  selectedTableView: viewModel.tableView,
                  tableViews: [
                    for (final view in PersonDirectoryTableView.values)
                      SuperadminDirectoryTableViewOption(value: view, label: view.label),
                  ],
                  cardsKey: const Key('people-view-cards'),
                  tableKey: const Key('people-view-table'),
                  onCardsSelected: () => viewModel.setLayout(PersonDirectoryLayout.cards),
                  onTableViewSelected: viewModel.setTableView,
                ),
                const SizedBox(width: CoeloSpacing.space2),
                PersonFileActions(
                  activityController: activityController,
                  compact: compactFileAction,
                  tableView: viewModel.tableView,
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

final class _PersonResults extends StatelessWidget {
  const _PersonResults({required this.viewModel, required this.onCreate, required this.onEdit});
  final PersonDirectoryViewModel viewModel;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    Widget state;
    switch (viewModel.state) {
      case PersonDirectoryLoadState.initial:
      case PersonDirectoryLoadState.loading:
        state = const CoeloStatePanel(
          title: 'Carregando pessoas',
          message: 'Aguarde enquanto buscamos o diretório.',
          loading: true,
        );
      case PersonDirectoryLoadState.empty:
        state = const CoeloStatePanel(
          title: 'Nenhuma pessoa cadastrada',
          message: 'Crie a primeira pessoa para começar.',
          icon: Icons.people_outline_rounded,
        );
      case PersonDirectoryLoadState.noResults:
        state = CoeloStatePanel(
          title: 'Nenhum resultado',
          message: 'Revise a busca ou os filtros aplicados.',
          icon: Icons.search_off_rounded,
          actionLabel: 'Limpar filtros',
          onAction: viewModel.clearFilters,
        );
      case PersonDirectoryLoadState.failure:
        state = CoeloStatePanel(
          title: 'Não foi possível carregar as pessoas',
          message: 'Tente novamente em instantes.',
          icon: Icons.error_outline_rounded,
          actionLabel: 'Tentar novamente',
          onAction: viewModel.retry,
        );
      case PersonDirectoryLoadState.unauthorized:
        state = const CoeloStatePanel(
          title: 'Acesso não autorizado',
          message: 'Você não possui people.read.',
          icon: Icons.lock_outline_rounded,
        );
      case PersonDirectoryLoadState.success:
        state = viewModel.layout == PersonDirectoryLayout.cards
            ? _PersonCards(items: viewModel.page.items, onCreate: onCreate, onEdit: onEdit)
            : _PersonTable(
                items: viewModel.page.items,
                onCreate: onCreate,
                onEdit: onEdit,
                sortColumn: viewModel.query.sortColumn,
                sortAscending: viewModel.query.sortAscending,
                onSort: viewModel.setSort,
                tableView: viewModel.tableView,
              );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.state == PersonDirectoryLoadState.loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        state,
      ],
    );
  }
}

final class _PersonCards extends StatelessWidget {
  const _PersonCards({required this.items, required this.onCreate, required this.onEdit});
  final List<PersonDirectoryItem> items;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(1, (constraints.maxWidth / 340).floor());
      final cards = <Widget>[
        ConstrainedBox(
          key: const Key('create-person-card'),
          constraints: const BoxConstraints(minHeight: 216),
          child: CoeloAdminCreateAction(
            label: 'Criar pessoa',
            icon: Icons.person_add_alt_1_outlined,
            onPressed: onCreate,
          ),
        ),
        for (final item in items) _PersonCard(item: item, onEdit: onEdit),
      ];
      return Column(
        key: const Key('people-card-grid'),
        children: [
          for (var start = 0; start < cards.length; start += columns) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    Expanded(
                      child: start + column < cards.length
                          ? cards[start + column]
                          : const SizedBox.shrink(),
                    ),
                    if (column + 1 < columns) const SizedBox(width: CoeloSpacing.space6),
                  ],
                ],
              ),
            ),
            if (start + columns < cards.length) const SizedBox(height: CoeloSpacing.space6),
          ],
        ],
      );
    },
  );
}

final class _PersonCard extends StatefulWidget {
  const _PersonCard({required this.item, required this.onEdit});
  final PersonDirectoryItem item;
  final ValueChanged<String> onEdit;

  @override
  State<_PersonCard> createState() => _PersonCardState();
}

final class _PersonCardState extends State<_PersonCard> {
  final FocusNode _focusNode = FocusNode();
  bool _highlighted = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = Theme.of(context).colorScheme;
    final metrics = <Widget>[
      _PersonDetail(
        icon: Icons.account_balance_outlined,
        label: 'Instituições',
        value: '${item.institutionCount}',
      ),
      _PersonDetail(icon: Icons.apartment_outlined, label: 'Unidades', value: '${item.unitCount}'),
      _PersonDetail(icon: Icons.groups_outlined, label: 'Grupos', value: '${item.groupCount}'),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 216),
      child: MouseRegion(
        onEnter: (_) => setState(() => _highlighted = true),
        onExit: (_) => setState(() => _highlighted = false),
        child: Semantics(
          button: true,
          label: '${item.displayName}. ${item.type.label}. Status: ${item.status.label}',
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _highlighted ? 1 : 0),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : CoeloMotion.standard,
            builder: (context, progress, child) => Container(
              key: Key('person-card-${item.id}'),
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
                    blurRadius: CoeloSpacing.space2 + CoeloSpacing.space1 * progress,
                    spreadRadius: CoeloSpacing.spaceHalf * progress,
                    offset: Offset(0, CoeloSpacing.spaceHalf + CoeloSpacing.spaceHalf * progress),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                child: InkWell(
                  focusNode: _focusNode,
                  onFocusChange: (value) => setState(() => _highlighted = value),
                  onTap: () => widget.onEdit(item.id),
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  child: child,
                ),
              ),
            ),
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
                      second: index + 1 < metrics.length
                          ? metrics[index + 1]
                          : const SizedBox.shrink(),
                    ),
                    if (index + 2 < metrics.length) const SizedBox(height: CoeloSpacing.space3),
                  ],
                ],
              ),
            ),
          ),
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
        child: Semantics(
          button: true,
          label: 'Status: ${widget.item.status.label}',
          child: GestureDetector(
            onTap: () => setState(() => _expandedByTap = !_expandedByTap),
            child: TweenAnimationBuilder<double>(
              key: Key('person-status-${widget.item.id}'),
              tween: Tween(begin: 0, end: _expanded ? 1 : 0),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : CoeloMotion.standard,
              curve: Curves.easeOutCubic,
              builder: (context, progress, child) => Container(
                width:
                    24 + (math.max(56, 24 + widget.item.status.label.length * 6.5) - 24) * progress,
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

final class _PersonTable extends StatelessWidget {
  const _PersonTable({
    required this.items,
    required this.onCreate,
    required this.onEdit,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.tableView,
  });
  final List<PersonDirectoryItem> items;
  final VoidCallback onCreate;
  final ValueChanged<String> onEdit;
  final PersonDirectorySortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<PersonDirectorySortColumn> onSort;
  final PersonDirectoryTableView tableView;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        SizedBox(
          width: constraints.maxWidth,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoeloSpacing.space20),
            child: CoeloAdminCreateAction(
              key: const Key('create-person-banner'),
              label: 'Criar pessoa',
              description: 'Cadastre identidade e vínculos contextuais.',
              icon: Icons.person_add_alt_1_outlined,
              variant: CoeloAdminCreateActionVariant.banner,
              onPressed: onCreate,
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        SizedBox(
          key: const Key('people-table-viewport'),
          width: constraints.maxWidth,
          child: CoeloAdminResizableTable<PersonDirectoryItem>(
            key: const Key('people-table'),
            items: items,
            rowKey: (item) => 'people-table-row-${item.id}',
            headerHeight: 56,
            rowHeight: 64,
            onRowPressed: (item) {
              onEdit(item.id);
            },
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
                  Expanded(
                    child: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
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
                  label: 'Grupo',
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
      ],
    ),
  );
}

final class _PersonPaginationFooter extends StatelessWidget {
  const _PersonPaginationFooter({required this.viewModel, required this.horizontalPadding});
  final PersonDirectoryViewModel viewModel;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final totalPages = math.max(1, (viewModel.page.totalCount / viewModel.query.pageSize).ceil());
    final options = viewModel.layout == PersonDirectoryLayout.cards
        ? const [11, 20, 50, 100]
        : const [8, 20, 50, 100];
    return SuperadminListingPaginationFooter(
      semanticKey: const Key('people-directory-pagination-footer'),
      horizontalPadding: horizontalPadding,
      child: CoeloAdminPagination(
        currentPage: viewModel.page.page + 1,
        totalPages: totalPages,
        pageSize: viewModel.query.pageSize,
        pageSizeOptions: options,
        onPageSelected: (page) => viewModel.goToPage(page - 1),
        onPageSizeChanged: viewModel.setPageSize,
        onPrevious: viewModel.page.hasPrevious
            ? () => viewModel.goToPage(viewModel.page.page - 1)
            : null,
        onNext: viewModel.page.hasNext ? () => viewModel.goToPage(viewModel.page.page + 1) : null,
      ),
    );
  }
}
