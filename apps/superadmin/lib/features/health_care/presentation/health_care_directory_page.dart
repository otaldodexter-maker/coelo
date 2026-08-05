import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import 'health_care_responsive_surface.dart';
import '../../auth/domain/logout_action.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../domain/health_care.dart';
import 'health_care_controller.dart';
import 'health_care_file_actions.dart';

enum _HealthCareTableView { grouped }

enum _ProfileStatusFilter { all, active, implementation, inactive }

final class HealthCareProfileDirectoryPage extends StatefulWidget {
  const HealthCareProfileDirectoryPage({
    required this.controller,
    required this.logout,
    this.onChildSelected,
    this.onCreate,
    super.key,
  });

  final HealthCareController controller;
  final LogoutAction logout;
  final ValueChanged<String>? onChildSelected;
  final VoidCallback? onCreate;

  @override
  State<HealthCareProfileDirectoryPage> createState() => _HealthCareProfileDirectoryPageState();
}

final class _HealthCareProfileDirectoryPageState extends State<HealthCareProfileDirectoryPage> {
  final _search = TextEditingController();
  late final SuperadminActivityController _activityController;

  @override
  void initState() {
    super.initState();
    _activityController = SuperadminActivityController();
    widget.controller.addListener(_refresh);
    widget.controller.load();
  }

