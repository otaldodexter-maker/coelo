import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/person_directory.dart';
import 'person_form_view_model.dart';

const _emptyOption = PersonFilterOption('', 'Selecione');

final class PersonFormPage extends StatefulWidget {
  const PersonFormPage({
    required this.repository,
    required this.logout,
    this.original,
    this.onCancel,
    this.onSaved,
    this.onDestinationSelected,
    super.key,
  });

  final PersonDirectoryRepository repository;
  final LogoutAction logout;
  final PersonDirectoryItem? original;
  final VoidCallback? onCancel;
  final ValueChanged<PersonDirectoryItem>? onSaved;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<PersonFormPage> createState() => _PersonFormPageState();
}

final class _PersonFormPageState extends State<PersonFormPage> {
  late final PersonFormViewModel _viewModel;
  late final SuperadminActivityController _activityController;
  late final Map<String, TextEditingController> _controllers;
  PersonDirectoryFilterOptions _options = const PersonDirectoryFilterOptions();
  PersonFilterOption _selectedInstitution = _emptyOption;
  PersonFilterOption _selectedUnit = _emptyOption;
  PersonFilterOption _selectedGroup = _emptyOption;
  PersonFilterOption _selectedRole = _emptyOption;
  String? _identityError;
  bool _loadingOptions = true;
  Object? _optionsError;

