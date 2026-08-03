import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/platform_user.dart';

final class PlatformUserFormPage extends StatefulWidget {
  const PlatformUserFormPage({
    required this.repository,
    required this.capability,
    required this.logout,
    this.internalUserId,
    this.institutions = const {
      'institution-1': 'Instituição 1',
      'institution-2': 'Instituição 2',
      'institution-3': 'Instituição 3',
    },
    this.onCreated,
    this.onUpdated,
    this.onCancel,
    this.onDestinationSelected,
    super.key,
  });

  final PlatformUserRepository repository;
  final PlatformUserCapability capability;
  final LogoutAction logout;
  final String? internalUserId;
  final Map<String, String> institutions;
  final ValueChanged<PlatformUserCreateResult>? onCreated;
  final ValueChanged<PlatformUserRecord>? onUpdated;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<PlatformUserFormPage> createState() => _PlatformUserFormPageState();
}

final class _PlatformUserFormPageState extends State<PlatformUserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _firstFocus = FocusNode();
  int _step = 0;
  PlatformUserRole _role = PlatformUserRole.operations;
  PlatformUserScope _scope = PlatformUserScope.platform;
  String? _institutionId;
  bool _saving = false;
  bool _dirty = false;
  double _footerHeight = 0;

  bool get _editing => widget.internalUserId != null;
  PlatformUserRecord? get _record =>
      widget.internalUserId == null ? null : widget.repository.findById(widget.internalUserId!);

  @override
  void initState() {
    super.initState();
    final record = _record;
    if (record != null) {
      _firstName.text = record.firstName;
      _lastName.text = record.lastName;
      _email.text = record.maskedEmail;
      _role = record.role;
      _scope = record.scope;
      _institutionId = record.institutionId;
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _firstFocus.dispose();
    super.dispose();
  }

  void _changed([Object? _]) {
    if (!_dirty) setState(() => _dirty = true);
  }

  bool _validateIdentity() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) _firstFocus.requestFocus();
    return valid;
  }

  void _continue() {
    if (_step == 0 && !_validateIdentity()) return;
    if (_step == 3 && _scope == PlatformUserScope.institution && _institutionId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione a instituição do escopo.')));
      return;
    }
    setState(() => _step++);
  }

  Future<void> _save() async {
    if (widget.capability != PlatformUserCapability.owner || !_validateIdentity()) return;
    setState(() => _saving = true);
    try {
      if (_editing) {
        final record = _record!;
        final updated = record.copyWith(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          role: _role,
          scope: _scope,
          institutionId: _institutionId,
          institutionName: _institutionId == null ? null : widget.institutions[_institutionId],
        );
        await widget.repository.update(updated);
        if (mounted) widget.onUpdated?.call(updated);
      } else {
        final result = await widget.repository.create(
          PlatformUserDraft(
            firstName: _firstName.text,
            lastName: _lastName.text,
            email: _email.text,
            role: _role,
            scope: _scope,
            institutionId: _institutionId,
            institutionName: _institutionId == null ? null : widget.institutions[_institutionId],
          ),
        );
        if (mounted) widget.onCreated?.call(result);
      }
      _dirty = false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Editar usuário interno' : 'Criar usuário interno';
    if (widget.capability != PlatformUserCapability.owner || (_editing && _record == null)) {
      return SuperadminShell(
        logout: widget.logout,
        title: title,
        subtitle: 'Preview da equipe Coelo.',
        currentDestination: 'internal-users',
        onDestinationSelected: widget.onDestinationSelected,
        child: const Padding(
          padding: EdgeInsets.all(CoeloSpacing.space6),
          child: CoeloStatePanel(
            title: 'Acesso não autorizado',
            message: 'Você não pode alterar usuários internos.',
            icon: Icons.lock_outline,
          ),
        ),
      );
    }
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _CancelIntent()},
      child: Actions(
        actions: {
          _CancelIntent: CallbackAction<_CancelIntent>(
            onInvoke: (_) {
              _cancel();
              return null;
            },
          ),
        },
        child: SuperadminShell(
          logout: widget.logout,
          title: title,
          subtitle: _editing
              ? 'Separe identidade global, vínculo e acesso.'
              : 'Cadastre um vínculo interno somente no preview.',
          currentDestination: 'internal-users',
          chatLauncherBottomInset: _footerHeight,
          onDestinationSelected: widget.onDestinationSelected,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                  ? CoeloSpacing.space10
                  : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                  ? CoeloSpacing.space6
                  : CoeloSpacing.space4;
              return Form(
                key: _formKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ListView(
                      key: const Key('platform-user-form-scroll'),
                      padding: EdgeInsets.fromLTRB(
                        inset,
                        inset,
                        inset,
                        inset + _footerHeight + CoeloSpacing.space4,
                      ),
                      children: [
                        _stepHeader(),
                        const SizedBox(height: CoeloSpacing.space6),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(CoeloSpacing.space6),
                            child: _flowStep(),
                          ),
                        ),
                      ],
                    ),
                    Positioned(left: inset, right: inset, bottom: inset, child: _footer()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stepHeader() {
    const labels = ['Identidade', 'Membership de plataforma', 'Papel', 'Escopo', 'Revisão'];
    return Semantics(
      label: 'Etapa ${_step + 1} de 5: ${labels[_step]}',
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++) ...[
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    backgroundColor: index <= _step
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: index <= _step
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    child: Text('${index + 1}'),
                  ),
                  const SizedBox(height: CoeloSpacing.space1),
                  Text(labels[index], textAlign: TextAlign.center),
                ],
              ),
            ),
            if (index < labels.length - 1) const SizedBox(width: CoeloSpacing.space2),
          ],
        ],
      ),
    );
  }

  Widget _flowStep() => switch (_step) {
    0 => _identitySection(title: 'Identidade'),
    1 => _membershipSection(),
    2 => _roleSection(),
    3 => _scopeSection(),
    _ => _reviewSection(),
  };

  Widget _membershipSection() {
    final status = _record?.status ?? PlatformMembershipStatus.invited;
    final invitation = _record?.invitationStatus ?? PlatformInvitationStatus.pending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Membership de plataforma', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space4),
        _summary('Status', status.label),
        _summary('Convite', invitation.label),
        const SizedBox(height: CoeloSpacing.space2),
        const Text(
          'Este vínculo interno é local ao preview. Status e convite não são editáveis aqui.',
        ),
      ],
    );
  }

  Widget _roleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Papel', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<PlatformUserRole>(
          label: 'Papel',
          value: _role,
          options: PlatformUserRole.values,
          optionLabel: (value) => value.label,
          onChanged: (value) {
            setState(() => _role = value);
            _changed();
          },
          prefixIcon: Icons.admin_panel_settings_outlined,
        ),
        const SizedBox(height: CoeloSpacing.space6),
        Text('Permissões derivadas do papel', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        Text(_role.permissions.join(' · ')),
        const SizedBox(height: CoeloSpacing.space1),
        const Text('Overrides não são editáveis neste preview.'),
      ],
    );
  }

  Widget _scopeSection() {
    final institutionIds = widget.institutions.keys.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Escopo', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<PlatformUserScope>(
          label: 'Escopo',
          value: _scope,
          options: PlatformUserScope.values,
          optionLabel: (value) => value.label,
          onChanged: (value) {
            setState(() {
              _scope = value;
              if (value == PlatformUserScope.platform) _institutionId = null;
            });
            _changed();
          },
          prefixIcon: Icons.layers_outlined,
        ),
        if (_scope == PlatformUserScope.institution) ...[
          const SizedBox(height: CoeloSpacing.space4),
          CoeloAdminSingleSelectField<String?>(
            key: const Key('platform-user-institution'),
            label: 'Instituição',
            value: _institutionId,
            options: [null, ...institutionIds],
            optionLabel: (value) => value == null ? 'Selecione' : widget.institutions[value]!,
            onChanged: (value) {
              setState(() => _institutionId = value);
              _changed();
            },
            prefixIcon: Icons.account_balance_outlined,
          ),
        ],
      ],
    );
  }

  Widget _identitySection({required String title}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space4),
        _responsiveFields([
          CoeloFormTextField(
            fieldKey: const Key('platform-user-first-name'),
            controller: _firstName,
            focusNode: _firstFocus,
            labelText: 'Nome',
            prefixIcon: Icons.person_outline,
            onChanged: _changed,
            validator: (value) => value == null || value.trim().isEmpty ? 'Informe o nome.' : null,
          ),
          CoeloFormTextField(
            fieldKey: const Key('platform-user-last-name'),
            controller: _lastName,
            labelText: 'Sobrenome',
            prefixIcon: Icons.person_outline,
            onChanged: _changed,
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Informe o sobrenome.' : null,
          ),
        ]),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          fieldKey: const Key('platform-user-email'),
          controller: _email,
          labelText: 'E-mail',
          prefixIcon: Icons.mail_outline,
          enabled: !_editing,
          keyboardType: TextInputType.emailAddress,
          onChanged: _changed,
          validator: (value) =>
              value == null || !value.contains('@') ? 'Informe um e-mail válido.' : null,
        ),
      ],
    );
  }

  Widget _reviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Revisão', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space4),
        _summary('Pessoa', '${_firstName.text.trim()} ${_lastName.text.trim()}'),
        _summary('E-mail', maskPlatformUserEmail(_email.text.trim())),
        _summary('Papel', _role.label),
        _summary(
          'Escopo',
          _institutionId == null ? _scope.label : widget.institutions[_institutionId]!,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(CoeloSpacing.space4),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined),
                SizedBox(width: CoeloSpacing.space3),
                Expanded(child: Text('Nenhum convite real será enviado.')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Flexible(child: Text(value)),
      ],
    ),
  );

  Widget _responsiveFields(List<Widget> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
          return Column(
            children: [
              for (var i = 0; i < fields.length; i++) ...[
                fields[i],
                if (i < fields.length - 1) const SizedBox(height: CoeloSpacing.space4),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              Expanded(child: fields[i]),
              if (i < fields.length - 1) const SizedBox(width: CoeloSpacing.space4),
            ],
          ],
        );
      },
    );
  }

  Widget _footer() {
    return SuperadminFormActionFooter(
      surfaceKey: const Key('platform-user-form-footer-surface'),
      onHeightChanged: (height) {
        if ((_footerHeight - height).abs() < .5) return;
        setState(() => _footerHeight = height);
      },
      tertiaryAction: TextButton(
        onPressed: _saving ? null : _cancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        if (_step > 0)
          OutlinedButton(
            onPressed: _saving ? null : () => setState(() => _step--),
            child: const Text('Voltar'),
          ),
        FilledButton(
          onPressed: _saving ? null : (_step == 4 ? _save : _continue),
          child: Text(
            _saving
                ? 'Salvando…'
                : _step < 4
                ? 'Continuar'
                : _editing
                ? 'Salvar alterações'
                : 'Salvar preview',
          ),
        ),
      ],
    );
  }

  Future<void> _cancel() async {
    if (!_dirty) {
      widget.onCancel?.call();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => CoeloAdminDialogShell(
        title: 'Descartar alterações?',
        body: const Text('O rascunho local será descartado.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Continuar editando'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Descartar'),
        ),
      ),
    );
    if (discard == true) widget.onCancel?.call();
  }
}

final class _CancelIntent extends Intent {
  const _CancelIntent();
}
