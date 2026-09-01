import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/coelo_compact_address_map.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../../institutions/presentation/widgets/institution_logo_picker.dart';
import '../../../shared/presentation/widgets/avatar_crop_dialog.dart';
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
  final _displayName = TextEditingController();
  final _cpf = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _additionalPhone = TextEditingController();
  final _jobTitle = TextEditingController();
  final _department = TextEditingController();
  final _internalFunction = TextEditingController();
  final _notes = TextEditingController();
  final _postalCode = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _complement = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController(text: 'Brasil');
  final _firstFocus = FocusNode();
  int _step = 0;
  late PlatformAccessProfile _profile;
  PlatformUserScope _scope = PlatformUserScope.limited;
  Set<String> _scopeIds = {};
  List<int>? _avatarBytes;
  DateTime? _birthDateValue;
  bool _saving = false;
  bool _dirty = false;
  double _footerHeight = 0;

  bool get _editing => widget.internalUserId != null;
  PlatformUserRecord? get _record =>
      widget.internalUserId == null ? null : widget.repository.findById(widget.internalUserId!);

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.profiles.firstWhere((item) => item.id == 'operations');
    final record = _record;
    if (record != null) {
      _firstName.text = record.firstName;
      _lastName.text = record.lastName;
      _displayName.text = record.identity.displayName;
      _birthDateValue = record.identity.birthDate;
      _cpf.text = _formatCpfInput(record.identity.cpf);
      _email.text = record.email;
      _mobile.text = record.identity.mobile;
      _additionalPhone.text = record.identity.additionalPhone;
      _jobTitle.text = record.identity.jobTitle;
      _department.text = record.identity.department;
      _internalFunction.text = record.identity.internalFunction;
      _notes.text = record.identity.professionalNotes;
      _postalCode.text = record.identity.postalCode;
      _street.text = record.identity.street;
      _number.text = record.identity.number;
      _complement.text = record.identity.complement;
      _neighborhood.text = record.identity.neighborhood;
      _city.text = record.identity.city;
      _state.text = record.identity.state;
      _country.text = record.identity.country;
      _avatarBytes = record.identity.avatarBytes;
      _profile = record.profile;
      _scope = record.scope;
      _scopeIds = record.membership.scopeIds.toSet();
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _displayName.dispose();
    _cpf.dispose();
    _email.dispose();
    _mobile.dispose();
    _additionalPhone.dispose();
    _jobTitle.dispose();
    _department.dispose();
    _internalFunction.dispose();
    _notes.dispose();
    _postalCode.dispose();
    _street.dispose();
    _number.dispose();
    _complement.dispose();
    _neighborhood.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _firstFocus.dispose();
    super.dispose();
  }

  void _changed([Object? _]) {
    setState(() => _dirty = true);
  }

  bool _validateIdentity() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) _firstFocus.requestFocus();
    return valid;
  }

  bool get _addressStarted => [
    _postalCode,
    _street,
    _number,
    _complement,
    _neighborhood,
    _city,
    _state,
  ].any((controller) => controller.text.trim().isNotEmpty);

  String? _validateAddressPart(String? value, String label) {
    if (!_addressStarted) return null;
    if (value == null || value.trim().isEmpty) return 'Informe $label.';
    return null;
  }

  void _continue() {
    if ((_step == 0 || _step == 1) && !_validateIdentity()) {
      return;
    }
    if (_step == 2 && _scope == PlatformUserScope.limited && _scopeIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione ao menos um escopo permitido.')));
      return;
    }
    setState(() => _step++);
  }

  PlatformUserDraft _draft() => PlatformUserDraft(
    identity: InternalUserIdentity(
      id: _record?.id ?? '',
      firstName: _firstName.text,
      lastName: _lastName.text,
      displayName: _displayName.text,
      birthDate: _birthDateValue,
      cpf: _cpf.text,
      professionalEmail: _email.text,
      mobile: _mobile.text,
      additionalPhone: _additionalPhone.text,
      jobTitle: _jobTitle.text,
      department: _department.text,
      internalFunction: _internalFunction.text,
      professionalNotes: _notes.text,
      postalCode: _postalCode.text,
      street: _street.text,
      number: _number.text,
      complement: _complement.text,
      neighborhood: _neighborhood.text,
      city: _city.text,
      state: _state.text,
      country: _country.text,
      avatarBytes: _avatarBytes,
    ),
    profile: _profile,
    scope: _scope,
    scopeIds: _scopeIds.toList(),
    scopeNames: _scopeIds.map((id) => widget.institutions[id]!).toList(),
  );

  Future<void> _save() async {
    if (widget.capability != PlatformUserCapability.owner || !_validateIdentity()) return;
    setState(() => _saving = true);
    try {
      if (_editing) {
        final updated = await widget.repository.update(widget.internalUserId!, _draft());
        if (mounted) {
          widget.onUpdated?.call(updated);
        }
      } else {
        final result = await widget.repository.create(_draft());
        if (mounted) {
          widget.onCreated?.call(result);
        }
      }
      _dirty = false;
    } on PlatformUserConflictException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on PlatformUserRuleException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
              ? 'Atualize a identidade e o acesso exclusivos do Superadmin.'
              : 'Crie um acesso interno exclusivo ao Superadmin.',
          currentDestination: 'internal-users',
          chatLauncherBottomInset: _footerHeight,
          onDestinationSelected: widget.onDestinationSelected,
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Form(
              key: _formKey,
              child: SuperadminFormFrame(
                viewportWidth: MediaQuery.sizeOf(context).width,
                scrollKey: const Key('platform-user-form-scroll'),
                navigation: _navigation(),
                body: KeyedSubtree(key: ValueKey(_step), child: _flowStep()),
                footer: _footer(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navigation() => SuperadminFormStepNavigation(
    steps: _steps(),
    currentIndex: _step,
    onStepSelected: (index) {
      if (index <= _step) setState(() => _step = index);
    },
  );

  List<SuperadminFormStep> _steps() {
    const labels = [
      'Identidade',
      'Contato, trabalho e endereço',
      'Acesso ao Superadmin',
      'Revisão e convite',
    ];
    return [
      for (var index = 0; index < labels.length; index++)
        SuperadminFormStep(
          label: labels[index],
          status: index == _step
              ? SuperadminFormStepStatus.current
              : index < _step
              ? SuperadminFormStepStatus.complete
              : SuperadminFormStepStatus.incomplete,
          enabled: index <= _step,
        ),
    ];
  }

  Widget _flowStep() => switch (_step) {
    0 => _identitySection(),
    1 => _contactSection(),
    2 => _accessSection(),
    _ => _reviewSection(),
  };

  Widget _identitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Identidade interna', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space3),
        Container(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined),
              SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Text(
                  'Você está criando um acesso interno exclusivo ao Superadmin. '
                  'Este cadastro não cria Admin, Principal, @ ou Pessoa e não compartilha credenciais.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: CoeloSpacing.space4,
          runSpacing: CoeloSpacing.space3,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: _avatarBytes == null
                  ? null
                  : MemoryImage(Uint8List.fromList(_avatarBytes!)),
              child: _avatarBytes == null ? const Icon(Icons.person_outline, size: 32) : null,
            ),
            OutlinedButton.icon(
              key: const Key('platform-user-avatar-action'),
              onPressed: _pickAvatar,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(_avatarBytes == null ? 'Adicionar foto' : 'Trocar foto'),
            ),
          ],
        ),
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
        _responsiveFields([
          _field(
            _displayName,
            'Nome de exibição (opcional)',
            Icons.badge_outlined,
            key: const Key('platform-user-display-name'),
          ),
          CoeloDateRangeField(
            key: const Key('platform-user-birth-date'),
            value: _birthDateValue == null
                ? null
                : DateTimeRange(start: _birthDateValue!, end: _birthDateValue!),
            onChanged: (value) {
              setState(() => _birthDateValue = value?.start);
              _changed();
            },
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            currentDate: DateTime.now(),
            showQuickRanges: false,
            selectionMode: CoeloDateSelectionMode.single,
            labelText: 'Data de nascimento (opcional)',
          ),
        ]),
        const SizedBox(height: CoeloSpacing.space4),
        _responsiveFields([
          _field(
            _cpf,
            'CPF',
            Icons.fingerprint,
            key: const Key('platform-user-cpf'),
            keyboardType: TextInputType.number,
            inputFormatters: const [_CpfInputFormatter()],
            validator: (value) =>
                value == null || !isValidPlatformUserCpf(value) ? 'Informe um CPF válido.' : null,
          ),
        ]),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    final file = await pickInstitutionLogo();
    if (file == null || !mounted) return;
    final adjusted = await showDialog<AvatarCropResult>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()?.scrim ?? Colors.black54,
      builder: (context) => AvatarCropDialog(bytes: file.bytes),
    );
    if (adjusted == null || !mounted) return;
    setState(() => _avatarBytes = adjusted.bytes);
    _changed();
  }

  Widget _contactSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Contato e informações profissionais', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space4),
      _responsiveFields([
        _field(
          _email,
          'E-mail profissional',
          Icons.mail_outline,
          key: const Key('platform-user-email'),
          enabled: !_editing || _record!.credentialStatus != SuperadminCredentialStatus.active,
          keyboardType: TextInputType.emailAddress,
          validator: (value) =>
              value == null || !value.contains('@') ? 'Informe um e-mail válido.' : null,
        ),
        _field(_mobile, 'Celular', Icons.phone_android_outlined, keyboardType: TextInputType.phone),
      ]),
      const SizedBox(height: CoeloSpacing.space4),
      Builder(
        builder: (context) {
          final coordinates = coeloApproximateAddressCoordinates(
            city: _city.text,
            state: _state.text,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Referência aproximada do município',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: CoeloSpacing.space2),
              CoeloCompactAddressMap(
                latitude: coordinates?.latitude ?? double.nan,
                longitude: coordinates?.longitude ?? double.nan,
              ),
            ],
          );
        },
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _responsiveFields([
        _field(
          _additionalPhone,
          'Telefone adicional',
          Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        _field(
          _jobTitle,
          'Cargo',
          Icons.work_outline,
          key: const Key('platform-user-job-title'),
          validator: (value) => value == null || value.trim().isEmpty ? 'Informe o cargo.' : null,
        ),
      ]),
      const SizedBox(height: CoeloSpacing.space4),
      _responsiveFields([
        _field(_department, 'Departamento ou área', Icons.apartment_outlined),
        _field(_internalFunction, 'Função interna', Icons.assignment_ind_outlined),
      ]),
      const SizedBox(height: CoeloSpacing.space4),
      _field(_notes, 'Observações profissionais', Icons.notes_outlined, maxLines: 3),
      const SizedBox(height: CoeloSpacing.space6),
      Text('Endereço', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space4),
      _responsiveFields([
        _field(
          _postalCode,
          'CEP',
          Icons.location_on_outlined,
          keyboardType: TextInputType.number,
          validator: (value) => _validateAddressPart(value, 'o CEP'),
        ),
        _field(
          _street,
          'Logradouro',
          Icons.signpost_outlined,
          validator: (value) => _validateAddressPart(value, 'o logradouro'),
        ),
      ]),
      const SizedBox(height: CoeloSpacing.space4),
      _responsiveFields([
        _field(
          _number,
          'Número',
          Icons.numbers_outlined,
          validator: (value) => _validateAddressPart(value, 'o número'),
        ),
        _field(_complement, 'Complemento', Icons.home_work_outlined),
      ]),
      const SizedBox(height: CoeloSpacing.space4),
      _responsiveFields([
        _field(
          _neighborhood,
          'Bairro',
          Icons.location_city_outlined,
          validator: (value) => _validateAddressPart(value, 'o bairro'),
        ),
        _field(
          _city,
          'Cidade',
          Icons.location_city_outlined,
          validator: (value) => _validateAddressPart(value, 'a cidade'),
        ),
      ]),
      const SizedBox(height: CoeloSpacing.space4),
      _responsiveFields([
        _field(
          _state,
          'Estado',
          Icons.map_outlined,
          validator: (value) => _validateAddressPart(value, 'o estado'),
        ),
        _field(
          _country,
          'País',
          Icons.public_outlined,
          validator: (value) => _validateAddressPart(value, 'o país'),
        ),
      ]),
    ],
  );

  Widget _accessSection() {
    final institutionIds = widget.institutions.keys.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Acesso ao Superadmin', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: CoeloSpacing.space2),
        const Text('Permissões são derivadas do perfil e não podem ser ampliadas neste cadastro.'),
        const SizedBox(height: CoeloSpacing.space4),
        _responsiveFields([
          CoeloAdminSingleSelectField<PlatformAccessProfile>(
            label: 'Perfil Superadmin',
            value: _profile,
            options: widget.repository.profiles,
            optionLabel: (value) => value.name,
            onChanged: (value) {
              setState(() {
                _profile = value;
                if (!value.allowsGlobal && _scope == PlatformUserScope.platform) {
                  _scope = PlatformUserScope.limited;
                }
              });
              _changed();
            },
            prefixIcon: Icons.admin_panel_settings_outlined,
          ),
          CoeloAdminSingleSelectField<PlatformUserScope>(
            label: 'Alcance',
            value: _scope,
            options: PlatformUserScope.values,
            optionLabel: (value) => value.label,
            onChanged: (value) {
              if (value == PlatformUserScope.platform && !_profile.allowsGlobal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('O perfil ${_profile.name} não autoriza acesso global.')),
                );
                return;
              }
              setState(() {
                _scope = value;
                if (value == PlatformUserScope.platform) _scopeIds = {};
              });
              _changed();
            },
            prefixIcon: Icons.layers_outlined,
          ),
        ]),
        if (!_profile.allowsGlobal) ...[
          const SizedBox(height: CoeloSpacing.space2),
          Text('Acesso global indisponível: o perfil ${_profile.name} exige escopo limitado.'),
        ],
        if (_scope == PlatformUserScope.limited) ...[
          const SizedBox(height: CoeloSpacing.space4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('platform-user-scopes-select-all'),
              onPressed: () {
                setState(() {
                  _scopeIds = _scopeIds.length == institutionIds.length
                      ? <String>{}
                      : institutionIds.toSet();
                  _dirty = true;
                });
              },
              icon: Icon(
                _scopeIds.length == institutionIds.length
                    ? Icons.deselect_outlined
                    : Icons.select_all_outlined,
              ),
              label: Text(
                _scopeIds.length == institutionIds.length ? 'Limpar seleção' : 'Selecionar todas',
              ),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          CoeloAdminMultiSelectField<String>(
            key: const Key('platform-user-scopes'),
            label: 'Instituições permitidas',
            options: institutionIds,
            selectedValues: _scopeIds,
            optionLabel: (id) => widget.institutions[id]!,
            onChanged: (values) {
              setState(() => _scopeIds = values);
              _changed();
            },
            searchable: true,
          ),
        ],
        const SizedBox(height: CoeloSpacing.space6),
        Text('Permissões derivadas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space2),
        for (final permission in _profile.permissions)
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 20),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(child: Text(permission)),
              ],
            ),
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
        _summary('Identidade', '${_firstName.text.trim()} ${_lastName.text.trim()}'),
        _summary('CPF', maskPlatformUserCpf(_cpf.text)),
        _summary('E-mail', maskPlatformUserEmail(_email.text.trim())),
        _summary('Cargo', _jobTitle.text.trim()),
        _summary('Perfil', _profile.name),
        _summary('Alcance', _scope.label),
        if (_scopeIds.isNotEmpty)
          _summary('Escopos', _scopeIds.map((id) => widget.institutions[id]!).join(', ')),
        _summary('Vínculo', (_record?.status ?? PlatformMembershipStatus.invited).label),
        _summary('Convite', (_record?.invitationStatus ?? PlatformInvitationStatus.pending).label),
        _summary(
          'Credencial',
          (_record?.credentialStatus ?? SuperadminCredentialStatus.noAccess).label,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(CoeloSpacing.space4),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined),
                SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Text('Confira o e-mail profissional antes de confirmar o convite.'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    Key? key,
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) => CoeloFormTextField(
    fieldKey: key,
    controller: controller,
    labelText: label,
    prefixIcon: icon,
    enabled: enabled,
    keyboardType: keyboardType,
    maxLines: maxLines,
    inputFormatters: inputFormatters,
    onChanged: _changed,
    validator: validator,
  );

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
          onPressed: _saving ? null : (_step == 3 ? _save : _continue),
          child: Text(
            _saving
                ? 'Salvando…'
                : _step < 3
                ? 'Continuar'
                : _editing
                ? 'Salvar alterações'
                : 'Criar e preparar convite',
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

final class _CpfInputFormatter extends TextInputFormatter {
  const _CpfInputFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = normalizePlatformUserDigits(newValue.text);
    final formatted = _formatCpfInput(digits.length > 11 ? digits.substring(0, 11) : digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatCpfInput(String value) {
  final digits = normalizePlatformUserDigits(value);
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length && index < 11; index++) {
    if (index == 3 || index == 6) buffer.write('.');
    if (index == 9) buffer.write('-');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
