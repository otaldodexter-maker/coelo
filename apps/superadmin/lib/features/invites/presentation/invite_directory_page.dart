import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/platform_invite.dart';
import 'invite_directory_widgets.dart';
import 'invite_presentation_support.dart';
import 'invite_request_id.dart';

final class InviteDirectoryPage extends StatefulWidget {
  const InviteDirectoryPage({
    required this.repository,
    this.onCreate,
    this.onOpen,
    this.allowCommands = false,
    this.logout = unavailableSuperadminLogout,
    this.onDestinationSelected,
    super.key,
  });

  final InviteRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
  final bool allowCommands;
  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<InviteDirectoryPage> createState() => _InviteDirectoryPageState();
}

final class _InviteDirectoryPageState extends State<InviteDirectoryPage> {
  final _searchController = TextEditingController();
  final Set<InviteStatus> _statuses = {};
  final Set<InviteChannel> _channels = {};
  InviteDirectorySnapshot _snapshot = const InviteDirectorySnapshot.loading();
  Timer? _searchDebounce;
  String? _busyInviteId;
  bool _actionInProgress = false;
  final Map<String, String> _actionRequestIds = {};
  final Set<_OwnedInviteOverlay> _ownedOverlays = {};
  var _page = 1;
  var _pageSize = 11;
  var _requestEpoch = 0;
  var _commandGeneration = 0;
  var _display = CoeloAdminDirectoryDisplay.cards;
  var _footerHeight = 0.0;

  InviteDirectoryQuery get _query => InviteDirectoryQuery(
    search: _searchController.text,
    statuses: _statuses,
    channels: _channels,
    page: _page,
    pageSize: _pageSize,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant InviteDirectoryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final repositoryChanged = !identical(oldWidget.repository, widget.repository);
    if (repositoryChanged || oldWidget.allowCommands != widget.allowCommands) {
      _commandGeneration++;
      _dismissOwnedOverlays();
      _busyInviteId = null;
      _actionInProgress = false;
      _actionRequestIds.clear();
    }
    if (repositoryChanged) {
      _searchDebounce?.cancel();
      _requestEpoch++;
      _searchController.clear();
      _statuses.clear();
      _channels.clear();
      _page = 1;
      _snapshot = const InviteDirectorySnapshot.loading();
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _requestEpoch++;
    _commandGeneration++;
    _dismissOwnedOverlays();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    _searchDebounce?.cancel();
    final epoch = ++_requestEpoch;
    final query = _query;
    if (showLoading && mounted) {
      setState(() => _snapshot = const InviteDirectorySnapshot.loading());
    }
    try {
      final page = await widget.repository.fetchPage(query);
      if (!mounted || epoch != _requestEpoch) return;
      setState(() {
        _snapshot = InviteDirectorySnapshot.loaded(
          page,
          search: query.hasActiveFilters ? 'active-filter' : '',
        );
      });
    } on InviteUnauthorizedException catch (error) {
      if (mounted && epoch == _requestEpoch) {
        _commandGeneration++;
        _dismissOwnedOverlays();
        setState(() {
          _snapshot = InviteDirectorySnapshot.unauthorized(error);
          _busyInviteId = null;
          _actionInProgress = false;
          _actionRequestIds.clear();
        });
      }
    } on Object catch (error) {
      if (mounted && epoch == _requestEpoch) {
        setState(() => _snapshot = InviteDirectorySnapshot.failure(error));
      }
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _requestEpoch++;
    setState(() => _snapshot = const InviteDirectorySnapshot.loading());
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _page = 1;
      unawaited(_load());
    });
  }

  void _setFilters(VoidCallback mutation) {
    setState(mutation);
    _page = 1;
    unawaited(_load());
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    setState(() {
      _searchController.clear();
      _statuses.clear();
      _channels.clear();
      _page = 1;
    });
    unawaited(_load());
  }

