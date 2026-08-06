import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../institutions/data/fake_institution_directory_repository.dart';
import '../../institutions/domain/institution_record.dart';
import '../../support/domain/support_ticket.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../domain/group_directory.dart';

enum GroupFormSaveResult { created, updated }

enum _GroupFormStep { hierarchy, identity, links, people, professionals, invites }

extension on _GroupFormStep {
  String get label => switch (this) {
    _GroupFormStep.hierarchy => 'Hierarquia',
    _GroupFormStep.identity => 'Identidade',
    _GroupFormStep.links => 'Vínculos e aparência',
    _GroupFormStep.people => 'Pessoas da turma',
    _GroupFormStep.professionals => 'Profissionais e admins',
    _GroupFormStep.invites => 'Convites',
  };
}

enum _GroupRoleType { aluno, responsavel, profissional, coordinator }

final class _GroupRoleLabel {
  const _GroupRoleLabel._();

  static String label(_GroupRoleType value) => switch (value) {
    _GroupRoleType.aluno => 'Aluno',
    _GroupRoleType.responsavel => 'Responsável',
    _GroupRoleType.profissional => 'Profissional',
    _GroupRoleType.coordinator => 'Administrador',
  };

  static IconData icon(_GroupRoleType value) => switch (value) {
    _GroupRoleType.aluno => Icons.child_care_rounded,
    _GroupRoleType.responsavel => Icons.family_restroom_rounded,
    _GroupRoleType.profissional => Icons.school_rounded,
    _GroupRoleType.coordinator => Icons.admin_panel_settings_rounded,
  };
}

final class _GroupActivityBinding {
  const _GroupActivityBinding({required this.id, required this.name, required this.mandatory});

  final String id;
  final String name;
  final bool mandatory;
}

final class _GroupPersonBinding {
  const _GroupPersonBinding({
    required this.id,
    required this.name,
    required this.identifier,
    required this.role,
    this.note,
  });

  final String id;
  final String name;
  final String identifier;
  final _GroupRoleType role;
  final String? note;

  _GroupPersonBinding copyWith({
    String? id,
    String? name,
    String? identifier,
    _GroupRoleType? role,
    String? note,
  }) => _GroupPersonBinding(
    id: id ?? this.id,
    name: name ?? this.name,
    identifier: identifier ?? this.identifier,
    role: role ?? this.role,
    note: note ?? this.note,
  );
}

final class _GroupInviteBinding {
  const _GroupInviteBinding({
    required this.id,
    required this.identifier,
    required this.role,
    required this.profile,
    required this.status,
  });

  final String id;
  final String identifier;
  final _GroupRoleType role;
  final String profile;
  final String status;
}

final class GroupFormPage extends StatefulWidget {
  const GroupFormPage({
    required this.institutions,
    required this.repository,
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.groupId,
    this.initialInstitutionId,
    this.initialUnitId,
    this.onDestinationSelected,
    this.onBugReportSubmitted,
    super.key,
  });

  final FakeInstitutionDirectoryRepository institutions;
  final GroupDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<GroupFormSaveResult> onSaved;
  final String? groupId;
  final String? initialInstitutionId;
  final String? initialUnitId;
  final ValueChanged<String>? onDestinationSelected;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;

  @override
  State<GroupFormPage> createState() => _GroupFormPageState();
}

