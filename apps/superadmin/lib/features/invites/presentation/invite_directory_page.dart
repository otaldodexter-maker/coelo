import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/fake_invite_repository.dart';
import '../domain/platform_invite.dart';
import 'invite_presentation_support.dart';

enum InviteDirectoryState { loading, content, empty, noResults, error, unauthorized }

enum _InvitePeriodFilter { all, last7Days, last30Days, last90Days, thisMonth }

enum _InviteRowAction { details, copyLink, resend, revoke }

final class InviteDirectoryPage extends StatefulWidget {
  const InviteDirectoryPage({
    required this.repository,
    this.onCreate,
    this.onOpen,
    this.state = InviteDirectoryState.content,
    super.key,
  });

  final FakeInviteRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
  final InviteDirectoryState state;

  @override
  State<InviteDirectoryPage> createState() => _InviteDirectoryPageState();
}

final class _InviteDirectoryPageState extends State<InviteDirectoryPage> {
  final _searchController = TextEditingController();
  final Set<InviteAudience> _audiences = {};
  final Set<InviteChannel> _channels = {};
  final Set<InviteStatus> _statuses = {};
  _InvitePeriodFilter _period = _InvitePeriodFilter.all;
  String? _busyInviteId;

  bool get _hasFilters =>
      _searchController.text.isNotEmpty ||
      _audiences.isNotEmpty ||
      _channels.isNotEmpty ||
      _statuses.isNotEmpty ||
      _period != _InvitePeriodFilter.all;

