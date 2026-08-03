import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import '../data/fake_invite_repository.dart';

final class InviteDetailPage extends StatefulWidget {
  const InviteDetailPage({required this.repository, required this.inviteId, super.key});
  final FakeInviteRepository repository;
  final String inviteId;
  @override
  State<InviteDetailPage> createState() => _InviteDetailPageState();
}

final class _InviteDetailPageState extends State<InviteDetailPage> {
  bool _copied = false;
  @override
  Widget build(BuildContext context) {
    final i = widget.repository.find(widget.inviteId);
    if (i == null) return const Center(child: Text('Convite não encontrado'));
    return LayoutBuilder(
      builder: (context, c) => Padding(
        padding: EdgeInsets.all(c.maxWidth < 768 ? CoeloSpacing.space4 : CoeloSpacing.space6),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              children: [
                Text('Detalhe do convite', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: CoeloSpacing.space4),
                Text(i.recipientMasked, style: Theme.of(context).textTheme.titleLarge),
                Text('${i.audience.label} · ${i.scope} · ${i.role}'),
                Text('Status: ${i.status.label}'),
                Text('Expira: ${i.expiresAt.toIso8601String()}'),
                const SizedBox(height: CoeloSpacing.space4),
                Wrap(
                  spacing: CoeloSpacing.space2,
                  children: [
                    OutlinedButton.icon(
                      onPressed: i.link == null ? null : () => setState(() => _copied = true),
                      icon: const Icon(Icons.content_copy_rounded),
                      label: const Text('Copiar link'),
                    ),
                    OutlinedButton(
                      onPressed: i.canResend
                          ? () => setState(() => widget.repository.resend(i.id))
                          : null,
                      child: const Text('Reenviar'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: i.canRevoke
                          ? () => setState(() => widget.repository.revoke(i.id))
                          : null,
                      child: const Text('Revogar'),
                    ),
                  ],
                ),
                if (_copied) const Text('Link copiado localmente.'),
                const SizedBox(height: CoeloSpacing.space6),
                Text('Linha do tempo', style: Theme.of(context).textTheme.titleMedium),
                for (final e in i.timeline)
                  ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(e.label),
                    subtitle: Text(e.occurredAt.toIso8601String()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