final class _GroupFormPageState extends State<GroupFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _handleController;
  late final TextEditingController _primaryColorController;
  late final TextEditingController _secondaryColorController;
  late final TextEditingController _surfaceColorController;
  late InstitutionRecord _institution;
  late InstitutionUnit _unit;
  late GroupStatus _status;
  late final String _identitySeed;
  GroupRecord? _original;
  bool _dirty = false;
  bool _saving = false;
  String? _saveError;
  _GroupFormStep _currentStep = _GroupFormStep.hierarchy;
  final Set<_GroupFormStep> _completedSteps = {};
  final Set<_GroupFormStep> _errorSteps = {};
  final Set<String> _selectedActivities = {'Matemática', 'Leitura'};
  final Set<String> _mandatoryActivities = {'Matemática'};
  final List<_GroupActivityBinding> _activityByStudentLinks = const [];
  final List<_GroupPersonBinding> _people = [];
  final List<_GroupPersonBinding> _professionals = [];
  final List<_GroupInviteBinding> _invites = [];

  bool get _editing => widget.groupId != null;

  static const _activityCatalog = [
    'Matemática',
    'Leitura',
    'Português',
    'Artes',
    'Horta',
    'Música',
    'Movimento',
  ];

  static const _profileCatalog = [
    'Observador',
    'Intermediário',
    'Admin local',
    'Coordenador pedagógico',
    'Diretor',
  ];

  @override
  void initState() {
    super.initState();
    _original = widget.groupId == null ? null : widget.repository.findById(widget.groupId!);
    final record = _original;
    _identitySeed = widget.groupId == null
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : widget.groupId!;
    _institution = record == null
        ? widget.institutions.findById(widget.initialInstitutionId ?? '') ??
              widget.institutions.records.first
        : widget.institutions.findById(record.institutionId)!;
    _unit = record == null
        ? _institution.units.firstWhere(
            (unit) => unit.id == widget.initialUnitId,
            orElse: () => _institution.units.first,
          )
        : _institution.units.firstWhere((unit) => unit.id == record.unitId);
    _status = record?.status ?? GroupStatus.active;
    _nameController = TextEditingController(text: record?.name ?? '');
    _typeController = TextEditingController(text: record?.groupType ?? 'class');
    _handleController = TextEditingController(
      text: record == null ? '' : '@${record.name.toLowerCase().replaceAll(' ', '.')}',
    );
    _primaryColorController = TextEditingController(text: '#D63C00');
    _secondaryColorController = TextEditingController(text: '#3F4549');
    _surfaceColorController = TextEditingController(text: '#FFFFFF');
    _seedLocalLists();
  }

  void _seedLocalLists() {
    if (_original == null) {
      _people.add(
        _GroupPersonBinding(
          id: 'person-$_identitySeed-a',
          name: 'Escola & Família',
          identifier: 'familia@coelo.me',
          role: _GroupRoleType.responsavel,
        ),
      );
      _professionals.add(
        _GroupPersonBinding(
          id: 'prof-$_identitySeed-a',
          name: 'Coordenação Pedagógica',
          identifier: 'coordenador@coelo.me',
          role: _GroupRoleType.coordinator,
          note: 'Libera/publica/solicita transição',
        ),
      );
      return;
    }
    if (_original == null) return;
    _people.addAll(const [
      _GroupPersonBinding(
        id: 'person-existing-1',
        name: 'Responsável de turma',
        identifier: 'responsavel@coelo.me',
        role: _GroupRoleType.responsavel,
      ),
      _GroupPersonBinding(
        id: 'person-existing-2',
        name: 'Ana de Souza',
        identifier: '11999990000',
        role: _GroupRoleType.aluno,
      ),
    ]);
    _professionals.add(
      _GroupPersonBinding(
        id: 'prof-existing-1',
        name: 'Equipe pedagógica',
        identifier: '@equipe-${_identitySeed.substring(0, 4)}',
        role: _GroupRoleType.coordinator,
        note: 'Admin da turma por padrão',
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _handleController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _surfaceColorController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        dialogKey: const Key('group-exit-dialog'),
        title: 'Sair sem salvar?',
        body: const Text('As alterações feitas nesta turma serão perdidas se você sair agora.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Continuar editando'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sair sem salvar'),
        ),
      ),
    );
    return discard ?? false;
  }

  Future<void> _cancel() async {
    if (await _confirmExit()) widget.onCancel();
  }

  Future<void> _selectDestination(String destination) async {
    if (await _confirmExit()) widget.onDestinationSelected?.call(destination);
  }

  bool get _identityValid =>
      _nameController.text.trim().isNotEmpty && _typeController.text.trim().isNotEmpty;

  SuperadminFormStepStatus _stepStatus(_GroupFormStep step) {
    if (_errorSteps.contains(step)) return SuperadminFormStepStatus.error;
    if (step == _currentStep) return SuperadminFormStepStatus.current;
    if (_completedSteps.contains(step)) return SuperadminFormStepStatus.complete;
    return SuperadminFormStepStatus.incomplete;
  }

  Widget _navigation() => SuperadminFormStepNavigation(
    steps: [
      for (final step in _GroupFormStep.values)
        SuperadminFormStep(label: step.label, status: _stepStatus(step)),
    ],
    currentIndex: _currentStep.index,
    onStepSelected: (index) => _selectStep(_GroupFormStep.values[index]),
  );

  bool _validateCurrentStep() {
    final valid =
        _currentStep != _GroupFormStep.identity ||
        (_formKey.currentState?.validate() ?? _identityValid);
    setState(() {
      if (valid) {
        _errorSteps.remove(_currentStep);
      } else {
        _errorSteps.add(_currentStep);
      }
    });
    return valid;
  }

  void _selectStep(_GroupFormStep step) {
    if (step == _currentStep) return;
    if (step.index > _currentStep.index && !_validateCurrentStep()) return;
    setState(() {
      _completedSteps.add(_currentStep);
      _currentStep = step;
    });
  }

  void _continue() {
    if (!_validateCurrentStep()) return;
    final next = _currentStep.index + 1;
    if (next >= _GroupFormStep.values.length) return;
    setState(() {
      _completedSteps.add(_currentStep);
      _currentStep = _GroupFormStep.values[next];
    });
  }

  void _previous() {
    if (_currentStep.index == 0) return;
    setState(() => _currentStep = _GroupFormStep.values[_currentStep.index - 1]);
  }

  Future<void> _save() async {
    setState(() => _saveError = null);
    if (!_identityValid) {
      setState(() {
        _errorSteps.add(_GroupFormStep.identity);
        _currentStep = _GroupFormStep.identity;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _formKey.currentState?.validate());
      return;
    }
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final original = _original;
      final record = original == null
          ? GroupRecord(
              id: widget.repository.createId(
                _institution.id,
                _unit.id,
                _nameController.text.trim(),
              ),
              institutionId: _institution.id,
              institutionName: _institution.publicName,
              unitId: _unit.id,
              unitName: _unit.name,
              name: _nameController.text.trim(),
              groupType: _typeController.text.trim(),
              status: _status,
              createdAt: now,
              updatedAt: now,
            )
          : original.copyWith(
              name: _nameController.text.trim(),
              groupType: _typeController.text.trim(),
              status: _status,
              updatedAt: now,
            );
      await widget.repository.upsert(record);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
      });
      widget.onSaved(original == null ? GroupFormSaveResult.created : GroupFormSaveResult.updated);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Não foi possível salvar a turma. Revise os dados e tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _editing ? 'Editar turma' : 'Criar turma';
    return SuperadminShell(
      logout: widget.logout,
      title: title,
      subtitle: _editing
          ? 'Atualize os dados da turma selecionada.'
          : 'Adicione uma nova turma ao Coelo.',
      currentDestination: 'groups',
      showChatLauncher: false,
      onDestinationSelected: _selectDestination,
      onBugReportSubmitted: widget.onBugReportSubmitted,
      child: _editing && _original == null
          ? CoeloStatePanel(
              key: const Key('group-form-not-found'),
              title: 'Turma não encontrada',
              message: 'O registro solicitado não existe nesta sessão local.',
              icon: Icons.search_off_rounded,
              actionLabel: 'Voltar às turmas',
              onAction: widget.onCancel,
            )
          : PopScope(
              canPop: !_dirty,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _cancel();
              },
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final desktop = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
                    final padding = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                        ? CoeloSpacing.space10
                        : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                        ? CoeloSpacing.space6
                        : CoeloSpacing.space4;
                    final navigation = _navigation();
                    return Padding(
                      key: const Key('group-form-golden-root'),
                      padding: EdgeInsets.fromLTRB(padding, padding, padding, CoeloSpacing.space4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (desktop) ...[navigation, const SizedBox(width: CoeloSpacing.space6)],
                          Expanded(
                            child: Column(
                              children: [
                                if (!desktop) ...[
                                  navigation,
                                  const SizedBox(height: CoeloSpacing.space4),
                                ],
                                Expanded(
                                  child: SingleChildScrollView(
                                    key: const Key('group-form-scroll'),
                                    padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 880),
                                        child: _formSurface(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: CoeloSpacing.space4),
                                _footer(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _formSurface() {
    final content = switch (_currentStep) {
      _GroupFormStep.hierarchy => _formSection(
        key: const Key('group-hierarchy-section'),
        title: 'Hierarquia',
        description: 'Instituição → Unidade → Turma.',
        child: _fieldGrid(_hierarchyFields()),
      ),
      _GroupFormStep.identity => _formSection(
        key: const Key('group-identity-section'),
        title: 'Identidade',
        description: 'Nome, tipo e status da turma.',
        child: _fieldGrid(_identityFields()),
      ),
      _GroupFormStep.links => _formSection(
        key: const Key('group-links-section'),
        title: 'Vínculos e aparência',
        description:
            'Atividades, rótulos de comunicação e identidade visual local: preview demonstrativo sem persistência adicional.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _fieldGrid(_prototypeFields()),
            const SizedBox(height: CoeloSpacing.space5),
            _activitySection(),
          ],
        ),
      ),
      _GroupFormStep.people => _formSection(
        key: const Key('group-people-section'),
        title: 'Pessoas da turma',
        description:
            'Cadastro local de pessoas, perfis e vínculos com tabela de inclusão, edição e exclusão.',
        child: _peopleSection(
          entries: _people,
          sectionTitle: 'Pessoas associadas',
          onAdd: () => _editPerson(),
          onEdit: (index) => _editPerson(index: index),
          onRemove: (index) {
            setState(() {
              _people.removeAt(index);
              _markDirty();
            });
          },
        ),
      ),
      _GroupFormStep.professionals => _formSection(
        key: const Key('group-professionals-section'),
        title: 'Profissionais e admins',
        description:
            'Acesso operacional da turma por função (padrão demonstrativo local). Defina permissões explícitas.',
        child: _peopleSection(
          entries: _professionals,
          sectionTitle: 'Gestão de acesso',
          onAdd: () => _editProfessional(),
          onEdit: (index) => _editProfessional(index: index),
          onRemove: (index) {
            setState(() {
              _professionals.removeAt(index);
              _markDirty();
            });
          },
          allowProfile: true,
        ),
      ),
      _GroupFormStep.invites => _formSection(
        key: const Key('group-invites-section'),
        title: 'Convites',
        description:
            'Convites demonstrativos para quem ainda não está vinculado, com busca por @, CPF, e-mail e celular.',
        child: _invitesSection(),
      ),
    };
    if (_saveError == null) return content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: MaterialBanner(
            content: Text(_saveError!),
            actions: [
              TextButton(
                onPressed: () => setState(() => _saveError = null),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        content,
      ],
    );
  }

  List<Widget> _hierarchyFields() {
    final locked = _editing;
    return [
      IgnorePointer(
        ignoring: locked,
        child: Opacity(
          opacity: locked ? .65 : 1,
          child: CoeloAdminSingleSelectField<InstitutionRecord>(
            key: const Key('group-institution-field'),
            label: 'Instituição',
            value: _institution,
            options: widget.institutions.records,
            optionLabel: (value) => value.publicName,
            enabled: !locked,
            prefixIcon: Icons.account_balance_outlined,
            onChanged: (value) => setState(() {
              _institution = value;
              _unit = value.units.first;
              _markDirty();
            }),
          ),
        ),
      ),
      IgnorePointer(
        ignoring: locked,
        child: Opacity(
          opacity: locked ? .65 : 1,
          child: CoeloAdminSingleSelectField<InstitutionUnit>(
            key: const Key('group-unit-field'),
            label: 'Unidade',
            value: _unit,
            options: _institution.units,
            optionLabel: (value) => value.name,
            enabled: !locked,
            prefixIcon: Icons.apartment_outlined,
            onChanged: (value) => setState(() {
              _unit = value;
              _markDirty();
            }),
          ),
        ),
      ),
    ];
  }

  List<Widget> _identityFields() => [
    CoeloFormTextField(
      fieldKey: const Key('group-name-field'),
      controller: _nameController,
      labelText: 'Nome da turma',
      prefixIcon: Icons.groups_rounded,
      textInputAction: TextInputAction.next,
      validator: _required('Informe o nome da turma.'),
      onChanged: (_) => _markDirty(),
    ),
    CoeloFormTextField(
      fieldKey: const Key('group-type-field'),
      controller: _typeController,
      labelText: 'Tipo da turma',
      hintText: 'Ex.: class',
      prefixIcon: Icons.category_outlined,
      textInputAction: TextInputAction.next,
      validator: _required('Informe o tipo da turma.'),
      onChanged: (_) => _markDirty(),
    ),
    CoeloAdminSingleSelectField<GroupStatus>(
      key: const Key('group-status-field'),
      label: 'Status',
      value: _status,
      options: GroupStatus.values,
      optionLabel: (value) => value.label,
      prefixIcon: Icons.toggle_on_outlined,
      onChanged: (value) => setState(() {
        _status = value;
        _dirty = true;
      }),
    ),
  ];

  List<Widget> _prototypeFields() => [
    CoeloFormTextField(
      fieldKey: const Key('group-handle-field'),
      controller: _handleController,
      labelText: 'Arroba da turma',
      hintText: '@turma',
      prefixIcon: Icons.alternate_email_rounded,
      onChanged: (_) => _markDirty(),
    ),
    CoeloFormTextField(
      fieldKey: const Key('group-primary-color-field'),
      controller: _primaryColorController,
      labelText: 'Cor principal',
      prefixIcon: Icons.palette_outlined,
      onChanged: (_) => _markDirty(),
    ),
    CoeloFormTextField(
      fieldKey: const Key('group-secondary-color-field'),
      controller: _secondaryColorController,
      labelText: 'Cor de apoio',
      prefixIcon: Icons.color_lens_outlined,
      onChanged: (_) => _markDirty(),
    ),
    CoeloFormTextField(
      fieldKey: const Key('group-surface-color-field'),
      controller: _surfaceColorController,
      labelText: 'Cor de superfície',
      prefixIcon: Icons.layers_outlined,
      onChanged: (_) => _markDirty(),
    ),
  ];

  Widget _activitySection() {
    final accent = _parseColor(_primaryColorController.text);
    final secondary = _parseColor(_secondaryColorController.text);
    final surface = _parseColor(_surfaceColorController.text, fallback: Colors.white);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Atividades da turma', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: CoeloSpacing.space2),
        Container(
          key: const Key('group-activity-links'),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: CoeloSpacing.space2,
                runSpacing: CoeloSpacing.space2,
                children: [
                  for (final activity in _activityCatalog)
                    FilterChip(
                      key: Key('group-activity-$activity'),
                      selected: _selectedActivities.contains(activity),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedActivities.add(activity);
                        } else {
                          _selectedActivities.remove(activity);
                        }
                        _markDirty();
                      }),
                      label: Text(activity),
                      color: WidgetStateProperty.resolveWith((states) {
                        final colors = Theme.of(context).colorScheme;
                        if (states.contains(WidgetState.selected)) {
                          return colors.primaryContainer;
                        }
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)) {
                          return colors.primary.withValues(alpha: 0.08);
                        }
                        return colors.surface;
                      }),
                      checkmarkColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              Text(
                'Atividades obrigatórias nesta turma',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Wrap(
                spacing: CoeloSpacing.space2,
                runSpacing: CoeloSpacing.space2,
                children: [
                  for (final activity
                      in _activityByStudentLinks.isNotEmpty
                          ? _activityByStudentLinks.map((item) => item.name).toSet()
                          : _selectedActivities)
                    _activityPill(
                      label: activity,
                      required: _mandatoryActivities.contains(activity),
                      onToggleRequired: (value) => setState(() {
                        if (value) {
                          _mandatoryActivities.add(activity);
                        } else {
                          _mandatoryActivities.remove(activity);
                        }
                        _markDirty();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space5),
              _identityPreview(accent, secondary, surface),
            ],
          ),
        ),
      ],
    );
  }

  Widget _activityPill({
    required String label,
    required bool required,
    required ValueChanged<bool> onToggleRequired,
  }) {
    return ActionChip(
      avatar: Icon(
        required ? Icons.star_rounded : Icons.star_border_rounded,
        size: 14,
        color: required ? Colors.white : Theme.of(context).colorScheme.onSurface,
      ),
      label: Text(
        required ? '$label (obrigatória)' : label,
        style: TextStyle(
          color: required ? Colors.white : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      color: WidgetStateProperty.resolveWith((states) {
        final colors = Theme.of(context).colorScheme;
        if (required) {
          return colors.primary;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          return colors.primary.withValues(alpha: 0.08);
        }
        return colors.surface;
      }),
      onPressed: () => onToggleRequired(!required),
    );
  }

  Widget _identityPreview(Color accent, Color secondary, Color surface) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Row(
          children: [
            Container(
              width: CoeloSize.touchMin * 2.5,
              height: CoeloSize.touchMin * 2.5,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(CoeloRadius.full),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.groups_rounded, color: secondary),
            ),
            const SizedBox(width: CoeloSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameController.text.trim().isEmpty
                        ? 'Nome da turma'
                        : _nameController.text.trim(),
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _handleController.text.trim().isEmpty
                        ? '@turma'
                        : _handleController.text.trim(),
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
    );
  }

  Widget _peopleSection({
    required List<_GroupPersonBinding> entries,
    required String sectionTitle,
    required VoidCallback onAdd,
    required ValueChanged<int> onEdit,
    required ValueChanged<int> onRemove,
    bool allowProfile = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(sectionTitle, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space3),
      _entryTable(entries: entries, allowProfile: allowProfile, onEdit: onEdit, onRemove: onRemove),
      const SizedBox(height: CoeloSpacing.space4),
      Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          FilledButton.icon(
            key: allowProfile ? const Key('group-add-professional') : const Key('group-add-person'),
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_rounded),
            label: Text(allowProfile ? 'Adicionar profissional ou admin' : 'Cadastrar pessoa'),
          ),
          if (!allowProfile)
            OutlinedButton.icon(
              key: const Key('group-search-person'),
              onPressed: () => _searchAndInvitePerson(),
              icon: const Icon(Icons.person_search_rounded),
              label: const Text('Buscar por @, CPF, e-mail ou celular'),
            ),
        ],
      ),
    ],
  );

  Widget _entryTable({
    required List<_GroupPersonBinding> entries,
    required ValueChanged<int> onEdit,
    required ValueChanged<int> onRemove,
    required bool allowProfile,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            color: colors.surfaceContainer,
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space4,
              vertical: CoeloSpacing.space3,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text('Nome', style: Theme.of(context).textTheme.labelLarge),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Identificador', style: Theme.of(context).textTheme.labelLarge),
                ),
                Expanded(child: Text('Papel', style: Theme.of(context).textTheme.labelLarge)),
                if (allowProfile)
                  Expanded(
                    flex: 2,
                    child: Text('Permissões', style: Theme.of(context).textTheme.labelLarge),
                  ),
                const SizedBox(width: CoeloSize.touchMin * 2),
              ],
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  allowProfile
                      ? 'Nenhum profissional ou admin nesta turma.'
                      : 'Nenhuma pessoa associada a esta turma.',
                ),
              ),
            ),
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0) Divider(height: 1, color: colors.outlineVariant),
            Semantics(
              label: '${entries[index].name}, ${entries[index].identifier}',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space4,
                  vertical: CoeloSpacing.space3,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(entries[index].name, style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: CoeloSpacing.space1),
                          Text(
                            entries[index].identifier,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _GroupRoleLabel.label(entries[index].role),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (allowProfile && entries[index].note != null)
                            Text(
                              entries[index].note!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: CoeloSpacing.space2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                onPressed: () => onEdit(index),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Remover',
                                onPressed: () => onRemove(index),
                                style: IconButton.styleFrom(foregroundColor: colors.error),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Icon(_GroupRoleLabel.icon(entries[index].role)),
                              const SizedBox(width: CoeloSpacing.space2),
                              Expanded(child: Text(entries[index].name)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            entries[index].identifier,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(_GroupRoleLabel.label(entries[index].role), maxLines: 2),
                        ),
                        if (allowProfile)
                          Expanded(
                            flex: 2,
                            child: Text(entries[index].note ?? 'Sem configuração', maxLines: 2),
                          ),
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: () => onEdit(index),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Remover',
                          onPressed: () => onRemove(index),
                          style: IconButton.styleFrom(foregroundColor: colors.error),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _invitesSection() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Convites da turma', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space3),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
              return Column(
                children: [
                  if (!compact)
                    Container(
                      color: colors.surfaceContainer,
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoeloSpacing.space4,
                        vertical: CoeloSpacing.space3,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Identificador',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          Expanded(
                            child: Text('Perfil', style: Theme.of(context).textTheme.labelLarge),
                          ),
                          Expanded(
                            child: Text(
                              'Perfil de acesso',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                          Expanded(
                            child: Text('Status', style: Theme.of(context).textTheme.labelLarge),
                          ),
                          const SizedBox(width: CoeloSize.touchMin * 2),
                        ],
                      ),
                    ),
                  if (_invites.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(CoeloSpacing.space4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Nenhum convite pendente para esta turma.'),
                      ),
                    ),
                  for (var index = 0; index < _invites.length; index++) ...[
                    if (index > 0) Divider(height: 1, color: colors.outlineVariant),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoeloSpacing.space4,
                        vertical: CoeloSpacing.space3,
                      ),
                      child: compact
                          ? Column(
                              key: Key('group-invite-compact-$index'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _invites[index].identifier,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: CoeloSpacing.space1),
                                Text(_GroupRoleLabel.label(_invites[index].role)),
                                Text(_invites[index].profile),
                                Row(
                                  children: [
                                    Expanded(child: Text(_invites[index].status)),
                                    IconButton(
                                      tooltip: 'Reenviar',
                                      onPressed: () => _resendInvite(index),
                                      icon: const Icon(Icons.forward_to_inbox_rounded),
                                    ),
                                    IconButton(
                                      tooltip: 'Revogar',
                                      onPressed: () => _cancelInvite(index),
                                      style: IconButton.styleFrom(foregroundColor: colors.error),
                                      icon: const Icon(Icons.block_rounded),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              key: Key('group-invite-wide-$index'),
                              children: [
                                Expanded(child: Text(_invites[index].identifier)),
                                Expanded(child: Text(_GroupRoleLabel.label(_invites[index].role))),
                                Expanded(child: Text(_invites[index].profile)),
                                Expanded(child: Text(_invites[index].status)),
                                IconButton(
                                  tooltip: 'Reenviar',
                                  onPressed: () => _resendInvite(index),
                                  icon: const Icon(Icons.forward_to_inbox_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Revogar',
                                  onPressed: () => _cancelInvite(index),
                                  style: IconButton.styleFrom(foregroundColor: colors.error),
                                  icon: const Icon(Icons.block_rounded),
                                ),
                              ],
                            ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            FilledButton.icon(
              key: const Key('group-invite-add'),
              onPressed: () => _invitePerson(),
              icon: const Icon(Icons.mail_outline_rounded),
              label: const Text('Convidar usuário'),
            ),
            OutlinedButton.icon(
              key: const Key('group-invite-export'),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Exportação de convites preparada localmente.')),
              ),
              icon: const Icon(Icons.download_outlined),
              label: const Text('Exportar convites (CSV/XLSX)'),
            ),
            TextButton.icon(
              key: const Key('group-invite-import'),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pré-visualização de importação demonstrativa.')),
              ),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Importar convites (CSV/XLSX)'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editPerson({int? index}) async {
    final person = index == null ? null : _people[index];
    final result = await _showPersonDialog(
      title: person == null ? 'Cadastrar pessoa' : 'Editar pessoa',
      initialName: person?.name,
      initialIdentifier: person?.identifier,
      initialRole: person?.role,
    );
    if (result == null) return;
    setState(() {
      if (person == null) {
        _people.add(
          _GroupPersonBinding(
            id: 'person-$_identitySeed-${DateTime.now().millisecondsSinceEpoch}',
            name: result.name,
            identifier: result.identifier,
            role: result.role,
          ),
        );
      } else {
        _people[index!] = _GroupPersonBinding(
          id: person.id,
          name: result.name,
          identifier: result.identifier,
          role: result.role,
          note: person.note,
        );
      }
      _markDirty();
    });
  }

  Future<void> _editProfessional({int? index}) async {
    final item = index == null ? null : _professionals[index];
    final result = await _showPersonDialog(
      title: item == null ? 'Adicionar profissional/admin' : 'Editar profissional/admin',
      initialName: item?.name,
      initialIdentifier: item?.identifier,
      initialRole: item?.role,
      showProfile: true,
      initialProfile: item?.note,
    );
    if (result == null) return;
    setState(() {
      if (item == null) {
        _professionals.add(
          _GroupPersonBinding(
            id: 'professional-$_identitySeed-${DateTime.now().millisecondsSinceEpoch}',
            name: result.name,
            identifier: result.identifier,
            role: result.role,
            note: result.note,
          ),
        );
      } else {
        _professionals[index!] = _GroupPersonBinding(
          id: item.id,
          name: result.name,
          identifier: result.identifier,
          role: result.role,
          note: result.note,
        );
      }
      _markDirty();
    });
  }

  Future<void> _searchAndInvitePerson() async {
    final result = await showDialog<_GroupPersonBinding>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (dialogContext) => const _GroupPersonDialog(mode: 'search', title: 'Buscar usuário'),
    );
    if (result == null) return;
    setState(() {
      _people.add(
        _GroupPersonBinding(
          id: 'person-$_identitySeed-${DateTime.now().millisecondsSinceEpoch}-found',
          name: result.name,
          identifier: result.identifier,
          role: result.role,
          note: 'Cadastro vinculado ao escopo local',
        ),
      );
      _markDirty();
    });
  }

  Future<void> _invitePerson() async {
    final result = await _showInviteDialog();
    if (result == null) return;
    setState(() {
      _invites.add(result);
      _markDirty();
    });
  }

  Future<void> _resendInvite(int index) async {
    final invite = _invites[index];
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Convite para ${invite.identifier} reenviado no fluxo local demonstrativo.',
          ),
        ),
      );
  }

  Future<void> _cancelInvite(int index) async {
    setState(() {
      _invites.removeAt(index);
      _markDirty();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Convite removido localmente.')));
  }

  Future<_GroupPersonBinding?> _showPersonDialog({
    required String title,
    String? initialName,
    String? initialIdentifier,
    _GroupRoleType? initialRole,
    bool showProfile = false,
    String? initialProfile,
  }) {
    return showDialog<_GroupPersonBinding>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => _GroupPersonDialog(
        mode: 'person',
        title: title,
        initialName: initialName,
        initialIdentifier: initialIdentifier,
        initialRole: initialRole ?? _GroupRoleType.responsavel,
        initialProfile: initialProfile,
        showProfile: showProfile,
        allowedProfiles: _profileCatalog,
      ),
    );
  }

  Future<_GroupInviteBinding?> _showInviteDialog() => showDialog<_GroupInviteBinding>(
    context: context,
    barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
    builder: (context) => _GroupInviteDialog(
      mode: 'invite',
      title: 'Convidar usuário para a turma',
      profiles: _profileCatalog,
      roles: _GroupRoleType.values,
    ),
  );

  Widget _formSection({
    required Key key,
    required String title,
    required String description,
    required Widget child,
  }) => Container(
    key: key,
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(CoeloRadius.md),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
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
    ),
  );

  Widget _fieldGrid(List<Widget> fields) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
      final width = twoColumns
          ? (constraints.maxWidth - CoeloSpacing.space3) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space4,
        children: [for (final field in fields) SizedBox(width: width, child: field)],
      );
    },
  );

  FormFieldValidator<String> _required(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;

  Color _parseColor(String value, {Color fallback = Colors.white}) {
    final normalized = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
      return fallback;
    }
    return Color(int.parse('FF$normalized', radix: 16));
  }

  Widget _footer() {
    final last = _currentStep == _GroupFormStep.invites;
    final primary = last
        ? FilledButton.icon(
            key: const Key('group-form-save'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: CoeloSize.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Salvando…' : 'Salvar turma'),
          )
        : _editing
        ? OutlinedButton(
            key: const Key('group-form-continue'),
            onPressed: _saving ? null : _continue,
            child: const Text('Continuar'),
          )
        : FilledButton(
            key: const Key('group-form-continue'),
            onPressed: _saving ? null : _continue,
            child: const Text('Continuar'),
          );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: SuperadminFormActionFooter(
        surfaceKey: const Key('group-form-footer-surface'),
        tertiaryAction: TextButton(
          key: const Key('group-form-cancel'),
          onPressed: _saving ? null : _cancel,
          child: const Text('Cancelar'),
        ),
        continuationActions: [
          if (_currentStep.index > 0)
            OutlinedButton(
              key: const Key('group-form-previous'),
              onPressed: _saving ? null : _previous,
              child: const Text('Anterior'),
            ),
          primary,
        ],
      ),
    );
  }
}

