import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/fake_invite_repository.dart';
import '../domain/platform_invite.dart';
import 'invite_presentation_support.dart';

enum _InviteDetailAction { copyLink, resend, revoke }

final class InviteDetailPage extends StatefulWidget {
  const InviteDetailPage({required this.repository, required this.inviteId, super.key});

  final FakeInviteRepository repository;
  final String inviteId;

  @override
  State<InviteDetailPage> createState() => _InviteDetailPageState();
}

final class _InviteDetailPageState extends State<InviteDetailPage> {
  _InviteDetailAction? _busyAction;

  @override
  Widget build(BuildContext context) {
    final invite = widget.repository.find(widget.inviteId);
    final colors = Theme.of(context).colorScheme;
    if (invite == null) {
      return ColoredBox(
        key: const Key('invite-detail-page-surface'),
        color: colors.surface,
        child: const Center(
          child: CoeloStatePanel(
            title: 'Convite não encontrado',
            message: 'O convite solicitado não está disponível neste contexto.',
            icon: Icons.mark_email_unread_outlined,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
        return ColoredBox(
          key: const Key('invite-detail-page-surface'),
          color: colors.surface,
          child: Padding(
            padding: EdgeInsets.all(compact ? CoeloSpacing.space4 : CoeloSpacing.space6),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  key: const Key('invite-detail-scroll'),
                  children: [
                    Text('Detalhe do convite', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(
                      'Informações de leitura e ações disponíveis para o estado atual.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    Wrap(
                      spacing: CoeloSpacing.space3,
                      runSpacing: CoeloSpacing.space2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(invite.recipientMasked, style: Theme.of(context).textTheme.titleLarge),
                        InviteStatusChip(status: invite.status),
                      ],
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    _actions(invite),
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
          ),
        );
      },
    );
  }

  Widget _actions(PlatformInvite invite) {
    final colors = Theme.of(context).colorScheme;
    final busy = _busyAction != null;
    return Wrap(
      key: const Key('invite-detail-actions'),
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        if (invite.link != null)
          OutlinedButton.icon(
            key: const Key('invite-detail-copy'),
            onPressed: busy ? null : () => _copyLink(invite),
            icon: _actionIcon(_InviteDetailAction.copyLink, Icons.content_copy_rounded),
            label: const Text('Copiar link'),
          ),
        if (invite.canResend)
          OutlinedButton.icon(
            key: const Key('invite-detail-resend'),
            onPressed: busy ? null : () => _resend(invite),
            icon: _actionIcon(_InviteDetailAction.resend, Icons.forward_to_inbox_outlined),
            label: const Text('Reenviar convite'),
          ),
        if (invite.canRevoke)
          TextButton.icon(
            key: const Key('invite-detail-revoke'),
            style:
                TextButton.styleFrom(
                  foregroundColor: colors.error,
                  minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) =>
                        states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                        ? colors.errorContainer
                        : Colors.transparent,
                  ),
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
            onPressed: busy ? null : () => _revoke(invite),
            icon: _actionIcon(_InviteDetailAction.revoke, Icons.block_rounded),
            label: const Text('Revogar convite'),
          ),
      ],
    );
  }

  Widget _actionIcon(_InviteDetailAction action, IconData icon) => _busyAction == action
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
          _detailField('Público', invite.audience.label, width),
          _detailField('Canal', invite.channel.label, width),
          _detailField('Contexto', invite.scope, width),
          _detailField('Papel', invite.role, width),
          _detailField('Status', invite.status.label, width),
          _detailField('Criado em', formatInviteDate(invite.createdAt), width),
          _detailField('Expira em', formatInviteDate(invite.expiresAt), width),
        ],
      );
    },
  );

  Widget _detailField(String label, String value, double width) => SizedBox(
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
    if (invite.timeline.isEmpty) {
      return Text(
        'Nenhum evento registrado.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in invite.timeline)
          Padding(
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
                      const SizedBox(height: CoeloSpacing.spaceHalf),
                      Text(
                        formatInviteDate(entry.occurredAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _copyLink(PlatformInvite invite) async {
    final link = invite.link;
    if (link == null) return;
    await _runAction(_InviteDetailAction.copyLink, () async {
      await Clipboard.setData(ClipboardData(text: link));
      return 'Link do convite copiado.';
    });
  }

  Future<void> _resend(PlatformInvite invite) async {
    await _runAction(_InviteDetailAction.resend, () async {
      await Future<void>.delayed(Duration.zero);
      widget.repository.resend(invite.id);
      return 'Convite reenviado com sucesso.';
    });
  }

  Future<void> _revoke(PlatformInvite invite) async {
    final confirmed = await showInviteRevokeConfirmation(
      context,
      recipientMasked: invite.recipientMasked,
    );
    if (!confirmed || !mounted) return;
    await _runAction(_InviteDetailAction.revoke, () async {
      await Future<void>.delayed(Duration.zero);
      widget.repository.revoke(invite.id);
      return 'Convite revogado com sucesso.';
    });
  }

  Future<void> _runAction(_InviteDetailAction action, Future<String> Function() operation) async {
    setState(() => _busyAction = action);
    try {
      final message = await operation();
      if (mounted) _showFeedback(message);
    } on Object catch (error) {
      if (mounted) _showFeedback(_errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  void _showFeedback(String message, {bool error = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? colors.error : null));
  }
}

String _errorMessage(Object error) =>
    error is StateError ? error.message.toString() : 'Não foi possível concluir a ação.';
