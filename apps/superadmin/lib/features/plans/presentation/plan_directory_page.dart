import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_placeholder_file_actions.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../data/fake_plan_catalog_repository.dart';
import '../domain/plan_catalog.dart';

enum _PlanStatusFilter { all, active, archived }

enum _PlanAction { edit, archive, restore }

final class PlanDirectoryPage extends StatefulWidget {
  const PlanDirectoryPage({required this.repository, this.onCreate, this.onEdit, super.key});

  final FakePlanCatalogRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;

  @override
  State<PlanDirectoryPage> createState() => _PlanDirectoryPageState();
}

final class _PlanDirectoryPageState extends State<PlanDirectoryPage> {
  final _search = TextEditingController();
  PlanDirectoryView _view = PlanDirectoryView.cards;
  _PlanStatusFilter _status = _PlanStatusFilter.all;
  int _page = 1;
  int _pageSize = 11;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  PlanStatus? get _selectedStatus => switch (_status) {
    _PlanStatusFilter.all => null,
    _PlanStatusFilter.active => PlanStatus.active,
    _PlanStatusFilter.archived => PlanStatus.archived,
  };

  void _resetQuery(VoidCallback change) => setState(() {
    change();
    _page = 1;
  });

  @override
  Widget build(BuildContext context) {
    final page = widget.repository.queryPage(
      PlanQuery(search: _search.text, status: _selectedStatus, page: _page, pageSize: _pageSize),
    );
    return Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloAdminListingToolbar(
            search: CoeloSearchField(
              controller: _search,
              semanticLabel: 'Buscar planos por nome ou código',
              hintText: 'Buscar por nome ou código',
              onChanged: (_) => _resetQuery(() {}),
            ),
            filters: const [],
            actions: [
              const SuperadminPlaceholderFileActions(resourceLabel: 'planos'),
              SuperadminDirectoryViewToggle<PlanDirectoryView>(
                cardsKey: const Key('plan-directory-cards-toggle'),
                tableKey: const Key('plan-directory-table-toggle'),
                cardsSelected: _view == PlanDirectoryView.cards,
                groupedView: PlanDirectoryView.table,
                selectedTableView: PlanDirectoryView.table,
                tableViews: const [
                  SuperadminDirectoryTableViewOption(
                    value: PlanDirectoryView.table,
                    label: 'Tabela de planos',
                  ),
                ],
                onCardsSelected: () => _resetQuery(() {
                  _view = PlanDirectoryView.cards;
                  _pageSize = 11;
                }),
                onTableViewSelected: (_) => _resetQuery(() {
                  _view = PlanDirectoryView.table;
                  _pageSize = 8;
                }),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          SuperadminUnderlineTabs<_PlanStatusFilter>(
            key: const Key('plan-status-tabs'),
            tabs: const [
              SuperadminUnderlineTab(value: _PlanStatusFilter.all, label: 'Todos'),
              SuperadminUnderlineTab(value: _PlanStatusFilter.active, label: 'Ativos'),
              SuperadminUnderlineTab(value: _PlanStatusFilter.archived, label: 'Arquivados'),
            ],
            selected: _status,
            onSelected: (value) => _resetQuery(() => _status = value),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Expanded(child: _body(page)),
          if (widget.repository.state == PlanDataState.ready && page.totalItems > 0) ...[
            const SizedBox(height: CoeloSpacing.space3),
            SuperadminListingPaginationFooter(
              horizontalPadding: 0,
              child: CoeloAdminPagination(
                key: const Key('plan-directory-pagination'),
                currentPage: _page.clamp(1, page.totalPages),
                totalPages: page.totalPages,
                pageSize: _pageSize,
                pageSizeOptions: _view == PlanDirectoryView.cards
                    ? const [11, 20, 50, 100]
                    : const [8, 20, 50, 100],
                onPageSizeChanged: (value) => setState(() {
                  _pageSize = value;
                  _page = 1;
                }),
                onPrevious: _page > 1 ? () => setState(() => _page -= 1) : null,
                onNext: _page < page.totalPages ? () => setState(() => _page += 1) : null,
                onPageSelected: (value) => setState(() => _page = value),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _body(PlanPage page) => switch (widget.repository.state) {
    PlanDataState.loading => const CoeloStatePanel(
      title: 'Carregando planos',
      message: 'Aguarde enquanto preparamos o catálogo.',
      loading: true,
    ),
    PlanDataState.error => CoeloStatePanel(
      title: 'Não foi possível carregar os planos',
      message: 'Tente novamente sem perder a consulta atual.',
      icon: Icons.cloud_off_outlined,
      actionLabel: 'Tentar novamente',
      onAction: () => setState(() {}),
    ),
    PlanDataState.unauthorized => const CoeloStatePanel(
      title: 'Acesso não autorizado',
      message: 'Você não possui autorização para consultar o catálogo de planos.',
      icon: Icons.lock_outline_rounded,
    ),
    PlanDataState.ready => _readyBody(page),
  };

  Widget _readyBody(PlanPage page) {
    if (page.totalItems == 0) {
      final filtered = _search.text.trim().isNotEmpty || _status != _PlanStatusFilter.all;
      return CoeloStatePanel(
        title: filtered ? 'Nenhum plano encontrado' : 'Nenhum plano cadastrado',
        message: filtered
            ? 'Ajuste a busca ou selecione outro status.'
            : 'Crie o primeiro plano do catálogo Coelo.',
        icon: filtered ? Icons.search_off_rounded : Icons.loyalty_outlined,
        actionLabel: filtered ? 'Limpar consulta' : 'Novo plano',
        onAction: filtered
            ? () => _resetQuery(() {
                _search.clear();
                _status = _PlanStatusFilter.all;
              })
            : widget.onCreate,
      );
    }
    return _view == PlanDirectoryView.cards ? _cards(page.items) : _table(page.items);
  }

  Widget _cards(List<PlanCatalog> plans) => LayoutBuilder(
    builder: (context, constraints) => GridView.builder(
      key: const Key('plan-card-grid'),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 216,
        crossAxisSpacing: CoeloSpacing.space4,
        mainAxisSpacing: CoeloSpacing.space4,
      ),
      itemCount: plans.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return CoeloAdminCreateAction(
            label: 'Novo plano',
            description: 'Adicionar ao catálogo global',
            icon: Icons.loyalty_outlined,
            onPressed: widget.onCreate,
          );
        }
        return _PlanCard(
          plan: plans[index - 1],
          onOpen: () => widget.onEdit?.call(plans[index - 1].id),
          onAction: (action) => _handleAction(plans[index - 1], action),
        );
      },
    ),
  );

  Widget _table(List<PlanCatalog> plans) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloAdminCreateAction(
        label: 'Novo plano',
        description: 'Adicionar ao catálogo global',
        icon: Icons.loyalty_outlined,
        variant: CoeloAdminCreateActionVariant.banner,
        onPressed: widget.onCreate,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      Expanded(
        child: CoeloAdminResizableTable<PlanCatalog>(
          key: const Key('plan-table'),
          items: plans,
          rowKey: (plan) => plan.id,
          headerHeight: 56,
          rowHeight: 64,
          onRowPressed: (plan) => widget.onEdit?.call(plan.id),
          pinnedColumn: CoeloAdminTableColumn(
            id: 'plan',
            label: 'Plano',
            initialWidth: 260,
            minWidth: 220,
            maxWidth: 360,
            cellBuilder: (context, plan) => _PlanName(plan: plan),
          ),
          columns: [
            CoeloAdminTableColumn(
              id: 'code',
              label: 'Código',
              initialWidth: 180,
              minWidth: 150,
              maxWidth: 240,
              cellBuilder: (context, plan) => Text(plan.code),
            ),
            CoeloAdminTableColumn(
              id: 'status',
              label: 'Status',
              initialWidth: 140,
              minWidth: 120,
              maxWidth: 180,
              cellBuilder: (context, plan) => Text(_statusLabel(plan.status)),
            ),
            CoeloAdminTableColumn(
              id: 'capabilities',
              label: 'Capacidades',
              initialWidth: 150,
              minWidth: 130,
              maxWidth: 190,
              cellBuilder: (context, plan) => Text('${plan.features.length} incluídas'),
            ),
            CoeloAdminTableColumn(
              id: 'institutions',
              label: 'Instituições',
              initialWidth: 150,
              minWidth: 130,
              maxWidth: 190,
              cellBuilder: (context, plan) => Text('${plan.usedByInstitutionCount} vinculadas'),
            ),
            CoeloAdminTableColumn(
              id: 'actions',
              label: 'Ações',
              initialWidth: 96,
              minWidth: 88,
              maxWidth: 120,
              cellBuilder: (context, plan) => Align(
                alignment: Alignment.centerLeft,
                child: _PlanActions(
                  plan: plan,
                  onSelected: (action) => _handleAction(plan, action),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  void _handleAction(PlanCatalog plan, _PlanAction action) {
    switch (action) {
      case _PlanAction.edit:
        widget.onEdit?.call(plan.id);
      case _PlanAction.archive:
        _confirmStatusChange(plan, archive: true);
      case _PlanAction.restore:
        _confirmStatusChange(plan, archive: false);
    }
  }

  Future<void> _confirmStatusChange(PlanCatalog plan, {required bool archive}) async {
    final reason = TextEditingController();
    var showReasonError = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final colors = Theme.of(dialogContext).colorScheme;
          return CoeloAdminDialogShell(
            title: archive ? 'Arquivar plano' : 'Restaurar plano',
            onClose: () => Navigator.pop(dialogContext, false),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  archive && plan.usedByInstitutionCount > 0
                      ? '${plan.usedByInstitutionCount} instituições utilizam este plano. As subscriptions não serão alteradas automaticamente.'
                      : 'Esta ação altera a disponibilidade do plano no catálogo.',
                ),
                const SizedBox(height: CoeloSpacing.space4),
                CoeloFormTextField(
                  controller: reason,
                  labelText: 'Motivo de auditoria',
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                  errorText: showReasonError ? 'Motivo obrigatório' : null,
                  onChanged: (value) {
                    if (showReasonError && value.trim().isNotEmpty) {
                      setDialogState(() => showReasonError = false);
                    }
                  },
                ),
              ],
            ),
            secondaryAction: OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            primaryAction: FilledButton(
              style: archive
                  ? FilledButton.styleFrom(
                      backgroundColor: colors.errorContainer,
                      foregroundColor: colors.error,
                    )
                  : null,
              onPressed: () {
                if (reason.text.trim().isEmpty) {
                  setDialogState(() => showReasonError = true);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(archive ? 'Arquivar' : 'Restaurar'),
            ),
          );
        },
      ),
    );
    if (confirmed == true) {
      if (archive) {
        widget.repository.archive(plan.id, reason: reason.text);
      } else {
        widget.repository.restore(plan.id, reason: reason.text);
      }
      if (mounted) setState(() {});
    }
    reason.dispose();
  }
}

final class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onOpen, required this.onAction});

  final PlanCatalog plan;
  final VoidCallback onOpen;
  final ValueChanged<_PlanAction> onAction;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    semanticLabel: 'Editar plano ${plan.name}',
    minHeight: 216,
    onPressed: onOpen,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _PlanName(plan: plan)),
              _PlanStatusIndicator(plan: plan),
              const SizedBox(width: CoeloSpacing.space2),
              _PlanActions(plan: plan, onSelected: onAction),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(plan.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Wrap(
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space2,
            children: [
              _Metric(icon: Icons.widgets_outlined, label: '${plan.features.length} capacidades'),
              _Metric(
                icon: Icons.apartment_rounded,
                label: '${plan.usedByInstitutionCount} instituições',
              ),
              const _Metric(icon: Icons.info_outline_rounded, label: 'Limites informativos'),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _PlanName extends StatelessWidget {
  const _PlanName({required this.plan});

  final PlanCatalog plan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        plan.name,
        style: Theme.of(context).textTheme.titleSmall,
        overflow: TextOverflow.ellipsis,
      ),
      Text(
        plan.code,
        style: Theme.of(context).textTheme.bodySmall,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

final class _PlanStatusIndicator extends StatelessWidget {
  const _PlanStatusIndicator({required this.plan});

  final PlanCatalog plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final pair = plan.status == PlanStatus.active
        ? (statusColors.successContainer, statusColors.onSuccessContainer)
        : (colors.surfaceContainerHighest, colors.onSurfaceVariant);
    final label = _statusLabel(plan.status);
    return CoeloAdminExpandableStatusIndicator(
      label: label,
      semanticLabel: 'Status: $label',
      surfaceKey: Key('plan-status-${plan.id}'),
      backgroundColor: pair.$1,
      foregroundColor: pair.$2,
    );
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: CoeloSize.iconSm),
      const SizedBox(width: CoeloSpacing.space1),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

final class _PlanActions extends StatelessWidget {
  const _PlanActions({required this.plan, required this.onSelected});

  final PlanCatalog plan;
  final ValueChanged<_PlanAction> onSelected;

  @override
  Widget build(BuildContext context) => CoeloAdminFlyout<_PlanAction>(
    items: [
      const CoeloAdminFlyoutItem(
        value: _PlanAction.edit,
        label: 'Editar plano',
        icon: Icons.edit_outlined,
      ),
      CoeloAdminFlyoutItem(
        value: plan.status == PlanStatus.active ? _PlanAction.archive : _PlanAction.restore,
        label: plan.status == PlanStatus.active ? 'Arquivar plano' : 'Restaurar plano',
        icon: plan.status == PlanStatus.active ? Icons.archive_outlined : Icons.restore_rounded,
        startsGroup: true,
        tone: plan.status == PlanStatus.active
            ? CoeloAdminFlyoutTone.negative
            : CoeloAdminFlyoutTone.standard,
      ),
    ],
    onSelected: onSelected,
    builder: (context, controller) => IconButton(
      tooltip: 'Ações de ${plan.name}',
      onPressed: controller.open,
      icon: const Icon(Icons.more_vert_rounded),
    ),
  );
}

String _statusLabel(PlanStatus status) => status == PlanStatus.active ? 'Ativo' : 'Arquivado';