  Future<void> _handleAction(PlatformInvite invite, InviteRowAction action) async {
    if (action == InviteRowAction.details) {
      widget.onOpen?.call(invite.id);
      return;
    }
    if (!mounted ||
        !widget.allowCommands ||
        _actionInProgress ||
        _snapshot.state != InviteDirectoryLoadState.ready) {
      return;
    }
    _actionInProgress = true;
    final repository = widget.repository;
    final generation = _commandGeneration;
    final requestKey = '${action.name}:${invite.id}';
    final requestId = _actionRequestIds.putIfAbsent(requestKey, newInviteRequestId);
    try {
      if (action == InviteRowAction.revoke) {
        final confirmed = await _showRevokeConfirmation(invite.recipientMasked);
        if (!_isCurrentCommand(generation, repository)) return;
        if (!confirmed) {
          _clearActionRequestId(requestKey, requestId);
          return;
        }
      }
      setState(() => _busyInviteId = invite.id);
      final result = switch (action) {
        InviteRowAction.resend => await repository.resend(
          InviteResendCommand(
            inviteId: invite.id,
            requestId: requestId,
            expectedVersion: invite.managementVersion,
          ),
        ),
        InviteRowAction.revoke => await repository.revoke(
          InviteRevokeCommand(
            inviteId: invite.id,
            requestId: requestId,
            expectedVersion: invite.managementVersion,
            reason: 'Revogação administrativa confirmada',
          ),
        ),
        InviteRowAction.details => throw StateError('Ação já tratada.'),
      };
      if (!_isCurrentCommand(generation, repository)) return;
      _clearActionRequestId(requestKey, requestId);
      if (result.link case final link?) {
        await _showLink(link, generation: generation, repository: repository);
      }
      if (_isCurrentCommand(generation, repository)) {
        _feedback(
          action == InviteRowAction.resend
              ? 'Reenvio solicitado. A entrega depende do provedor.'
              : 'Convite revogado.',
        );
        await _load(showLoading: false);
      }
    } on InviteConflictException {
      if (!_isCurrentCommand(generation, repository)) return;
      _clearActionRequestId(requestKey, requestId);
      if (mounted) _feedback('O convite mudou. Atualize e tente novamente.', error: true);
      await _load(showLoading: false);
    } on InviteUnauthorizedException {
      if (!_isCurrentCommand(generation, repository)) return;
      _clearActionRequestId(requestKey, requestId);
      if (mounted) _feedback('Ação não autorizada.', error: true);
    } on Object {
      if (_isCurrentCommand(generation, repository)) {
        _feedback('Não foi possível concluir a ação.', error: true);
      }
    } finally {
      if (_isCurrentCommand(generation, repository)) {
        setState(() {
          _busyInviteId = null;
          _actionInProgress = false;
        });
      }
    }
  }

  bool _isCurrentCommand(int generation, InviteRepository repository) =>
      mounted &&
      widget.allowCommands &&
      generation == _commandGeneration &&
      identical(repository, widget.repository);

  void _clearActionRequestId(String key, String requestId) {
    if (_actionRequestIds[key] == requestId) _actionRequestIds.remove(key);
  }

