import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../domain/access_profile.dart';
import 'access_profile_view_model.dart';

enum AccessProfileDirectoryKind { profiles, templates }

final class AccessProfileDirectoryPage extends StatefulWidget {
  const AccessProfileDirectoryPage({
    required this.repository,
    required this.logout,
    this.onCreate,
    this.onCreateFromModel,
    this.onOpen,
    this.onDuplicate,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    this.onConversationsOpen,
    this.title = 'Perfis e permissões',
    this.subtitle = 'Gerencie perfis do Superadmin e Admin e consulte capacidades do Principal.',
    this.currentDestination = 'profiles',
    this.createActionLabel = 'Criar perfil',
    this.directoryKind = AccessProfileDirectoryKind.profiles,
    this.onDirectoryKindSelected,
    super.key,
  });

  final AccessProfileRepository repository;
  final LogoutAction logout;
  final ValueChanged<AccessProfileDomain>? onCreate;

  /// P31: com este callback, "Criar perfil" pergunta se o perfil nasce do
  /// zero ou a partir de um modelo do sistema (perfil predefinido da lista).
  final void Function(AccessProfileDomain domain, String sourceProfileId)? onCreateFromModel;
  final void Function(AccessProfileDomain domain, String profileId)? onOpen;
  final void Function(AccessProfileDomain domain, String profileId)? onDuplicate;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final VoidCallback? onConversationsOpen;
  final String title;
  final String subtitle;
  final String currentDestination;
  final String createActionLabel;
  final AccessProfileDirectoryKind directoryKind;
  final ValueChanged<AccessProfileDirectoryKind>? onDirectoryKindSelected;

  @override
  State<AccessProfileDirectoryPage> createState() => _AccessProfileDirectoryPageState();
}

final class _AccessProfileDirectoryPageState extends State<AccessProfileDirectoryPage> {
  late AccessProfileViewModel _viewModel;
  late final TextEditingController _searchController;
  late final SuperadminActivityController _activityController;
  double _footerHeight = 0;

  @override
  void initState() {
    super.initState();
    _viewModel = AccessProfileViewModel(
      widget.repository,
      principalCapabilitiesOnly: widget.directoryKind == AccessProfileDirectoryKind.profiles,
    );
    _searchController = TextEditingController();
    _activityController = SuperadminActivityController();
    _scheduleLoad(_viewModel);
  }

  @override
  void didUpdateWidget(covariant AccessProfileDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) &&
        oldWidget.directoryKind == widget.directoryKind) {
      return;
    }
    _viewModel.dispose();
    _viewModel = AccessProfileViewModel(
      widget.repository,
      principalCapabilitiesOnly: widget.directoryKind == AccessProfileDirectoryKind.profiles,
    );
    _searchController.clear();
    _footerHeight = 0;
    _scheduleLoad(_viewModel);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _searchController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _scheduleLoad(AccessProfileViewModel viewModel) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_viewModel, viewModel)) return;
      viewModel.load();
    });
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: widget.title,
    subtitle: widget.subtitle,
    currentDestination: widget.currentDestination,
    activityController: _activityController,
    showChatLauncher: widget.onConversationsOpen != null,
    chatLauncherBottomInset: _footerHeight,
    onDestinationSelected: widget.onDestinationSelected,
    onBugReportSubmitted: widget.onBugReportSubmitted,
    onOpenConversations: widget.onConversationsOpen,
    child: _AccessProfileDirectoryContent(
      viewModel: _viewModel,
      searchController: _searchController,
      onCreate: widget.onCreate,
      onCreateFromModel: widget.onCreateFromModel,
      onOpen: widget.onOpen,
      onDuplicate: widget.onDuplicate,
      createActionLabel: widget.createActionLabel,
      directoryKind: widget.directoryKind,
      onDirectoryKindSelected: widget.onDirectoryKindSelected,
      onFooterHeightChanged: (height) {
        if ((_footerHeight - height).abs() < .5) return;
        setState(() => _footerHeight = height);
      },
    ),
  );
}

