import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/platform_user.dart';

final class PlatformUserDirectoryPage extends StatefulWidget {
  const PlatformUserDirectoryPage({
    required this.repository,
    required this.capability,
    required this.logout,
    this.onCreate,
    this.onView,
    this.onDestinationSelected,
    this.successMessage,
    super.key,
  });

  final PlatformUserRepository repository;
  final PlatformUserCapability capability;
  final LogoutAction logout;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onView;
  final ValueChanged<String>? onDestinationSelected;
  final String? successMessage;

  @override
  State<PlatformUserDirectoryPage> createState() => _PlatformUserDirectoryPageState();
}

final class _PlatformUserDirectoryPageState extends State<PlatformUserDirectoryPage> {
  final _searchController = TextEditingController();
  final GlobalKey _footerKey = GlobalKey();
  Timer? _debounce;
  PlatformUserDirectoryView _view = PlatformUserDirectoryView.cards;
  PlatformUserTableView _tableView = PlatformUserTableView.grouped;
  Set<String> _profileIds = {};
  Set<PlatformMembershipStatus> _statuses = {};
  Set<PlatformUserScope> _scopes = {};
  int _page = 1;
  int _pageSize = PlatformUserQuery.cardsPageSize;
  bool _loading = true;
  Object? _error;
  double _footerHeight = 0;
  bool _measurementScheduled = false;
  var _loadGeneration = 0;
  PlatformUserPage _result = const PlatformUserPage(
    items: [],
    totalCount: 0,
    page: 1,
    pageSize: PlatformUserQuery.cardsPageSize,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    if (widget.successMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.successMessage!)));
      });
    }
  }

  @override
  void didUpdateWidget(covariant PlatformUserDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) &&
        oldWidget.capability == widget.capability) {
      return;
    }
    _debounce?.cancel();
    _loadGeneration += 1;
    _resetSensitiveState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _loadGeneration += 1;
    _resetSensitiveState();
    _searchController.dispose();
    super.dispose();
  }

  void _resetSensitiveState() {
    _searchController.clear();
    _view = PlatformUserDirectoryView.cards;
    _tableView = PlatformUserTableView.grouped;
    _profileIds = {};
    _statuses = {};
    _scopes = {};
    _page = 1;
    _pageSize = PlatformUserQuery.cardsPageSize;
    _loading = true;
    _error = null;
    _footerHeight = 0;
    _measurementScheduled = false;
    _result = const PlatformUserPage(
      items: [],
      totalCount: 0,
      page: 1,
      pageSize: PlatformUserQuery.cardsPageSize,
    );
  }

  PlatformUserQuery get _query => PlatformUserQuery(
    search: _searchController.text,
    profileIds: _profileIds,
    statuses: _statuses,
    scopes: _scopes,
    page: _page,
    view: _view,
    pageSize: _pageSize,
  );

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    final query = _query;
    if (widget.capability == PlatformUserCapability.unauthorized) {
      if (_isCurrent(generation, repository)) {
        setState(() {
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await repository.fetchPage(query);
      if (!_isCurrent(generation, repository)) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!_isCurrent(generation, repository)) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  bool _isCurrent(int generation, PlatformUserRepository repository) =>
      mounted && generation == _loadGeneration && identical(widget.repository, repository);

  void _search(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _page = 1;
      unawaited(_load());
    });
  }

  void _changeView(PlatformUserDirectoryView view) {
    setState(() {
      _view = view;
      _page = 1;
      _pageSize = view == PlatformUserDirectoryView.cards
          ? PlatformUserQuery.cardsPageSize
          : PlatformUserQuery.tablePageSize;
    });
    unawaited(_load());
  }

  void _changeTableView(PlatformUserTableView view) {
    setState(() {
      _view = PlatformUserDirectoryView.table;
      _tableView = view;
      _page = 1;
      _pageSize = PlatformUserQuery.tablePageSize;
    });
    unawaited(_load());
  }

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return SuperadminShell(
      logout: widget.logout,
      title: 'Usuários internos',
      subtitle: 'Gerencie identidades e acessos exclusivos do Superadmin.',
      currentDestination: 'internal-users',
      onDestinationSelected: widget.onDestinationSelected,
      chatLauncherBottomInset: _footerHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          final showFooter =
              !_loading &&
              _error == null &&
              widget.capability != PlatformUserCapability.unauthorized &&
              _result.totalCount > 0;
          _measureFooter(showFooter);
          final footerInset = showFooter ? _footerHeight + CoeloSpacing.space4 : 0.0;
          return ColoredBox(
            color: constraints.maxWidth <= 1024
                ? Theme.of(context).colorScheme.surface
                : Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListView(
                  key: const Key('platform-user-directory-content-scroll'),
                  padding: EdgeInsets.fromLTRB(padding, padding, padding, padding + footerInset),
                  children: [
                    if (widget.capability != PlatformUserCapability.unauthorized)
                      _toolbar(constraints.maxWidth - (padding * 2)),
                    if (widget.capability != PlatformUserCapability.unauthorized)
                      const SizedBox(height: CoeloSpacing.space4),
                    _results(),
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
                        child: _paginationFooter(padding),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _toolbar(double width) {
    final compact = width < CoeloBreakpoints.medium.minWidth;
    final filterWidth = compact ? (width - CoeloSpacing.space3) / 2 : 160.0;
    final searchWidth = compact ? width : 300.0;
    return CoeloAdminListingToolbar(
      key: const Key('platform-user-filter-toolbar'),
      search: Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: searchWidth,
            height: CoeloSize.touchMin,
            child: CoeloSearchField(
              key: const Key('platform-user-search'),
              controller: _searchController,
              hintText: 'Buscar por nome, e-mail, CPF, celular ou cargo',
              semanticLabel:
                  'Buscar usuário interno por nome, e-mail, CPF ou celular protegido, ou cargo',
              onChanged: _search,
            ),
          ),
          SizedBox(
            width: filterWidth,
            child: CoeloAdminMultiSelectFilter<String>(
              key: const Key('platform-user-role-filter'),
              label: 'Perfil',
              options: widget.repository.profiles.map((item) => item.id).toList(),
              selectedValues: _profileIds,
              optionLabel: (id) =>
                  widget.repository.profiles.firstWhere((item) => item.id == id).name,
              onChanged: (profiles) {
                setState(() {
                  _profileIds = profiles;
                  _page = 1;
                });
                unawaited(_load());
              },
            ),
          ),
          SizedBox(
            width: filterWidth,
            child: CoeloAdminMultiSelectFilter<PlatformMembershipStatus>(
              key: const Key('platform-user-status-filter'),
              label: 'Vínculo',
              options: PlatformMembershipStatus.values,
              selectedValues: _statuses,
              optionLabel: (status) => status.label,
              onChanged: (statuses) {
                setState(() {
                  _statuses = statuses;
                  _page = 1;
                });
                unawaited(_load());
              },
            ),
          ),
          SizedBox(
            width: filterWidth,
            child: CoeloAdminMultiSelectFilter<PlatformUserScope>(
              key: const Key('platform-user-scope-filter'),
              label: 'Alcance',
              options: PlatformUserScope.values,
              selectedValues: _scopes,
              optionLabel: (scope) => scope.label,
              onChanged: (scopes) {
                setState(() {
                  _scopes = scopes;
                  _page = 1;
                });
                unawaited(_load());
              },
            ),
          ),
          if (_profileIds.isNotEmpty ||
              _statuses.isNotEmpty ||
              _scopes.isNotEmpty ||
              _searchController.text.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _profileIds = {};
                  _statuses = {};
                  _scopes = {};
                  _page = 1;
                });
                unawaited(_load());
              },
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtros'),
            ),
        ],
      ),
      filters: const [],
      actions: [
        SizedBox(
          key: const Key('platform-user-display-toggle'),
          height: CoeloSize.touchMin,
          child: SuperadminDirectoryViewToggle<PlatformUserTableView>(
            cardsSelected: _view == PlatformUserDirectoryView.cards,
            groupedView: PlatformUserTableView.grouped,
            selectedTableView: _tableView,
            tableViews: [
              for (final view in PlatformUserTableView.values)
                SuperadminDirectoryTableViewOption(value: view, label: view.label),
            ],
            cardsKey: const Key('platform-user-view-cards'),
            tableKey: const Key('platform-user-view-table'),
            onCardsSelected: () => _changeView(PlatformUserDirectoryView.cards),
            onTableViewSelected: _changeTableView,
          ),
        ),
      ],
    );
  }

  Widget _results() {
    if (widget.capability == PlatformUserCapability.unauthorized) {
      return const CoeloStatePanel(
        title: 'Acesso não autorizado',
        message: 'Você não tem permissão para visualizar usuários internos.',
        icon: Icons.lock_outline,
      );
    }
    if (_loading) {
      return const Column(
        children: [
          LinearProgressIndicator(),
          SizedBox(height: CoeloSpacing.space4),
          CoeloStatePanel(
            title: 'Carregando usuários internos',
            message: 'Aguarde enquanto preparamos o diretório.',
            loading: true,
          ),
        ],
      );
    }
    if (_error != null) {
      return CoeloStatePanel(
        title: 'Não foi possível carregar os usuários internos',
        message: 'Tente novamente. Nenhuma alteração foi realizada.',
        icon: Icons.error_outline,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      );
    }
    if (_result.totalCount == 0) {
      final filtered =
          _searchController.text.isNotEmpty ||
          _profileIds.isNotEmpty ||
          _statuses.isNotEmpty ||
          _scopes.isNotEmpty;
      return CoeloStatePanel(
        title: filtered ? 'Nenhum resultado encontrado' : 'Nenhum usuário interno cadastrado',
        message: filtered
            ? 'Ajuste a busca ou limpe os filtros.'
            : 'Crie o primeiro vínculo de equipe no preview.',
        icon: filtered ? Icons.search_off_outlined : Icons.badge_outlined,
        actionLabel: !filtered && widget.capability == PlatformUserCapability.owner
            ? 'Criar usuário'
            : null,
        onAction: !filtered && widget.capability == PlatformUserCapability.owner
            ? widget.onCreate
            : null,
      );
    }
    return _view == PlatformUserDirectoryView.cards ? _cards() : _table();
  }

  Widget _cards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(1, (constraints.maxWidth / 340).floor());
        final cardWidth = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
        return Wrap(
          key: const Key('platform-user-card-grid'),
          spacing: CoeloSpacing.space6,
          runSpacing: CoeloSpacing.space6,
          children: [
            if (widget.capability == PlatformUserCapability.owner && widget.onCreate != null)
              SizedBox(
                width: cardWidth,
                child: ConstrainedBox(
                  key: const Key('create-platform-user-card'),
                  constraints: const BoxConstraints(minHeight: 216),
                  child: CoeloAdminCreateAction(
                    label: 'Criar acesso interno',
                    icon: Icons.person_add_alt_1_outlined,
                    onPressed: widget.onCreate!,
                  ),
                ),
              ),
            for (final item in _result.items)
              SizedBox(
                width: cardWidth,
                child: _PlatformUserCard(item: item, onView: widget.onView),
              ),
          ],
        );
      },
    );
  }

  Widget _table() {
    return Column(
      children: [
        if (widget.capability == PlatformUserCapability.owner && widget.onCreate != null) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoeloSpacing.space20),
            child: SizedBox(
              width: double.infinity,
              child: CoeloAdminCreateAction(
                label: 'Criar usuário interno',
                icon: Icons.person_add_alt_1_outlined,
                variant: CoeloAdminCreateActionVariant.banner,
                description: 'Adicionar novo vínculo à equipe Coelo.',
                onPressed: widget.onCreate!,
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        KeyedSubtree(
          key: const Key('platform-user-table-page-size-8'),
          child: CoeloAdminResizableTable<PlatformUserRecord>(
            key: const Key('platform-user-directory-table'),
            items: _result.items,
            rowKey: (item) => 'platform-user-table-row-${item.id}',
            pinnedColumn: _column('person', 'Pessoa', 260, _personCell),
            columns: _tableColumns(),
            headerHeight: 56,
            rowHeight: MediaQuery.textScalerOf(context).scale(1) >= 1.75 ? 88 : 64,
            onRowPressed: widget.onView == null ? null : (item) => widget.onView!(item.id),
          ),
        ),
      ],
    );
  }

  List<CoeloAdminTableColumn<PlatformUserRecord>> _tableColumns() {
    return [
      _column('role', 'Perfil', 180, (context, item) => _textCell(item.profile.name)),
      _column('scope', 'Escopo', 190, (context, item) => _textCell(item.scopeLabel)),
      _column('status', 'Vínculo', 150, (context, item) => _statusChip(context, item.status)),
      _column(
        'invitation',
        'Convite',
        150,
        (context, item) => _textCell(item.invitationStatus.label),
      ),
      _column(
        'reviewed',
        'Revisado em',
        150,
        (context, item) => _textCell(_formatDate(item.invitation.updatedAt)),
      ),
    ];
  }

  CoeloAdminTableColumn<PlatformUserRecord> _column(
    String id,
    String label,
    double width,
    Widget Function(BuildContext, PlatformUserRecord) builder,
  ) {
    return CoeloAdminTableColumn<PlatformUserRecord>(
      id: id,
      label: label,
      initialWidth: width,
      minWidth: math.min(width, 140),
      maxWidth: 420,
      cellBuilder: builder,
    );
  }

  Widget _personCell(BuildContext context, PlatformUserRecord item) {
    return Row(
      children: [
        CoeloAvatar(
          semanticLabel: 'Avatar de ${item.fullName}',
          initials: item.initials,
          size: CoeloAvatarSize.small,
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                item.maskedEmail,
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

  Widget _textCell(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
  );

  Widget _paginationFooter(double horizontalPadding) {
    return SuperadminListingPaginationFooter(
      semanticKey: const Key('platform-user-pagination-footer'),
      horizontalPadding: horizontalPadding,
      child: CoeloAdminPagination(
        currentPage: _result.page.clamp(1, _result.pageCount),
        totalPages: _result.pageCount,
        onPrevious: _page > 1
            ? () {
                _page--;
                unawaited(_load());
              }
            : null,
        onNext: _page < _result.pageCount
            ? () {
                _page++;
                unawaited(_load());
              }
            : null,
        onPageSelected: (page) {
          _page = page;
          unawaited(_load());
        },
        pageSize: _pageSize,
        pageSizeOptions: _view == PlatformUserDirectoryView.cards
            ? const [11, 20, 50, 100]
            : const [8, 20, 50, 100],
        onPageSizeChanged: (pageSize) {
          setState(() {
            _pageSize = pageSize;
            _page = 1;
          });
          unawaited(_load());
        },
      ),
    );
  }
}

final class _PlatformUserCard extends StatelessWidget {
  const _PlatformUserCard({required this.item, required this.onView});

  final PlatformUserRecord item;
  final ValueChanged<String>? onView;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final colors = Theme.of(context).colorScheme;
    return CoeloAdminInteractiveCard(
      key: Key('platform-user-card-${item.id}'),
      surfaceKey: Key('platform-user-card-surface-${item.id}'),
      minHeight: 216,
      semanticLabel: onView == null
          ? 'Usuário interno ${item.fullName}'
          : 'Abrir usuário interno ${item.fullName}',
      onPressed: onView == null ? null : () => onView!(item.id),
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
                CoeloAvatar(semanticLabel: 'Avatar de ${item.fullName}', initials: item.initials),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.fullName,
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.maskedEmail,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                _MembershipStatusDot(status: item.status),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            const Divider(height: 1),
            const SizedBox(height: CoeloSpacing.space4),
            _UserCardDetailRow(
              first: _UserCardDetail(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Perfil',
                value: item.profile.name,
              ),
              second: _UserCardDetail(
                icon: Icons.layers_outlined,
                label: 'Escopo',
                value: item.scopeLabel,
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            _UserCardDetailRow(
              first: _UserCardDetail(
                icon: Icons.mark_email_unread_outlined,
                label: 'Convite',
                value: item.invitationStatus.label,
              ),
              second: _UserCardDetail(
                icon: Icons.fact_check_outlined,
                label: 'Última revisão',
                value: _formatDate(item.invitation.updatedAt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _UserCardDetailRow extends StatelessWidget {
  const _UserCardDetailRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: CoeloSpacing.space4),
        Expanded(child: second),
      ],
    );
  }
}

final class _UserCardDetail extends StatelessWidget {
  const _UserCardDetail({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: CoeloSpacing.space8,
          height: CoeloSpacing.space8,
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
          ),
          child: Icon(icon, size: CoeloSize.iconSm, color: colors.onSurfaceVariant),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _MembershipStatusDot extends StatelessWidget {
  const _MembershipStatusDot({required this.status});

  final PlatformMembershipStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColors =
        Theme.of(context).extension<CoeloStatusColors>() ??
        (Theme.of(context).brightness == Brightness.dark
            ? CoeloStatusColors.dark
            : CoeloStatusColors.light);
    final (background, foreground) = switch (status) {
      PlatformMembershipStatus.active => (
        statusColors.successContainer,
        statusColors.onSuccessContainer,
      ),
      PlatformMembershipStatus.invited => (
        statusColors.infoContainer,
        statusColors.onInfoContainer,
      ),
      PlatformMembershipStatus.suspended => (
        statusColors.errorContainer,
        statusColors.onErrorContainer,
      ),
      PlatformMembershipStatus.revoked => (colors.surfaceContainer, colors.onSurfaceVariant),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: status.label,
      semanticLabel: 'Vínculo interno: ${status.label}',
      backgroundColor: background,
      foregroundColor: foreground,
    );
  }
}

Widget _statusChip(BuildContext context, PlatformMembershipStatus status) {
  final colors = Theme.of(context).colorScheme;
  final statusColors =
      Theme.of(context).extension<CoeloStatusColors>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? CoeloStatusColors.dark
          : CoeloStatusColors.light);
  final (background, foreground) = switch (status) {
    PlatformMembershipStatus.active => (
      statusColors.successContainer,
      statusColors.onSuccessContainer,
    ),
    PlatformMembershipStatus.invited => (statusColors.infoContainer, statusColors.onInfoContainer),
    PlatformMembershipStatus.suspended => (
      statusColors.errorContainer,
      statusColors.onErrorContainer,
    ),
    PlatformMembershipStatus.revoked => (colors.surfaceContainer, colors.onSurfaceVariant),
  };
  return CoeloStatusChip(
    label: status.label,
    backgroundColor: background,
    foregroundColor: foreground,
  );
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Não revisado';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
