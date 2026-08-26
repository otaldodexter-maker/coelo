import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/platform_invite.dart';
import 'invite_presentation_support.dart';

enum InviteRecipientMode {
  person('Pessoa cadastrada'),
  email('Novo e-mail');

  const InviteRecipientMode(this.label);
  final String label;
}

final class InviteScopeProfileSection extends StatelessWidget {
  const InviteScopeProfileSection({
    required this.options,
    required this.scope,
    required this.profile,
    required this.searchController,
    required this.loading,
    required this.showErrors,
    required this.onSearchChanged,
    required this.onScopeChanged,
    required this.onProfileChanged,
    super.key,
  });

  final InviteFormOptions options;
  final InviteScopeOption? scope;
  final InviteProfileOption? profile;
  final TextEditingController searchController;
  final bool loading;
  final bool showErrors;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<InviteScopeOption?> onScopeChanged;
  final ValueChanged<InviteProfileOption?> onProfileChanged;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Contexto e perfil',
    description: 'Busque somente nos contextos e perfis que você pode administrar.',
    children: [
      CoeloFormTextField(
        fieldKey: const Key('invite-options-search'),
        controller: searchController,
        labelText: 'Buscar contexto ou perfil',
        hintText: 'Instituição, unidade, turma ou perfil',
        prefixIcon: Icons.search_rounded,
        textInputAction: TextInputAction.search,
        onChanged: onSearchChanged,
      ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloAdminSingleSelectField<InviteScopeOption?>(
        key: const Key('invite-scope-field'),
        label: 'Contexto',
        value: scope,
        options: <InviteScopeOption?>[null, ...options.scopes],
        optionLabel: (value) => value?.label ?? 'Selecionar contexto',
        prefixIcon: Icons.account_tree_outlined,
        searchable: true,
        searchHintText: 'Buscar contexto carregado',
        isLoading: loading,
        errorText: showErrors && scope == null ? 'Selecione o contexto.' : null,
        onChanged: onScopeChanged,
      ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloAdminSingleSelectField<InviteProfileOption?>(
        key: const Key('invite-profile-field'),
        label: 'Perfil',
        value: profile,
        options: <InviteProfileOption?>[null, ...options.profiles],
        optionLabel: (value) => value?.label ?? 'Selecionar perfil',
        prefixIcon: Icons.badge_outlined,
        searchable: true,
        searchHintText: 'Buscar perfil carregado',
        isLoading: loading,
        enabled: scope != null,
        errorText: showErrors && scope != null && profile == null ? 'Selecione o perfil.' : null,
        onChanged: onProfileChanged,
      ),
    ],
  );
}

final class InviteRecipientSection extends StatelessWidget {
  const InviteRecipientSection({
    required this.options,
    required this.mode,
    required this.recipient,
    required this.emailController,
    required this.searchController,
    required this.onSearchChanged,
    required this.showErrors,
    required this.loading,
    required this.onModeChanged,
    required this.onRecipientChanged,
    super.key,
  });

  final InviteFormOptions options;
  final InviteRecipientMode mode;
  final InviteRecipientOption? recipient;
  final TextEditingController emailController;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final bool showErrors;
  final bool loading;
  final ValueChanged<InviteRecipientMode> onModeChanged;
  final ValueChanged<InviteRecipientOption?> onRecipientChanged;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Destinatário',
    description:
        'Use uma Pessoa global existente ou informe um novo e-mail. Nunca duplicamos Pessoas.',
    children: [
      CoeloAdminSingleSelectField<InviteRecipientMode>(
        key: const Key('invite-recipient-mode'),
        label: 'Tipo de destinatário',
        value: mode,
        options: InviteRecipientMode.values,
        optionLabel: (value) => value.label,
        prefixIcon: Icons.person_search_outlined,
        onChanged: onModeChanged,
      ),
      const SizedBox(height: CoeloSpacing.space3),
      if (mode == InviteRecipientMode.person) ...[
        CoeloFormTextField(
          fieldKey: const Key('invite-recipient-search'),
          controller: searchController,
          labelText: 'Buscar pessoa',
          hintText: 'Nome ou e-mail no contexto selecionado',
          prefixIcon: Icons.search_rounded,
          textInputAction: TextInputAction.search,
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        CoeloAdminSingleSelectField<InviteRecipientOption?>(
          key: const Key('invite-recipient-field'),
          label: 'Pessoa',
          value: recipient,
          options: <InviteRecipientOption?>[null, ...options.recipients],
          optionLabel: (value) {
            if (value == null) return 'Selecionar pessoa';
            final email = value.maskedEmail;
            return email == null ? value.label : '${value.label} · $email';
          },
          prefixIcon: Icons.person_outline_rounded,
          searchable: true,
          searchHintText: 'Buscar pessoa autorizada',
          isLoading: loading,
          errorText: showErrors && recipient == null ? 'Selecione a pessoa.' : null,
          onChanged: onRecipientChanged,
        ),
      ] else
        CoeloFormTextField(
          fieldKey: const Key('invite-recipient-email'),
          controller: emailController,
          labelText: 'E-mail do destinatário',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: validateInviteEmail,
        ),
    ],
  );
}

final class InviteDeliverySection extends StatelessWidget {
  const InviteDeliverySection({
    required this.channels,
    required this.expiresInHours,
    required this.onChannelsChanged,
    required this.onExpiryChanged,
    required this.showErrors,
    super.key,
  });