/// Diretório de Perfis de acesso: instância do `CoeloAdminDirectory` com o
/// conteúdo de domínio (abas Perfis/Modelos, domínios, escopos, cards, linhas
/// e o catálogo somente leitura do Principal).
final class _AccessProfileDirectoryContent extends StatelessWidget {
  const _AccessProfileDirectoryContent({
    required this.viewModel,
    required this.searchController,
    required this.onCreate,
    required this.onCreateFromModel,
    required this.onOpen,
    required this.onDuplicate,
    required this.createActionLabel,
    required this.directoryKind,
    required this.onDirectoryKindSelected,
    required this.onFooterHeightChanged,
  });

  final AccessProfileViewModel viewModel;
  final TextEditingController searchController;
  final void Function(AccessProfileDomain)? onCreate;
  final void Function(AccessProfileDomain, String)? onCreateFromModel;
  final void Function(AccessProfileDomain, String)? onOpen;
  final void Function(AccessProfileDomain, String)? onDuplicate;
  final String createActionLabel;
  final AccessProfileDirectoryKind directoryKind;
  final ValueChanged<AccessProfileDirectoryKind>? onDirectoryKindSelected;
  final ValueChanged<double> onFooterHeightChanged;

  /// P31: o perfil nasce do zero ou a partir de um modelo do sistema.
  Future<void> _chooseCreateMode(
    BuildContext context,
    AccessProfileDomain domain,
    List<AccessProfile> models,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => CoeloAdminDialogShell(
        dialogKey: const Key('access-profile-create-mode-dialog'),
        title: 'Como criar o perfil?',
        closeTooltip: 'Fechar',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Modelos do sistema não são editáveis; um perfil criado a partir deles pode ser ajustado.',
            ),
            const SizedBox(height: CoeloSpacing.space3),
            for (final model in models)
              ListTile(
                key: Key('access-profile-create-from-${model.id}'),
                leading: const Icon(Icons.control_point_duplicate_outlined),
                title: Text('A partir de: ${model.name}'),
                subtitle: Text(model.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).pop(model.id),
              ),
          ],
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          key: const Key('access-profile-create-from-scratch'),
          onPressed: () => Navigator.of(context).pop(''),
          child: const Text('Do zero'),
        ),
      ),
    );
    if (choice == null) return;
    if (choice.isEmpty) {
      onCreate!(domain);
    } else {
      onCreateFromModel!(domain, choice);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: viewModel,
    builder: (context, _) {
      if (viewModel.state == AccessProfileLoadState.unauthorized) {
        return const Padding(
          padding: EdgeInsets.all(CoeloSpacing.space4),
          child: CoeloStatePanel(
            key: Key('access-profile-unauthorized'),
            title: 'Acesso não autorizado',
            message: 'Você não possui permissão para consultar esta central.',
            icon: Icons.lock_outline_rounded,
          ),
        );
      }
      final query = viewModel.query;
      final principal = viewModel.usesPrincipalCapabilities;
      final conflict = viewModel.state == AccessProfileLoadState.conflict;
      final showsDemo =
          viewModel.page.isDemo ||
          (query.domain == AccessProfileDomain.principal && viewModel.isDemo);
      final models = viewModel.page.items.where((item) => item.isSystem).toList(growable: false);
      final onCreate = this.onCreate == null || principal
          ? null
          : onCreateFromModel == null || models.isEmpty
          ? () => this.onCreate!(query.domain)
          : () => _chooseCreateMode(context, query.domain, models);
      final onOpen = this.onOpen == null ? null : (String id) => this.onOpen!(query.domain, id);
      final onDuplicate = this.onDuplicate == null
          ? null
          : (String id) => this.onDuplicate!(query.domain, id);
      final validScopes = switch (query.domain) {
        AccessProfileDomain.platform => const [
          AccessProfileScope.platform,
          AccessProfileScope.institution,
        ],
        AccessProfileDomain.institution => const [
          AccessProfileScope.institution,
          AccessProfileScope.unit,
          AccessProfileScope.group,
        ],
        AccessProfileDomain.principal => const [AccessProfileScope.group],
      };
      final totalPages = math.max(1, (viewModel.resultCount / query.pageSize).ceil());
      return CoeloAdminDirectory<AccessProfileTableView>(
        scrollKey: const Key('access-profiles-scroll'),
        toolbarKey: const Key('access-profile-toolbar'),
        cardsKey: const Key('access-profile-view-cards'),
        tableKey: const Key('access-profile-view-table'),
        gridKey: const Key('access-profile-card-grid'),
        leading: [
          CoeloAdminUnderlineTabs<AccessProfileDirectoryKind>(
            key: const Key('access-profile-kind-selector'),
            tabs: const [
              CoeloAdminUnderlineTab(value: AccessProfileDirectoryKind.profiles, label: 'Perfis'),
              CoeloAdminUnderlineTab(value: AccessProfileDirectoryKind.templates, label: 'Modelos'),
            ],
            selected: directoryKind,
            onSelected: onDirectoryKindSelected ?? (_) {},
          ),
        ],
        status: switch (viewModel.state) {
          AccessProfileLoadState.initial ||
          AccessProfileLoadState.loading => CoeloAdminDirectoryStatus.loading,
          AccessProfileLoadState.empty => CoeloAdminDirectoryStatus.empty,
          AccessProfileLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
          AccessProfileLoadState.failure ||
          AccessProfileLoadState.conflict => CoeloAdminDirectoryStatus.failure,
          AccessProfileLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
          AccessProfileLoadState.success => CoeloAdminDirectoryStatus.success,
        },
        refreshing: viewModel.state == AccessProfileLoadState.loading,
        messages: CoeloAdminDirectoryMessages(
          empty: principal ? 'Nenhuma capacidade disponível' : 'Nenhum perfil cadastrado',
          emptyIcon: Icons.manage_accounts_outlined,
          noResults: 'Nenhum resultado',
          noResultsIcon: Icons.search_off_rounded,
          failure: conflict ? 'O perfil foi alterado' : 'Não foi possível carregar os perfis',
          failureIcon: conflict ? Icons.sync_problem_outlined : Icons.error_outline_rounded,
          retryLabel: conflict ? 'Recarregar' : 'Tentar novamente',
          unauthorized: 'Acesso não autorizado',
          unauthorizedIcon: Icons.lock_outline_rounded,
        ),
        errorMessage: switch (viewModel.state) {
          AccessProfileLoadState.empty =>
            principal
                ? 'O catálogo contextual não retornou capacidades.'
                : 'Crie o primeiro perfil para começar.',
          AccessProfileLoadState.noResults => 'Revise a busca ou os filtros aplicados.',
          AccessProfileLoadState.failure =>
            viewModel.errorMessage ?? 'Tente novamente em instantes.',
          AccessProfileLoadState.conflict => 'Recarregue os dados antes de continuar.',
          _ => null,
        },
        onRetry: viewModel.load,
        onClearFilters: viewModel.clearFilters,
        search: CoeloSearchField(
          controller: searchController,
          hintText: principal ? 'Buscar capacidade' : 'Buscar por nome',
          semanticLabel: principal ? 'Buscar capacidade do Principal' : 'Buscar perfis por nome',
          onChanged: viewModel.setSearch,
        ),
        filters: [
          if (!principal)
            CoeloAdminMultiSelectFilter<AccessProfileScope>(
              label: 'Todos os escopos',
              options: validScopes,
              selectedValues: query.scopes,
              optionLabel: (value) => value.label,
              onChanged: viewModel.setScopes,
            ),
        ],
        trailing: [
          if (!principal && (query.search.trim().isNotEmpty || query.scopes.isNotEmpty))
            TextButton.icon(
              onPressed: () {
                searchController.clear();
                viewModel.clearSearchAndScopes();
              },
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtros'),
            ),
        ],
        display: query.layout == AccessProfileLayout.cards
            ? CoeloAdminDirectoryDisplay.cards
            : CoeloAdminDirectoryDisplay.table,
        onDisplayChanged: (value) => viewModel.setLayout(
          value == CoeloAdminDirectoryDisplay.cards
              ? AccessProfileLayout.cards
              : AccessProfileLayout.table,
        ),
        groupedTableView: AccessProfileTableView.grouped,
        selectedTableView: viewModel.tableView,
        tableViews: [
          for (final view in AccessProfileTableView.values)
            CoeloAdminDirectoryTableViewOption(value: view, label: view.label),
        ],
        onTableViewSelected: viewModel.setTableView,
        fileActions: const [
          CoeloAdminFileAction(
            key: Key('access-profile-files-import'),
            label: 'Importar',
            icon: Icons.upload_file_outlined,
            onPressed: null,
          ),
          CoeloAdminFileAction(
            key: Key('access-profile-files-export-csv'),
            label: 'Exportar CSV',
            icon: Icons.table_rows_outlined,
            onPressed: null,
          ),
          CoeloAdminFileAction(
            key: Key('access-profile-files-export-xlsx'),
            label: 'Exportar XLSX',
            icon: Icons.grid_on_outlined,
            onPressed: null,
          ),
        ],
        tabs: CoeloAdminUnderlineTabs<AccessProfileDomain>(
          key: const Key('access-profile-domain-selector'),
          tabs: [
            for (final domain in AccessProfileDomain.values)
              CoeloAdminUnderlineTab(value: domain, label: domain.label),
          ],
          selected: query.domain,
          onSelected: (value) {
            searchController.clear();
            viewModel.setDomain(value);
          },
        ),
        beforeResults: [
          if (showsDemo) const _DemoNotice(),
          if (!principal)
            Text(
              'Perfil define teto; atribuição define contexto efetivo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        create: onCreate == null
            ? null
            : CoeloAdminDirectoryCreate(
                label: createActionLabel,
                description: 'Adicionar novo perfil de acesso ao sistema.',
                icon: Icons.manage_accounts_outlined,
                onPressed: onCreate,
                tileKey: const Key('create-access-profile-card'),
                bannerKey: const Key('create-access-profile-banner'),
              ),
        cards: [
          if (!principal)
            for (final item in viewModel.page.items)
              _AccessProfileCard(
                item: item,
                onPressed: onOpen == null ? null : () => onOpen(item.id),
                onDuplicate: onDuplicate == null ? null : () => onDuplicate(item.id),
              ),
        ],
        table: _AccessProfileTableRows(
          items: viewModel.page.items,
          tableView: viewModel.tableView,
          onOpen: onOpen,
          onDuplicate: onDuplicate,
        ),
        bodyOverride: principal
            ? _PrincipalCapabilities(capabilities: viewModel.pagedCapabilities)
            : null,
        pagination: viewModel.state == AccessProfileLoadState.success
            ? CoeloAdminDirectoryPagination(
                footerKey: const Key('access-profile-pagination-footer'),
                currentPage: query.page + 1,
                totalPages: totalPages,
                pageSize: query.pageSize,
                pageSizeOptions: query.layout == AccessProfileLayout.cards
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

final class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Dados de demonstração',
    child: Container(
      key: const Key('access-profile-demo-notice'),
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space4,
        vertical: CoeloSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined),
          SizedBox(width: CoeloSpacing.space2),
          Expanded(
            child: Text('Dados de demonstração — disponíveis somente em dev, catálogo e testes.'),
          ),
        ],
      ),
    ),
  );
}

final class _AccessProfileCard extends StatelessWidget {
  const _AccessProfileCard({
    required this.item,
    required this.onPressed,
    required this.onDuplicate,
  });

  final AccessProfile item;
  final VoidCallback? onPressed;
  final VoidCallback? onDuplicate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CoeloAdminInteractiveCard(
      surfaceKey: Key('access-profile-card-${item.id}'),
      semanticLabel: onPressed == null ? 'Perfil ${item.name}' : 'Abrir perfil ${item.name}',
      minHeight: 216,
      onPressed: onPressed,
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
                CircleAvatar(
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                  child: const Icon(Icons.badge_outlined),
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
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (onDuplicate != null)
                  IconButton(
                    key: Key('access-profile-duplicate-${item.id}'),
                    tooltip: 'Duplicar modelo',
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_all_outlined),
                  ),
                _ProfileExpandableStatus(status: item.status, itemId: item.id),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space4),
            _ProfileMetricRow(
              icon: Icons.layers_outlined,
              label: 'Escopo máximo',
              value: item.maxScope.label,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            _ProfileMetricRow(
              icon: Icons.link_outlined,
              label: 'Vínculos',
              value: '${item.membershipCount}',
            ),
            const SizedBox(height: CoeloSpacing.space3),
            _ProfileMetricRow(
              icon: Icons.verified_outlined,
              label: 'Tipo',
              value: item.isSystem ? 'Predefinido' : 'Personalizado',
            ),
          ],
        ),
      ),
    );
  }
}

