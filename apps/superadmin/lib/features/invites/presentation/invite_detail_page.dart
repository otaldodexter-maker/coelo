import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/platform_invite.dart';
import 'invite_form_sections.dart';
import 'invite_presentation_support.dart';
import 'invite_request_id.dart';

enum _DetailState { loading, ready, notFound, failure, unauthorized }

enum _DetailAction { resend, revoke }

final class InviteDetailPage extends StatefulWidget {
  const InviteDetailPage({
    required this.repository,
    required this.inviteId,
    this.allowCommands = false,
    this.logout = unavailableSuperadminLogout,
    this.onDestinationSelected,
    super.key,
  });

  final InviteRepository repository;
  final String inviteId;
  final bool allowCommands;
  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<InviteDetailPage> createState() => _InviteDetailPageState();
}

final class _InviteDetailPageState extends State<InviteDetailPage> {
  _DetailState _state = _DetailState.loading;
  PlatformInvite? _invite;
  _DetailAction? _busy;
  InviteCommandResult? _result;
  var _requestEpoch = 0;
  String? _resendRequestId;
  String? _revokeRequestId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant InviteDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inviteId != widget.inviteId ||
        !identical(oldWidget.repository, widget.repository)) {
      setState(() {
        _invite = null;
        _result = null;
        _busy = null;
        _resendRequestId = null;
        _revokeRequestId = null;
      });
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final epoch = ++_requestEpoch;
    final inviteId = widget.inviteId;
    if (mounted) setState(() => _state = _DetailState.loading);
    try {
      final invite = await widget.repository.fetchById(inviteId);
      if (!mounted || epoch != _requestEpoch || inviteId != widget.inviteId) return;
      setState(() {
        _invite = invite;
        _state = invite == null ? _DetailState.notFound : _DetailState.ready;
      });
    } on InviteUnauthorizedException {
      if (mounted && epoch == _requestEpoch) {
        setState(() => _state = _DetailState.unauthorized);
      }
    } on Object {
      if (mounted && epoch == _requestEpoch) {
        setState(() => _state = _DetailState.failure);
      }
    }
  }

  Future<void> _resend(PlatformInvite invite) async {
    final inviteId = widget.inviteId;
    final requestId = _resendRequestId ??= newInviteRequestId();
    setState(() => _busy = _DetailAction.resend);
    try {
      final result = await widget.repository.resend(
        InviteResendCommand(
          inviteId: invite.id,
          requestId: requestId,
          expectedVersion: invite.managementVersion,
        ),
      );
      if (mounted && inviteId == widget.inviteId && _resendRequestId == requestId) {
        setState(() {
          _invite = result.invite;
          _result = result;
          _resendRequestId = null;
          _busy = null;
        });
      }
    } on InviteConflictException {
      if (mounted && inviteId == widget.inviteId && _resendRequestId == requestId) {
        setState(() {
          _resendRequestId = null;
          _busy = null;
        });
        _feedback('O convite mudou. Atualize e tente novamente.', error: true);
        await _load();
      }
    } on Object {
      if (mounted && inviteId == widget.inviteId && _resendRequestId == requestId) {
        _feedback('Não foi possível reenviar o convite.', error: true);
      }
    } finally {
      if (mounted && inviteId == widget.inviteId && _resendRequestId == requestId) {
        setState(() => _busy = null);
      }
    }
  }

  Future<void> _revoke(PlatformInvite invite) async {
    final inviteId = widget.inviteId;
    final confirmed = await showInviteRevokeConfirmation(
      context,
      recipientMasked: invite.recipientMasked,
    );
    if (!confirmed || !mounted || inviteId != widget.inviteId) return;
    final requestId = _revokeRequestId ??= newInviteRequestId();
    setState(() => _busy = _DetailAction.revoke);
    try {
      final result = await widget.repository.revoke(
        InviteRevokeCommand(
          inviteId: invite.id,
          requestId: requestId,
          expectedVersion: invite.managementVersion,
          reason: 'Revogação administrativa confirmada',
        ),
      );
      if (mounted && inviteId == widget.inviteId && _revokeRequestId == requestId) {
        setState(() {
          _invite = result.invite;
          _result = null;
          _revokeRequestId = null;
          _busy = null;
        });
      }
    } on InviteConflictException {
      if (mounted && inviteId == widget.inviteId && _revokeRequestId == requestId) {
        setState(() {
          _revokeRequestId = null;
          _busy = null;
        });
        _feedback('O convite mudou. Atualize e tente novamente.', error: true);
        await _load();
      }
    } on Object {
      if (mounted && inviteId == widget.inviteId && _revokeRequestId == requestId) {
        _feedback('Não foi possível revogar o convite.', error: true);
      }
    } finally {
      if (mounted && inviteId == widget.inviteId && _revokeRequestId == requestId) {
        setState(() => _busy = null);
      }
    }
  }

  void _feedback(String message, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? colors.error : null));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = ColoredBox(
      key: const Key('invite-detail-page-surface'),
      color: colors.surface,
      child: switch (_state) {
        _DetailState.loading => const Center(
          child: CoeloStatePanel(
            title: 'Carregando convite',
            message: 'Buscando dados autorizados.',
            icon: Icons.hourglass_top_rounded,
          ),
        ),
        _DetailState.notFound => const Center(
          child: CoeloStatePanel(
            title: 'Convite não encontrado',
            message: 'O convite não está disponível neste contexto.',
            icon: Icons.mark_email_unread_outlined,
          ),
        ),
        _DetailState.unauthorized => const Center(
          child: CoeloStatePanel(
            title: 'Acesso não autorizado',
            message: 'Seu contexto atual não permite consultar este convite.',
            icon: Icons.lock_outline_rounded,
          ),
        ),
        _DetailState.failure => Center(
          child: CoeloStatePanel(
            title: 'Convite indisponível',
            message: 'Não foi possível carregar o convite.',
            icon: Icons.error_outline_rounded,
            actionLabel: 'Tentar novamente',
            onAction: _load,
          ),
        ),
        _DetailState.ready => _content(_invite!),
      },
    );
    return SuperadminShell(
      logout: widget.logout,
      title: 'Convite',
      subtitle: 'Acompanhe status, entrega e ações auditadas.',
      currentDestination: 'invites',
      onDestinationSelected: widget.onDestinationSelected,
      child: content,
    );
  }

  Widget _content(PlatformInvite invite) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final inset = compact ? CoeloSpacing.space4 : CoeloSpacing.space6;
      return ListView(
        key: const Key('invite-detail-scroll'),
        padding: EdgeInsets.all(inset),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Detalhe do convite', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: CoeloSpacing.space1),
                  Text(invite.recipientMasked, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: CoeloSpacing.space3),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InviteStatusChip(status: invite.status),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _actions(invite),
                  if (_result case final result?) ...[
                    const SizedBox(height: CoeloSpacing.space5),
                    InviteDeliveryResult(
                      result: result,
                      onDone: () => setState(() => _result = null),
                    ),
                  ],
                  const SizedBox(height: CoeloSpacing.space6),
                  Text('Dados do convite', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: CoeloSpacing.space3),
                  _details(invite),
                  const SizedBox(height: CoeloSpacing.space6),
                  Text('Linha do tempo', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: CoeloSpacing.space3),
                  _timeline(invite),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _actions(PlatformInvite invite) {
    final busy = _busy != null;
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        if (widget.allowCommands && invite.canResend)
          if (invite.status == InviteStatus.expired)
            FilledButton.icon(
              key: const Key('invite-detail-resend'),
              onPressed: busy ? null : () => _resend(invite),
              icon: _actionIcon(_DetailAction.resend, Icons.forward_to_inbox_outlined),
              label: const Text('Reenviar convite'),
            )
          else
            OutlinedButton.icon(
              key: const Key('invite-detail-resend'),
              onPressed: busy ? null : () => _resend(invite),
              icon: _actionIcon(_DetailAction.resend, Icons.forward_to_inbox_outlined),
              label: const Text('Reenviar convite'),
            ),
        if (widget.allowCommands && invite.canRevoke)
          TextButton.icon(
            key: const Key('invite-detail-revoke'),
            style: TextButton.styleFrom(
              foregroundColor: colors.error,
              minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
            ),
            onPressed: busy ? null : () => _revoke(invite),
            icon: _actionIcon(_DetailAction.revoke, Icons.block_rounded),
            label: const Text('Revogar convite'),
          ),
      ],
    );
  }

  Widget _actionIcon(_DetailAction action, IconData icon) => _busy == action
      ? const SizedBox.square(
          dimension: CoeloSize.iconSm,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon);

  Widget _details(PlatformInvite invite) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth ? 2 : 1;
      final width = columns == 1
          ? constraints.maxWidth
          : (constraints.maxWidth - CoeloSpacing.space4) / 2;
      return Wrap(
        spacing: CoeloSpacing.space4,
        runSpacing: CoeloSpacing.space4,
        children: [
          _field('Contexto', invite.scope.label, width),
          _field('Perfil', invite.profile.label, width),
          _field('Canais', invite.channels.map((value) => value.label).join(' + '), width),
          _field('Emissor', invite.issuer.label, width),
          _field('Criado em', formatInviteDate(invite.createdAt), width),
          _field('Expira em', formatInviteDate(invite.expiresAt), width),
        ],
      );
    },
  );

  Widget _field(String label, String value, double width) => SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: CoeloSpacing.space1),
        Text(value),
      ],
    ),
  );

  Widget _timeline(PlatformInvite invite) {
    if (invite.timeline.isEmpty) return const Text('Nenhum evento registrado.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in invite.timeline)
          Semantics(
            container: true,
            label: '${entry.label}, ${formatInviteDate(entry.occurredAt)}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: CoeloSize.touchMin,
                    height: CoeloSize.touchMin,
                    child: Icon(Icons.history_rounded),
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.label, style: Theme.of(context).textTheme.titleSmall),
                        Text(formatInviteDate(entry.occurredAt)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
