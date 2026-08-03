import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../domain/health_safety.dart';
import 'health_safety_controller.dart';

enum _HealthSafetyTableView { grouped }

final class HealthSafetyDirectoryPage extends StatefulWidget {
  const HealthSafetyDirectoryPage({
    required this.controller,
    required this.logout,
    this.onChildSelected,
    super.key,
  });

  final HealthSafetyController controller;
  final LogoutAction logout;
  final ValueChanged<String>? onChildSelected;

  @override
  State<HealthSafetyDirectoryPage> createState() => _HealthSafetyDirectoryPageState();
}

final class _HealthSafetyDirectoryPageState extends State<HealthSafetyDirectoryPage> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.controller.load();
  }

  @override
  void didUpdateWidget(covariant HealthSafetyDirectoryPage oldWidget) {
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
    currentDestination: 'health-safety',
    title: 'Saúde e Segurança',
    subtitle: 'Medicamentos, alergias, restrições e Perfil de Cuidado.',
    chatLauncherBottomInset: CoeloSpacing.space20,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        return Stack(
          children: [
            ListView(
              key: const Key('health-safety-directory-scroll'),
              padding: EdgeInsets.fromLTRB(padding, padding, padding, CoeloSpacing.space24 * 2),
              children: [
                _demoBanner(context),
                const SizedBox(height: CoeloSpacing.space4),
                _toolbar(constraints),
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
                  semanticKey: const Key('health-safety-pagination-footer'),
                  horizontalPadding: padding,
                  child: CoeloAdminPagination(
                    currentPage: widget.controller.query.page + 1,
                    totalPages: widget.controller.totalPages,
                    pageSize: widget.controller.query.pageSize,
                    pageSizeOptions: widget.controller.display == HealthSafetyDirectoryDisplay.cards
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
  );

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
        semanticLabel: 'Buscar crianças em Saúde e Segurança',
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
        'Grupo/Atividade',
        widget.controller.availableGroupIds.toList(growable: false),
        widget.controller.query.groupOrActivityIds,
        widget.controller.setGroupIds,
      ),
      _filterBox(
        CoeloAdminMultiSelectFilter<HealthSafetyOperationalStatus>(
          label: 'Status',
          options: HealthSafetyOperationalStatus.values,
          selectedValues: widget.controller.query.operationalStatuses,
          optionLabel: _statusLabel,
          onChanged: widget.controller.setStatuses,
        ),
      ),
      _filterBox(
        CoeloAdminMultiSelectFilter<HealthMedicationDoseSituation>(
          label: 'Dose',
          options: HealthMedicationDoseSituation.values,
          selectedValues: widget.controller.query.doseSituations,
          optionLabel: _doseLabel,
          onChanged: widget.controller.setDoseSituations,
        ),
      ),
    ],
    actions: [
      SuperadminDirectoryViewToggle<_HealthSafetyTableView>(
        cardsSelected: widget.controller.display == HealthSafetyDirectoryDisplay.cards,
        groupedView: _HealthSafetyTableView.grouped,
        selectedTableView: _HealthSafetyTableView.grouped,
        tableViews: const [
          SuperadminDirectoryTableViewOption(
            value: _HealthSafetyTableView.grouped,
            label: 'Agrupado',
          ),
        ],
        cardsKey: const Key('health-safety-view-cards'),
        tableKey: const Key('health-safety-view-table'),
        onCardsSelected: () => widget.controller.setDisplay(HealthSafetyDirectoryDisplay.cards),
        onTableViewSelected: (_) =>
            widget.controller.setDisplay(HealthSafetyDirectoryDisplay.table),
      ),
    ],
  );

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
    if (controller.state != HealthSafetyLoadState.ready &&
        controller.state != HealthSafetyLoadState.minimized) {
      return switch (controller.state) {
        HealthSafetyLoadState.loading => const CoeloStatePanel(
          title: 'Carregando',
          message: 'Buscando registros locais.',
          loading: true,
        ),
        HealthSafetyLoadState.empty => const CoeloStatePanel(
          title: 'Nenhum registro',
          message: 'Ainda não existem registros demonstrativos.',
        ),
        HealthSafetyLoadState.noResults => const CoeloStatePanel(
          title: 'Nenhum resultado',
          message: 'Revise a busca ou os filtros independentes.',
        ),
        HealthSafetyLoadState.error => CoeloStatePanel(
          title: 'Não foi possível carregar',
          message: 'Tente novamente.',
          actionLabel: 'Tentar novamente',
          onAction: controller.load,
        ),
        HealthSafetyLoadState.unauthorized => const CoeloStatePanel(
          title: 'Sem permissão',
          message: 'O contexto não autoriza esta consulta.',
        ),
        _ => const SizedBox.shrink(),
      };
    }
    if (controller.state == HealthSafetyLoadState.minimized && controller.items.isEmpty) {
      return const CoeloStatePanel(
        title: 'Resumo minimizado',
        message: 'Somente contagens, pendências e status estão disponíveis.',
      );
    }
    return controller.display == HealthSafetyDirectoryDisplay.cards
        ? _cards(context, constraints)
        : _table();
  }

  Widget _cards(BuildContext context, BoxConstraints constraints) {
    const minimumCardWidth = 340.0;
    final usable = constraints.maxWidth;
    final columns = math.max(1, (usable / minimumCardWidth).floor());
    final width = (usable - (CoeloSpacing.space6 * (columns - 1))) / columns;
    return Wrap(
      key: const Key('health-safety-cards'),
      spacing: CoeloSpacing.space6,
      runSpacing: CoeloSpacing.space6,
      children: [
        for (final item in widget.controller.items)
          SizedBox(
            width: width,
            child: _ChildCard(
              item: item,
              minimized: widget.controller.profile == DemoHealthSafetyProfile.minimized,
              onPressed: widget.controller.canReadSensitive
                  ? () => widget.onChildSelected?.call(item.id)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _table() => CoeloAdminResizableTable<HealthSafetyChildSummary>(
    key: const Key('health-safety-table'),
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
        initialWidth: 160,
        minWidth: 120,
        maxWidth: 240,
        cellBuilder: (_, item) => Text(_statusLabel(item.operationalStatus)),
      ),
      CoeloAdminTableColumn(
        id: 'medications',
        label: 'Medicamentos',
        initialWidth: 160,
        minWidth: 120,
        maxWidth: 240,
        cellBuilder: (_, item) => Text('${item.medicationCount}'),
      ),
      CoeloAdminTableColumn(
        id: 'allergies',
        label: 'Alergias ativas',
        initialWidth: 160,
        minWidth: 120,
        maxWidth: 240,
        cellBuilder: (_, item) => Text('${item.activeAllergyCount}'),
      ),
      CoeloAdminTableColumn(
        id: 'awareness',
        label: 'Ciência pendente',
        initialWidth: 180,
        minWidth: 140,
        maxWidth: 260,
        cellBuilder: (_, item) => Text('${item.pendingAcknowledgementCount}'),
      ),
    ],
    headerHeight: 56,
    rowHeight: 64,
    onRowPressed: widget.controller.canReadSensitive
        ? (item) => widget.onChildSelected?.call(item.id)
        : null,
  );
}

final class _ChildCard extends StatefulWidget {
  const _ChildCard({required this.item, required this.minimized, required this.onPressed});
  final HealthSafetyChildSummary item;
  final bool minimized;
  final VoidCallback? onPressed;

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

final class _ChildCardState extends State<_ChildCard> {
  var _hovered = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final interactive = widget.onPressed != null;
    final highlighted = interactive && (_hovered || _focused);
    final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.fast;
    return Semantics(
      button: interactive,
      enabled: interactive,
      label: interactive
          ? 'Abrir Saúde e Segurança de ${widget.item.displayName}'
          : 'Resumo minimizado de ${widget.item.displayName}',
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        enabled: interactive,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() => _hovered = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: duration,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              border: Border.all(
                color: highlighted ? colors.primary.withValues(alpha: 0.5) : colors.outlineVariant,
              ),
              boxShadow: highlighted
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.12),
                        blurRadius: CoeloSpacing.space2,
                        offset: const Offset(0, CoeloSpacing.space1),
                      ),
                    ]
                  : const [],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 216),
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
                          semanticLabel: 'Avatar de ${widget.item.displayName}',
                          initials: widget.minimized ? null : 'CD',
                        ),
                        const SizedBox(width: CoeloSpacing.space3),
                        Expanded(
                          child: Text(
                            widget.item.displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    Text(_statusLabel(widget.item.operationalStatus)),
                    Text('${widget.item.medicationCount} medicamento(s)'),
                    Text('${widget.item.activeAllergyCount} alergia(s) ativa(s)'),
                    Text('${widget.item.pendingAcknowledgementCount} ciência(s) pendente(s)'),
                    if (widget.minimized) const Text('Resumo minimizado'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _profileLabel(DemoHealthSafetyProfile value) => switch (value) {
  DemoHealthSafetyProfile.owner => 'Owner',
  DemoHealthSafetyProfile.sensitiveReader => 'Leitor sensível',
  DemoHealthSafetyProfile.minimized => 'Operador minimizado',
};

String _statusLabel(HealthSafetyOperationalStatus value) => switch (value) {
  HealthSafetyOperationalStatus.active => 'Ativo',
  HealthSafetyOperationalStatus.pending => 'Pendente',
  HealthSafetyOperationalStatus.inactive => 'Inativo',
};

String _doseLabel(HealthMedicationDoseSituation value) => switch (value) {
  HealthMedicationDoseSituation.scheduled => 'Agendada',
  HealthMedicationDoseSituation.claimed => 'Assumida',
  HealthMedicationDoseSituation.administered => 'Administrada',
  HealthMedicationDoseSituation.notAdministered => 'Não administrada',
  HealthMedicationDoseSituation.refused => 'Recusada',
  HealthMedicationDoseSituation.paused => 'Pausada',
  HealthMedicationDoseSituation.late => 'Atrasada',
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
  'group-demo-a' => 'Grupo Demo A',
  'group-demo-b' => 'Grupo Demo B',
  _ => value,
};