final class _ProfileMetricRow extends StatelessWidget {
  const _ProfileMetricRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(CoeloRadius.sm),
        ),
        child: Icon(icon, size: CoeloSize.iconSm),
      ),
      const SizedBox(width: CoeloSpacing.space2),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ],
  );
}

/// Linhas e colunas de domínio dos perfis sobre a tabela compartilhada.
final class _AccessProfileTableRows extends StatelessWidget {
  const _AccessProfileTableRows({
    required this.items,
    required this.tableView,
    required this.onOpen,
    required this.onDuplicate,
  });

  final List<AccessProfile> items;
  final AccessProfileTableView tableView;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onDuplicate;

  @override
  Widget build(BuildContext context) => CoeloAdminResizableTable<AccessProfile>(
    key: const Key('access-profile-table'),
    items: items,
    rowKey: (item) => item.id,
    pinnedColumn: CoeloAdminTableColumn(
      id: 'name',
      label: 'Perfil',
      initialWidth: 280,
      minWidth: 200,
      maxWidth: 480,
      cellBuilder: (context, item) => Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: const Icon(Icons.badge_outlined, size: 18),
          ),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
    columns: [
      ...(tableView == AccessProfileTableView.grouped
          ? [
              CoeloAdminTableColumn(
                id: 'description',
                label: 'Descrição',
                initialWidth: 340,
                minWidth: 220,
                maxWidth: 520,
                cellBuilder: (context, item) =>
                    Text(item.description, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              CoeloAdminTableColumn(
                id: 'scope',
                label: 'Escopo máximo',
                initialWidth: 180,
                minWidth: 140,
                maxWidth: 240,
                cellBuilder: (context, item) => Text(item.maxScope.label),
              ),
              CoeloAdminTableColumn(
                id: 'status',
                label: 'Status',
                initialWidth: 150,
                minWidth: 120,
                maxWidth: 200,
                cellBuilder: (context, item) => _ProfileStatusChip(status: item.status),
              ),
              CoeloAdminTableColumn(
                id: 'memberships',
                label: 'Vínculos',
                initialWidth: 120,
                minWidth: 96,
                maxWidth: 180,
                cellBuilder: (context, item) => Text('${item.membershipCount}'),
              ),
              CoeloAdminTableColumn(
                id: 'type',
                label: 'Tipo',
                initialWidth: 150,
                minWidth: 120,
                maxWidth: 200,
                cellBuilder: (context, item) => Text(
                  item.isSystem ? 'Predefinido' : 'Personalizado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]
          : [
              _assignmentColumn('institution', 'Instituição', AccessAssignmentContext.institution),
              _assignmentColumn('unit', 'Unidade', AccessAssignmentContext.unit),
              _assignmentColumn('group', 'Turma', AccessAssignmentContext.group),
              _assignmentColumn('activity', 'Atividade', AccessAssignmentContext.activity),
            ]),
      if (onDuplicate != null)
        CoeloAdminTableColumn(
          id: 'actions',
          label: 'Ações',
          initialWidth: 96,
          minWidth: 80,
          maxWidth: 120,
          cellBuilder: (context, item) => IconButton(
            key: Key('access-profile-table-duplicate-${item.id}'),
            tooltip: 'Duplicar modelo',
            onPressed: () => onDuplicate!(item.id),
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ),
    ],
    headerHeight: 56,
    rowHeight: 64,
    onRowPressed: onOpen == null ? null : (item) => onOpen!(item.id),
  );

  CoeloAdminTableColumn<AccessProfile> _assignmentColumn(
    String id,
    String label,
    AccessAssignmentContext assignmentContext,
  ) => CoeloAdminTableColumn(
    id: id,
    label: label,
    initialWidth: 220,
    minWidth: 160,
    maxWidth: 360,
    cellBuilder: (context, item) {
      final labels = item.localAssignments
          .where((assignment) => assignment.context == assignmentContext)
          .map((assignment) => assignment.label)
          .toList(growable: false);
      return Text(
        labels.isEmpty ? '—' : labels.join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

final class _PrincipalCapabilities extends StatelessWidget {
  const _PrincipalCapabilities({required this.capabilities});

  final List<PrincipalCapability> capabilities;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const CoeloStatePanel(
        title: 'Catálogo somente leitura',
        message:
            'No Principal, capacidades são contextuais. Esta entrega não cria perfis familiares.',
        icon: Icons.visibility_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      for (final capability in capabilities) ...[
        CoeloAdminInteractiveCard(
          semanticLabel: '${capability.name}. ${capability.description}',
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space4,
              vertical: CoeloSpacing.space2,
            ),
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(capability.name),
            subtitle: Text(capability.description),
            trailing: Semantics(
              label: '${capability.contextCount} contextos impactados',
              child: Chip(label: Text('${capability.contextCount} contextos')),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space2),
      ],
    ],
  );
}

final class _ProfileExpandableStatus extends StatelessWidget {
  const _ProfileExpandableStatus({required this.status, required this.itemId});

  final AccessProfileStatus status;
  final String itemId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColors =
        theme.extension<CoeloStatusColors>() ??
        (theme.brightness == Brightness.dark ? CoeloStatusColors.dark : CoeloStatusColors.light);
    final pair = switch (status) {
      AccessProfileStatus.active => (
        statusColors.successContainer,
        statusColors.onSuccessContainer,
      ),
      AccessProfileStatus.inactive => (colors.surfaceContainer, colors.onSurfaceVariant),
      AccessProfileStatus.archived => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: status.label,
      semanticLabel: 'Status: ${status.label}',
      surfaceKey: Key('access-profile-status-$itemId'),
      backgroundColor: pair.$1,
      foregroundColor: pair.$2,
    );
  }
}

final class _ProfileStatusChip extends StatelessWidget {
  const _ProfileStatusChip({required this.status});

  final AccessProfileStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pair = switch (status) {
      AccessProfileStatus.active => (colors.primaryContainer, colors.onPrimaryContainer),
      AccessProfileStatus.inactive => (colors.surfaceContainer, colors.onSurfaceVariant),
      AccessProfileStatus.archived => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
    };
    return CoeloStatusChip(label: status.label, backgroundColor: pair.$1, foregroundColor: pair.$2);
  }
}
