import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/activity/superadmin_activity.dart';
import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/person_directory.dart';
import 'person_form_view_model.dart';

const _emptyOption = PersonFilterOption('', 'Selecione');

final class _LinkCandidate {
  const _LinkCandidate({
    required this.id,
    required this.name,
    required this.searchableData,
    required this.summary,
  });

  final String id;
  final String name;
  final String searchableData;
  final String summary;
}

const _adultLinkCandidates = [
  _LinkCandidate(
    id: 'adult-ana',
    name: 'Ana Souza',
    searchableData: 'ana souza @ana.coelo ***.456.***-** a***@exemplo.test (11) 9****-1204',
    summary: '@ana.coelo · CPF ***.456.***-** · a***@exemplo.test · (11) 9****-1204',
  ),
  _LinkCandidate(
    id: 'adult-caio',
    name: 'Caio Lima',
    searchableData: 'caio lima @caio.lima ***.802.***-** c***@exemplo.test (21) 9****-7712',
    summary: '@caio.lima · CPF ***.802.***-** · c***@exemplo.test · (21) 9****-7712',
  ),
];

const _childLinkCandidates = [
  _LinkCandidate(
    id: 'child-lia',
    name: 'Lia Coelo',
    searchableData: 'lia coelo crianca-014 turma girassol unidade centro',
    summary: 'ID criança-014 · Turma Girassol · Unidade Centro',
  ),
  _LinkCandidate(
    id: 'child-noah',
    name: 'Noah Coelo',
    searchableData: 'noah coelo crianca-027 turma ipê grupo unidade jardins',
    summary: 'ID criança-027 · Turma Ipê · Unidade Jardins',
  ),
];

final class PersonFormPage extends StatefulWidget {
  const PersonFormPage({
    required this.repository,
    required this.logout,
    this.original,
    this.onCancel,
    this.onSaved,
    this.onDestinationSelected,
    this.onOpenChildSecurity,
    this.initialInstitutionId,
    this.initialUnitId,
    this.initialGroupId,
    this.initialRole,
    this.initialPersonType,
    super.key,
  });

  final PersonDirectoryRepository repository;
  final LogoutAction logout;
  final PersonDirectoryItem? original;
  final VoidCallback? onCancel;
  final ValueChanged<PersonDirectoryItem>? onSaved;
  final ValueChanged<String>? onDestinationSelected;
  final VoidCallback? onOpenChildSecurity;
  final String? initialInstitutionId;
  final String? initialUnitId;
  final String? initialGroupId;
  final String? initialRole;
  final PersonType? initialPersonType;

  @override
  State<PersonFormPage> createState() => _PersonFormPageState();
}

