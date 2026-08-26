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
import 'invite_presentation_support.dart';
import 'invite_request_id.dart';

final class InviteDirectoryPage extends StatefulWidget {
  const InviteDirectoryPage({
    required this.repository,
    this.onCreate,
    this.onOpen,
    this.logout = unavailableSuperadminLogout,
    this.onDestinationSelected,
    super.key,
  });

  final InviteRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
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
  var _page = 1;
  var _pageSize = 20;
  var _requestEpoch = 0;
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
      _page = 1;
      _actionRequestIds.clear();
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
    if (action == InviteRowAction.revoke) {
      final confirmed = await showInviteRevokeConfirmation(
        context,
        recipientMasked: invite.recipientMasked,
      );
      if (!confirmed || !mounted) return;
    }
    final requestKey = '${action.name}:${invite.id}';
    final requestId = _actionRequestIds.putIfAbsent(requestKey, newInviteRequestId);
    setState(() => _busyInviteId = invite.id);
    try {
      final result = switch (action) {
        InviteRowAction.resend => await widget.repository.resend(
          InviteResendCommand(
            inviteId: invite.id,
            requestId: requestId,
            expectedVersion: invite.managementVersion,
          ),
        ),
        InviteRowAction.revoke => await widget.repository.revoke(
          InviteRevokeCommand(
            inviteId: invite.id,
            requestId: requestId,
            expectedVersion: invite.managementVersion,
            reason: 'Revogação administrativa confirmada',
          ),
        ),
        InviteRowAction.details => throw StateError('Ação já tratada.'),
      };
      if (!mounted) return;
      _clearActionRequestId(requestKey, requestId);
      if (result.link case final link?) await _showLink(link);
      if (mounted) {
        _feedback(
          action == InviteRowAction.resend
              ? 'Reenvio solicitado. A entrega depende do provedor.'
              : 'Convite revogado.',
        );
        await _load(showLoading: false);
      }
    } on InviteConflictException {
      _clearActionRequestId(requestKey, requestId);
      if (mounted) _feedback('O convite mudou. Atualize e tente novamente.', error: true);
      await _load(showLoading: false);
    } on InviteUnauthorizedException {
      _clearActionRequestId(requestKey, requestId);
      if (mounted) _feedback('Ação não autorizada.', error: true);
    } on Object {
      if (mounted) _feedback('Não foi possível concluir a ação.', error: true);
    } finally {
      if (mounted) setState(() => _busyInviteId = null);
    }
  }

  void _clearActionRequestId(String key, String requestId) {
    if (_actionRequestIds[key] == requestId) _actionRequestIds.remove(key);
  }

  Future<void> _showLink(Uri link) async {
    await showDialog<void>(
      context: context,
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
                    onClear: _query.hasActiveFilters ? _clearFilters : null,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  if (_snapshot.state != InviteDirectoryLoadState.unauthorized) ...[
                    CoeloAdminCreateAction(
                      key: const Key('invite-create-action'),
                      label: 'Novo convite',
                      description: 'Escolha contexto, perfil, destinatário e canais.',
                      icon: Icons.mark_email_unread_outlined,
                      variant: CoeloAdminCreateActionVariant.banner,
                      onPressed: widget.onCreate,
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
    InviteDirectoryLoadState.empty => CoeloStatePanel(
      title: 'Nenhum convite',
      message: 'Crie o primeiro convite para iniciar o acompanhamento.',
      icon: Icons.mail_outline_rounded,
      actionLabel: widget.onCreate == null ? null : 'Novo convite',
      onAction: widget.onCreate,
    ),
    InviteDirectoryLoadState.noResults => CoeloStatePanel(
      title: 'Nenhum resultado',
      message: 'Ajuste a busca ou os filtros.',
      icon: Icons.search_off_rounded,
      actionLabel: 'Limpar filtros',
      onAction: _clearFilters,
    ),
    InviteDirectoryLoadState.failure => CoeloStatePanel(
      title: 'Convites indisponíveis',
      message: 'Não foi possível carregar os convites.',
      icon: Icons.error_outline_rounded,
      actionLabel: 'Tentar novamente',
      onAction: _load,
    ),
    InviteDirectoryLoadState.unauthorized => const CoeloStatePanel(
      title: 'Acesso não autorizado',
      message: 'Seu contexto atual não permite consultar convites.',
      icon: Icons.lock_outline_rounded,
    ),
    InviteDirectoryLoadState.ready => _ready(_snapshot.page!),
  };

  Widget _ready(InviteDirectoryResult page) => InviteDirectoryTable(
    items: page.items,
    busyInviteId: _busyInviteId,
    onOpen: widget.onOpen,
    onAction: _handleAction,
  );

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
          pageSizeOptions: InviteDirectoryQuery.allowedPageSizes,
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
