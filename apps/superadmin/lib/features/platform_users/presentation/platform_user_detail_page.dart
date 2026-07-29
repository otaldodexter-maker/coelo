import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/platform_user.dart';

final class PlatformUserDetailPage extends StatefulWidget {
  const PlatformUserDetailPage({
    required this.repository,
    required this.internalUserId,
    required this.capability,
    required this.logout,
    this.onEdit,
    this.onBack,
    this.onDestinationSelected,
    super.key,
  });

  final PlatformUserRepository repository;
  final String internalUserId;
  final PlatformUserCapability capability;
  final LogoutAction logout;
  final VoidCallback? onEdit;
  final VoidCallback? onBack;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<PlatformUserDetailPage> createState() => _PlatformUserDetailPageState();
}

final class _PlatformUserDetailPageState extends State<PlatformUserDetailPage> {
  PlatformUserRecord? get _record => widget.repository.findById(widget.internalUserId);

  @override
  Widget build(BuildContext context) {
    final record = _record;
    final allowed = widget.capability != PlatformUserCapability.unauthorized;
    return SuperadminShell(
      logout: widget.logout,
      title: 'Visualizar usuário interno',
      subtitle: 'Identidade global e vínculo com a equipe Coelo.',
      currentDestination: 'internal-users',
      onDestinationSelected: widget.onDestinationSelected,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          if (!allowed) {
            return const Padding(
              padding: EdgeInsets.all(CoeloSpacing.space6),
              child: CoeloStatePanel(
                title: 'Acesso não autorizado',
                message: 'Você não pode visualizar usuários internos.',
                icon: Icons.lock_outline,
              ),
            );
          }
          if (record == null) {
            return const Padding(
              padding: EdgeInsets.all(CoeloSpacing.space6),
              child: CoeloStatePanel(
                title: 'Usuário interno não encontrado',
                message: 'O vínculo solicitado não existe neste preview.',
                icon: Icons.person_off_outlined,
              ),
            );
          }
          return ListView(
            padding: EdgeInsets.all(inset),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: CoeloSpacing.space3,
                runSpacing: CoeloSpacing.space2,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Voltar'),
                  ),
                  if (widget.capability == PlatformUserCapability.owner)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Editar'),
                        ),
                        const SizedBox(width: CoeloSpacing.space2),
                        _actions(record),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _section('Identidade', [
                _field('Nome', record.fullName),
                _field('E-mail', record.maskedEmail),
              ]),
              _section('Vínculo interno', [
                _field('Papel', record.role.label),
                _field('Escopo', record.scopeLabel),
              ]),
              _section('Papel e permissões', [
                for (final permission in record.role.permissions)
                  _field(permission, 'Permitido pelo papel'),
                _field('Overrides', 'Não editáveis neste preview'),
              ]),
              _section('Convite e status', [
                _field('Status do vínculo', record.status.label),
                _field('Convite', record.invitationStatus.label),
                _field('Última revisão', _formatDate(record.lastReviewedAt)),
              ]),
            ],
          );
        },
      ),
    );
  }

  Widget _actions(PlatformUserRecord record) {
    final actions = switch (record.status) {
      PlatformMembershipStatus.invited => const ['Reenviar convite', 'Revogar convite'],
      PlatformMembershipStatus.active => const ['Suspender acesso'],
      PlatformMembershipStatus.suspended || PlatformMembershipStatus.revoked => const <String>[],
    };
    if (actions.isEmpty) return const SizedBox.shrink();
    return MenuAnchor(
      menuChildren: [
        for (final action in actions)
          MenuItemButton(
            onPressed: () => _confirmAction(record, action),
            leadingIcon: Icon(
              action == 'Reenviar convite' ? Icons.forward_to_inbox_outlined : Icons.block_outlined,
            ),
            child: Text(action),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton.icon(
        key: const Key('platform-user-actions'),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz),
        label: const Text('Ações'),
      ),
    );
  }

  Future<void> _confirmAction(PlatformUserRecord record, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => CoeloAdminDialogShell(
        title: action,
        body: Text(
          'Esta é uma ação local de preview para ${record.fullName}. Nenhuma operação real será executada.',
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirmar preview'),
        ),
      ),
    );
    if (confirmed != true) return;
    final updated = switch (action) {
      'Revogar convite' => record.copyWith(
        status: PlatformMembershipStatus.revoked,
        invitationStatus: PlatformInvitationStatus.revoked,
      ),
      'Suspender acesso' => record.copyWith(status: PlatformMembershipStatus.suspended),
      _ => record,
    };
    await widget.repository.update(updated);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$action registrado somente no preview.')));
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: CoeloSpacing.space4),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(width: CoeloSpacing.space3),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Não revisado';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