  @override
  void didUpdateWidget(covariant HealthCareProfileDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
      Future.microtask(widget.controller.load);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _search.dispose();
    _activityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    activityController: _activityController,
    currentDestination: 'health-care-profiles',
    title: 'Perfis de cuidado',
    subtitle: 'Alergias, restrições e características permanentes de cada criança.',
    chatLauncherBottomInset: CoeloSpacing.space20,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        return Stack(
          children: [
            ListView(
              key: const Key('health-care-profiles-directory-scroll'),
              padding: EdgeInsets.fromLTRB(padding, padding, padding, CoeloSpacing.space24 * 2),
              children: [
                _demoBanner(context),
                const SizedBox(height: CoeloSpacing.space4),
                _toolbar(constraints),
                const SizedBox(height: CoeloSpacing.space3),
                _statusTabs(),
                const SizedBox(height: CoeloSpacing.space1),
                const SizedBox(height: CoeloSpacing.space4),
                LayoutBuilder(
                  builder: (context, contentConstraints) => _content(context, contentConstraints),
                ),
              ],
            ),
            if (widget.controller.page != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: SuperadminListingPaginationFooter(
                  semanticKey: const Key('health-care-profiles-pagination-footer'),
                  horizontalPadding: padding,
                  child: CoeloAdminPagination(
                    currentPage: widget.controller.query.page + 1,
                    totalPages: widget.controller.totalPages,
                    pageSize: widget.controller.query.pageSize,
                    pageSizeOptions: widget.controller.display == HealthCareDirectoryDisplay.cards
                        ? const [11, 20, 50, 100]
                        : const [8, 20, 50, 100],
                    onPrevious: widget.controller.query.page == 0
                        ? null
                        : () => widget.controller.setPage(widget.controller.query.page - 1),
                    onNext: widget.controller.query.page + 1 >= widget.controller.totalPages
                        ? null
                        : () => widget.controller.setPage(widget.controller.query.page + 1),
                    onPageSelected: (value) => widget.controller.setPage(value - 1),
                    onPageSizeChanged: widget.controller.setPageSize,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  ).withHealthCareResponsiveSurface();

  Widget _demoBanner(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surface,
    surfaceTintColor: Colors.transparent,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.science_outlined),
          const Text('Demonstração local • nenhum dado real ou operação produtiva.'),
          Chip(label: Text('Perfil: ${_profileLabel(widget.controller.profile)}')),
        ],
      ),
    ),
  );

  Widget _toolbar(BoxConstraints constraints) => CoeloAdminListingToolbar(
    search: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: CoeloSpacing.space24 * 3),
      child: CoeloSearchField(
        controller: _search,
        semanticLabel: 'Buscar crianças em Perfis de cuidado',
        hintText: 'Buscar criança',
        onChanged: widget.controller.setSearch,
      ),
    ),
    filters: [
      _filter(
        'Pessoa',
        const ['person-demo-a', 'person-demo-b'],
        widget.controller.query.personIds,
        widget.controller.setPersonIds,
      ),
      _filter(
        'Criança',
        const ['child-demo-a', 'child-demo-b'],
        widget.controller.query.childIds,
        widget.controller.setChildIds,
      ),
      _filter(
        'Instituição',
        const ['institution-demo-a', 'institution-demo-b'],
        widget.controller.query.institutionIds,
        widget.controller.setInstitutionIds,
      ),
      _filter(
        'Unidade',
        widget.controller.availableUnitIds.toList(growable: false),
        widget.controller.query.unitIds,
        widget.controller.setUnitIds,
      ),
      _filter(
        'Turma/Atividade',
        widget.controller.availableGroupIds.toList(growable: false),
        widget.controller.query.groupOrActivityIds,
        widget.controller.setGroupIds,
      ),
    ],
    actions: [
      SuperadminDirectoryViewToggle<_HealthCareTableView>(
        cardsSelected: widget.controller.display == HealthCareDirectoryDisplay.cards,
        groupedView: _HealthCareTableView.grouped,
        selectedTableView: _HealthCareTableView.grouped,
        tableViews: const [
          SuperadminDirectoryTableViewOption(
            value: _HealthCareTableView.grouped,
            label: 'Agrupado',
          ),
        ],
        cardsKey: const Key('health-care-profiles-view-cards'),
        tableKey: const Key('health-care-profiles-view-table'),
        onCardsSelected: () => widget.controller.setDisplay(HealthCareDirectoryDisplay.cards),
        onTableViewSelected: (_) => widget.controller.setDisplay(HealthCareDirectoryDisplay.table),
      ),
      HealthCareFileActions(
        activityController: _activityController,
        subject: 'Perfis de cuidado',
        fileBaseName: 'perfis-de-cuidado',
      ),
    ],
  );

  Widget _statusTabs() => SuperadminUnderlineTabs<_ProfileStatusFilter>(
    tabs: const [
      SuperadminUnderlineTab(value: _ProfileStatusFilter.all, label: 'Todos'),
      SuperadminUnderlineTab(value: _ProfileStatusFilter.active, label: 'Ativos'),
      SuperadminUnderlineTab(value: _ProfileStatusFilter.implementation, label: 'Em Implantação'),
      SuperadminUnderlineTab(value: _ProfileStatusFilter.inactive, label: 'Inativos'),
    ],
    selected: _selectedStatus,
    onSelected: (value) => widget.controller.setStatuses(switch (value) {
      _ProfileStatusFilter.all => const {},
      _ProfileStatusFilter.active => const {HealthCareOperationalStatus.active},
      _ProfileStatusFilter.implementation => const {HealthCareOperationalStatus.implementation},
      _ProfileStatusFilter.inactive => const {HealthCareOperationalStatus.inactive},
    }),
  );

  _ProfileStatusFilter get _selectedStatus {
    final statuses = widget.controller.query.operationalStatuses;
    if (statuses.length != 1) return _ProfileStatusFilter.all;
    return switch (statuses.first) {
      HealthCareOperationalStatus.active => _ProfileStatusFilter.active,
      HealthCareOperationalStatus.implementation => _ProfileStatusFilter.implementation,
      HealthCareOperationalStatus.inactive => _ProfileStatusFilter.inactive,
    };
  }

  Widget _filter(
    String label,
    List<String> options,
    Set<String> selected,
    ValueChanged<Set<String>> onChanged,
  ) => _filterBox(
    CoeloAdminMultiSelectFilter<String>(
      label: label,
      options: options,
      selectedValues: selected,
      optionLabel: _contextLabel,
      onChanged: onChanged,
    ),
  );

  Widget _filterBox(Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: CoeloSpacing.space24 * 3),
    child: child,
  );

  Widget _content(BuildContext context, BoxConstraints constraints) {
    final controller = widget.controller;
    if (controller.state != HealthCareLoadState.ready &&
        controller.state != HealthCareLoadState.minimized) {
      return switch (controller.state) {
        HealthCareLoadState.loading => const CoeloStatePanel(
          title: 'Carregando',
          message: 'Buscando registros locais.',
          loading: true,
        ),
        HealthCareLoadState.empty => const CoeloStatePanel(
          title: 'Nenhum registro',
          message: 'Ainda não existem registros demonstrativos.',
        ),
        HealthCareLoadState.noResults => const CoeloStatePanel(
          title: 'Nenhum resultado',
          message: 'Revise a busca ou os filtros independentes.',
        ),
        HealthCareLoadState.error => CoeloStatePanel(
          title: 'Não foi possível carregar',
          message: 'Tente novamente.',
          actionLabel: 'Tentar novamente',
          onAction: controller.load,
        ),
        HealthCareLoadState.unauthorized => const CoeloStatePanel(
          title: 'Sem permissão',
          message: 'O contexto não autoriza esta consulta.',
        ),
        _ => const SizedBox.shrink(),
      };
    }
    if (controller.state == HealthCareLoadState.minimized && controller.items.isEmpty) {
      return const CoeloStatePanel(
        title: 'Resumo minimizado',
        message: 'Somente contagens, pendências e status estão disponíveis.',
      );
    }
    return controller.display == HealthCareDirectoryDisplay.cards
        ? _cards(context, constraints)
        : _table();
  }

  Widget _cards(BuildContext context, BoxConstraints constraints) {
    const minimumCardWidth = 340.0;
    final usable = constraints.maxWidth;
    final columns = math.max(1, (usable / minimumCardWidth).floor());
    final width = (usable - (CoeloSpacing.space6 * (columns - 1))) / columns;
    return Wrap(
      key: const Key('health-care-profiles-cards'),
      spacing: CoeloSpacing.space6,
      runSpacing: CoeloSpacing.space6,
      children: [
        SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 216),
            child: CoeloAdminCreateAction(
              label: 'Criar perfil de cuidado',
              onPressed: widget.onCreate,
            ),
          ),
        ),
        for (final item in widget.controller.items)
          SizedBox(
            width: width,
            child: _ProfileCard(
              item: item,
              minimized: widget.controller.profile == DemoHealthCareProfile.minimized,
              onPressed: widget.controller.canReadSensitive
                  ? () => widget.onChildSelected?.call(item.id)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _table() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloAdminCreateAction(
        label: 'Criar perfil de cuidado',
        description: 'Cadastre alergias, restrições e características de cuidado.',
        variant: CoeloAdminCreateActionVariant.banner,
        onPressed: widget.onCreate,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminResizableTable<HealthCareChildSummary>(
        key: const Key('health-care-profiles-table'),
        items: widget.controller.items,
        rowKey: (item) => item.id,
        pinnedColumn: CoeloAdminTableColumn(
          id: 'child',
          label: 'Criança',
          initialWidth: 260,
          minWidth: 180,
          maxWidth: 420,
          cellBuilder: (_, item) => Text(item.displayName, overflow: TextOverflow.ellipsis),
        ),
        columns: [
          CoeloAdminTableColumn(
            id: 'status',
            label: 'Status',
            initialWidth: 180,
            minWidth: 140,
            maxWidth: 240,
            cellBuilder: (_, item) => _StatusText(status: item.operationalStatus),
          ),
          CoeloAdminTableColumn(
            id: 'allergies',
            label: 'Alergias e restrições',
            initialWidth: 190,
            minWidth: 150,
            maxWidth: 260,
            cellBuilder: (_, item) => Text('${item.activeAllergyCount} ativas'),
          ),
          CoeloAdminTableColumn(
            id: 'care',
            label: 'Perfil de cuidado',
            initialWidth: 190,
            minWidth: 150,
            maxWidth: 260,
            cellBuilder: (_, item) => Text(
              item.pendingAcknowledgementCount == 0
                  ? 'Atualizado'
                  : '${item.pendingAcknowledgementCount} ciência(s)',
            ),
          ),
        ],
        headerHeight: 56,
        rowHeight: 64,
        onRowPressed: widget.controller.canReadSensitive
            ? (item) => widget.onChildSelected?.call(item.id)
            : null,
      ),
    ],
  );
}

