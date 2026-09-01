import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
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

final class _AccessProfileDirectoryContent extends StatefulWidget {
  const _AccessProfileDirectoryContent({
    required this.viewModel,
    required this.searchController,
    required this.onCreate,
    required this.onOpen,
    required this.onDuplicate,
    required this.onFooterHeightChanged,
    required this.createActionLabel,
    required this.directoryKind,
    required this.onDirectoryKindSelected,
  });

  final AccessProfileViewModel viewModel;
  final TextEditingController searchController;
  final ValueChanged<AccessProfileDomain>? onCreate;
  final void Function(AccessProfileDomain domain, String profileId)? onOpen;
  final void Function(AccessProfileDomain domain, String profileId)? onDuplicate;
  final ValueChanged<double> onFooterHeightChanged;
  final String createActionLabel;
  final AccessProfileDirectoryKind directoryKind;
  final ValueChanged<AccessProfileDirectoryKind>? onDirectoryKindSelected;

  @override
  State<_AccessProfileDirectoryContent> createState() => _AccessProfileDirectoryContentState();
}

final class _AccessProfileDirectoryContentState extends State<_AccessProfileDirectoryContent> {
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
          if (widget.viewModel.state == AccessProfileLoadState.unauthorized) {
            _measureFooter(false);
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
          final query = widget.viewModel.query;
          final showPagination = widget.viewModel.state == AccessProfileLoadState.success;
          _measureFooter(showPagination);
          final footerInset = showPagination ? _footerHeight + CoeloSpacing.space4 : 0.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              ListView(
                key: const Key('access-profiles-scroll'),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  horizontalPadding,
                  horizontalPadding,
                  horizontalPadding + footerInset,
                ),
                children: [
                  SuperadminUnderlineTabs<AccessProfileDirectoryKind>(
                    key: const Key('access-profile-kind-selector'),
                    tabs: const [
                      SuperadminUnderlineTab(
                        value: AccessProfileDirectoryKind.profiles,
                        label: 'Perfis',
                      ),
                      SuperadminUnderlineTab(
                        value: AccessProfileDirectoryKind.templates,
                        label: 'Modelos',
                      ),
                    ],
                    selected: widget.directoryKind,
                    onSelected: widget.onDirectoryKindSelected ?? (_) {},
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _AccessProfileToolbar(
                    viewModel: widget.viewModel,
                    searchController: widget.searchController,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _DomainSelector(
                    value: query.domain,
                    onChanged: (value) {
                      widget.searchController.clear();
                      widget.viewModel.setDomain(value);
                    },
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  if (widget.viewModel.page.isDemo ||
                      (query.domain == AccessProfileDomain.principal && widget.viewModel.isDemo))
                    const _DemoNotice(),
                  if (widget.viewModel.page.isDemo ||
                      (query.domain == AccessProfileDomain.principal && widget.viewModel.isDemo))
                    const SizedBox(height: CoeloSpacing.space4),
                  if (!widget.viewModel.usesPrincipalCapabilities) ...[
                    Text(
                      'Perfil define teto; atribuição define contexto efetivo',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                  ],
                  _AccessProfileResults(
                    viewModel: widget.viewModel,
                    compact: constraints.maxWidth < CoeloBreakpoints.medium.minWidth,
                    onCreate: widget.onCreate == null ? null : () => widget.onCreate!(query.domain),
                    onOpen: widget.onOpen == null ? null : (id) => widget.onOpen!(query.domain, id),
                    onDuplicate: widget.onDuplicate == null
                        ? null
                        : (id) => widget.onDuplicate!(query.domain, id),
                    createActionLabel: widget.createActionLabel,
                  ),
                ],
              ),
              if (showPagination)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: NotificationListener<SizeChangedLayoutNotification>(
                    onNotification: (_) {
                      _measureFooter(true);
                      return true;
                    },
                    child: SizeChangedLayoutNotifier(
                      key: _footerKey,
                      child: SuperadminListingPaginationFooter(
                        semanticKey: const Key('access-profile-pagination-footer'),
                        horizontalPadding: horizontalPadding,
                        child: _AccessProfilePagination(viewModel: widget.viewModel),
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

final class _DomainSelector extends StatelessWidget {
  const _DomainSelector({required this.value, required this.onChanged});

  final AccessProfileDomain value;
  final ValueChanged<AccessProfileDomain> onChanged;

  @override
  Widget build(BuildContext context) => SuperadminUnderlineTabs<AccessProfileDomain>(
    key: const Key('access-profile-domain-selector'),
    tabs: [
      for (final domain in AccessProfileDomain.values)
        SuperadminUnderlineTab(value: domain, label: domain.label),
    ],
    selected: value,
    onSelected: onChanged,
  );
}

final class _AccessProfileToolbar extends StatelessWidget {
  const _AccessProfileToolbar({required this.viewModel, required this.searchController});

  final AccessProfileViewModel viewModel;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final query = viewModel.query;
      if (viewModel.usesPrincipalCapabilities) {
        return CoeloAdminListingToolbar(
          search: SizedBox(
            width: compact ? constraints.maxWidth : 300,
            height: CoeloSize.touchMin,
            child: CoeloSearchField(
              controller: searchController,
              hintText: 'Buscar capacidade',
              semanticLabel: 'Buscar capacidade do Principal',
              onChanged: viewModel.setSearch,
            ),
          ),
          filters: const [],
          actions: [_AccessProfileFileActions(compact: compact)],
        );
      }
      final filterWidth = compact ? constraints.maxWidth : 176.0;
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
      return CoeloAdminListingToolbar(
        key: const Key('access-profile-toolbar'),
        search: SizedBox(
          width: compact ? constraints.maxWidth : 300,
          height: CoeloSize.touchMin,
          child: CoeloSearchField(
            controller: searchController,
            hintText: 'Buscar por nome',
            semanticLabel: 'Buscar perfis por nome',
            onChanged: viewModel.setSearch,
          ),
        ),
        filters: [
          SizedBox(
            width: filterWidth,
            child: CoeloAdminMultiSelectFilter<AccessProfileScope>(
              label: 'Todos os escopos',
              options: validScopes,
              selectedValues: query.scopes,
              optionLabel: (value) => value.label,
              onChanged: viewModel.setScopes,
            ),
          ),
          if (query.search.trim().isNotEmpty || query.scopes.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                searchController.clear();
                viewModel.clearSearchAndScopes();
              },
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtros'),
            ),
        ],
        actions: [
          SizedBox(
            height: CoeloSize.touchMin,
            child: SuperadminDirectoryViewToggle<AccessProfileTableView>(
              cardsSelected: query.layout == AccessProfileLayout.cards,
              groupedView: AccessProfileTableView.grouped,
              selectedTableView: viewModel.tableView,
              tableViews: [
                for (final view in AccessProfileTableView.values)
                  SuperadminDirectoryTableViewOption(value: view, label: view.label),
              ],
              cardsKey: const Key('access-profile-view-cards'),
              tableKey: const Key('access-profile-view-table'),
              onCardsSelected: () => viewModel.setLayout(AccessProfileLayout.cards),
              onTableViewSelected: viewModel.setTableView,
            ),
          ),
          _AccessProfileFileActions(compact: compact),
        ],
      );
    },
  );
}

final class _AccessProfileFileActions extends StatelessWidget {
  const _AccessProfileFileActions({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => CoeloAdminFileActions(
    compact: compact,
    actions: [
      CoeloAdminFileAction(
        key: const Key('access-profile-files-import'),
        label: 'Importar',
        icon: Icons.upload_file_outlined,
        onPressed: null,
      ),
      CoeloAdminFileAction(
        key: const Key('access-profile-files-export-csv'),
        label: 'Exportar CSV',
        icon: Icons.table_rows_outlined,
        onPressed: null,
      ),
      CoeloAdminFileAction(
        key: const Key('access-profile-files-export-xlsx'),
        label: 'Exportar XLSX',
        icon: Icons.grid_on_outlined,
        onPressed: null,
      ),
    ],
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

final class _AccessProfileResults extends StatelessWidget {
  const _AccessProfileResults({
    required this.viewModel,
    required this.compact,
    required this.onCreate,
    required this.onOpen,
    required this.onDuplicate,
    required this.createActionLabel,
  });

  final AccessProfileViewModel viewModel;
  final bool compact;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onDuplicate;
  final String createActionLabel;

  @override
  Widget build(BuildContext context) {
    Widget result;
    switch (viewModel.state) {
      case AccessProfileLoadState.initial:
      case AccessProfileLoadState.loading:
        result = const CoeloStatePanel(
          title: 'Carregando perfis',
          message: 'Aguarde enquanto consultamos as permissões.',
          loading: true,
        );
      case AccessProfileLoadState.empty:
        result = CoeloStatePanel(
          title: viewModel.usesPrincipalCapabilities
              ? 'Nenhuma capacidade disponível'
              : 'Nenhum perfil cadastrado',
          message: viewModel.usesPrincipalCapabilities
              ? 'O catálogo contextual não retornou capacidades.'
              : 'Crie o primeiro perfil para começar.',
          icon: Icons.manage_accounts_outlined,
          actionLabel: viewModel.usesPrincipalCapabilities || onCreate == null
              ? null
              : createActionLabel,
          onAction: viewModel.usesPrincipalCapabilities ? null : onCreate,
        );
      case AccessProfileLoadState.noResults:
        result = CoeloStatePanel(
          title: 'Nenhum resultado',
          message: 'Revise a busca ou os filtros aplicados.',
          icon: Icons.search_off_rounded,
          actionLabel: 'Limpar filtros',
          onAction: viewModel.clearFilters,
        );
      case AccessProfileLoadState.failure:
        result = CoeloStatePanel(
          title: 'Não foi possível carregar os perfis',
          message: viewModel.errorMessage ?? 'Tente novamente em instantes.',
          icon: Icons.error_outline_rounded,
          actionLabel: 'Tentar novamente',
          onAction: viewModel.load,
        );
      case AccessProfileLoadState.unauthorized:
        result = const CoeloStatePanel(
          title: 'Acesso não autorizado',
          message: 'Você não possui permissão para consultar esta central.',
          icon: Icons.lock_outline_rounded,
        );
      case AccessProfileLoadState.conflict:
        result = CoeloStatePanel(
          title: 'O perfil foi alterado',
          message: 'Recarregue os dados antes de continuar.',
          icon: Icons.sync_problem_outlined,
          actionLabel: 'Recarregar',
          onAction: viewModel.load,
        );
      case AccessProfileLoadState.success:
        if (viewModel.usesPrincipalCapabilities) {
          result = _PrincipalCapabilities(capabilities: viewModel.pagedCapabilities);
        } else if (viewModel.query.layout == AccessProfileLayout.cards) {
          result = _AccessProfileCards(
            items: viewModel.page.items,
            onCreate: onCreate,
            onOpen: onOpen,
            onDuplicate: onDuplicate,
            createActionLabel: createActionLabel,
          );
        } else {
          result = _AccessProfileTable(
            items: viewModel.page.items,
            tableView: viewModel.tableView,
            onCreate: onCreate,
            onOpen: onOpen,
            onDuplicate: onDuplicate,
            createActionLabel: createActionLabel,
          );
        }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.state == AccessProfileLoadState.loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        result,
      ],
    );
  }
}

final class _AccessProfileCards extends StatelessWidget {
  const _AccessProfileCards({
    required this.items,
    required this.onCreate,
    required this.onOpen,
    required this.onDuplicate,
    required this.createActionLabel,
  });

  final List<AccessProfile> items;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onDuplicate;
  final String createActionLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(1, (constraints.maxWidth / 340).floor());
      final cards = <Widget>[
        if (onCreate != null)
          ConstrainedBox(
            key: const Key('create-access-profile-card'),
            constraints: const BoxConstraints(minHeight: 216),
            child: CoeloAdminCreateAction(
              label: createActionLabel,
              icon: Icons.manage_accounts_outlined,
              onPressed: onCreate!,
            ),
          ),
        for (final item in items)
          _AccessProfileCard(
            item: item,
            onPressed: onOpen == null ? null : () => onOpen!(item.id),
            onDuplicate: onDuplicate == null ? null : () => onDuplicate!(item.id),
          ),
      ];
      return Column(
        key: const Key('access-profile-card-grid'),
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

final class _AccessProfileTable extends StatelessWidget {
  const _AccessProfileTable({
    required this.items,
    required this.tableView,
    required this.onCreate,
    required this.onOpen,
    required this.onDuplicate,
    required this.createActionLabel,
  });

  final List<AccessProfile> items;
  final AccessProfileTableView tableView;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
  final ValueChanged<String>? onDuplicate;
  final String createActionLabel;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (onCreate != null) ...[
        CoeloAdminCreateAction(
          key: const Key('create-access-profile-banner'),
          label: createActionLabel,
          description: 'Adicionar novo perfil de acesso ao sistema.',
          variant: CoeloAdminCreateActionVariant.banner,
          onPressed: onCreate!,
        ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      CoeloAdminResizableTable<AccessProfile>(
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
                  _assignmentColumn(
                    'institution',
                    'Instituição',
                    AccessAssignmentContext.institution,
                  ),
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
      ),
    ],
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

final class _AccessProfilePagination extends StatelessWidget {
  const _AccessProfilePagination({required this.viewModel});

  final AccessProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final totalPages = math.max(1, (viewModel.resultCount / viewModel.query.pageSize).ceil());
    final options = viewModel.query.layout == AccessProfileLayout.cards
        ? const [11, 20, 50, 100]
        : const [8, 20, 50, 100];
    return CoeloAdminPagination(
      currentPage: viewModel.query.page + 1,
      totalPages: totalPages,
      pageSize: viewModel.query.pageSize,
      pageSizeOptions: options,
      onPageSelected: (value) => viewModel.goToPage(value - 1),
      onPageSizeChanged: viewModel.setPageSize,
      onPrevious: viewModel.hasPreviousPage
          ? () => viewModel.goToPage(viewModel.query.page - 1)
          : null,
      onNext: viewModel.hasNextPage ? () => viewModel.goToPage(viewModel.query.page + 1) : null,
    );
  }
}