  Future<void> _showLink(
    Uri link, {
    required int generation,
    required InviteRepository repository,
  }) async {
    if (!_isCurrentCommand(generation, repository)) return;
    await _showOwnedDialog<void>(
      builder: (dialogContext) => CoeloAdminDialogShell(
        title: 'Novo link do convite',
        body: SelectableText(link.toString(), key: const Key('invite-resend-link')),
        secondaryAction: TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Fechar'),
        ),
        primaryAction: FilledButton.icon(
          key: const Key('invite-resend-copy-link'),
          onPressed: () async {
            final copied = await copyInviteLink(
              dialogContext,
              link,
              isContextCurrent: () => _isCurrentCommand(generation, repository),
            );
            if (copied && dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          icon: const Icon(Icons.content_copy_rounded),
          label: const Text('Copiar link'),
        ),
      ),
    );
  }

  Future<bool> _showRevokeConfirmation(String recipientMasked) async {
    final colors = Theme.of(context).colorScheme;
    return await _showOwnedDialog<bool>(
          builder: (dialogContext) => CoeloAdminDialogShell(
            dialogKey: const Key('invite-revoke-dialog'),
            closeButtonKey: const Key('invite-revoke-dialog-close'),
            title: 'Revogar convite?',
            body: Text(
              'O convite para $recipientMasked deixará de poder ser aceito. '
              'Esta ação será registrada na auditoria.',
            ),
            secondaryAction: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            primaryAction: FilledButton(
              key: const Key('invite-revoke-confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Revogar convite'),
            ),
          ),
        ) ??
        false;
  }

  Future<T?> _showOwnedDialog<T>({required WidgetBuilder builder}) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final overlay = Theme.of(context).extension<CoeloOverlayColors>();
    final route = DialogRoute<T>(
      context: context,
      barrierColor: overlay?.scrim ?? Colors.black54,
      builder: builder,
    );
    final owned = _OwnedInviteOverlay(navigator, route);
    _ownedOverlays.add(owned);
    try {
      unawaited(navigator.push<T>(route));
      return await route.completed;
    } finally {
      _ownedOverlays.remove(owned);
    }
  }

  void _dismissOwnedOverlays() {
    for (final owned in _ownedOverlays.toList(growable: false)) {
      if (owned.route.isActive) owned.navigator.removeRoute(owned.route);
    }
    _ownedOverlays.clear();
  }