final class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.item, required this.minimized, required this.onPressed});

  final HealthCareChildSummary item;
  final bool minimized;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    minHeight: 216,
    onPressed: onPressed,
    semanticLabel: onPressed == null
        ? 'Resumo minimizado de ${item.displayName}'
        : 'Abrir perfil de cuidado de ${item.displayName}',
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space6,
        vertical: CoeloSpacing.space4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoeloAvatar(
                semanticLabel: 'Avatar de ${item.displayName}',
                initials: minimized ? null : 'CD',
              ),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Text(item.displayName, style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              _StatusIndicator(status: item.operationalStatus),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Text('${item.activeAllergyCount} alergia(s) ou restrição(ões) ativa(s)'),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            item.pendingAcknowledgementCount == 0
                ? 'Informações de cuidado atualizadas'
                : '${item.pendingAcknowledgementCount} ciência(s) pendente(s)',
          ),
          if (minimized) ...[
            const SizedBox(height: CoeloSpacing.space2),
            const Text('Resumo minimizado'),
          ],
        ],
      ),
    ),
  );
}

final class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.status});
  final HealthCareOperationalStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final pair = switch (status) {
      HealthCareOperationalStatus.active => (colors.successContainer, colors.onSuccessContainer),
      HealthCareOperationalStatus.implementation => (colors.infoContainer, colors.onInfoContainer),
      HealthCareOperationalStatus.inactive => (colors.historyContainer, colors.onHistoryContainer),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: _statusLabel(status),
      backgroundColor: pair.$1,
      foregroundColor: pair.$2,
    );
  }
}

