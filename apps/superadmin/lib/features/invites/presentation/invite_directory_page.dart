import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/platform_invite.dart';
import 'invite_directory_widgets.dart';
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
  final Map<String, String> _actionRequestIds = {};
  final Set<_OwnedInviteOverlay> _ownedOverlays = {};
  var _page = 1;
  var _pageSize = 11;
  var _requestEpoch = 0;
  var _commandGeneration = 0;
  var _display = InviteDirectoryDisplay.cards;
  final _footerKey = GlobalKey();
  var _footerHeight = 0.0;
  var _footerMeasurementScheduled = false;

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
    if (!identical(oldWidget.repository, widget.repository)) {
      _searchDebounce?.cancel();
      _requestEpoch++;
      _commandGeneration++;
      _dismissOwnedOverlays();
      _searchController.clear();
      _statuses.clear();
      _channels.clear();
      _page = 1;
      _busyInviteId = null;
      _actionRequestIds.clear();
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
        setState(() => _snapshot = InviteDirectorySnapshot.unauthorized(error));
      }
    } on Object catch (error) {
      if (mounted && epoch == _requestEpoch) {
        setState(() => _snapshot = InviteDirectorySnapshot.failure(error));
      }
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
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
    if (!widget.allowCommands || _busyInviteId != null) return;
    final repository = widget.repository;
    final generation = _commandGeneration;
    if (action == InviteRowAction.revoke) {
      final confirmed = await _showRevokeConfirmation(invite.recipientMasked);
      if (!confirmed || !_isCurrentCommand(generation, repository)) return;
    }
    final requestKey = '${action.name}:${invite.id}';
    final requestId = _actionRequestIds.putIfAbsent(requestKey, newInviteRequestId);
    setState(() => _busyInviteId = invite.id);
    try {
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
        setState(() => _busyInviteId = null);
      }
    }
  }

  bool _isCurrentCommand(int generation, InviteRepository repository) =>
      mounted && generation == _commandGeneration && identical(repository, widget.repository);

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
            await Clipboard.setData(ClipboardData(text: link.toString()));
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
          ? CoeloSpacing.space10
          : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
          ? CoeloSpacing.space6
          : CoeloSpacing.space4;
      final showFooter =
          _snapshot.state == InviteDirectoryLoadState.ready &&
          (_snapshot.page?.totalCount ?? 0) > 0;
      _scheduleFooterMeasurement(showFooter);
      final footerInset = showFooter ? _footerHeight + CoeloSpacing.space4 : 0.0;
      final content = ColoredBox(
        key: const Key('invite-directory-page-surface'),
        color: Theme.of(context).colorScheme.surface,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SingleChildScrollView(
              key: const Key('invite-directory-vertical-scroll'),
              padding: EdgeInsets.fromLTRB(inset, inset, inset, inset + footerInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InviteDirectoryToolbar(
                    searchController: _searchController,
                    statuses: _statuses,
                    channels: _channels,
                    onSearchChanged: _onSearchChanged,
                    onStatusesChanged: (values) => _setFilters(() {
                      _statuses
                        ..clear()
                        ..addAll(values);
                    }),
                    onChannelsChanged: (values) => _setFilters(() {
                      _channels
                        ..clear()
                        ..addAll(values);
                    }),
                    display: _display,
                    onDisplayChanged: _changeDisplay,
                    onClear: _query.hasActiveFilters ? _clearFilters : null,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  if (_snapshot.state != InviteDirectoryLoadState.unauthorized &&
                      _display == InviteDirectoryDisplay.table &&
                      widget.onCreate != null) ...[
                    CoeloAdminCreateAction(
                      key: const Key('invite-create-action'),
                      label: 'Novo convite',
                      description: 'Escolha contexto, perfil, destinatário e canais.',
                      icon: Icons.mark_email_unread_outlined,
                      variant: CoeloAdminCreateActionVariant.banner,
                      onPressed: widget.onCreate!,
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                  ],
                  _body(),
                ],
              ),
            ),
            if (showFooter)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: NotificationListener<SizeChangedLayoutNotification>(
                  onNotification: (_) {
                    _scheduleFooterMeasurement(true);
                    return true;
                  },
                  child: SizeChangedLayoutNotifier(
                    key: _footerKey,
                    child: _pagination(_snapshot.page!, horizontalPadding: inset),
                  ),
                ),
              ),
          ],
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
    },
  );

  Widget _body() => switch (_snapshot.state) {
    InviteDirectoryLoadState.loading => const CoeloStatePanel(
      title: 'Carregando convites',
      message: 'Buscando dados autorizados.',
      icon: Icons.hourglass_top_rounded,
    ),
    InviteDirectoryLoadState.empty => _withCardsCreate(
      const CoeloStatePanel(
        title: 'Nenhum convite',
        message: 'Crie o primeiro convite para iniciar o acompanhamento.',
        icon: Icons.mail_outline_rounded,
      ),
    ),
    InviteDirectoryLoadState.noResults => _withCardsCreate(
      CoeloStatePanel(
        title: 'Nenhum resultado',
        message: 'Ajuste a busca ou os filtros.',
        icon: Icons.search_off_rounded,
        actionLabel: 'Limpar filtros',
        onAction: _clearFilters,
      ),
    ),
    InviteDirectoryLoadState.failure => _withCardsCreate(
      CoeloStatePanel(
        title: 'Convites indisponíveis',
        message: 'Não foi possível carregar os convites.',
        icon: Icons.error_outline_rounded,
        actionLabel: 'Tentar novamente',
        onAction: _load,
      ),
    ),
    InviteDirectoryLoadState.unauthorized => const CoeloStatePanel(
      title: 'Acesso não autorizado',
      message: 'Seu contexto atual não permite consultar convites.',
      icon: Icons.lock_outline_rounded,
    ),
    InviteDirectoryLoadState.ready => _ready(_snapshot.page!),
  };

  Widget _ready(InviteDirectoryResult page) => switch (_display) {
    InviteDirectoryDisplay.cards => InviteDirectoryCards(
      items: page.items,
      busyInviteId: _busyInviteId,
      onCreate: widget.onCreate,
      onOpen: widget.onOpen,
      allowCommands: widget.allowCommands,
      onAction: _handleAction,
    ),
    InviteDirectoryDisplay.table => InviteDirectoryTable(
      items: page.items,
      busyInviteId: _busyInviteId,
      onOpen: widget.onOpen,
      allowCommands: widget.allowCommands,
      onAction: _handleAction,
    ),
  };

  Widget _withCardsCreate(Widget statePanel) {
    if (_display != InviteDirectoryDisplay.cards || widget.onCreate == null) {
      return statePanel;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InviteDirectoryCards(
          items: const [],
          busyInviteId: null,
          onCreate: widget.onCreate,
          allowCommands: false,
          onAction: _handleAction,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        statePanel,
      ],
    );
  }

  void _changeDisplay(InviteDirectoryDisplay display) {
    if (_display == display) return;
    setState(() {
      _display = display;
      _page = 1;
      _pageSize = display == InviteDirectoryDisplay.cards ? 11 : 8;
    });
    unawaited(_load());
  }

  Widget _pagination(InviteDirectoryResult page, {required double horizontalPadding}) =>
      SuperadminListingPaginationFooter(
        semanticKey: const Key('invite-directory-pagination-footer'),
        horizontalPadding: horizontalPadding,
        compactCurrentPage: page.page,
        compactTotalPages: page.totalPages,
        compactOnPrevious: page.page > 1 ? () => _goToPage(page.page - 1) : null,
        compactOnNext: page.page < page.totalPages ? () => _goToPage(page.page + 1) : null,
        child: CoeloAdminPagination(
          currentPage: page.page,
          totalPages: page.totalPages,
          pageSize: page.pageSize,
          pageSizeOptions: _display == InviteDirectoryDisplay.cards
              ? InviteDirectoryQuery.cardPageSizes
              : InviteDirectoryQuery.tablePageSizes,
          onPageSizeChanged: (value) {
            setState(() {
              _pageSize = value;
              _page = 1;
            });
            unawaited(_load());
          },
          onPrevious: page.page > 1
              ? () {
                  _page--;
                  unawaited(_load());
                }
              : null,
          onNext: page.page < page.totalPages
              ? () {
                  _page++;
                  unawaited(_load());
                }
              : null,
          onPageSelected: (value) {
            _page = value;
            unawaited(_load());
          },
        ),
      );

  void _goToPage(int value) {
    _page = value;
    unawaited(_load());
  }

  void _scheduleFooterMeasurement(bool visible) {
    if (!visible) {
      if (_footerHeight != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _footerHeight = 0);
        });
      }
      return;
    }
    if (_footerMeasurementScheduled) return;
    _footerMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _footerMeasurementScheduled = false;
      if (!mounted) return;
      final box = _footerKey.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.size.height ?? 0;
      if ((_footerHeight - height).abs() >= 0.5) setState(() => _footerHeight = height);
    });
  }
}

final class _OwnedInviteOverlay {
  const _OwnedInviteOverlay(this.navigator, this.route);

  final NavigatorState navigator;
  final Route<dynamic> route;
}
