import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/platform_user.dart';

enum _InternalUserAction {
  resendInvitation,
  revokeInvitation,
  suspend,
  reactivate,
  revoke,
  createReplacement,
}

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

  bool get _canManage => widget.capability == PlatformUserCapability.owner;

  bool _isProtectedLastOwner(PlatformUserRecord record) {
    if (record.profile.baseRole != PlatformUserRole.owner ||
        record.status != PlatformMembershipStatus.active) {
      return false;
    }
    return widget.repository.records
            .where(
              (candidate) =>
                  candidate.profile.baseRole == PlatformUserRole.owner &&
                  candidate.status == PlatformMembershipStatus.active,
            )
            .length ==
        1;
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return SuperadminShell(
      logout: widget.logout,
      title: 'Visualizar usuário interno',
      subtitle: 'Identidade e acesso exclusivos do Superadmin.',
      currentDestination: 'internal-users',
      onDestinationSelected: widget.onDestinationSelected,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (widget.capability == PlatformUserCapability.unauthorized) {
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
                message: 'O cadastro solicitado não existe nesta demonstração local.',
                icon: Icons.person_off_outlined,
              ),
            );
          }

          final wide = constraints.maxWidth >= CoeloBreakpoints.large.minWidth;
          final inset = wide
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          final protectedOwner = _isProtectedLastOwner(record);
          return ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: ListView(
              padding: EdgeInsets.all(inset),
              children: [
                _toolbar(record, protectedOwner),
                const SizedBox(height: CoeloSpacing.space4),
                _identityHeader(record),
                const SizedBox(height: CoeloSpacing.space4),
                if (!_canManage)
                  _notice(
                    Icons.visibility_outlined,
                    'Visualização somente leitura',
                    'Seu perfil permite consultar este cadastro, mas não executar ações de acesso.',
                  ),
                if (protectedOwner)
                  _notice(
                    Icons.shield_outlined,
                    'Último Owner ativo protegido',
                    'Este acesso não pode ser suspenso, revogado, rebaixado ou limitado enquanto for o último Owner ativo.',
                  ),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _personalColumn(record)),
                      const SizedBox(width: CoeloSpacing.space4),
                      Expanded(child: _accessColumn(record)),
                    ],
                  )
                else ...[
                  _personalColumn(record),
                  _accessColumn(record),
                ],
                _historySection(record),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _toolbar(PlatformUserRecord record, bool protectedOwner) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: CoeloSpacing.space3,
      runSpacing: CoeloSpacing.space2,
      children: [
        OutlinedButton.icon(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Voltar'),
        ),
        if (_canManage)
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              if (record.status != PlatformMembershipStatus.revoked)
                OutlinedButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              _actions(record, protectedOwner),
            ],
          ),
      ],
    );
  }

  Widget _identityHeader(PlatformUserRecord record) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      label: '${record.fullName}, ${record.identity.jobTitle}',
      child: Container(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: Wrap(
          spacing: CoeloSpacing.space4,
          runSpacing: CoeloSpacing.space3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: Text(record.initials.toUpperCase()),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.identity.visibleName, style: Theme.of(context).textTheme.headlineSmall),
                Text(record.fullName, style: Theme.of(context).textTheme.bodyMedium),
                Text(record.identity.jobTitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _personalColumn(PlatformUserRecord record) => Column(
    children: [
      _section('Identidade', [
        _field('Nome completo', record.fullName),
        _field('Nome de exibição', record.identity.visibleName),
        _field('CPF protegido', record.maskedCpf),
        _field('Nascimento', _formatDate(record.identity.birthDate, empty: 'Não informado')),
      ]),
      _section('Contato', [
        _field('E-mail profissional protegido', record.maskedEmail),
        _field('Celular protegido', record.maskedMobile),
        _field('Telefone adicional', maskPlatformUserPhone(record.identity.additionalPhone)),
      ]),
      _section('Informações profissionais', [
        _field('Cargo', record.identity.jobTitle),
        _field('Departamento ou área', _valueOrFallback(record.identity.department)),
        _field('Função interna', _valueOrFallback(record.identity.internalFunction)),
        _field('Observações', _valueOrFallback(record.identity.professionalNotes)),
      ]),
      _section('Endereço', [
        _field('CEP', _valueOrFallback(record.identity.postalCode)),
        _field('Endereço', _address(record.identity)),
        _field('Cidade e estado', _cityState(record.identity)),
        _field('País', _valueOrFallback(record.identity.country)),
      ]),
    ],
  );

  Widget _accessColumn(PlatformUserRecord record) => Column(
    children: [
      _section('Acesso ao Superadmin', [
        _field('Perfil', record.profile.name),
        _field('Alcance', record.scope.label),
        _field('Escopos autorizados', record.scopeLabel),
      ]),
      _section('Permissões derivadas', [
        for (final permission in record.profile.permissions)
          _field(permission, 'Derivada do perfil'),
      ]),
      _section('Estados independentes', [
        _stateRow(
          Icons.badge_outlined,
          'Vínculo interno',
          record.status.label,
          _membershipExplanation(record.status),
        ),
        _stateRow(
          Icons.mark_email_unread_outlined,
          'Convite',
          record.invitationStatus.label,
          _invitationExplanation(record.invitationStatus),
        ),
        _stateRow(
          Icons.key_outlined,
          'Credencial Superadmin',
          record.credentialStatus.label,
          _credentialExplanation(record.credentialStatus),
        ),
      ]),
    ],
  );

  Widget _actions(PlatformUserRecord record, bool protectedOwner) {
    final items = <CoeloAdminFlyoutItem<_InternalUserAction>>[];
    if (record.invitationStatus == PlatformInvitationStatus.pending ||
        record.invitationStatus == PlatformInvitationStatus.expired) {
      items.add(
        const CoeloAdminFlyoutItem(
          value: _InternalUserAction.resendInvitation,
          label: 'Reenviar convite fake',
          icon: Icons.forward_to_inbox_outlined,
        ),
      );
      items.add(
        const CoeloAdminFlyoutItem(
          value: _InternalUserAction.revokeInvitation,
          label: 'Revogar convite pendente',
          icon: Icons.mark_email_unread_outlined,
          startsGroup: true,
          tone: CoeloAdminFlyoutTone.negative,
        ),
      );
    }
    if (record.status == PlatformMembershipStatus.active) {
      items.add(
        CoeloAdminFlyoutItem(
          value: _InternalUserAction.suspend,
          label: 'Suspender acesso',
          icon: Icons.pause_circle_outline,
          startsGroup: items.isNotEmpty,
          tone: CoeloAdminFlyoutTone.negative,
          enabled: !protectedOwner,
        ),
      );
    }
    if (record.status == PlatformMembershipStatus.suspended) {
      items.add(
        const CoeloAdminFlyoutItem(
          value: _InternalUserAction.reactivate,
          label: 'Reativar acesso',
          icon: Icons.play_circle_outline,
        ),
      );
    }
    if (record.status != PlatformMembershipStatus.revoked) {
      items.add(
        CoeloAdminFlyoutItem(
          value: _InternalUserAction.revoke,
          label: 'Revogar usuário interno',
          icon: Icons.block_outlined,
          startsGroup: true,
          tone: CoeloAdminFlyoutTone.negative,
          enabled: !protectedOwner,
        ),
      );
    } else {
      items.add(
        const CoeloAdminFlyoutItem(
          value: _InternalUserAction.createReplacement,
          label: 'Criar novo vínculo',
          icon: Icons.person_add_alt_1_outlined,
        ),
      );
    }
    return CoeloAdminFlyout<_InternalUserAction>(
      items: items,
      onSelected: (action) => _confirmAction(record, action),
      builder: (context, controller) => OutlinedButton.icon(
        key: const Key('platform-user-actions'),
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_horiz_rounded),
        label: const Text('Ações'),
      ),
    );
  }

  Future<void> _confirmAction(PlatformUserRecord record, _InternalUserAction action) async {
    final negative =
        action == _InternalUserAction.revokeInvitation ||
        action == _InternalUserAction.suspend ||
        action == _InternalUserAction.revoke;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        title: _actionLabel(action),
        body: Text(
          '${_actionDescription(action, record.fullName)} Esta operação altera somente os dados fake desta demonstração e não executa Auth, e-mail ou persistência externa.',
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          style: negative
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(negative ? 'Confirmar ação' : 'Confirmar demonstração'),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      await switch (action) {
        _InternalUserAction.resendInvitation => widget.repository.resendInvitation(record.id),
        _InternalUserAction.revokeInvitation => widget.repository.revokeInvitation(record.id),
        _InternalUserAction.suspend => widget.repository.suspend(record.id),
        _InternalUserAction.reactivate => widget.repository.reactivate(record.id),
        _InternalUserAction.revoke => widget.repository.revoke(record.id),
        _InternalUserAction.createReplacement => widget.repository.createReplacementMembership(
          record.id,
        ),
      };
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Demonstração local: ${_actionLabel(action).toLowerCase()} registrada sem operação externa.',
          ),
        ),
      );
    } on PlatformUserRuleException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Widget _notice(IconData icon, String title, String message) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space4),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space4),
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space4),
          ...children,
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: CoeloSpacing.space1),
        Text(value),
      ],
    ),
  );

  Widget _stateRow(IconData icon, String label, String value, String explanation) => Semantics(
    label: '$label: $value. $explanation',
    child: Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: CoeloSize.iconSm),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label · $value', style: Theme.of(context).textTheme.titleSmall),
                Text(explanation),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _historySection(PlatformUserRecord record) => _section('Histórico demonstrativo', [
    if (record.history.isEmpty)
      const Text('Nenhuma mudança registrada nesta demonstração.')
    else
      for (final event in record.history.reversed)
        Padding(
          padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.history_rounded, size: CoeloSize.iconSm),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title),
                    Text(event.detail),
                    Text(_formatDateTime(event.at), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
  ]);
}

