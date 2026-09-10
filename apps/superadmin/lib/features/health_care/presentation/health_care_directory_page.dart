import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import 'health_care_responsive_surface.dart';
import '../../auth/domain/logout_action.dart';
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
    this.onImport,
    this.onExportCsv,
    this.onExportXlsx,
    super.key,
  });

  final HealthCareController controller;
  final LogoutAction logout;
  final ValueChanged<String>? onChildSelected;
  final VoidCallback? onCreate;
  final VoidCallback? onImport;
  final VoidCallback? onExportCsv;
  final VoidCallback? onExportXlsx;

  @override
  State<HealthCareProfileDirectoryPage> createState() => _HealthCareProfileDirectoryPageState();
}

final class _HealthCareProfileDirectoryPageState extends State<HealthCareProfileDirectoryPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: 'health-care-profiles',
    title: 'Perfis de cuidado',
    subtitle: 'Alergias, restrições e características permanentes de cada criança.',
    child: widget.controller.state == HealthCareLoadState.unauthorized
        ? LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: EdgeInsets.all(_directoryInset(constraints.maxWidth)),
              child: const CoeloStatePanel(
                key: Key('health-care-profiles-unauthorized'),
                title: 'Sem permissão',
                message: 'O contexto não autoriza esta consulta.',
              ),
            ),
          )
        : widget.controller.state == HealthCareLoadState.unavailable
        ? LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: EdgeInsets.all(_directoryInset(constraints.maxWidth)),
              child: const CoeloStatePanel(
                key: Key('health-care-profiles-unavailable'),
                title: 'Perfis de cuidado indisponíveis',
                message:
                    'A integração necessária para consultar estes dados ainda não está disponível.',
                icon: Icons.cloud_off_outlined,
              ),
            ),
          )
        : _directory(context),
  ).withHealthCareResponsiveSurface();

  Widget _directory(BuildContext context) {
    final controller = widget.controller;
    final minimizedSummary =
        controller.state == HealthCareLoadState.minimized && controller.items.isEmpty;
    final onPressedFor = controller.canReadSensitive && widget.onChildSelected != null
        ? (HealthCareChildSummary item) => widget.onChildSelected!(item.id)
        : null;
    return CoeloAdminDirectory<_HealthCareTableView>(
      scrollKey: const Key('health-care-profiles-directory-scroll'),
      cardsKey: const Key('health-care-profiles-view-cards'),
      tableKey: const Key('health-care-profiles-view-table'),
      gridKey: const Key('health-care-profiles-cards'),
      status: switch (controller.state) {
        HealthCareLoadState.loading => CoeloAdminDirectoryStatus.loading,
        HealthCareLoadState.empty => CoeloAdminDirectoryStatus.empty,
        HealthCareLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
        HealthCareLoadState.error => CoeloAdminDirectoryStatus.failure,
        HealthCareLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
        HealthCareLoadState.unavailable => CoeloAdminDirectoryStatus.failure,
        HealthCareLoadState.ready ||
        HealthCareLoadState.minimized => CoeloAdminDirectoryStatus.success,
      },
      messages: const CoeloAdminDirectoryMessages(
        empty: 'Nenhum registro',
        emptyIcon: Icons.health_and_safety_outlined,
        noResults: 'Nenhum resultado',
        failure: 'Não foi possível carregar',
        unauthorized: 'Sem permissão',
      ),
      errorMessage: switch (controller.state) {
        HealthCareLoadState.empty => 'Ainda não existem perfis de cuidado cadastrados.',
        HealthCareLoadState.error => 'Tente novamente.',
        _ => null,
      },
      onRetry: controller.load,
      search: CoeloSearchField(
        controller: _search,
        semanticLabel: 'Buscar crianças em Perfis de cuidado',
        hintText: 'Buscar criança',
        onChanged: controller.setSearch,
      ),
      filters: [
        _filter('Pessoa', const [], controller.query.personIds, controller.setPersonIds),
        _filter('Criança', const [], controller.query.childIds, controller.setChildIds),
        _filter(
          'Instituição',
          const [],
          controller.query.institutionIds,
          controller.setInstitutionIds,
        ),
        _filter(
          'Unidade',
          controller.availableUnitIds.toList(growable: false),
          controller.query.unitIds,
          controller.setUnitIds,
        ),
        _filter(
          'Turma/Atividade',
          controller.availableGroupIds.toList(growable: false),
          controller.query.groupOrActivityIds,
          controller.setGroupIds,
        ),
      ],
      display: controller.display == HealthCareDirectoryDisplay.cards
          ? CoeloAdminDirectoryDisplay.cards
          : CoeloAdminDirectoryDisplay.table,
      onDisplayChanged: (value) => controller.setDisplay(
        value == CoeloAdminDirectoryDisplay.cards
            ? HealthCareDirectoryDisplay.cards
            : HealthCareDirectoryDisplay.table,
      ),
      groupedTableView: _HealthCareTableView.grouped,
      selectedTableView: _HealthCareTableView.grouped,
      tableViews: const [
        CoeloAdminDirectoryTableViewOption(value: _HealthCareTableView.grouped, label: 'Agrupado'),
      ],
      onTableViewSelected: (_) => controller.setDisplay(HealthCareDirectoryDisplay.table),
      fileActions: healthCareFileActions(
        context,
        onImport: widget.onImport,
        onExportCsv: widget.onExportCsv,
        onExportXlsx: widget.onExportXlsx,
      ),
      tabs: _statusTabs(),
      create: _canCreate
          ? CoeloAdminDirectoryCreate(
              label: 'Criar perfil de cuidado',
              description: 'Cadastre alergias, restrições e características de cuidado.',
              icon: Icons.health_and_safety_outlined,
              onPressed: widget.onCreate!,
            )
          : null,
      cards: [
        for (final item in controller.items)
          _ProfileCard(
            item: item,
            minimized: controller.isMinimized,
            onPressed: onPressedFor == null ? null : () => onPressedFor(item),
          ),
      ],
      table: _table(onPressedFor),
      bodyOverride: minimizedSummary
          ? const CoeloStatePanel(
              title: 'Resumo minimizado',
              message: 'Somente contagens, pendências e status estão disponíveis.',
            )
          : null,
      pagination: controller.page != null
          ? CoeloAdminDirectoryPagination(
              footerKey: const Key('health-care-profiles-pagination-footer'),
              currentPage: controller.query.page + 1,
              totalPages: controller.totalPages,
              pageSize: controller.query.pageSize,
              pageSizeOptions: controller.display == HealthCareDirectoryDisplay.cards
                  ? const [11, 20, 50, 100]
                  : const [8, 20, 50, 100],
              onPageSelected: (value) => controller.setPage(value - 1),
              onPageSizeChanged: controller.setPageSize,
            )
          : null,
    );
  }

  Widget _statusTabs() => CoeloAdminUnderlineTabs<_ProfileStatusFilter>(
    tabs: const [
      CoeloAdminUnderlineTab(value: _ProfileStatusFilter.all, label: 'Todos'),
      CoeloAdminUnderlineTab(value: _ProfileStatusFilter.active, label: 'Ativos'),
      CoeloAdminUnderlineTab(value: _ProfileStatusFilter.implementation, label: 'Em Implantação'),
      CoeloAdminUnderlineTab(value: _ProfileStatusFilter.inactive, label: 'Inativos'),
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
  ) => CoeloAdminMultiSelectFilter<String>(
    label: label,
    options: options,
    selectedValues: selected,
    optionLabel: (value) => value,
    onChanged: onChanged,
  );

  bool get _canCreate => widget.controller.canEdit && widget.onCreate != null;

  Widget _table(ValueChanged<HealthCareChildSummary>? onPressed) =>
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
        onRowPressed: onPressed,
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
    semanticLabel: minimized
        ? 'Resumo minimizado de ${item.displayName}'
        : onPressed == null
        ? 'Perfil de cuidado de ${item.displayName}'
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

String _statusLabel(HealthCareOperationalStatus value) => switch (value) {
  HealthCareOperationalStatus.active => 'Ativo',
  HealthCareOperationalStatus.implementation => 'Em Implantação',
  HealthCareOperationalStatus.inactive => 'Inativo',
};

double _directoryInset(double width) => width >= CoeloBreakpoints.large.minWidth
    ? CoeloSpacing.space10
    : width >= CoeloBreakpoints.medium.minWidth
    ? CoeloSpacing.space6
    : CoeloSpacing.space4;