final class _PersonFormSurface extends StatelessWidget {
  const _PersonFormSurface({super.key, required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

final class _RelationshipSearch extends StatefulWidget {
  const _RelationshipSearch();

  @override
  State<_RelationshipSearch> createState() => _RelationshipSearchState();
}

final class _RelationshipSearchState extends State<_RelationshipSearch> {
  final _adultController = TextEditingController();
  final _childController = TextEditingController();
  String _adultQuery = '';
  String _childQuery = '';
  String? _selectedAdultId;
  String? _selectedChildId;

  Iterable<_LinkCandidate> _matches(List<_LinkCandidate> candidates, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    return candidates.where(
      (candidate) => candidate.searchableData.toLowerCase().contains(normalized),
    );
  }

  Widget _results(
    Iterable<_LinkCandidate> candidates, {
    required String? selectedId,
    required ValueChanged<_LinkCandidate> onSelected,
    required String keyPrefix,
  }) => Column(
    children: [
      for (final candidate in candidates)
        TextButton(
          key: Key('$keyPrefix-${candidate.id}'),
          onPressed: () => onSelected(candidate),
          style: ButtonStyle(
            alignment: Alignment.centerLeft,
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            minimumSize: const WidgetStatePropertyAll(Size(0, CoeloSize.touchMin)),
            foregroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.onSurface),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              final highlighted =
                  selectedId == candidate.id ||
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused);
              return highlighted
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent;
            }),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(candidate.name), Text(candidate.summary)],
                  ),
                ),
                Icon(
                  selectedId == candidate.id
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                ),
              ],
            ),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    _adultController.dispose();
    _childController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    key: const Key('person-relationship-search-section'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Buscar vínculos existentes', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space4),
      Text('Buscar adulto existente', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: CoeloSpacing.space1),
      const Text('Consulte por nome ou dados mascarados de e-mail e celular.'),
      const SizedBox(height: CoeloSpacing.space2),
      SizedBox(
        height: CoeloSize.touchMin,
        child: CoeloSearchField(
          key: const Key('person-adult-link-search'),
          controller: _adultController,
          hintText: 'Nome, arroba, CPF ou contato mascarado',
          semanticLabel: 'Buscar adulto por nome, arroba, CPF, e-mail ou celular mascarados',
          onChanged: (value) => setState(() => _adultQuery = value),
        ),
      ),
      _results(
        _matches(_adultLinkCandidates, _adultQuery),
        selectedId: _selectedAdultId,
        keyPrefix: 'person-adult-link-result',
        onSelected: (candidate) => setState(() => _selectedAdultId = candidate.id),
      ),
      if (_selectedAdultId case final id?)
        Padding(
          padding: const EdgeInsets.only(top: CoeloSpacing.space2),
          child: Text(
            'Vínculo selecionado: ${_adultLinkCandidates.firstWhere((item) => item.id == id).name}',
          ),
        ),
      const SizedBox(height: CoeloSpacing.space4),
      Text('Buscar criança existente', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: CoeloSpacing.space1),
      const Text(
        'Consulte por nome, identificador ou contexto; e-mail e celular não são exigidos.',
      ),
      const SizedBox(height: CoeloSpacing.space2),
      SizedBox(
        height: CoeloSize.touchMin,
        child: CoeloSearchField(
          key: const Key('person-child-link-search'),
          controller: _childController,
          hintText: 'Nome, identificador ou contexto',
          semanticLabel: 'Buscar criança por nome, identificador ou contexto',
          onChanged: (value) => setState(() => _childQuery = value),
        ),
      ),
      _results(
        _matches(_childLinkCandidates, _childQuery),
        selectedId: _selectedChildId,
        keyPrefix: 'person-child-link-result',
        onSelected: (candidate) => setState(() => _selectedChildId = candidate.id),
      ),
    ],
  );
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
  double _footerHeight = 0;

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
    if (widget.initialPersonType != null) {
      _viewModel.type = widget.initialPersonType!;
    }
    _activityController = SuperadminActivityController();
    _controllers = {
      'firstName': TextEditingController(text: _viewModel.firstName),
      'lastName': TextEditingController(text: _viewModel.lastName),
      'displayName': TextEditingController(text: _viewModel.displayName),
      'legalName': TextEditingController(text: _viewModel.legalName),
      'postalCode': TextEditingController(),
      'street': TextEditingController(),
      'number': TextEditingController(),
      'complement': TextEditingController(),
      'neighborhood': TextEditingController(),
      'city': TextEditingController(),
      'state': TextEditingController(),
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
      if (widget.initialInstitutionId != null) {
        _applyInitialMembershipContext();
      }
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

  void _applyInitialMembershipContext() {
    final institution = _options.institutions
        .where((option) => option.id == widget.initialInstitutionId)
        .firstOrNull;
    if (institution == null) return;

    _selectedInstitution = institution;
    if (widget.initialUnitId != null) {
      final unit = _options.units
          .where(
            (option) => option.id == widget.initialUnitId && option.institutionId == institution.id,
          )
          .firstOrNull;
      if (unit != null) {
        _selectedUnit = unit;
      }
    }
    if (widget.initialGroupId != null) {
      final group = _options.groups
          .where(
            (option) =>
                option.id == widget.initialGroupId &&
                option.institutionId == institution.id &&
                option.unitId == _selectedUnit.id,
          )
          .firstOrNull;
      if (group != null) {
        _selectedGroup = group;
      }
    }
    if (widget.initialRole != null) {
      final role = _options.roles
          .where(
            (option) => option.id == widget.initialRole && option.institutionId == institution.id,
          )
          .firstOrNull;
      if (role != null) {
        _selectedRole = role;
      }
    } else if (_roleOptions.isNotEmpty) {
      _selectedRole = _roleOptions.first;
    }
    setState(() {});
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
    final steps = _viewModel.steps;
    final currentIndex = steps.indexOf(_viewModel.step);
    final targetIndex = steps.indexOf(step);
    if (currentIndex < 0 || targetIndex < 0) return;
    if (targetIndex < currentIndex) {
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
    chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
    onDestinationSelected: widget.onDestinationSelected,
    child: AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) => SuperadminFormFrame(
        viewportWidth: MediaQuery.sizeOf(context).width,
        scrollKey: const Key('person-form-scroll'),
        navigation: _navigation(),
        body: _section(),
        footer: _footer(),
      ),
    ),
  );

  Widget _navigation() {
    final steps = _viewModel.steps;
    final currentIndex = steps.indexOf(_viewModel.step);
    return KeyedSubtree(
      key: const Key('person-form-navigation'),
      child: SuperadminFormStepNavigation(
        steps: [
          for (var index = 0; index < steps.length; index++)
            SuperadminFormStep(
              label: _stepLabel(steps[index]),
              status: index == currentIndex
                  ? SuperadminFormStepStatus.current
                  : index < currentIndex
                  ? SuperadminFormStepStatus.complete
                  : SuperadminFormStepStatus.incomplete,
              enabled: !_viewModel.isReadOnly,
            ),
        ],
        currentIndex: currentIndex,
        onStepSelected: (index) => _selectStep(steps[index]),
      ),
    );
  }

  String _stepLabel(PersonFormStep step) => switch (step) {
    PersonFormStep.identity => 'Identidade',
    PersonFormStep.contexts => 'Vínculos contextuais',
    PersonFormStep.review => 'Revisão',
  };
  Widget _section() => KeyedSubtree(
    key: ValueKey(_viewModel.step),
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

  ButtonStyle _negativeActionStyle() {
    final colors = Theme.of(context).colorScheme;
    return ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(colors.error),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
          return colors.errorContainer;
        }
        return Colors.transparent;
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

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
        const SizedBox(height: CoeloSpacing.space5),
        _localAddress(),
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

  Widget _localAddress() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Endereço local', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space4),
      _responsiveFields([
        CoeloFormTextField(
          fieldKey: const Key('person-address-postal-code'),
          controller: _controllers['postalCode']!,
          labelText: 'CEP',
          prefixIcon: Icons.local_post_office_outlined,
        ),
        CoeloFormTextField(
          fieldKey: const Key('person-address-street'),
          controller: _controllers['street']!,
          labelText: 'Logradouro',
          prefixIcon: Icons.signpost_outlined,
        ),
        CoeloFormTextField(
          controller: _controllers['number']!,
          labelText: 'Número',
          prefixIcon: Icons.pin_outlined,
        ),
        CoeloFormTextField(
          controller: _controllers['complement']!,
          labelText: 'Complemento',
          prefixIcon: Icons.add_home_outlined,
        ),
        CoeloFormTextField(
          controller: _controllers['neighborhood']!,
          labelText: 'Bairro',
          prefixIcon: Icons.location_city_outlined,
        ),
        CoeloFormTextField(
          fieldKey: const Key('person-address-city'),
          controller: _controllers['city']!,
          labelText: 'Município',
          prefixIcon: Icons.location_city_outlined,
        ),
        CoeloFormTextField(
          controller: _controllers['state']!,
          labelText: 'UF',
          prefixIcon: Icons.map_outlined,
        ),
      ]),
    ],
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
              : 'Associe instituições, unidades, turmas e papéis sem alterar outros vínculos.',
        ),
        Text('Relações com outras pessoas', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space1),
        const Text(
          'Busque uma pessoa existente para representar uma relação pessoal separada do acesso institucional.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        const _RelationshipSearch(),
        const SizedBox(height: CoeloSpacing.space5),
        Text('Contexto institucional', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: CoeloSpacing.space1),
        const Text(
          'Selecione Instituição, Unidade e Turma em ordem. O Perfil de acesso define o acesso contextual do funcionário.',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        if (_viewModel.type == PersonType.adult)
          for (final (index, membership) in _viewModel.memberships.indexed) ...[
            if (index > 0) const SizedBox(height: CoeloSpacing.space3),
            _PersonFormSurface(
              key: Key('person-membership-card-${membership.id}'),
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(membership.institutionName, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: CoeloSpacing.space2),
                  Text([membership.unitName, membership.groupName].whereType<String>().join(' • ')),
                  const SizedBox(height: CoeloSpacing.space3),
                  CoeloAdminSingleSelectField<PersonFilterOption>(
                    label: 'Perfil de acesso',
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
                      style: _negativeActionStyle(),
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Revogar vínculo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        if (_viewModel.type == PersonType.child)
          for (final (index, childContext) in _viewModel.childContexts.indexed) ...[
            if (index > 0) const SizedBox(height: CoeloSpacing.space3),
            _childContextEditor(childContext),
          ],
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
              label: 'Turma',
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
                label: 'Perfil de acesso',
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
    return _PersonFormSurface(
      key: Key('person-child-context-card-${childContext.id}'),
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
            label: 'Turma',
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
              style: _negativeActionStyle(),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Revogar contexto'),
            ),
          ),
        ],
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
      return SuperadminFormActionFooter(
        surfaceKey: const Key('person-form-footer-surface'),
        onHeightChanged: _setFooterHeight,
        tertiaryAction: TextButton(onPressed: widget.onCancel, child: const Text('Voltar')),
        continuationActions: const [SizedBox.shrink()],
      );
    }
    final last = _viewModel.step == PersonFormStep.review;
    final currentStepIndex = _viewModel.steps.indexOf(_viewModel.step);
    return SuperadminFormActionFooter(
      surfaceKey: const Key('person-form-footer-surface'),
      onHeightChanged: _setFooterHeight,
      tertiaryAction: TextButton(
        onPressed: _viewModel.saving ? null : widget.onCancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        if (currentStepIndex > 0)
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
      ],
    );
  }

  void _setFooterHeight(double height) {
    if ((_footerHeight - height).abs() < .5 || !mounted) return;
    setState(() => _footerHeight = height);
  }
}