  final Set<InviteChannel> channels;
  final int expiresInHours;
  final ValueChanged<Set<InviteChannel>> onChannelsChanged;
  final ValueChanged<int> onExpiryChanged;
  final bool showErrors;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Entrega',
    description: 'Selecione um ou dois canais. Não há envio por SMS.',
    children: [
      CoeloAdminMultiSelectField<InviteChannel>(
        key: const Key('invite-channels-field'),
        label: 'Canais',
        options: InviteChannel.values,
        selectedValues: channels,
        optionLabel: (value) => value.label,
        prefixIcon: Icons.send_outlined,
        emptyLabel: 'Selecionar canais',
        errorText: showErrors && channels.isEmpty ? 'Selecione ao menos um canal.' : null,
        onChanged: onChannelsChanged,
      ),
      const SizedBox(height: CoeloSpacing.space3),
      CoeloAdminSingleSelectField<int>(
        key: const Key('invite-expiry-field'),
        label: 'Validade',
        value: expiresInHours,
        options: const [48, 72],
        optionLabel: (value) => '$value horas',
        prefixIcon: Icons.schedule_outlined,
        onChanged: onExpiryChanged,
      ),
      if (channels.contains(InviteChannel.email)) ...[
        const SizedBox(height: CoeloSpacing.space3),
        Semantics(
          container: true,
          child: Text(
            'O e-mail será colocado na fila real. A tela não informa entrega antes da confirmação do provedor.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    ],
  );
}

final class InviteReviewSection extends StatelessWidget {
  const InviteReviewSection({
    required this.scope,
    required this.profile,
    required this.recipientLabel,
    required this.channels,
    required this.expiresInHours,
    super.key,
  });

  final InviteScopeOption scope;
  final InviteProfileOption profile;
  final String recipientLabel;
  final Set<InviteChannel> channels;
  final int expiresInHours;

  @override
  Widget build(BuildContext context) => _Section(
    title: 'Revisão',
    description: 'Confira a intenção. O banco recalculará escopo, perfil e autorização ao emitir.',
    children: [
      _ReviewRow(label: 'Contexto', value: scope.label),
      _ReviewRow(label: 'Perfil', value: profile.label),
      _ReviewRow(label: 'Destinatário', value: recipientLabel),
      _ReviewRow(label: 'Canais', value: channels.map((value) => value.label).join(' + ')),
      _ReviewRow(label: 'Validade', value: '$expiresInHours horas'),
    ],
  );
}

final class InviteDeliveryResult extends StatelessWidget {
  const InviteDeliveryResult({required this.result, this.onDone, super.key});

  final InviteCommandResult result;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final link = result.invite.channels.contains(InviteChannel.link) ? result.link : null;
    return _Section(
      title: 'Convite emitido',
      description: result.replayed
          ? 'A solicitação já havia sido processada. Por segurança, o link não é reexibido em replay.'
          : 'O convite foi registrado. Guarde o link agora se esse canal foi selecionado.',
      children: [
        InviteStatusChip(status: result.invite.status),
        if (link != null) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Semantics(
            key: const Key('invite-delivery-result'),
            container: true,
            label: 'Link copiável do convite',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(CoeloRadius.md),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SelectableText(link.toString(), key: const Key('invite-result-link')),
                    const SizedBox(height: CoeloSpacing.space2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        key: const Key('invite-result-copy-link'),
                        onPressed: () => Clipboard.setData(ClipboardData(text: link.toString())),
                        icon: const Icon(Icons.content_copy_rounded),
                        label: const Text('Copiar link'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (result.invite.channels.contains(InviteChannel.email)) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Text(switch (result.invite.emailDeliveryStatus) {
            InviteDeliveryStatus.notRequested => 'Entrega por e-mail não solicitada.',
            InviteDeliveryStatus.queued =>
              'E-mail na fila. A entrega ainda depende da confirmação do provedor.',
            InviteDeliveryStatus.sent => 'Entrega por e-mail confirmada pelo provedor.',
            InviteDeliveryStatus.failed =>
              'O e-mail falhou. O convite continua válido para um novo reenvio.',
          }, key: const Key('invite-result-email-state')),
        ],
        if (onDone != null) ...[
          const SizedBox(height: CoeloSpacing.space4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('invite-result-done'),
              onPressed: onDone,
              child: const Text('Fechar resultado'),
            ),
          ),
        ],
      ],
    );
  }
}

final class _Section extends StatelessWidget {
  const _Section({required this.title, required this.description, required this.children});

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey(title),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: CoeloSpacing.space1),
      Text(
        description,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: CoeloSpacing.space5),
      ...children,
    ],
  );
}

final class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

String? validateInviteEmail(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return 'Informe o e-mail.';
  if (normalized.length > 254 || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
    return 'Informe um e-mail válido.';
  }
  return null;
}