  List<PersonFilterOption> get _unitOptions => _options.units
      .where((option) => option.institutionId == _selectedInstitution.id)
      .toList(growable: false);
  List<PersonFilterOption> get _groupOptions => _options.groups
      .where(
        (option) =>
            option.institutionId == _selectedInstitution.id && option.unitId == _selectedUnit.id,
      )
      .toList(growable: false);
  List<PersonFilterOption> get _roleOptions => _options.roles
      .where((option) => option.institutionId == _selectedInstitution.id)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _viewModel = PersonFormViewModel(widget.repository, original: widget.original);
    _activityController = SuperadminActivityController();
    _controllers = {
      'firstName': TextEditingController(text: _viewModel.firstName),
      'lastName': TextEditingController(text: _viewModel.lastName),
      'displayName': TextEditingController(text: _viewModel.displayName),
      'legalName': TextEditingController(text: _viewModel.legalName),
    };
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _optionsError = null;
    });
    try {
      final value = await widget.repository.fetchFilterOptions();
      if (!mounted) return;
      setState(() {
        _options = value;
        _loadingOptions = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingOptions = false;
        _optionsError = error;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _viewModel.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _syncIdentity() {
    _viewModel
      ..firstName = _controllers['firstName']!.text
      ..lastName = _controllers['lastName']!.text
      ..displayName = _controllers['displayName']!.text
      ..legalName = _controllers['legalName']!.text;
  }

  void _continue() {
    _syncIdentity();
    if (_viewModel.step == PersonFormStep.identity &&
        [
          _viewModel.firstName,
          _viewModel.lastName,
          _viewModel.displayName,
          _viewModel.legalName,
        ].any((value) => value.trim().isEmpty)) {
      setState(() => _identityError = 'Informe os campos obrigatórios.');
      return;
    }
    setState(() => _identityError = null);
    _viewModel.next();
  }

  void _selectStep(PersonFormStep step) {
    if (_viewModel.isReadOnly || step == _viewModel.step) return;
    if (step.index < _viewModel.step.index) {
      setState(() => _viewModel.step = step);
      return;
    }
    _continue();
  }

  Future<void> _save() async {
    _syncIdentity();
    try {
      final saved = await _viewModel.save();
      if (mounted) widget.onSaved?.call(saved);
    } on PersonDirectoryConflictException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A pessoa foi alterada em outra sessão. Recarregue.')),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não foi possível salvar a pessoa.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    title: widget.original == null ? 'Criar pessoa' : 'Editar pessoa',
    subtitle: widget.original == null
        ? 'Cadastre identidade e vínculos contextuais.'
        : 'Altere somente dados globais e vínculos aprovados.',
    currentDestination: 'people',
    activityController: _activityController,
    onDestinationSelected: widget.onDestinationSelected,
    child: AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) => LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
          final contentInset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : CoeloSpacing.space4;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              contentInset,
              contentInset,
              contentInset,
              CoeloSpacing.space4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desktop) ...[_navigation(), const SizedBox(width: CoeloSpacing.space6)],
                Expanded(
                  child: Column(
                    children: [
                      if (!desktop) ...[_navigation(), const SizedBox(height: CoeloSpacing.space4)],
                      Expanded(
                        child: SingleChildScrollView(
                          key: const Key('person-form-scroll'),
                          padding: const EdgeInsets.only(bottom: CoeloSpacing.space6),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 880),
                              child: _section(),
                            ),
                          ),
                        ),
                      ),
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
  );

  Widget _navigation() => LayoutBuilder(
    key: const Key('person-form-navigation'),
    builder: (context, constraints) {
      if (constraints.maxWidth >= CoeloBreakpoints.large.minWidth) {
        return SizedBox(
          width: 248,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final step in PersonFormStep.values) _stepButton(step)],
          ),
        );
      }
      if (constraints.maxWidth >= CoeloBreakpoints.medium.minWidth) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final step in PersonFormStep.values)
                Padding(
                  padding: const EdgeInsets.only(right: CoeloSpacing.space2),
                  child: _stepButton(step, compact: true),
                ),
            ],
          ),
        );
      }
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Etapa ${_viewModel.step.index + 1} de ${PersonFormStep.values.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(_viewModel.step.label, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          MenuAnchor(
            menuChildren: [
              for (final step in PersonFormStep.values)
                MenuItemButton(
                  onPressed: _viewModel.isReadOnly ? null : () => _selectStep(step),
                  child: Text(step.label),
                ),
            ],
            builder: (context, menu, child) => IconButton(
              tooltip: 'Selecionar etapa',
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              icon: const Icon(Icons.format_list_bulleted_rounded),
            ),
          ),
        ],
      );
    },
  );

  Widget _stepButton(PersonFormStep step, {bool compact = false}) {
    final current = step == _viewModel.step;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: current,
      label: '${step.label}, ${current ? 'selecionada' : 'incompleta'}',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 0 : CoeloSpacing.spaceHalf),
        child: TextButton.icon(
          onPressed: _viewModel.isReadOnly ? null : () => _selectStep(step),
          style:
              TextButton.styleFrom(
                minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
              ).copyWith(
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      current ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      current ||
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused)
                      ? colors.primaryContainer
                      : Colors.transparent,
                ),
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
          icon: Icon(
            current ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
          ),
          label: Text(step.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _section() => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.short,
    child: switch (_viewModel.step) {
      PersonFormStep.identity => _identity(),
      PersonFormStep.contexts => _contexts(),
      PersonFormStep.review => _review(),
    },
  );

  Widget _heading(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space1),
      Text(description),
      const SizedBox(height: CoeloSpacing.space5),
    ],
  );

  Widget _identity() => Column(
    key: const ValueKey(PersonFormStep.identity),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Identidade', 'Informe somente os dados globais aprovados.'),
      if (_viewModel.isReadOnly) ...[
        const CoeloStatePanel(
          title: 'Pessoa de serviço — somente leitura',
          message: 'Identidade, Auth e vínculos não podem ser alterados nesta tela.',
          icon: Icons.lock_outline_rounded,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _readOnlySummaries(widget.original!),
      ] else ...[
        if (_identityError case final error?) ...[
          Semantics(liveRegion: true, child: Text(error)),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        _responsiveFields([
          IgnorePointer(
            ignoring: widget.original != null,
            child: Opacity(
              opacity: widget.original == null ? 1 : .65,
              child: CoeloAdminSingleSelectField<PersonType>(
                label: 'Tipo',
                value: _viewModel.type,
                options: const [PersonType.adult, PersonType.child],
                optionLabel: (value) => value.label,
                onChanged: (value) => setState(() => _viewModel.type = value),
                prefixIcon: Icons.person_outline_rounded,
              ),
            ),
          ),
          _field('firstName', 'Primeiro nome', const Key('person-first-name-field')),
          _field('lastName', 'Sobrenome', const Key('person-last-name-field')),
          _field('displayName', 'Nome de exibição', const Key('person-display-name-field')),
          _field('legalName', 'Nome legal', const Key('person-legal-name-field')),
        ]),
        if (widget.original case final original?) ...[
          const SizedBox(height: CoeloSpacing.space5),
          _readOnlySummaries(original),
        ],
      ],
    ],
  );

  Widget _field(String id, String label, Key key) => CoeloFormTextField(
    fieldKey: key,
    controller: _controllers[id]!,
    labelText: label,
    prefixIcon: Icons.badge_outlined,
    errorText: _identityError != null && _controllers[id]!.text.trim().isEmpty
        ? 'Campo obrigatório'
        : null,
  );

  Widget _contexts() {
    if (_loadingOptions) {
      return const CoeloStatePanel(
        title: 'Carregando vínculos',
        message: 'Aguarde enquanto buscamos as opções autorizadas.',
        loading: true,
      );
    }
    if (_optionsError case final error?) {
      return CoeloStatePanel(
        title: error is PersonDirectoryUnauthorizedException
            ? 'Acesso não autorizado'
            : 'Não foi possível carregar os vínculos',
        message: error is PersonDirectoryUnauthorizedException
            ? 'Você não possui permissão para consultar as opções.'
            : 'Tente novamente em instantes.',
        icon: error is PersonDirectoryUnauthorizedException
            ? Icons.lock_outline_rounded
            : Icons.error_outline_rounded,
        actionLabel: error is PersonDirectoryUnauthorizedException ? null : 'Tentar novamente',
        onAction: error is PersonDirectoryUnauthorizedException ? null : _loadOptions,
      );
    }
    return Column(
      key: const ValueKey(PersonFormStep.contexts),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(
          'Vínculos contextuais',
          _viewModel.type == PersonType.child
              ? 'Gerencie contextos institucionais da criança separadamente de papéis adultos.'
              : 'Associe instituições, unidades, grupos e papéis sem alterar outros vínculos.',
        ),
        if (_viewModel.type == PersonType.adult)
          for (final membership in _viewModel.memberships)
            Card(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(CoeloSpacing.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(membership.institutionName, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: CoeloSpacing.space2),
                    Text(
                      [membership.unitName, membership.groupName].whereType<String>().join(' • '),
                    ),
                    const SizedBox(height: CoeloSpacing.space3),
                    CoeloAdminSingleSelectField<PersonFilterOption>(
                      label: 'Papel contextual',
                      value: _roleOption(membership.role, membership.institutionId),
                      options: [
                        _emptyOption,
                        ..._options.roles.where(
                          (option) => option.institutionId == membership.institutionId,
                        ),
                      ],
                      optionLabel: (value) => value.label,
                      onChanged: (value) {
                        if (value.id.isNotEmpty) {
                          _viewModel.updateMembership(membership.copyWith(role: value.id));
                        }
                      },
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: CoeloSpacing.space2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _viewModel.removeMembership(membership),
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Revogar vínculo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        if (_viewModel.type == PersonType.child)
          for (final childContext in _viewModel.childContexts) _childContextEditor(childContext),
        if (_options.institutions.isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space4),
          _responsiveFields([
            CoeloAdminSingleSelectField<PersonFilterOption>(
              key: const Key('person-membership-institution'),
              label: 'Instituição',
              value: _selectedInstitution,
              options: [_emptyOption, ..._options.institutions],
              optionLabel: (value) => value.label,
              onChanged: (value) => setState(() {
                _selectedInstitution = value;
                _selectedUnit = _emptyOption;
                _selectedGroup = _emptyOption;
                _selectedRole = _emptyOption;
              }),
              prefixIcon: Icons.account_balance_outlined,
            ),
            CoeloAdminSingleSelectField<PersonFilterOption>(
              key: const Key('person-membership-unit'),
              label: 'Unidade',
              value: _selectedUnit,
              options: [_emptyOption, ..._unitOptions],
              optionLabel: (value) => value.label,
              onChanged: (value) => setState(() {
                _selectedUnit = value;
                _selectedGroup = _emptyOption;
              }),
              prefixIcon: Icons.apartment_outlined,
              enabled: _selectedInstitution.id.isNotEmpty,
            ),
            CoeloAdminSingleSelectField<PersonFilterOption>(
              key: const Key('person-membership-group'),
              label: 'Grupo',
              value: _selectedGroup,
              options: [_emptyOption, ..._groupOptions],
              optionLabel: (value) => value.label,
              onChanged: (value) => setState(() => _selectedGroup = value),
              prefixIcon: Icons.groups_outlined,
              enabled: _selectedUnit.id.isNotEmpty,
            ),
            if (_viewModel.type == PersonType.adult)
              CoeloAdminSingleSelectField<PersonFilterOption>(
                key: const Key('person-membership-role'),
                label: 'Papel contextual',
                value: _selectedRole,
                options: [_emptyOption, ..._roleOptions],
                optionLabel: (value) => value.label,
                onChanged: (value) => setState(() => _selectedRole = value),
                prefixIcon: Icons.badge_outlined,
              ),
          ]),
          const SizedBox(height: CoeloSpacing.space4),
          OutlinedButton.icon(
            key: const Key('person-add-membership'),
            onPressed:
                _selectedInstitution.id.isEmpty ||
                    (_viewModel.type == PersonType.adult && _selectedRole.id.isEmpty)
                ? null
                : _addSelectedContext,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              _viewModel.type == PersonType.child ? 'Adicionar contexto' : 'Adicionar vínculo',
            ),
          ),
        ],
        if (_viewModel.type == PersonType.child) ...[
          const SizedBox(height: CoeloSpacing.space4),
          const CoeloStatePanel(
            title: 'Vínculos de responsável',
            message: 'Os vínculos de responsável permanecem somente leitura nesta etapa.',
            icon: Icons.child_care_outlined,
          ),
        ],
      ],
    );
  }

  Widget _childContextEditor(PersonChildContext childContext) {
    final unitOptions = _options.units
        .where((option) => option.institutionId == childContext.institutionId)
        .toList(growable: false);
    final groupOptions = _options.groups
        .where(
          (option) =>
              option.institutionId == childContext.institutionId &&
              option.unitId == childContext.unitId,
        )
        .toList(growable: false);
    final selectedUnit = unitOptions
        .where((option) => option.id == childContext.unitId)
        .firstOrNull;
    final selectedGroup = groupOptions
        .where((option) => option.id == childContext.groupId)
        .firstOrNull;
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              childContext.institutionName ?? childContext.institutionId,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            CoeloAdminSingleSelectField<PersonFilterOption>(
              label: 'Unidade',
              value: selectedUnit ?? _emptyOption,
              options: [_emptyOption, ...unitOptions],
              optionLabel: (value) => value.label,
              onChanged: (value) => _viewModel.updateChildContext(
                PersonChildContext(
                  id: childContext.id,
                  institutionId: childContext.institutionId,
                  institutionName: childContext.institutionName,
                  unitId: value.id.isEmpty ? null : value.id,
                  unitName: value.id.isEmpty ? null : value.label,
                  childUnitLinkId: childContext.childUnitLinkId,
                  childGroupLinkId: childContext.childGroupLinkId,
                ),
              ),
              prefixIcon: Icons.apartment_outlined,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            CoeloAdminSingleSelectField<PersonFilterOption>(
              label: 'Grupo',
              value: selectedGroup ?? _emptyOption,
              options: [_emptyOption, ...groupOptions],
              optionLabel: (value) => value.label,
              enabled: childContext.unitId != null,
              onChanged: (value) => _viewModel.updateChildContext(
                PersonChildContext(
                  id: childContext.id,
                  institutionId: childContext.institutionId,
                  institutionName: childContext.institutionName,
                  unitId: childContext.unitId,
                  unitName: childContext.unitName,
                  groupId: value.id.isEmpty ? null : value.id,
                  groupName: value.id.isEmpty ? null : value.label,
                  childUnitLinkId: childContext.childUnitLinkId,
                  childGroupLinkId: childContext.childGroupLinkId,
                ),
              ),
              prefixIcon: Icons.groups_outlined,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _viewModel.removeChildContext(childContext),
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('Revogar contexto'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PersonFilterOption _roleOption(String role, String institutionId) =>
      _options.roles
          .where((option) => option.id == role && option.institutionId == institutionId)
          .firstOrNull ??
      PersonFilterOption(role, role);

  void _addSelectedContext() {
    if (_viewModel.type == PersonType.child) {
      _viewModel.addChildContext(
        PersonChildContext(
          id: 'new-child-${_viewModel.childContexts.length}',
          institutionId: _selectedInstitution.id,
          institutionName: _selectedInstitution.label,
          unitId: _selectedUnit.id.isEmpty ? null : _selectedUnit.id,
          unitName: _selectedUnit.id.isEmpty ? null : _selectedUnit.label,
          groupId: _selectedGroup.id.isEmpty ? null : _selectedGroup.id,
          groupName: _selectedGroup.id.isEmpty ? null : _selectedGroup.label,
        ),
      );
    } else {
      _viewModel.addMembership(
        PersonMembership(
          id: 'new-${_viewModel.memberships.length}',
          institutionId: _selectedInstitution.id,
          institutionName: _selectedInstitution.label,
          unitId: _selectedUnit.id.isEmpty ? null : _selectedUnit.id,
          unitName: _selectedUnit.id.isEmpty ? null : _selectedUnit.label,
          groupId: _selectedGroup.id.isEmpty ? null : _selectedGroup.id,
          groupName: _selectedGroup.id.isEmpty ? null : _selectedGroup.label,
          role: _selectedRole.id,
        ),
      );
    }
    setState(() {
      _selectedInstitution = _emptyOption;
      _selectedUnit = _emptyOption;
      _selectedGroup = _emptyOption;
      _selectedRole = _emptyOption;
    });
  }

  Widget _review() => Column(
    key: const ValueKey(PersonFormStep.review),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Revisão', 'Confira os dados antes de salvar como rascunho.'),
      _reviewLine('Nome de exibição', _controllers['displayName']!.text),
      _reviewLine('Tipo', _viewModel.type.label),
      _reviewLine('Status', widget.original?.status.label ?? PersonStatus.draft.label),
      _reviewLine('Vínculos contextuais', '${_viewModel.memberships.length}'),
      const SizedBox(height: CoeloSpacing.space4),
      const CoeloStatePanel(
        title: 'Acesso não será ativado',
        message: 'Adultos não recebem login durante este cadastro.',
        icon: Icons.lock_outline_rounded,
      ),
    ],
  );

  Widget _readOnlySummaries(PersonDirectoryItem person) => Card(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _reviewLine('Tipo', person.type.label),
          _reviewLine('Status', person.status.label),
          _reviewLine('Vínculo Auth', person.authLink.label),
          _reviewLine(
            'Membership de plataforma',
            person.platformMembershipSummary ?? 'Não informado',
          ),
          _reviewLine('Vínculos de responsável', person.guardianLinksSummary ?? 'Não informado'),
        ],
      ),
    ),
  );

  Widget _reviewLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _responsiveFields(List<Widget> fields) => LayoutBuilder(
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

  Widget _footer() {
    if (_viewModel.isReadOnly) {
      return SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: widget.onCancel, child: const Text('Voltar')),
        ),
      );
    }
    final last = _viewModel.step == PersonFormStep.review;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actions = <Widget>[
              TextButton(
                onPressed: _viewModel.saving ? null : widget.onCancel,
                child: const Text('Cancelar'),
              ),
              if (_viewModel.step.index > 0)
                OutlinedButton(
                  onPressed: _viewModel.saving ? null : _viewModel.previous,
                  child: const Text('Anterior'),
                ),
              FilledButton(
                key: Key(last ? 'person-form-save' : 'person-form-continue'),
                onPressed: _viewModel.saving
                    ? null
                    : last
                    ? _save
                    : _continue,
                child: Text(last ? 'Salvar pessoa' : 'Continuar'),
              ),
            ];
            if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children:
                    actions.reversed
                        .expand((item) => [item, const SizedBox(height: CoeloSpacing.space2)])
                        .toList()
                      ..removeLast(),
              );
            }
            return Row(
              children: [
                actions.first,
                const Spacer(),
                for (final action in actions.skip(1)) ...[
                  action,
                  if (action != actions.last) const SizedBox(width: CoeloSpacing.space2),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