String _valueOrFallback(String value) => value.trim().isEmpty ? 'Não informado' : value.trim();

String _address(InternalUserIdentity identity) {
  final parts = [
    identity.street,
    identity.number,
    identity.complement,
    identity.neighborhood,
  ].where((part) => part.trim().isNotEmpty).toList();
  return parts.isEmpty ? 'Não informado' : parts.join(', ');
}

String _cityState(InternalUserIdentity identity) {
  final parts = [identity.city, identity.state].where((part) => part.trim().isNotEmpty).toList();
  return parts.isEmpty ? 'Não informado' : parts.join(' - ');
}

String _formatDate(DateTime? date, {String empty = 'Não revisado'}) {
  if (date == null) return empty;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatDateTime(DateTime date) =>
    '${_formatDate(date)} às ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _membershipExplanation(PlatformMembershipStatus status) => switch (status) {
  PlatformMembershipStatus.invited => 'O vínculo foi criado e aguarda aceite do convite fake.',
  PlatformMembershipStatus.active => 'O vínculo interno está habilitado nesta demonstração.',
  PlatformMembershipStatus.suspended =>
    'O vínculo está temporariamente suspenso e pode ser reativado.',
  PlatformMembershipStatus.revoked =>
    'O vínculo foi encerrado de forma terminal e não pode ser reativado.',
};