final class _GroupPersonDialog extends StatefulWidget {
  const _GroupPersonDialog({
    required this.mode,
    required this.title,
    this.initialName,
    this.initialIdentifier,
    this.initialRole,
    this.initialProfile,
    this.showProfile = false,
    this.allowedProfiles,
  });

  final String mode;
  final String title;
  final String? initialName;
  final String? initialIdentifier;
  final _GroupRoleType? initialRole;
  final String? initialProfile;
  final bool showProfile;
  final List<String>? allowedProfiles;

  @override
  State<_GroupPersonDialog> createState() => _GroupPersonDialogState();
}

final class _GroupPersonDialogState extends State<_GroupPersonDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _identifierController;
  late _GroupRoleType _role;
  String _profile = 'Observador';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _identifierController = TextEditingController(text: widget.initialIdentifier);
    _role = widget.initialRole ?? _GroupRoleType.responsavel;
    _profile = widget.initialProfile ?? 'Observador';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogMessage = switch (widget.mode) {
      'search' => 'Digite @, CPF, e-mail ou celular para localizar usuário.',
      _ => 'Preencha os dados da pessoa.',
    };
    return CoeloAdminDialogShell(
      dialogKey: const Key('group-person-dialog'),
      title: widget.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(dialogMessage),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloFormTextField(
            fieldKey: const Key('group-person-name-field'),
            controller: _nameController,
            labelText: widget.mode == 'search' ? 'Identificador' : 'Nome',
            prefixIcon: Icons.search_rounded,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          if (widget.mode != 'search')
            CoeloFormTextField(
              fieldKey: const Key('group-person-identifier-field'),
              controller: _identifierController,
              labelText: '@, CPF, e-mail ou celular',
              prefixIcon: Icons.badge_outlined,
            ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloAdminSingleSelectField<_GroupRoleType>(
            label: 'Papel',
            value: _role,
            options: _GroupRoleType.values,
            optionLabel: _GroupRoleLabel.label,
            prefixIcon: Icons.manage_accounts_rounded,
            onChanged: (value) => setState(() => _role = value),
          ),
          if (widget.showProfile) ...[
            const SizedBox(height: CoeloSpacing.space4),
            CoeloAdminSingleSelectField<String>(
              key: const Key('group-person-profile-field'),
              label: 'Perfil de acesso',
              value: _profile,
              options: widget.allowedProfiles ?? const [],
              optionLabel: (value) => value,
              prefixIcon: Icons.workspace_premium_outlined,
              onChanged: (value) => setState(() => _profile = value),
            ),
          ],
        ],
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      primaryAction: FilledButton(
        key: const Key('group-person-save'),
        onPressed: () {
          final name = _nameController.text.trim();
          final identifier = _identifierController.text.trim();
          if (name.isEmpty && identifier.isEmpty) return;
          Navigator.of(context).pop(
            _GroupPersonBinding(
              id: 'person-${DateTime.now().millisecondsSinceEpoch}',
              name: name.isEmpty ? identifier : name,
              identifier: identifier.isEmpty ? name : identifier,
              role: _role,
              note: widget.showProfile ? _profile : null,
            ),
          );
        },
        child: Text(widget.mode == 'search' ? 'Incluir usuário' : 'Salvar'),
      ),
    );
  }
}

