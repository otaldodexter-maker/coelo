import 'dart:async';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../support/domain/support_ticket.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
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

enum _GroupRoleType { aluno, responsavel, profissional, administrador }

final class _GroupRoleLabel {
  const _GroupRoleLabel._();

  static String label(_GroupRoleType value) => switch (value) {
    _GroupRoleType.aluno => 'student',
    _GroupRoleType.responsavel => 'guardian',
    _GroupRoleType.profissional => 'professional',
    _GroupRoleType.administrador => 'admin',
  };

  static String visualLabel(_GroupRoleType value) => switch (value) {
    _GroupRoleType.aluno => 'Aluno',
    _GroupRoleType.responsavel => 'Responsável',
    _GroupRoleType.profissional => 'Profissional',
    _GroupRoleType.administrador => 'Administrador',
  };

  static IconData icon(_GroupRoleType value) => switch (value) {
    _GroupRoleType.aluno => Icons.child_care_rounded,
    _GroupRoleType.responsavel => Icons.family_restroom_rounded,
    _GroupRoleType.profissional => Icons.school_rounded,
    _GroupRoleType.administrador => Icons.admin_panel_settings_rounded,
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
  late final TextEditingController _typeOtherController;
  late final TextEditingController _primaryColorController;
  late final TextEditingController _secondaryColorController;
  late final TextEditingController _surfaceColorController;
  List<GroupDirectoryFilterOption> _institutionOptions = const [];
  List<GroupDirectoryFilterOption> _unitOptions = const [];
  List<GroupDirectoryFilterOption> _typeOptions = const [];
  GroupDirectoryFilterOption? _selectedInstitution;
  GroupDirectoryFilterOption? _selectedUnit;
  late GroupStatus _status;
  bool _inheritAppearance = true;
  bool _inheritAccess = true;
  bool _inheritActivities = true;
  GroupRecord? _original;
  bool _dirty = false;
  bool _loading = true;
  String? _loadingError;
  bool _saving = false;
  String? _saveError;
  _GroupFormStep _currentStep = _GroupFormStep.hierarchy;
  final Set<_GroupFormStep> _completedSteps = {};
  final Set<_GroupFormStep> _errorSteps = {};
  final Set<String> _selectedActivities = {};
  final Set<String> _mandatoryActivities = {};
  final List<_GroupActivityBinding> _activityByStudentLinks = const [];
  final List<_GroupPersonBinding> _people = [];
  final List<_GroupPersonBinding> _professionals = [];
  final List<_GroupInviteBinding> _invites = [];
  double _footerHeight = 0;

  bool get _editing => widget.groupId != null;

  static const _activityCatalog = <String>[];
  static const _profileCatalog = <String>[];

  @override
  void initState() {
    super.initState();
    _status = GroupStatus.active;
    _nameController = TextEditingController();
    _typeController = TextEditingController();
    _typeOtherController = TextEditingController();
    _primaryColorController = TextEditingController(text: '#D63C00');
    _secondaryColorController = TextEditingController(text: '#3F4549');
    _surfaceColorController = TextEditingController(text: '#FFFFFF');
    unawaited(_loadContext());
  }

  Future<void> _loadContext() async {
    try {
      final initialRecord = widget.groupId == null
          ? null
          : await widget.repository.findById(widget.groupId!);
      final context = await widget.repository.fetchFormContext(
        institutionId: widget.initialInstitutionId ?? initialRecord?.institutionId,
      );
      if (!mounted) return;

      _institutionOptions = context.institutions;
      _unitOptions = context.units;
      _typeOptions = [
        ...context.types,
        if (!context.types.any((option) => option.id == 'class'))
          const GroupDirectoryFilterOption(id: 'class', label: 'Turma'),
        if (!context.types.any((option) => option.id == 'other'))
          const GroupDirectoryFilterOption(id: 'other', label: 'Outros'),
      ];
      _status = initialRecord?.status ?? GroupStatus.active;
      _original = initialRecord;
      _nameController.text = initialRecord?.name ?? '';
      _typeController.text = initialRecord?.groupType ?? 'class';
      _typeOtherController.text = initialRecord?.groupTypeOtherText ?? '';
      if (!_typeOptions.any((option) => option.id == _typeController.text)) {
        _typeOptions = [
          ..._typeOptions,
          GroupDirectoryFilterOption(
            id: _typeController.text,
            label: GroupRecord.groupTypeLabelFor(_typeController.text),
          ),
        ];
      }
      _inheritAppearance = initialRecord?.inheritAppearance ?? true;
      _inheritAccess = initialRecord?.inheritAccess ?? true;
      _inheritActivities = initialRecord?.inheritActivities ?? true;
      _selectedActivities
        ..clear()
        ..addAll(initialRecord?.activityIds ?? const []);
      final appearance = initialRecord?.effectiveAppearance ?? const <String, String?>{};
      _primaryColorController.text = appearance['accent_color'] ?? '#D63C00';
      _secondaryColorController.text = appearance['secondary_color'] ?? '#3F4549';
      _surfaceColorController.text = appearance['surface_color'] ?? '#FFFFFF';

      _selectedInstitution =
          _resolveInstitution(widget.initialInstitutionId ?? initialRecord?.institutionId) ??
          (context.institutions.isNotEmpty ? context.institutions.first : null);
      _selectedUnit = _resolveUnitForInstitution(
        widget.initialUnitId ?? initialRecord?.unitId,
        _selectedInstitution?.id,
      );
      if (_selectedUnit == null) {
        final units = _unitsForInstitution(_selectedInstitution?.id);
        _selectedUnit = units.isEmpty ? null : units.first;
      }
      _hydrateLocalAccess(initialRecord);
      setState(() {
        _loading = false;
      });
    } on GroupDirectoryUnauthorizedException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingError = 'Sem permissão para carregar os dados desta tela.';
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingError = 'Não foi possível carregar as opções de turma.';
      });
    }
  }

  List<GroupDirectoryFilterOption> _unitsForInstitution(String? institutionId) =>
      institutionId == null
      ? const []
      : [
          for (final unit in _unitOptions)
            if (unit.institutionId == institutionId) unit,
        ];

  GroupDirectoryFilterOption? _resolveInstitution(String? institutionId) {
    for (final institution in _institutionOptions) {
      if (institution.id == institutionId) return institution;
    }
    return null;
  }

  GroupDirectoryFilterOption? _resolveUnitForInstitution(String? unitId, String? institutionId) {
    if (unitId == null || institutionId == null) return null;
    for (final unit in _unitOptions) {
      if (unit.id == unitId && unit.institutionId == institutionId) return unit;
    }
    return null;
  }

  void _onSelectInstitution(GroupDirectoryFilterOption institution) => setState(() {
    _selectedInstitution = institution;
    _selectedUnit = null;
    final units = _unitsForInstitution(institution.id);
    _selectedUnit = units.isEmpty ? null : units.first;
    _markDirty();
  });

  void _onSelectUnit(GroupDirectoryFilterOption unit) => setState(() {
    _selectedUnit = unit;
    _markDirty();
  });

  void _hydrateLocalAccess(GroupRecord? record) {
    if (record == null) return;
    for (final access in record.effectiveAccess.where((entry) => !entry.inherited)) {
      final role = switch (access.profileCode) {
        'student' => _GroupRoleType.aluno,
        'guardian' => _GroupRoleType.responsavel,
        'professional' => _GroupRoleType.profissional,
        'admin' => _GroupRoleType.administrador,
        _ => null,
      };
      if (role == null) continue;
      final binding = _GroupPersonBinding(
        id: access.personId,
        name: access.displayName,
        identifier: access.personId,
        role: role,
        note: access.profileName,
      );
      if (role == _GroupRoleType.profissional || role == _GroupRoleType.administrador) {
        _professionals.add(binding);
      } else {
        _people.add(binding);
      }
    }
    for (final invite in record.invites) {
      final role = switch (invite.role) {
        'student' => _GroupRoleType.aluno,
        'guardian' => _GroupRoleType.responsavel,
        'professional' => _GroupRoleType.profissional,
        'admin' => _GroupRoleType.administrador,
        _ => null,
      };
      if (role == null) continue;
      _invites.add(
        _GroupInviteBinding(
          id: invite.id,
          identifier: invite.identifier,
          role: role,
          profile: invite.profile,
          status: invite.status,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _typeOtherController.dispose();
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
      _nameController.text.trim().isNotEmpty &&
      _typeController.text.trim().isNotEmpty &&
      (_typeController.text != 'other' || _typeOtherController.text.trim().isNotEmpty);

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
      if (_selectedInstitution == null || _selectedUnit == null) {
        setState(() {
          _saving = false;
          _saveError = 'Selecione uma instituição e uma unidade para salvar a turma.';
        });
        return;
      }
      final now = DateTime.now();
      final original = _original;
      final institution = _selectedInstitution!;
      final unit = _selectedUnit!;
      final record = original == null
          ? GroupRecord(
              id: widget.repository.createId(institution.id, unit.id, _nameController.text.trim()),
              institutionId: institution.id,
              institutionName: institution.label,
              unitId: unit.id,
              unitName: unit.label,
              name: _nameController.text.trim(),
              groupType: _typeController.text.trim(),
              groupTypeOtherText: _typeController.text == 'other'
                  ? _typeOtherController.text.trim()
                  : null,
              status: _status,
              inheritAppearance: _inheritAppearance,
              inheritAccess: _inheritAccess,
              inheritActivities: _inheritActivities,
              createdAt: now,
              updatedAt: now,
            )
          : original.copyWith(
              name: _nameController.text.trim(),
              groupType: _typeController.text.trim(),
              groupTypeOtherText: _typeController.text == 'other'
                  ? _typeOtherController.text.trim()
                  : null,
              status: _status,
              inheritAppearance: _inheritAppearance,
              inheritAccess: _inheritAccess,
              inheritActivities: _inheritActivities,
              updatedAt: now,
            );
      final result = await widget.repository.saveComposition(
        GroupDirectorySaveRequest(
          requestId:
              'group-save-${_editing ? 'edit' : 'create'}-${DateTime.now().millisecondsSinceEpoch}',
          record: record,
          branding: {
            'accent_color': _primaryColorController.text.trim(),
            'secondary_color': _secondaryColorController.text.trim(),
            'surface_color': _surfaceColorController.text.trim(),
          },
          people: [
            for (final person in _people)
              GroupDirectoryPersonBinding(
                id: person.id,
                name: person.name,
                identifier: person.identifier,
                role: _GroupRoleLabel.label(person.role),
                profile: person.note,
              ),
          ],
          professionals: [
            for (final professional in _professionals)
              GroupDirectoryPersonBinding(
                id: professional.id,
                name: professional.name,
                identifier: professional.identifier,
                role: _GroupRoleLabel.label(professional.role),
                profile: professional.note,
              ),
          ],
          activityIds: _inheritActivities ? const [] : _selectedActivities.toList(growable: false),
          typeRequestLabel: _typeController.text == 'other'
              ? _typeOtherController.text.trim()
              : null,
          typeRequestJustification: _typeController.text == 'other'
              ? 'Solicitado no formulário de Turma'
              : null,
          invites: [
            for (final invite in _invites)
              GroupDirectoryInviteBinding(
                id: invite.id,
                identifier: invite.identifier,
                role: _GroupRoleLabel.label(invite.role),
                profile: invite.profile,
                status: invite.status,
              ),
          ],
        ),
      );
      if (!mounted) return;
      if (result.hasFailure) {
        final failedSteps = <_GroupFormStep>{};
        final lines = <String>[];
        for (final step in result.steps) {
          if (!step.isFailure) continue;
          failedSteps.add(switch (step.stage) {
            GroupDirectorySaveStage.group => _GroupFormStep.hierarchy,
            GroupDirectorySaveStage.people => _GroupFormStep.people,
            GroupDirectorySaveStage.professionals => _GroupFormStep.professionals,
            GroupDirectorySaveStage.activityLinks => _GroupFormStep.links,
            GroupDirectorySaveStage.invites => _GroupFormStep.invites,
          });
          lines.add('${step.stage.label}: ${step.message ?? 'falhou'}');
        }
        _errorSteps
          ..clear()
          ..addAll(failedSteps);
        for (final step in _GroupFormStep.values) {
          if (_errorSteps.contains(step)) {
            _currentStep = step;
            break;
          }
        }
        setState(() {
          _saving = false;
          _saveError = 'Não foi possível concluir o salvamento da turma:\n${lines.join('\n')}';
        });
        return;
      }
      setState(() {
        _errorSteps.clear();
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
    return LayoutBuilder(
      builder: (context, outerConstraints) => SuperadminShell(
        logout: widget.logout,
        title: title,
        subtitle: _editing
            ? 'Atualize os dados da turma selecionada.'
            : 'Adicione uma nova turma ao Coelo.',
        currentDestination: 'groups',
        onDestinationSelected: _selectDestination,
        onBugReportSubmitted: widget.onBugReportSubmitted,
        chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadingError != null
            ? CoeloStatePanel(
                key: const Key('group-form-load-error'),
                title: 'Não foi possível carregar',
                message: _loadingError!,
                icon: Icons.error_outline_outlined,
                actionLabel: 'Voltar às turmas',
                onAction: widget.onCancel,
              )
            : (_editing && _original == null)
            ? CoeloStatePanel(
                key: const Key('group-form-not-found'),
                title: 'Turma não encontrada',
                message: 'O registro solicitado não foi encontrado.',
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
                  child: SuperadminFormFrame(
                    key: const Key('group-form-golden-root'),
                    viewportWidth: outerConstraints.maxWidth,
                    navigation: _navigation(),
                    scrollKey: const Key('group-form-scroll'),
                    body: _formSurface(),
                    footer: _footer(),
                  ),
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
        description: 'Instituição · Unidade · Turma.',
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
        description: 'Atividades, rótulos de comunicação e identidade visual da turma.',
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
        description: 'Pessoas, perfis e vínculos da turma.',
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
        description: 'Acesso operacional da turma por função. Defina permissões explícitas.',
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
            'Convites referenciam uma identidade global existente; novos cadastros usam o fluxo aprovado de Pessoas.',
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
    const emptyInstitution = GroupDirectoryFilterOption(id: '', label: 'Selecione uma Instituição');
    const emptyUnit = GroupDirectoryFilterOption(id: '', label: 'Selecione uma Unidade');
    final institutionValue = _selectedInstitution ?? emptyInstitution;
    final institutionOptions = _selectedInstitution == null
        ? [emptyInstitution, ..._institutionOptions]
        : _institutionOptions;
    final unitOptions = _selectedInstitution == null
        ? const <GroupDirectoryFilterOption>[]
        : _unitsForInstitution(_selectedInstitution!.id);
    final unitValue = _selectedUnit ?? emptyUnit;
    final displayedUnitOptions = _selectedUnit == null ? [emptyUnit, ...unitOptions] : unitOptions;
    return [
      IgnorePointer(
        ignoring: locked,
        child: Opacity(
          opacity: locked ? .65 : 1,
          child: CoeloAdminSingleSelectField<GroupDirectoryFilterOption>(
            key: const Key('group-institution-field'),
            label: 'Instituição',
            value: institutionValue,
            options: institutionOptions,
            optionLabel: (value) => value.label,
            enabled: !locked,
            prefixIcon: Icons.account_balance_outlined,
            onChanged: (value) {
              if (value.id.isNotEmpty) _onSelectInstitution(value);
            },
          ),
        ),
      ),
      IgnorePointer(
        ignoring: locked,
        child: Opacity(
          opacity: locked ? .65 : 1,
          child: CoeloAdminSingleSelectField<GroupDirectoryFilterOption>(
            key: const Key('group-unit-field'),
            label: 'Unidade',
            value: unitValue,
            options: displayedUnitOptions,
            optionLabel: (value) => value.label,
            enabled: !locked,
            prefixIcon: Icons.apartment_outlined,
            onChanged: (value) {
              if (value.id.isNotEmpty) _onSelectUnit(value);
            },
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
    CoeloAdminSingleSelectField<String>(
      key: const Key('group-type-field'),
      label: 'Tipo da turma',
      value: _typeController.text,
      options: _typeOptions.map((option) => option.id).toList(growable: false),
      optionLabel: (value) => _typeOptions.firstWhere((option) => option.id == value).label,
      prefixIcon: Icons.category_outlined,
      onChanged: (value) => setState(() {
        _typeController.text = value;
        _dirty = true;
      }),
    ),
    if (_typeController.text == 'other')
      CoeloFormTextField(
        fieldKey: const Key('group-type-other-field'),
        controller: _typeOtherController,
        labelText: 'Qual tipo de turma?',
        prefixIcon: Icons.edit_note_outlined,
        validator: _required('Informe o tipo de turma em Outros.'),
        onChanged: (_) => _markDirty(),
      ),
    CoeloAdminSingleSelectField<GroupStatus>(
      key: const Key('group-status-field'),
      label: 'Status da turma',
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
    SwitchListTile.adaptive(
      key: const Key('group-inherit-appearance'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Herdar aparência da Unidade'),
      subtitle: Text(
        _inheritAppearance
            ? 'Origem efetiva: ${_appearanceOriginLabel(_original?.appearanceOrigin ?? 'unit')}'
            : 'Personalização local da Turma',
      ),
      value: _inheritAppearance,
      onChanged: (value) => setState(() {
        _inheritAppearance = value;
        _dirty = true;
        if (value) {
          final inherited = _original?.effectiveAppearance ?? const <String, String?>{};
          _primaryColorController.text = inherited['accent_color'] ?? '#D63C00';
          _secondaryColorController.text = inherited['secondary_color'] ?? '#3F4549';
          _surfaceColorController.text = inherited['surface_color'] ?? '#FFFFFF';
        }
      }),
    ),
    SwitchListTile.adaptive(
      key: const Key('group-inherit-access'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Herdar acessos da Instituição e Unidade'),
      subtitle: const Text('A remoção local não revoga acessos válidos de escopos superiores.'),
      value: _inheritAccess,
      onChanged: (value) => setState(() {
        _inheritAccess = value;
        _dirty = true;
      }),
    ),
    SwitchListTile.adaptive(
      key: const Key('group-inherit-activities'),
      contentPadding: EdgeInsets.zero,
      title: const Text('Herdar atividades disponíveis da Unidade'),
      value: _inheritActivities,
      onChanged: (value) => setState(() {
        _inheritActivities = value;
        _dirty = true;
      }),
    ),
    if (!_inheritAppearance) ...[
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
    ],
  ];

  String _appearanceOriginLabel(String origin) => switch (origin) {
    'institution' => 'Instituição',
    'group_local' => 'Turma',
    _ => 'Unidade',
  };

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
                    _inheritAppearance
                        ? 'Aparência herdada de ${_appearanceOriginLabel(_original?.appearanceOrigin ?? 'unit')}'
                        : 'Aparência personalizada na Turma',
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

  Widget _effectiveAccessSummary() {
    final inherited =
        _original?.effectiveAccess.where((entry) => entry.inherited).toList(growable: false) ??
        const <GroupEffectiveAccess>[];
    if (inherited.isEmpty) {
      return const Text('Nenhum acesso herdado disponível.');
    }
    return Column(
      key: const Key('group-inherited-access-summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Pessoas herdadas', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: CoeloSpacing.space2),
        for (final access in inherited)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_tree_outlined),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(access.displayName, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: CoeloSpacing.space1),
                      Text(
                        '${access.profileName} · origem: ${_appearanceOriginLabel(access.origin)}\n'
                        'Capacidades: ${access.capabilities.isEmpty ? 'nenhuma' : access.capabilities.join(', ')}'
                        '${access.restrictions.isEmpty ? '' : '\nRestrições: ${access.restrictions.join(', ')}'}',
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
        const Divider(),
      ],
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
      if (allowProfile) _effectiveAccessSummary(),
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
                            _GroupRoleLabel.visualLabel(entries[index].role),
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
                          child: Text(
                            _GroupRoleLabel.visualLabel(entries[index].role),
                            maxLines: 2,
                          ),
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
                                Text(_GroupRoleLabel.visualLabel(_invites[index].role)),
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
                                Expanded(
                                  child: Text(_GroupRoleLabel.visualLabel(_invites[index].role)),
                                ),
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
            id: 'person-pending-${DateTime.now().millisecondsSinceEpoch}',
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
            id: 'professional-pending-${DateTime.now().millisecondsSinceEpoch}',
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
          id: 'person-pending-${DateTime.now().millisecondsSinceEpoch}-found',
          name: result.name,
          identifier: result.identifier,
          role: result.role,
          note: 'Cadastro vinculado ao escopo da turma',
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
    setState(() {
      _invites[index] = _GroupInviteBinding(
        id: invite.id,
        identifier: invite.identifier,
        role: invite.role,
        profile: invite.profile,
        status: 'Reenviar ao salvar',
      );
      _markDirty();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('O reenvio será executado e auditado ao salvar a Turma.')),
    );
  }

  Future<void> _cancelInvite(int index) async {
    setState(() {
      _invites.removeAt(index);
      _markDirty();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A revogação será executada e auditada ao salvar a Turma.')),
    );
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
  }) => Column(
    key: key,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: CoeloSpacing.space1),
      Text(description, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: CoeloSpacing.space5),
      child,
    ],
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
            label: Text(_saving ? 'Salvando...' : 'Salvar turma'),
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
        onHeightChanged: (height) {
          if ((_footerHeight - height).abs() < 0.5) return;
          setState(() => _footerHeight = height);
        },
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
              labelText: 'ID da pessoa global existente',
              prefixIcon: Icons.badge_outlined,
            ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloAdminSingleSelectField<_GroupRoleType>(
            label: 'Papel',
            value: _role,
            options: _GroupRoleType.values,
            optionLabel: _GroupRoleLabel.visualLabel,
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
    _profile = widget.profiles.isEmpty ? _GroupRoleLabel.label(_role) : widget.profiles.first;
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
            labelText: 'ID da pessoa global existente',
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
            optionLabel: _GroupRoleLabel.visualLabel,
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