  void _feedback(String message, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? colors.error : null));
  }

  @override
  Widget build(BuildContext context) {
    final page = _snapshot.page;
    final onCreate = widget.onCreate;
    final content = ColoredBox(
      key: const Key('invite-directory-page-surface'),
      color: Theme.of(context).colorScheme.surface,
      child: CoeloAdminDirectory<InviteDirectoryTableView>(
        scrollKey: const Key('invite-directory-vertical-scroll'),
        toggleKey: const Key('invite-display-toggle'),
        cardsKey: const Key('invite-view-cards'),
        tableKey: const Key('invite-view-table'),
        gridKey: const Key('invite-card-grid'),
        status: switch (_snapshot.state) {
          InviteDirectoryLoadState.loading => CoeloAdminDirectoryStatus.loading,
          InviteDirectoryLoadState.empty => CoeloAdminDirectoryStatus.empty,
          InviteDirectoryLoadState.noResults => CoeloAdminDirectoryStatus.noResults,
          InviteDirectoryLoadState.failure => CoeloAdminDirectoryStatus.failure,
          InviteDirectoryLoadState.unauthorized => CoeloAdminDirectoryStatus.unauthorized,
          InviteDirectoryLoadState.ready => CoeloAdminDirectoryStatus.success,
        },
        messages: const CoeloAdminDirectoryMessages(
          empty: 'Nenhum convite',
          emptyIcon: Icons.mail_outline_rounded,
          noResults: 'Nenhum resultado',
          noResultsIcon: Icons.search_off_rounded,
          failure: 'Convites indisponíveis',
          failureIcon: Icons.error_outline_rounded,
          unauthorized: 'Acesso não autorizado',
          unauthorizedIcon: Icons.lock_outline_rounded,
        ),
        errorMessage: switch (_snapshot.state) {
          InviteDirectoryLoadState.empty =>
            'Crie o primeiro convite para iniciar o acompanhamento.',
          InviteDirectoryLoadState.noResults => 'Ajuste a busca ou os filtros.',
          InviteDirectoryLoadState.failure => 'Não foi possível carregar os convites.',
          InviteDirectoryLoadState.unauthorized =>
            'Seu contexto atual não permite consultar convites.',
          _ => null,
        },
        onRetry: _load,
        onClearFilters: _clearFilters,
        search: CoeloSearchField(
          controller: _searchController,
          semanticLabel: 'Buscar convites',
          hintText: 'Buscar destinatário',
          onChanged: _onSearchChanged,
        ),
        filters: [
          CoeloAdminMultiSelectFilter<InviteStatus>(
            label: 'Status',
            options: InviteStatus.values,
            selectedValues: _statuses,
            optionLabel: (value) => value.label,
            onChanged: (values) => _setFilters(() {
              _statuses
                ..clear()
                ..addAll(values);
            }),
          ),
          CoeloAdminMultiSelectFilter<InviteChannel>(
            label: 'Canal',
            options: InviteChannel.values,
            selectedValues: _channels,
            optionLabel: (value) => value.label,
            onChanged: (values) => _setFilters(() {
              _channels
                ..clear()
                ..addAll(values);
            }),
          ),
        ],
        trailing: [
          if (_query.hasActiveFilters)
            TextButton.icon(
              key: const Key('invite-clear-filters'),
              onPressed: _clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Limpar filtros'),
            ),
        ],
        display: _display,
        onDisplayChanged: _changeDisplay,
        groupedTableView: InviteDirectoryTableView.all,
        selectedTableView: InviteDirectoryTableView.all,
        tableViews: const [
          CoeloAdminDirectoryTableViewOption(
            value: InviteDirectoryTableView.all,
            label: 'Todos os convites',
          ),
        ],
        onTableViewSelected: (_) => _changeDisplay(CoeloAdminDirectoryDisplay.table),
        fileActions: inviteFileActions(context),
        create: onCreate == null
            ? null
            : CoeloAdminDirectoryCreate(
                label: 'Novo convite',
                description: 'Escolha contexto, perfil, destinatário e canais.',
                icon: Icons.mark_email_unread_outlined,
                onPressed: onCreate,
                tileKey: const Key('invite-create-card'),
                bannerKey: const Key('invite-create-action'),
              ),
        cards: [
          if (page != null)
            for (final invite in page.items)
              InviteCard(
                invite: invite,
                busy: _busyInviteId == invite.id,
                onOpen: widget.onOpen == null ? null : () => widget.onOpen!(invite.id),
                allowCommands: widget.allowCommands,
                onSelected: (action) => _handleAction(invite, action),
              ),
        ],
        table: InviteTableRows(
          items: page?.items ?? const [],
          busyInviteId: _busyInviteId,
          onOpen: widget.onOpen,
          allowCommands: widget.allowCommands,
          onAction: _handleAction,
        ),
        pagination: _snapshot.state == InviteDirectoryLoadState.ready && page != null
            ? CoeloAdminDirectoryPagination(
                footerKey: const Key('invite-directory-pagination-footer'),
                currentPage: page.page,
                totalPages: page.totalPages,
                pageSize: page.pageSize,
                pageSizeOptions: _display == CoeloAdminDirectoryDisplay.cards
                    ? InviteDirectoryQuery.cardPageSizes
                    : InviteDirectoryQuery.tablePageSizes,
                onPageSelected: _goToPage,
                onPageSizeChanged: (value) {
                  setState(() {
                    _pageSize = value;
                    _page = 1;
                  });
                  unawaited(_load());
                },
              )
            : null,
        onFooterHeightChanged: (height) {
          if ((_footerHeight - height).abs() >= 0.5) setState(() => _footerHeight = height);
        },
      ),
    );
    return SuperadminShell(
      logout: widget.logout,
      title: 'Convites',
      subtitle: 'Emita, acompanhe, reenvie e revogue convites.',
      currentDestination: 'invites',
      onDestinationSelected: widget.onDestinationSelected,
      chatLauncherBottomInset: _footerHeight,
      child: content,
    );
  }

  void _changeDisplay(CoeloAdminDirectoryDisplay display) {
    if (_display == display) return;
    setState(() {
      _display = display;
      _page = 1;
      _pageSize = display == CoeloAdminDirectoryDisplay.cards ? 11 : 8;
    });
    unawaited(_load());
  }

  void _goToPage(int value) {
    _page = value;
    unawaited(_load());
  }
}

final class _OwnedInviteOverlay {
  const _OwnedInviteOverlay(this.navigator, this.route);

  final NavigatorState navigator;
  final Route<dynamic> route;
}