final class _GroupInviteDialog extends StatefulWidget {
  const _GroupInviteDialog({
    required this.mode,
    required this.title,
    required this.profiles,
    required this.roles,
  });

  final String mode;
  final String title;
  final List<String> profiles;
  final List<_GroupRoleType> roles;

  @override
  State<_GroupInviteDialog> createState() => _GroupInviteDialogState();
}

final class _GroupInviteDialogState extends State<_GroupInviteDialog> {
  final _identifierController = TextEditingController();
  late String _profile;
  late _GroupRoleType _role;

  @override
  void initState() {
    super.initState();
    _role = _GroupRoleType.responsavel;
    _profile = widget.profiles.first;
  }

  @override
  void dispose() {
    _identifierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoeloAdminDialogShell(
      dialogKey: const Key('group-invite-dialog'),
      title: widget.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloFormTextField(
            fieldKey: const Key('group-invite-identifier-field'),
            controller: _identifierController,
            labelText: '@, CPF, e-mail ou celular',
            prefixIcon: Icons.search_rounded,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloAdminSingleSelectField<String>(
            key: const Key('group-invite-profile'),
            label: 'Perfil de acesso',
            value: _profile,
            options: widget.profiles,
            optionLabel: (value) => value,
            prefixIcon: Icons.verified_user_outlined,
            onChanged: (value) => setState(() => _profile = value),
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloAdminSingleSelectField<_GroupRoleType>(
            label: 'Função na turma',
            value: _role,
            options: widget.roles,
            optionLabel: _GroupRoleLabel.label,
            prefixIcon: Icons.groups_2_outlined,
            onChanged: (value) => setState(() => _role = value),
          ),
        ],
      ),
      secondaryAction: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      primaryAction: FilledButton(
        key: const Key('group-invite-save'),
        onPressed: () {
          final identifier = _identifierController.text.trim();
          if (identifier.isEmpty) return;
          Navigator.of(context).pop(
            _GroupInviteBinding(
              id: 'invite-${DateTime.now().millisecondsSinceEpoch}',
              identifier: identifier,
              role: _role,
              profile: _profile,
              status: 'Pendente',
            ),
          );
        },
        child: const Text('Convidar'),
      ),
    );
  }
}