String _invitationExplanation(PlatformInvitationStatus status) => switch (status) {
  PlatformInvitationStatus.pending => 'Existe um convite fake pendente para o e-mail profissional.',
  PlatformInvitationStatus.accepted => 'O convite demonstrativo foi aceito.',
  PlatformInvitationStatus.expired => 'O convite fake expirou e pode ser reenviado.',
  PlatformInvitationStatus.revoked => 'O convite fake foi revogado sem envio ou operação externa.',
};

String _credentialExplanation(SuperadminCredentialStatus status) => switch (status) {
  SuperadminCredentialStatus.noAccess => 'Nenhuma credencial real foi criada para este preview.',
  SuperadminCredentialStatus.active =>
    'Estado local representando credencial exclusiva do Superadmin.',
  SuperadminCredentialStatus.blocked => 'Estado local representando uma credencial bloqueada.',
  SuperadminCredentialStatus.recoveryPending =>
    'Estado demonstrativo de recuperação, sem executar Auth.',
};

String _actionLabel(_InternalUserAction action) => switch (action) {
  _InternalUserAction.resendInvitation => 'Reenviar convite fake',
  _InternalUserAction.revokeInvitation => 'Revogar convite pendente',
  _InternalUserAction.suspend => 'Suspender acesso',
  _InternalUserAction.reactivate => 'Reativar acesso',
  _InternalUserAction.revoke => 'Revogar usuário interno',
  _InternalUserAction.createReplacement => 'Criar novo vínculo',
};

String _actionDescription(_InternalUserAction action, String name) => switch (action) {
  _InternalUserAction.resendInvitation => 'Uma nova tentativa fake será registrada para $name.',
  _InternalUserAction.revokeInvitation => 'O convite pendente de $name será revogado localmente.',
  _InternalUserAction.suspend => 'O acesso de $name ficará suspenso e poderá ser reativado.',
  _InternalUserAction.reactivate => 'O vínculo suspenso de $name voltará ao estado ativo.',
  _InternalUserAction.revoke => 'O vínculo de $name será encerrado de forma terminal.',
  _InternalUserAction.createReplacement =>
    'Um novo vínculo e um novo convite fake serão criados para $name, preservando o ciclo anterior.',
};