final class _StatusText extends StatelessWidget {
  const _StatusText({required this.status});
  final HealthCareOperationalStatus status;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _StatusIndicator(status: status),
      const SizedBox(width: CoeloSpacing.space2),
      Flexible(child: Text(_statusLabel(status), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}

String _profileLabel(DemoHealthCareProfile value) => switch (value) {
  DemoHealthCareProfile.owner => 'Owner',
  DemoHealthCareProfile.sensitiveReader => 'Leitor sensível',
  DemoHealthCareProfile.minimized => 'Operador minimizado',
};

String _statusLabel(HealthCareOperationalStatus value) => switch (value) {
  HealthCareOperationalStatus.active => 'Ativo',
  HealthCareOperationalStatus.implementation => 'Em Implantação',
  HealthCareOperationalStatus.inactive => 'Inativo',
};

String _contextLabel(String value) => switch (value) {
  'person-demo-a' => 'Pessoa Demo A',
  'person-demo-b' => 'Pessoa Demo B',
  'child-demo-a' => 'Criança Demo A',
  'child-demo-b' => 'Criança Demo B',
  'institution-demo-a' => 'Instituição Demo A',
  'institution-demo-b' => 'Instituição Demo B',
  'unit-demo-a' => 'Unidade Demo A',
  'unit-demo-b' => 'Unidade Demo B',
  'group-demo-a' => 'Turma Demo A',
  'group-demo-b' => 'Turma Demo B',
  _ => value,
};
