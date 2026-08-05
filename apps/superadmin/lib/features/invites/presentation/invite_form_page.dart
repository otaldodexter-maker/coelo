import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../data/fake_invite_repository.dart';
import '../domain/platform_invite.dart';

enum _InviteExpiry { hours48, hours72 }

const _stepLabels = [
  'Público',
  'Contexto',
  'Papel',
  'Destinatário',
  'Canal',
  'Expiração',
  'Revisão',
];

final class InviteFormPage extends StatefulWidget {
  const InviteFormPage({required this.repository, required this.onCancel, this.onSent, super.key});

  final FakeInviteRepository repository;
  final VoidCallback onCancel;
  final ValueChanged<PlatformInvite>? onSent;

  @override
  State<InviteFormPage> createState() => _InviteFormPageState();
}

final class _InviteFormPageState extends State<InviteFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _scope = TextEditingController(text: 'Instituição Aurora');
  final _role = TextEditingController(text: 'Administrador');
  final _recipient = TextEditingController();

  InviteAudience _audience = InviteAudience.institutionAdmin;
  InviteChannel _channel = InviteChannel.email;
  _InviteExpiry _expiry = _InviteExpiry.hours48;
  int _step = 0;
  bool _sending = false;

  @override
  void dispose() {
    _scope.dispose();
    _role.dispose();
    _recipient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final simpleBase = constraints.maxWidth < CoeloBreakpoints.large.minWidth;
      final padding = compact ? CoeloSpacing.space4 : CoeloSpacing.space6;
      return ColoredBox(
        key: const Key('invite-form-page-surface'),
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Novo convite', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: CoeloSpacing.space1),
                  Text(
                    'Defina somente os dados necessários para emitir o convite.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  Expanded(
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _stepNavigation(),
                              const SizedBox(height: CoeloSpacing.space4),
                              Expanded(child: _formSurface(simpleBase: simpleBase)),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _stepNavigation(),
                              const SizedBox(width: CoeloSpacing.space6),
                              Expanded(child: _formSurface(simpleBase: simpleBase)),
                            ],
                          ),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _stepNavigation() => SuperadminFormStepNavigation(
    steps: [
      for (var index = 0; index < _stepLabels.length; index++)
        SuperadminFormStep(
          label: _stepLabels[index],
          status: index == _step
              ? SuperadminFormStepStatus.current
              : index < _step
              ? SuperadminFormStepStatus.complete
              : SuperadminFormStepStatus.incomplete,
          enabled: !_sending && index <= _step,
        ),
    ],
    currentIndex: _step,
    onStepSelected: (index) {
      if (index <= _step) setState(() => _step = index);
    },
  );

  Widget _formSurface({required bool simpleBase}) {
    final colors = Theme.of(context).colorScheme;
    final formContent = Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Form(
        key: _formKey,
        child: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.fast,
          child: KeyedSubtree(key: ValueKey(_step), child: _stepContent()),
        ),
      ),
    );
    final content = simpleBase
        ? formContent
        : DecoratedBox(
            key: const Key('invite-form-desktop-panel'),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: formContent,
          );
    return SingleChildScrollView(
      key: const Key('invite-form-scroll'),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: content),
      ),
    );
  }

  Widget _stepContent() => switch (_step) {
    0 => _section(
      title: 'Público do convite',
      description: 'Escolha o público sustentado pelo domínio atual.',
      child: CoeloAdminSingleSelectField<InviteAudience>(
        key: const Key('invite-audience-field'),
        label: 'Público',
        value: _audience,
        options: InviteAudience.values,
        optionLabel: (value) => value.label,
        prefixIcon: Icons.groups_outlined,
        onChanged: (value) => setState(() => _audience = value),
      ),
    ),
    1 => _section(
      title: 'Contexto ou vínculo',
      description: 'Informe onde o convite será aplicado.',
      child: CoeloFormTextField(
        fieldKey: const Key('invite-scope-field'),
        controller: _scope,
        labelText: 'Contexto ou vínculo',
        prefixIcon: Icons.account_tree_outlined,
        textInputAction: TextInputAction.next,
        validator: (value) => _required(value, 'Informe o contexto ou vínculo.'),
      ),
    ),
    2 => _section(
      title: 'Papel',
      description: 'Use o papel contextual já previsto para este convite.',
      child: CoeloFormTextField(
        fieldKey: const Key('invite-role-field'),
        controller: _role,
        labelText: 'Papel ou finalidade',
        prefixIcon: Icons.badge_outlined,
        textInputAction: TextInputAction.next,
        validator: (value) => _required(value, 'Informe o papel ou finalidade.'),
      ),
    ),
    3 => _section(
      title: 'Destinatário',
      description: 'O contato será mascarado nas superfícies de acompanhamento.',
      child: CoeloFormTextField(
        fieldKey: const Key('invite-recipient-field'),
        controller: _recipient,
        labelText: _recipientLabel,
        prefixIcon: _channel == InviteChannel.mobile
            ? Icons.phone_outlined
            : _channel == InviteChannel.email
            ? Icons.mail_outline_rounded
            : Icons.person_outline_rounded,
        keyboardType: _channel == InviteChannel.mobile
            ? TextInputType.phone
            : _channel == InviteChannel.email
            ? TextInputType.emailAddress
            : TextInputType.text,
        textInputAction: TextInputAction.next,
        autofillHints: _channel == InviteChannel.email
            ? const [AutofillHints.email]
            : _channel == InviteChannel.mobile
            ? const [AutofillHints.telephoneNumber]
            : null,
        validator: (_) => _recipientError,
      ),
    ),
    4 => _section(
      title: 'Canal de envio',
      description: 'Escolha somente um canal disponível no domínio atual.',
      child: CoeloAdminSingleSelectField<InviteChannel>(
        key: const Key('invite-channel-field'),
        label: 'Canal',
        value: _channel,
        options: InviteChannel.values,
        optionLabel: (value) => value.label,
        prefixIcon: Icons.send_outlined,
        onChanged: (value) => setState(() => _channel = value),
      ),
    ),
    5 => _section(
      title: 'Expiração',
      description: 'O preview atual suporta validade de 48 ou 72 horas.',
      child: CoeloAdminSingleSelectField<_InviteExpiry>(
        key: const Key('invite-expiry-field'),
        label: 'Validade',
        value: _expiry,
        options: _InviteExpiry.values,
        optionLabel: _expiryLabel,
        prefixIcon: Icons.schedule_outlined,
        onChanged: (value) => setState(() => _expiry = value),
      ),
    ),
    _ => _review(),
  };

  Widget _section({required String title, required String description, required Widget child}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          child,
        ],
      );

  Widget _review() => _section(
    title: 'Revise o convite',
    description: 'Confira os dados antes do envio fictício.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _reviewRow('Destinatário', maskInviteRecipient(_recipient.text.trim(), _channel)),
        _reviewRow('Público', _audience.label),
        _reviewRow('Contexto', _scope.text.trim()),
        _reviewRow('Papel', _role.text.trim()),
        _reviewRow('Canal', _channel.label),
        _reviewRow('Expiração', _expiryLabel(_expiry)),
      ],
    ),
  );

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
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

  Widget _footer() {
    final primary = _step == _stepLabels.length - 1
        ? FilledButton(
            key: const Key('invite-form-send'),
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox.square(
                    dimension: CoeloSize.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enviar convite'),
          )
        : FilledButton(
            key: const Key('invite-form-continue'),
            onPressed: _sending ? null : _continue,
            child: const Text('Continuar'),
          );
    return SuperadminFormActionFooter(
      surfaceKey: const Key('invite-form-footer-surface'),
      tertiaryAction: TextButton(
        key: const Key('invite-form-cancel'),
        onPressed: _sending ? null : widget.onCancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        if (_step > 0)
          OutlinedButton(
            key: const Key('invite-form-previous'),
            onPressed: _sending ? null : () => setState(() => _step--),
            child: const Text('Anterior'),
          ),
        primary,
      ],
    );
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? true)) return;
    if (_step == 4 && _recipientError != null) {
      setState(() => _step = 3);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
      _showFeedback('Revise o destinatário para o canal selecionado.', error: true);
      return;
    }
    if (_step < _stepLabels.length - 1) setState(() => _step++);
  }

  Future<void> _send() async {
    final recipientError = _recipientError;
    if (recipientError != null) {
      setState(() => _step = 3);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
      _showFeedback(recipientError, error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await Future<void>.delayed(Duration.zero);
      final invite = widget.repository.send(
        InviteDraft(
          audience: _audience,
          scope: _scope.text.trim(),
          role: _role.text.trim(),
          recipient: _recipient.text.trim(),
          channel: _channel,
          expiresAt: _expiry == _InviteExpiry.hours72
              ? DateTime.now().add(const Duration(hours: 72))
              : null,
        ),
      );
      if (mounted) widget.onSent?.call(invite);
    } on Object catch (_) {
      if (mounted) _showFeedback('Não foi possível enviar o convite.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String get _recipientLabel => switch (_channel) {
    InviteChannel.email => 'E-mail do destinatário',
    InviteChannel.mobile => 'Celular do destinatário',
    InviteChannel.link => 'Referência do destinatário',
  };

  String? get _recipientError {
    final value = _recipient.text.trim();
    if (value.isEmpty) return 'Informe o destinatário.';
    return switch (_channel) {
      InviteChannel.email =>
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value) ? null : 'Informe um e-mail válido.',
      InviteChannel.mobile =>
        value.replaceAll(RegExp(r'\D'), '').length >= 10 ? null : 'Informe um celular válido.',
      InviteChannel.link => null,
    };
  }

  void _showFeedback(String message, {required bool error}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? colors.error : null));
  }
}

String? _required(String? value, String message) =>
    value == null || value.trim().isEmpty ? message : null;

String _expiryLabel(_InviteExpiry value) => switch (value) {
  _InviteExpiry.hours48 => '48 horas',
  _InviteExpiry.hours72 => '72 horas',
};