  InviteQuery get _query {
    final now = DateTime.now();
    final (periodStart, periodEnd) = switch (_period) {
      _InvitePeriodFilter.all => (null, null),
      _InvitePeriodFilter.last7Days => (
        _startOfDay(now.subtract(const Duration(days: 6))),
        _endOfDay(now),
      ),
      _InvitePeriodFilter.last30Days => (
        _startOfDay(now.subtract(const Duration(days: 29))),
        _endOfDay(now),
      ),
      _InvitePeriodFilter.last90Days => (
        _startOfDay(now.subtract(const Duration(days: 89))),
        _endOfDay(now),
      ),
      _InvitePeriodFilter.thisMonth => (
        DateTime(now.year, now.month, 1),
        _endOfDay(DateTime(now.year, now.month + 1, 0)),
      ),
    };
    return InviteQuery(
      search: _searchController.text,
      audiences: _audiences,
      channels: _channels,
      statuses: _statuses,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _audiences.clear();
      _channels.clear();
      _statuses.clear();
      _period = _InvitePeriodFilter.all;
    });
  }

  Future<void> _handleAction(PlatformInvite invite, _InviteRowAction action) async {
    switch (action) {
      case _InviteRowAction.details:
        widget.onOpen?.call(invite.id);
        return;
      case _InviteRowAction.copyLink:
        final link = invite.link;
        if (link == null) return;
        await _runAction(invite.id, () async {
          await Clipboard.setData(ClipboardData(text: link));
          return 'Link do convite copiado.';
        });
        return;
      case _InviteRowAction.resend:
        await _runAction(invite.id, () async {
          await Future<void>.delayed(Duration.zero);
          widget.repository.resend(invite.id);
          return 'Convite reenviado com sucesso.';
        });
        return;
      case _InviteRowAction.revoke:
        final confirmed = await showInviteRevokeConfirmation(
          context,
          recipientMasked: invite.recipientMasked,
        );
        if (!confirmed || !mounted) return;
        await _runAction(invite.id, () async {
          await Future<void>.delayed(Duration.zero);
          widget.repository.revoke(invite.id);
          return 'Convite revogado com sucesso.';
        });
        return;
    }
  }

  Future<void> _runAction(String inviteId, Future<String> Function() action) async {
    setState(() => _busyInviteId = inviteId);
    try {
      final message = await action();
      if (mounted) _showFeedback(message);
    } on Object catch (error) {
      if (mounted) _showFeedback(_errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busyInviteId = null);
    }
  }

  void _showFeedback(String message, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? colors.error : null));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final searchWidth = compact ? constraints.maxWidth : 280.0;
      final filterWidth = compact ? constraints.maxWidth : CoeloSpacing.space20 * 2;
      final items = widget.repository.list(_query);
      final rowHeight = MediaQuery.textScalerOf(context).scale(64).clamp(64, 96).toDouble();
      return ColoredBox(
        key: const Key('invite-directory-page-surface'),
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          key: const Key('invite-directory-vertical-scroll'),
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Convites', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: CoeloSpacing.space2),
                Text(
                  'Acompanhe convites fictícios e mascarados do preview local.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: CoeloSpacing.space4),
                CoeloAdminListingToolbar(
                  search: SizedBox(
                    width: searchWidth,
                    height: CoeloSize.touchMin,
                    child: CoeloSearchField(
                      controller: _searchController,
                      semanticLabel: 'Buscar convites pelo destinatário mascarado',
                      hintText: 'Buscar destinatário',
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  filters: [
                    SizedBox(
                      width: filterWidth,
                      child: CoeloAdminMultiSelectFilter<InviteStatus>(
                        label: 'Status',
                        options: InviteStatus.values,
                        selectedValues: _statuses,
                        optionLabel: (value) => value.label,
                        onChanged: (values) => setState(() {
                          _statuses
                            ..clear()
                            ..addAll(values);
                        }),
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: CoeloAdminMultiSelectFilter<InviteAudience>(
                        label: 'Público',
                        options: InviteAudience.values,
                        selectedValues: _audiences,
                        optionLabel: (value) => value.label,
                        onChanged: (values) => setState(() {
                          _audiences
                            ..clear()
                            ..addAll(values);
                        }),
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: CoeloAdminMultiSelectFilter<InviteChannel>(
                        label: 'Canal',
                        options: InviteChannel.values,
                        selectedValues: _channels,
                        optionLabel: (value) => value.label,
                        onChanged: (values) => setState(() {
                          _channels
                            ..clear()
                            ..addAll(values);
                        }),
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: CoeloAdminSingleSelectField<_InvitePeriodFilter>(
                        label: 'Criação',
                        value: _period,
                        options: _InvitePeriodFilter.values,
                        optionLabel: _periodLabel,
                        onChanged: (value) => setState(() => _period = value),
                      ),
                    ),
                  ],
                  actions: [
                    if (_hasFilters)
                      TextButton.icon(
                        key: const Key('invite-clear-filters'),
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Limpar filtros'),
                      ),
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space4),
                SizedBox(
                  height: 300 + (rowHeight * (items.isEmpty ? 1 : items.length)),
                  child: _InviteDirectoryBody(
                    state: widget.state,
                    items: items,
                    hasFilters: _hasFilters,
                    busyInviteId: _busyInviteId,
                    rowHeight: rowHeight,
                    onCreate: widget.onCreate,
                    onOpen: widget.onOpen,
                    onClearFilters: _clearFilters,
                    onAction: _handleAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

final class _InviteDirectoryBody extends StatelessWidget {
  const _InviteDirectoryBody({
    required this.state,
    required this.items,
    required this.hasFilters,
    required this.busyInviteId,
    required this.rowHeight,
    required this.onClearFilters,
    required this.onAction,
    this.onCreate,
    this.onOpen,
  });

  final InviteDirectoryState state;
  final List<PlatformInvite> items;
  final bool hasFilters;
  final String? busyInviteId;
  final double rowHeight;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onOpen;
  final VoidCallback onClearFilters;
  final void Function(PlatformInvite invite, _InviteRowAction action) onAction;

  @override
  Widget build(BuildContext context) {
    if (state != InviteDirectoryState.content) {
      return _statePanel(state, onCreate: onCreate, onClearFilters: onClearFilters);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoeloAdminCreateAction(
          key: const Key('invite-create-action'),
          label: 'Novo convite',
          description: 'Defina público, contexto e canal de envio.',
          icon: Icons.mark_email_unread_outlined,
          variant: CoeloAdminCreateActionVariant.banner,
          onPressed: onCreate,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Expanded(
          child: items.isEmpty
              ? CoeloStatePanel(
                  title: hasFilters ? 'Nenhum resultado' : 'Nenhum convite',
                  message: hasFilters
                      ? 'Ajuste a busca ou os filtros para localizar convites.'
                      : 'Crie o primeiro convite para iniciar o acompanhamento.',
                  icon: hasFilters ? Icons.search_off_rounded : Icons.mail_outline_rounded,
                  actionLabel: hasFilters ? 'Limpar filtros' : null,
                  onAction: hasFilters ? onClearFilters : null,
                )
              : SingleChildScrollView(
                  key: const Key('invite-directory-vertical-scroll'),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: CoeloAdminResizableTable<PlatformInvite>(
                      key: const Key('invite-table'),
                      items: items,
                      rowKey: (invite) => 'invite-row-${invite.id}',
                      headerHeight: 56,
                      rowHeight: rowHeight,
                      showHorizontalScrollbar: true,
                      onRowPressed: onOpen == null ? null : (invite) => onOpen!(invite.id),
                      pinnedColumn: CoeloAdminTableColumn<PlatformInvite>(
                        id: 'recipient',
                        label: 'Destinatário',
                        initialWidth: 220,
                        minWidth: 180,
                        maxWidth: 280,
                        sortable: true,
                        cellBuilder: (context, invite) => Text(
                          invite.recipientMasked,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      columns: [
                        CoeloAdminTableColumn<PlatformInvite>(
                          id: 'audience',
                          label: 'Público',
                          initialWidth: 160,
                          minWidth: 130,
                          maxWidth: 220,
                          sortable: true,
                          cellBuilder: (context, invite) => Text(
                            invite.audience.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        CoeloAdminTableColumn<PlatformInvite>(
                          id: 'context',
                          label: 'Contexto',
                          initialWidth: 220,
                          minWidth: 180,
                          maxWidth: 280,
                          sortable: true,
                          cellBuilder: (context, invite) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(invite.scope, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                invite.role,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        CoeloAdminTableColumn<PlatformInvite>(
                          id: 'channel',
                          label: 'Canal',
                          initialWidth: 120,
                          minWidth: 100,
                          maxWidth: 150,
                          sortable: true,
                          cellBuilder: (context, invite) => Text(invite.channel.label),
                        ),
                        CoeloAdminTableColumn<PlatformInvite>(
                          id: 'status',
                          label: 'Status',
                          initialWidth: 150,
                          minWidth: 130,
                          maxWidth: 190,
                          sortable: true,
                          cellBuilder: (context, invite) => InviteStatusChip(status: invite.status),
                        ),
                        CoeloAdminTableColumn<PlatformInvite>(
                          id: 'createdAt',
                          label: 'Criado em',
                          initialWidth: 150,
                          minWidth: 130,
                          maxWidth: 190,
                          sortable: true,
                          cellBuilder: (context, invite) =>
                              Text(formatInviteDate(invite.createdAt)),
                        ),
                        CoeloAdminTableColumn<PlatformInvite>(
                          id: 'expiresAt',
                          label: 'Expira em',
                          initialWidth: 150,
                          minWidth: 130,
                          maxWidth: 190,
                          sortable: true,
                          cellBuilder: (context, invite) =>
                              Text(formatInviteDate(invite.expiresAt)),
                        ),
                        CoeloAdminTableColumn<PlatformInvite>(
                          id: 'actions',
                          label: 'Ações',
                          initialWidth: 80,
                          minWidth: 72,
                          maxWidth: 96,
                          cellBuilder: (context, invite) => _InviteRowActions(
                            invite: invite,
                            busy: busyInviteId == invite.id,
                            showDetails: onOpen != null,
                            onSelected: (action) => onAction(invite, action),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

final class _InviteRowActions extends StatelessWidget {
  const _InviteRowActions({
    required this.invite,
    required this.busy,
    required this.showDetails,
    required this.onSelected,
  });

  final PlatformInvite invite;
  final bool busy;
  final bool showDetails;
  final ValueChanged<_InviteRowAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = <CoeloAdminFlyoutItem<_InviteRowAction>>[
      if (showDetails)
        const CoeloAdminFlyoutItem(
          value: _InviteRowAction.details,
          icon: Icons.visibility_outlined,
          label: 'Ver detalhes',
        ),
      if (invite.link != null)
        const CoeloAdminFlyoutItem(
          value: _InviteRowAction.copyLink,
          icon: Icons.content_copy_rounded,
          label: 'Copiar link',
        ),
      if (invite.canResend)
        const CoeloAdminFlyoutItem(
          value: _InviteRowAction.resend,
          icon: Icons.forward_to_inbox_outlined,
          label: 'Reenviar convite',
        ),
      if (invite.canRevoke)
        const CoeloAdminFlyoutItem(
          value: _InviteRowAction.revoke,
          icon: Icons.block_rounded,
          label: 'Revogar convite',
          startsGroup: true,
          tone: CoeloAdminFlyoutTone.negative,
        ),
    ];
    return CoeloAdminFlyout<_InviteRowAction>(
      items: items,
      onSelected: onSelected,
      builder: (context, controller) => IconButton(
        key: Key('invite-actions-${invite.id}'),
        tooltip: busy ? 'Processando convite' : 'Ações do convite',
        style: IconButton.styleFrom(
          foregroundColor: colors.onSurface,
          minimumSize: const Size.square(CoeloSize.touchMin),
        ),
        onPressed: busy ? null : () => controller.isOpen ? controller.close() : controller.open(),
        icon: busy
            ? const SizedBox.square(
                dimension: CoeloSize.iconSm,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.more_horiz_rounded),
      ),
    );
  }
}

CoeloStatePanel _statePanel(
  InviteDirectoryState state, {
  required VoidCallback? onCreate,
  required VoidCallback onClearFilters,
}) => switch (state) {
  InviteDirectoryState.loading => const CoeloStatePanel(
    title: 'Carregando convites',
    message: 'Aguarde enquanto os convites são preparados.',
    icon: Icons.hourglass_top_rounded,
  ),
  InviteDirectoryState.empty => CoeloStatePanel(
    title: 'Nenhum convite',
    message: 'Crie o primeiro convite para iniciar o acompanhamento.',
    icon: Icons.mail_outline_rounded,
    actionLabel: onCreate == null ? null : 'Novo convite',
    onAction: onCreate,
  ),
  InviteDirectoryState.noResults => CoeloStatePanel(
    title: 'Nenhum resultado',
    message: 'Ajuste a busca ou os filtros para localizar convites.',
    icon: Icons.search_off_rounded,
    actionLabel: 'Limpar filtros',
    onAction: onClearFilters,
  ),
  InviteDirectoryState.error => const CoeloStatePanel(
    title: 'Convites indisponíveis',
    message: 'Não foi possível carregar os convites. Tente novamente mais tarde.',
    icon: Icons.error_outline_rounded,
  ),
  InviteDirectoryState.unauthorized => const CoeloStatePanel(
    title: 'Acesso não autorizado',
    message: 'Seu contexto atual não permite consultar convites.',
    icon: Icons.lock_outline_rounded,
  ),
  InviteDirectoryState.content => throw StateError('Conteúdo não é um estado de painel.'),
};

String _periodLabel(_InvitePeriodFilter period) => switch (period) {
  _InvitePeriodFilter.all => 'Qualquer período',
  _InvitePeriodFilter.last7Days => 'Últimos 7 dias',
  _InvitePeriodFilter.last30Days => 'Últimos 30 dias',
  _InvitePeriodFilter.last90Days => 'Últimos 90 dias',
  _InvitePeriodFilter.thisMonth => 'Este mês',
};

DateTime _startOfDay(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime _endOfDay(DateTime value) => DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

String _errorMessage(Object error) =>
    error is StateError ? error.message.toString() : 'Não foi possível concluir a ação.';
