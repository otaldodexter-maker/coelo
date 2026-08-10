import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../app/widgets/superadmin_advanced_color_picker_dialog.dart';
import '../../auth/domain/logout_action.dart';
import '../../institutions/data/institution_location_service.dart';
import '../../institutions/domain/institution_record.dart';
import '../../institutions/presentation/widgets/institution_form_dialogs.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../domain/unit_directory.dart';
import 'unit_form_controller.dart';
import 'unit_form_navigation.dart';
import 'widgets/unit_local_management_section.dart';

enum UnitFormSaveResult { created, updated }

final class UnitFormPage extends StatefulWidget {
  const UnitFormPage({
    required this.repository,
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.unitId,
    this.locationService,
    this.onDestinationSelected,
    this.onCreateGroup,
    this.onEditGroup,
    this.onCreateActivity,
    this.onEditActivity,
    super.key,
  });

  final UnitDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<UnitFormSaveResult> onSaved;
  final String? unitId;
  final InstitutionLocationService? locationService;
  final ValueChanged<String>? onDestinationSelected;
  final void Function(String institutionId, String? unitId)? onCreateGroup;
  final ValueChanged<String>? onEditGroup;
  final void Function(String institutionId, String? unitId)? onCreateActivity;
  final ValueChanged<String>? onEditActivity;

  @override
  State<UnitFormPage> createState() => _UnitFormPageState();
}

final class _UnitFormPageState extends State<UnitFormPage> {
  final _profileFormKey = GlobalKey<FormState>();
  final _locationFormKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  late final UnitFormController _formController;
  late final InstitutionLocationService _locationService;
  late InstitutionRecord _institution;
  List<InstitutionRecord> _institutions = const [];
  UnitRecord? _original;
  UnitStatus _status = UnitStatus.draft;
  late String _typeId;
  bool _inheritPlan = true;
  InstitutionPlan _plan = InstitutionPlan.essential;
  bool _inheritLogo = true;
  bool _inheritCover = true;
  bool _inheritSurfaceColors = true;
  bool _inheritBrandColors = true;
  bool _inheritTextColors = true;
  bool _hasLogo = false;
  bool _hasCover = false;
  bool _lookingUpPostalCode = false;
  double _footerHeight = 0;

  static const _fields = [
    'brandDisplayName',
    'accentColor',
    'secondaryColor',
    'textColor',
    'surfaceColor',
    'name',
    'slug',
    'postalCode',
    'country',
    'state',
    'city',
    'district',
    'street',
    'addressNumber',
    'complement',
    'contactEmail',
    'contactPhone',
    'contactMobilePhone',
  ];

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? InstitutionLocationService();
    _formController = UnitFormController(isEditing: widget.unitId != null);
    _formController.setLoadStatus(UnitFormLoadStatus.loading);
    _loadForm();
  }

  Future<void> _loadForm() async {
    try {
      final data = await widget.repository.loadForm(unitId: widget.unitId);
      _institutions = data.institutions;
      _original = data.record;
      final missingUnit = widget.unitId != null && _original == null;
      if (!missingUnit && _institutions.isNotEmpty) {
        _initializeForm();
      }
      _formController.setLoadStatus(
        missingUnit
            ? UnitFormLoadStatus.missing
            : _institutions.isEmpty
            ? UnitFormLoadStatus.failure
            : UnitFormLoadStatus.ready,
      );
    } on UnitDirectoryUnauthorizedException {
      _formController.setLoadStatus(UnitFormLoadStatus.unauthorized);
    } catch (_) {
      _formController.setLoadStatus(UnitFormLoadStatus.failure);
    }
  }

  void _initializeForm() {
    _institution = _original?.institution ?? _institutions.first;
    _status = _original?.status ?? UnitStatus.draft;
    _typeId = _original?.typeId.isNotEmpty == true ? _original!.typeId : _institution.typeId;
    _inheritPlan = _original?.planOverride == null;
    _plan = _original?.effectivePlan ?? _institution.plan;
    final inheritBranding = _original?.inheritInstitutionBranding ?? true;
    _inheritLogo = inheritBranding;
    _inheritCover = inheritBranding;
    _inheritSurfaceColors = inheritBranding;
    _inheritBrandColors = inheritBranding;
    _inheritTextColors = inheritBranding;
    _hasLogo = _original?.hasSimulatedLogo ?? false;
    _hasCover = _original?.hasSimulatedCover ?? false;
    for (final field in _fields) {
      _controllers[field] = TextEditingController(text: _initialValue(field));
      _controllers[field]!.addListener(_markDirty);
    }
  }

  void _markDirty() {
    _formController.markDirty();
  }

  String _initialValue(String field) {
    final original = _original;
    if (original == null) {
      return switch (field) {
        'country' => 'Brasil',
        'brandDisplayName' => '',
        'accentColor' => '#D63C00',
        'secondaryColor' => '#3F4549',
        'textColor' => '#3F4549',
        'surfaceColor' => '#FFFFFF',
        _ => '',
      };
    }
    return switch (field) {
      'brandDisplayName' => original.brandDisplayName,
      'accentColor' => original.accentColor,
      'secondaryColor' => original.secondaryColor,
      'textColor' => original.textColor,
      'surfaceColor' => original.surfaceColor,
      'name' => original.name,
      'slug' => original.slug,
      'postalCode' => original.postalCode,
      'country' => original.country,
      'state' => original.state,
      'city' => original.city,
      'district' => original.district,
      'street' => original.street,
      'addressNumber' => original.addressNumber,
      'complement' => original.complement,
      'contactEmail' => original.contactEmail,
      'contactPhone' => original.contactPhone,
      'contactMobilePhone' => original.contactMobilePhone,
      _ => '',
    };
  }

  String _text(String field) => _controllers[field]!.text.trim();

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _formController.dispose();
    if (widget.locationService == null) {
      _locationService.close();
    }
    super.dispose();
  }

  List<InstitutionRecord> get _institutionOptions => _institutions;
  List<InstitutionRecord> get _typeOptions {
    final values = <String, InstitutionRecord>{};
    for (final institution in _institutions) {
      values[institution.typeId] = institution;
    }
    return values.values.toList()
      ..sort((first, second) => first.typeName.compareTo(second.typeName));
  }

  void _continue() {
    final formKey = switch (_formController.currentStep) {
      UnitFormStep.profile => _profileFormKey,
      UnitFormStep.location => _locationFormKey,
      _ => null,
    };
    if (formKey != null && !_formController.validateCurrentStep(formKey)) {
      return;
    }
    _formController.nextStep();
  }

  Future<void> _save() async {
    if (!_formController.validateForSave(
      profileFormKey: _profileFormKey,
      locationFormKey: _locationFormKey,
    )) {
      return;
    }
    _formController.setSaving(true);
    _formController.setSaveError(null);
    try {
      final type = _typeOptions.firstWhere((option) => option.typeId == _typeId);
      final id = _original?.id ?? widget.repository.createId(_institution.id, _text('slug'));
      final unit = InstitutionUnit(
        id: id,
        name: _text('name'),
        slug: _text('slug'),
        status: _status,
        typeId: type.typeId,
        typeName: type.typeName,
        postalCode: _text('postalCode'),
        country: _text('country'),
        state: _text('state'),
        city: _text('city'),
        district: _text('district'),
        street: _text('street'),
        addressNumber: _text('addressNumber'),
        complement: _text('complement'),
        contactEmail: _text('contactEmail'),
        contactPhone: _text('contactPhone'),
        contactMobilePhone: _text('contactMobilePhone'),
        planOverride: _inheritPlan ? null : _plan,
        inheritInstitutionBranding:
            _inheritLogo &&
            _inheritCover &&
            _inheritSurfaceColors &&
            _inheritBrandColors &&
            _inheritTextColors,
        brandDisplayName: _text('brandDisplayName').isEmpty
            ? _text('name')
            : _text('brandDisplayName'),
        hasSimulatedLogo: _hasLogo,
        hasSimulatedCover: _hasCover,
        accentColor: _text('accentColor'),
        secondaryColor: _text('secondaryColor'),
        textColor: _text('textColor'),
        surfaceColor: _text('surfaceColor'),
        activitiesCount: _original?.activitiesCount ?? 0,
        groups: _original?.unit.groups ?? const [],
      );
      await widget.repository.upsert(UnitRecord(institution: _institution, unit: unit));
      if (!mounted) return;
      _formController.setSaving(false);
      _formController.markSaved();
      if (_original != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Alterações salvas localmente.')));
        return;
      }
      widget.onSaved(UnitFormSaveResult.created);
    } catch (_) {
      if (!mounted) return;
      _formController.setSaving(false);
      _formController.setSaveError(
        'Não foi possível salvar a unidade. Revise os dados e tente novamente.',
      );
    }
  }

  Future<void> _cancel() async {
    if (_formController.isDirty &&
        !await showInstitutionExitDialog(context, entityLabel: 'unidade')) {
      return;
    }
    widget.onCancel();
  }

  Future<void> _selectDestination(String destination) async {
    if (_formController.isDirty &&
        !await showInstitutionExitDialog(context, entityLabel: 'unidade')) {
      return;
    }
    widget.onDestinationSelected?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.unitId == null ? 'Criar unidade' : 'Editar unidade';
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, outerConstraints) => Theme(
        data: theme.copyWith(scaffoldBackgroundColor: theme.colorScheme.surface),
        child: SuperadminShell(
          logout: widget.logout,
          title: title,
          subtitle: widget.unitId == null
              ? 'Adicione uma nova unidade ao Coelo.'
              : 'Atualize os dados da unidade selecionada.',
          currentDestination: 'units',
          onDestinationSelected: _selectDestination,
          showChatLauncher:
              widget.onDestinationSelected != null &&
              outerConstraints.maxWidth >= CoeloBreakpoints.expanded.minWidth,
          chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
          child: AnimatedBuilder(
            animation: _formController,
            builder: (context, child) => _buildState(outerConstraints),
          ),
        ),
      ),
    );
  }

  Widget _buildState(BoxConstraints outerConstraints) {
    if (_formController.loadStatus == UnitFormLoadStatus.loading) {
      return const Center(child: CircularProgressIndicator(key: Key('unit-form-loading')));
    }
    if (_formController.loadStatus == UnitFormLoadStatus.unauthorized) {
      return CoeloStatePanel(
        key: const Key('unit-form-unauthorized'),
        title: 'Sem permissão para acessar esta unidade',
        message: 'Sua conta não possui acesso aos dados desta unidade.',
        icon: Icons.lock_outline_rounded,
        actionLabel: 'Voltar às unidades',
        onAction: widget.onCancel,
      );
    }
    if (_formController.loadStatus == UnitFormLoadStatus.failure) {
      return CoeloStatePanel(
        key: const Key('unit-form-error'),
        title: 'Não foi possível carregar a unidade',
        message: 'Tente novamente ou volte para a listagem.',
        icon: Icons.error_outline_rounded,
        actionLabel: 'Voltar às unidades',
        onAction: widget.onCancel,
      );
    }
    if (_formController.loadStatus == UnitFormLoadStatus.missing) {
      return CoeloStatePanel(
        key: const Key('unit-form-not-found'),
        title: 'Unidade não encontrada',
        message: 'O registro solicitado não existe nesta sessão local.',
        icon: Icons.search_off_rounded,
        actionLabel: 'Voltar às unidades',
        onAction: widget.onCancel,
      );
    }
    return PopScope(
      canPop: !_formController.isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: SuperadminFormFrame(
        viewportWidth: outerConstraints.maxWidth,
        navigation: UnitFormNavigation(controller: _formController),
        scrollKey: const Key('unit-form-scroll'),
        body: KeyedSubtree(key: const Key('unit-form-content'), child: _section()),
        footer: _footer(),
      ),
    );
  }

  Widget _section() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_formController.saveError != null) ...[
          Semantics(
            liveRegion: true,
            child: MaterialBanner(
              key: const Key('unit-form-save-error'),
              content: Text(_formController.saveError!),
              actions: [
                TextButton(
                  onPressed: () => _formController.setSaveError(null),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
        Stack(
          children: [
            for (final step in UnitFormStep.values)
              Offstage(
                offstage: step != _formController.currentStep,
                child: TickerMode(
                  enabled: step == _formController.currentStep,
                  child: KeyedSubtree(key: ValueKey(step), child: _stepContent(step)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stepContent(UnitFormStep step) => switch (step) {
    UnitFormStep.branding => _branding(),
    UnitFormStep.profile => _profile(),
    UnitFormStep.location => _location(),
    UnitFormStep.administrators => _localManagement(UnitLocalManagementKind.administrators),
    UnitFormStep.people => _localManagement(UnitLocalManagementKind.people),
    UnitFormStep.invitations => _localManagement(UnitLocalManagementKind.invitations),
    UnitFormStep.groups => _localManagement(UnitLocalManagementKind.groups),
    UnitFormStep.activities => _localManagement(UnitLocalManagementKind.activities),
    UnitFormStep.plan => _planSection(),
    UnitFormStep.review => _review(),
  };

  Widget _localManagement(UnitLocalManagementKind kind) {
    final inheritedAdministrators = kind == UnitLocalManagementKind.administrators
        ? [
            for (final administrator in _institution.administrators)
              UnitLocalEntry(
                name: administrator.person.displayName,
                detail: 'Owner · herdado da instituição',
                readOnly: true,
              ),
          ]
        : const <UnitLocalEntry>[];
    final initialEntries = switch (kind) {
      UnitLocalManagementKind.groups => [
        for (final group in _original?.unit.groups ?? const <InstitutionGroup>[])
          UnitLocalEntry(id: group.id, name: group.name, detail: 'Turma desta unidade'),
      ],
      UnitLocalManagementKind.activities => [
        for (var index = 0; index < (_original?.activitiesCount ?? 0); index++)
          UnitLocalEntry(
            id: 'activity-${index + 1}',
            name: 'Atividade ${index + 1}',
            detail: 'Atividade desta unidade',
          ),
      ],
      _ => const <UnitLocalEntry>[],
    };
    return UnitLocalManagementSection(
      kind: kind,
      inheritedEntries: inheritedAdministrators,
      initialEntries: initialEntries,
      onOpenCreateFlow: switch (kind) {
        UnitLocalManagementKind.groups =>
          widget.onCreateGroup == null
              ? null
              : () => widget.onCreateGroup!(_institution.id, _original?.unit.id),
        UnitLocalManagementKind.activities =>
          widget.onCreateActivity == null
              ? null
              : () => widget.onCreateActivity!(_institution.id, _original?.unit.id),
        _ => null,
      },
      onOpenEditFlow: switch (kind) {
        UnitLocalManagementKind.groups => widget.onEditGroup,
        UnitLocalManagementKind.activities => widget.onEditActivity,
        _ => null,
      },
      onChanged: _formController.markDirty,
    );
  }

  Widget _heading(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: CoeloSpacing.space1),
      Text(description, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: CoeloSpacing.space5),
    ],
  );

  Widget _branding() {
    final colors = Theme.of(context).colorScheme;
    final accent = _unitHexColor(
      _inheritBrandColors ? _institution.accentColor : _text('accentColor'),
      fallback: colors.primary,
    );
    final secondary = _unitHexColor(
      _inheritBrandColors ? _institution.secondaryColor : _text('secondaryColor'),
      fallback: colors.secondary,
    );
    final displayName = _inheritBrandColors
        ? (_institution.brandDisplayName.isEmpty
              ? _institution.publicName
              : _institution.brandDisplayName)
        : (_text('brandDisplayName').isEmpty
              ? (_text('name').isEmpty ? 'Nova unidade' : _text('name'))
              : _text('brandDisplayName'));
    final hasLogo = _inheritLogo ? _institution.hasSimulatedLogo : _hasLogo;
    final hasCover = _inheritCover ? _institution.hasSimulatedCover : _hasCover;
    final allInherited =
        _inheritLogo &&
        _inheritCover &&
        _inheritSurfaceColors &&
        _inheritBrandColors &&
        _inheritTextColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Identidade', 'Defina como a unidade será reconhecida no Coelo.'),
        _UnitBrandPreview(
          displayName: displayName,
          institutionName: _institution.publicName,
          accent: accent,
          secondary: secondary,
          hasLogo: hasLogo,
          hasCover: hasCover,
          inherited: allInherited,
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _InheritanceControl(
          controlKey: const Key('unit-inherit-logo'),
          title: 'Foto de perfil',
          institutionName: _institution.publicName,
          inherited: _inheritLogo,
          onChanged: (value) => setState(() {
            _inheritLogo = value;
            _formController.markDirty();
          }),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _UnitBrandMediaCard(
          key: const Key('unit-logo-card'),
          title: 'Foto de perfil',
          description: _inheritLogo
              ? 'Herdada de ${_institution.publicName}.'
              : 'Imagem quadrada em PNG, JPG ou WebP, com até 2 MB.',
          accent: accent,
          isCover: false,
          selected: hasLogo,
          inherited: _inheritLogo,
          onToggle: () => setState(() {
            _hasLogo = !_hasLogo;
            _formController.markDirty();
          }),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _InheritanceControl(
          controlKey: const Key('unit-inherit-cover'),
          title: 'Foto de capa',
          institutionName: _institution.publicName,
          inherited: _inheritCover,
          onChanged: (value) => setState(() {
            _inheritCover = value;
            _formController.markDirty();
          }),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _UnitBrandMediaCard(
          key: const Key('unit-cover-card'),
          title: 'Foto de capa',
          description: _inheritCover
              ? 'Herdada de ${_institution.publicName}.'
              : 'Imagem em PNG, JPG ou WebP, com até 2 MB.',
          accent: accent,
          isCover: true,
          selected: hasCover,
          inherited: _inheritCover,
          onToggle: () => setState(() {
            _hasCover = !_hasCover;
            _formController.markDirty();
          }),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _InheritanceControl(
          controlKey: const Key('unit-inherit-surface'),
          title: 'Cores de superfície',
          institutionName: _institution.publicName,
          inherited: _inheritSurfaceColors,
          onChanged: (value) => setState(() {
            _inheritSurfaceColors = value;
            _formController.markDirty();
          }),
        ),
        if (!_inheritSurfaceColors) ...[
          const SizedBox(height: CoeloSpacing.space3),
          _responsiveFields([_colorField('surfaceColor', 'Cor principal da superfície')]),
        ],
        const SizedBox(height: CoeloSpacing.space4),
        _InheritanceControl(
          controlKey: const Key('unit-inherit-brand'),
          title: 'Cores da marca',
          institutionName: _institution.publicName,
          inherited: _inheritBrandColors,
          onChanged: (value) => setState(() {
            _inheritBrandColors = value;
            _formController.markDirty();
          }),
        ),
        if (!_inheritBrandColors) ...[
          const SizedBox(height: CoeloSpacing.space3),
          _responsiveFields([
            _field('brandDisplayName', 'Nome de exibição', Icons.badge_outlined),
            _colorField('accentColor', 'Cor principal da marca'),
            _colorField('secondaryColor', 'Cor secundária da marca'),
          ]),
        ],
        const SizedBox(height: CoeloSpacing.space4),
        _InheritanceControl(
          controlKey: const Key('unit-inherit-text'),
          title: 'Cores de texto',
          institutionName: _institution.publicName,
          inherited: _inheritTextColors,
          onChanged: (value) => setState(() {
            _inheritTextColors = value;
            _formController.markDirty();
          }),
        ),
        if (!_inheritTextColors) ...[
          const SizedBox(height: CoeloSpacing.space3),
          _responsiveFields([_colorField('textColor', 'Cor principal do texto')]),
        ],
      ],
    );
  }

  Widget _profile() => Form(
    key: _profileFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Hierarquia', 'Informe instituição, unidade, tipo e status operacional.'),
        _responsiveFields([
          IgnorePointer(
            ignoring: _original != null,
            child: Opacity(
              opacity: _original == null ? 1 : .65,
              child: CoeloAdminSingleSelectField<InstitutionRecord>(
                key: const Key('unit-institution-field'),
                label: 'Instituição',
                value: _institution,
                options: _institutionOptions,
                optionLabel: (value) => value.publicName,
                onChanged: (value) => setState(() {
                  _institution = value;
                  _plan = value.plan;
                  _typeId = value.typeId;
                  _formController.markDirty();
                }),
                prefixIcon: Icons.account_balance_outlined,
              ),
            ),
          ),
          _field(
            'name',
            'Nome da unidade',
            Icons.apartment_outlined,
            key: const Key('unit-name-field'),
            required: true,
          ),
          _field(
            'slug',
            'Identificador',
            Icons.alternate_email_rounded,
            key: const Key('unit-slug-field'),
            required: true,
          ),
          CoeloAdminSingleSelectField<InstitutionRecord>(
            label: 'Tipo',
            value: _typeOptions.firstWhere((value) => value.typeId == _typeId),
            options: _typeOptions,
            optionLabel: (value) => value.typeName,
            onChanged: (value) => setState(() {
              _typeId = value.typeId;
              _formController.markDirty();
            }),
            prefixIcon: Icons.category_outlined,
          ),
          CoeloAdminSingleSelectField<UnitStatus>(
            label: 'Status operacional',
            value: _status,
            options: UnitStatus.values,
            optionLabel: (value) => value.label,
            onChanged: (value) => setState(() {
              _status = value;
              _formController.markDirty();
            }),
            prefixIcon: Icons.toggle_on_outlined,
          ),
        ]),
      ],
    ),
  );

  Future<void> _lookupPostalCode() async {
    final postalCode = _text('postalCode').replaceAll(RegExp(r'\D'), '');
    if (postalCode.length != 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Informe um CEP com 8 números.')));
      return;
    }
    setState(() => _lookingUpPostalCode = true);
    try {
      final address = await _locationService.lookupPostalCode(postalCode);
      if (!mounted) return;
      _controllers['country']!.text = 'Brasil';
      _controllers['state']!.text = address.state;
      _controllers['city']!.text = address.municipality;
      _controllers['district']!.text = address.district;
      _controllers['street']!.text = address.street;
    } on InstitutionLocationException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não foi possível buscar este CEP.')));
      }
    } finally {
      if (mounted) {
        setState(() => _lookingUpPostalCode = false);
      }
    }
  }

  Widget _location() => Form(
    key: _locationFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Localização', 'Cadastre endereço e canais da unidade.'),
        _responsiveFields([
          _field(
            'postalCode',
            'CEP',
            Icons.location_searching_outlined,
            suffixIcon: IconButton(
              key: const Key('unit-postal-code-lookup'),
              tooltip: 'Buscar CEP',
              style: _semanticIconActionStyle(context),
              onPressed: _lookingUpPostalCode ? null : _lookupPostalCode,
              icon: _lookingUpPostalCode
                  ? const SizedBox.square(
                      key: Key('unit-postal-code-loading'),
                      dimension: CoeloSize.iconMd,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore_rounded),
            ),
          ),
          _field('country', 'País', Icons.public_outlined),
          _field('state', 'UF', Icons.map_outlined),
          _field('city', 'Município', Icons.location_city_outlined),
          _field('district', 'Bairro', Icons.place_outlined),
          _field('street', 'Logradouro', Icons.signpost_outlined),
          _field('addressNumber', 'Número', Icons.numbers_outlined),
          _field('complement', 'Complemento', Icons.add_home_outlined),
          _field(
            'contactEmail',
            'E-mail',
            Icons.email_outlined,
            key: const Key('unit-contact-email-field'),
          ),
          _field('contactPhone', 'Telefone', Icons.phone_outlined),
          _field('contactMobilePhone', 'Celular', Icons.smartphone_outlined),
        ]),
      ],
    ),
  );

  Widget _planSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Plano', 'A unidade pode acompanhar a instituição ou usar um override.'),
      _UnitPlanSummary(
        institutionName: _institution.publicName,
        plan: _inheritPlan ? _institution.plan : _plan,
        inherited: _inheritPlan,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminToggleField(
        key: const Key('unit-inherit-plan'),
        label: 'Herdar plano da instituição',
        description: 'Plano institucional: ${_institution.plan.label}',
        value: _inheritPlan,
        onChanged: (value) => setState(() {
          _inheritPlan = value;
          if (value) _plan = _institution.plan;
          _formController.markDirty();
        }),
      ),
      if (!_inheritPlan)
        Padding(
          padding: const EdgeInsets.only(top: CoeloSpacing.space4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
              final width = twoColumns
                  ? (constraints.maxWidth - CoeloSpacing.space3) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: CoeloSpacing.space3,
                runSpacing: CoeloSpacing.space3,
                children: [
                  for (final plan in InstitutionPlan.values)
                    SizedBox(
                      width: width,
                      child: _UnitPlanCard(
                        plan: plan,
                        selected: plan == _plan,
                        onPressed: () => setState(() {
                          _plan = plan;
                          _formController.markDirty();
                        }),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
    ],
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Revisão', 'Confira os dados antes de concluir. Você pode editar qualquer seção.'),
      _UnitReviewCard(
        editKey: const Key('unit-review-edit-profile'),
        title: 'Hierarquia',
        summary:
            '${_text('name')} · ${_institution.publicName}\n'
            '${_typeOptions.firstWhere((value) => value.typeId == _typeId).typeName} · '
            '${_status.label}',
        onEdit: () => _formController.selectStep(UnitFormStep.profile),
      ),
      _UnitReviewCard(
        editKey: const Key('unit-review-edit-location'),
        title: 'Localização',
        summary: _text('city').isEmpty && _text('state').isEmpty
            ? 'Não informado'
            : '${_text('city')} / ${_text('state')}',
        onEdit: () => _formController.selectStep(UnitFormStep.location),
      ),
      _UnitReviewCard(
        editKey: const Key('unit-review-edit-plan'),
        title: 'Plano',
        summary: _inheritPlan
            ? '${_institution.plan.label} · herdado de ${_institution.publicName}'
            : '${_plan.label} · específico da unidade',
        onEdit: () => _formController.selectStep(UnitFormStep.plan),
      ),
      _UnitReviewCard(
        editKey: const Key('unit-review-edit-branding'),
        title: 'Identidade',
        summary:
            _inheritLogo &&
                _inheritCover &&
                _inheritSurfaceColors &&
                _inheritBrandColors &&
                _inheritTextColors
            ? 'Herdada de ${_institution.publicName}'
            : 'Herança configurada por contexto',
        onEdit: () => _formController.selectStep(UnitFormStep.branding),
      ),
      for (final item in const [
        (UnitFormStep.administrators, 'Administradores'),
        (UnitFormStep.people, 'Pessoas'),
        (UnitFormStep.invitations, 'Convites'),
        (UnitFormStep.groups, 'Turmas'),
        (UnitFormStep.activities, 'Atividades'),
      ])
        _UnitReviewCard(
          editKey: Key('unit-review-edit-${item.$1.name}'),
          title: item.$2,
          summary: 'Dados mantidos localmente nesta sessão.',
          onEdit: () => _formController.selectStep(item.$1),
        ),
    ],
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

  Widget _field(
    String id,
    String label,
    IconData icon, {
    Key? key,
    bool required = false,
    Widget? suffixIcon,
  }) {
    return CoeloFormTextField(
      fieldKey: key,
      controller: _controllers[id]!,
      labelText: label,
      prefixIcon: icon,
      suffixIcon: suffixIcon,
      validator: (value) {
        final normalized = value?.trim() ?? '';
        if (required && normalized.isEmpty) return 'Campo obrigatório.';
        if (id == 'contactEmail' &&
            normalized.isNotEmpty &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
          return 'Informe um e-mail válido.';
        }
        if (id == 'slug' &&
            normalized.isNotEmpty &&
            widget.repository.records.any(
              (record) =>
                  record.institutionId == _institution.id &&
                  record.id != _original?.id &&
                  record.slug == normalized,
            )) {
          return 'Identificador já usado nesta instituição.';
        }
        return null;
      },
    );
  }

  Widget _colorField(String id, String label) {
    final color = _unitHexColor(_text(id), fallback: Theme.of(context).colorScheme.primary);
    return _field(
      id,
      label,
      Icons.palette_outlined,
      suffixIcon: IconButton(
        key: Key('unit-color-picker-$id'),
        tooltip: 'Selecionar $label',
        style: _semanticIconActionStyle(context),
        onPressed: () async {
          final selected = await showSuperadminAdvancedColorPicker(
            context,
            initialColor: color,
            title: label,
          );
          if (selected != null) {
            _controllers[id]!.text =
                '#${selected.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
          }
        },
        icon: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: const SizedBox.square(dimension: CoeloSize.iconMd),
        ),
      ),
    );
  }

  Widget _footer() {
    final currentStep = _formController.currentStep;
    final previous = currentStep.index > 0 ? _formController.previousStep : null;
    final last = currentStep == UnitFormStep.review;
    final primary = last
        ? FilledButton(
            key: const Key('unit-form-save'),
            onPressed: _formController.isSaving ? null : _save,
            child: _formController.isSaving
                ? const SizedBox.square(
                    dimension: CoeloSize.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_original == null ? 'Criar unidade' : 'Salvar alterações'),
          )
        : _original == null
        ? FilledButton(
            key: const Key('unit-form-continue'),
            onPressed: _formController.isSaving ? null : _continue,
            child: const Text('Continuar'),
          )
        : OutlinedButton(
            key: const Key('unit-form-continue'),
            onPressed: _formController.isSaving ? null : _continue,
            child: const Text('Continuar'),
          );
    final saveCurrentButton = FilledButton(
      key: const Key('unit-form-save-current'),
      onPressed: _formController.isSaving ? null : _save,
      child: _formController.isSaving
          ? const SizedBox.square(
              dimension: CoeloSize.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Salvar'),
    );
    return SuperadminFormActionFooter(
      surfaceKey: const Key('unit-form-footer'),
      onHeightChanged: (height) {
        if ((_footerHeight - height).abs() < 0.5) return;
        setState(() => _footerHeight = height);
      },
      tertiaryAction: TextButton(
        onPressed: _formController.isSaving ? null : _cancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        if (previous != null) OutlinedButton(onPressed: previous, child: const Text('Anterior')),
        primary,
        if (_original != null && !last) saveCurrentButton,
      ],
    );
  }
}

final class _InheritanceControl extends StatelessWidget {
  const _InheritanceControl({
    required this.controlKey,
    required this.title,
    required this.institutionName,
    required this.inherited,
    required this.onChanged,
  });

  final Key controlKey;
  final String title;
  final String institutionName;
  final bool inherited;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: CoeloSpacing.spaceHalf),
            Text(
              inherited ? 'Herdado de $institutionName.' : 'Personalizado nesta unidade.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
        final action = OutlinedButton.icon(
          key: controlKey,
          onPressed: () => onChanged(!inherited),
          icon: Icon(inherited ? Icons.link_off_rounded : Icons.link_rounded),
          label: Text(inherited ? 'Personalizar' : 'Herdar'),
        );
        if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copy,
              const SizedBox(height: CoeloSpacing.space3),
              action,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: CoeloSpacing.space4),
            action,
          ],
        );
      },
    );
  }
}

final class _UnitBrandPreview extends StatelessWidget {
  const _UnitBrandPreview({
    required this.displayName,
    required this.institutionName,
    required this.accent,
    required this.secondary,
    required this.hasLogo,
    required this.hasCover,
    required this.inherited,
  });

  final String displayName;
  final String institutionName;
  final Color accent;
  final Color secondary;
  final bool hasLogo;
  final bool hasCover;
  final bool inherited;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('unit-brand-preview'),
      width: double.infinity,
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasCover) ...[
            Container(
              height: CoeloSize.touchMin,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(CoeloRadius.md),
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
          ],
          Row(
            children: [
              if (hasLogo) ...[
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.18),
                  foregroundColor: colors.onSurface,
                  child: Text(_unitInitials(displayName)),
                ),
                const SizedBox(width: CoeloSpacing.space3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      inherited
                          ? 'Identidade herdada de $institutionName'
                          : 'Prévia da unidade no Coelo',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _UnitColorSwatch(color: accent, label: 'Destaque'),
              const SizedBox(width: CoeloSpacing.space2),
              _UnitColorSwatch(color: secondary, label: 'Secundária'),
            ],
          ),
        ],
      ),
    );
  }
}

final class _UnitColorSwatch extends StatelessWidget {
  const _UnitColorSwatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cor $label',
      child: Tooltip(
        message: label,
        child: Container(
          width: CoeloSize.touchMin,
          height: CoeloSize.touchMin,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ),
    );
  }
}

final class _UnitBrandMediaCard extends StatelessWidget {
  const _UnitBrandMediaCard({
    required this.title,
    required this.description,
    required this.accent,
    required this.isCover,
    required this.selected,
    required this.inherited,
    required this.onToggle,
    super.key,
  });

  final String title;
  final String description;
  final Color accent;
  final bool isCover;
  final bool selected;
  final bool inherited;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final preview = Container(
      width: isCover ? CoeloSize.touchMin * 3 : CoeloSize.touchMin * 2,
      height: CoeloSize.touchMin * 2,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(isCover ? CoeloRadius.md : CoeloRadius.full),
        border: isCover ? Border.all(color: colors.outlineVariant) : null,
      ),
      child: Icon(
        isCover ? Icons.panorama_outlined : Icons.apartment_rounded,
        color: colors.primary,
        size: CoeloSize.iconLg,
      ),
    );
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Wrap(
        spacing: CoeloSpacing.space4,
        runSpacing: CoeloSpacing.space3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          preview,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: CoeloSpacing.spaceHalf),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: CoeloSpacing.space2),
                if (inherited)
                  Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: CoeloSize.iconSm,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: CoeloSpacing.space1),
                      Expanded(
                        child: Text(
                          'Gerenciada pela instituição',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ],
                  )
                else
                  Wrap(
                    spacing: CoeloSpacing.space2,
                    children: [
                      OutlinedButton.icon(
                        key: Key(isCover ? 'unit-cover-picker' : 'unit-logo-picker'),
                        onPressed: onToggle,
                        icon: const Icon(Icons.upload_rounded),
                        label: Text(
                          selected
                              ? isCover
                                    ? 'Trocar capa'
                                    : 'Trocar foto'
                              : isCover
                              ? 'Escolher capa'
                              : 'Escolher foto',
                        ),
                      ),
                      if (selected)
                        TextButton(
                          key: Key(isCover ? 'unit-cover-remove' : 'unit-logo-remove'),
                          style: _negativeTextActionStyle(context),
                          onPressed: onToggle,
                          child: const Text('Remover'),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _UnitPlanSummary extends StatelessWidget {
  const _UnitPlanSummary({
    required this.institutionName,
    required this.plan,
    required this.inherited,
  });

  final String institutionName;
  final InstitutionPlan plan;
  final bool inherited;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('unit-plan-summary'),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: CoeloSize.touchMin,
            height: CoeloSize.touchMin,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(CoeloRadius.md),
            ),
            child: Icon(Icons.sell_outlined, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.label, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  inherited
                      ? 'Plano efetivo herdado de $institutionName'
                      : 'Plano específico desta unidade',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          CoeloStatusChip(
            label: inherited ? 'Herdado' : 'Override',
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            icon: inherited ? Icons.link_rounded : Icons.tune_rounded,
          ),
        ],
      ),
    );
  }
}

final class _UnitPlanCard extends StatelessWidget {
  const _UnitPlanCard({required this.plan, required this.selected, required this.onPressed});

  final InstitutionPlan plan;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final description = switch (plan) {
      InstitutionPlan.essential => 'Comunicação, agenda e rotina',
      InstitutionPlan.professional => 'Essencial + gestão ampliada',
      InstitutionPlan.complete => 'Todos os módulos do Coelo',
      InstitutionPlan.custom => 'Composição personalizada',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: 'Plano ${plan.label}',
      child: OutlinedButton(
        key: Key('unit-plan-${plan.name}'),
        onPressed: onPressed,
        style:
            OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(104),
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
            ).copyWith(
              side: WidgetStatePropertyAll(
                BorderSide(
                  color: selected ? colors.primary : colors.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                final isActive =
                    states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
                return selected || isActive ? colors.primaryContainer : colors.surface;
              }),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(plan.label, style: Theme.of(context).textTheme.titleMedium),
                  Text(description, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _UnitReviewCard extends StatelessWidget {
  const _UnitReviewCard({
    required this.editKey,
    required this.title,
    required this.summary,
    required this.onEdit,
  });

  final Key editKey;
  final String title;
  final String summary;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  Text(summary.isEmpty ? 'Não informado' : summary),
                ],
              ),
            ),
            TextButton(key: editKey, onPressed: onEdit, child: const Text('Editar')),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _semanticIconActionStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(colors.primary),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
        return colors.primaryContainer;
      }
      return Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

ButtonStyle _negativeTextActionStyle(BuildContext context) {
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

String _unitInitials(String value) {
  final words = value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
  if (words.isEmpty) return 'U';
  final initials = words.length > 1 ? '${words.first[0]}${words.last[0]}' : words.first;
  return initials.substring(0, initials.length.clamp(0, 2)).toUpperCase();
}

Color _unitHexColor(String value, {required Color fallback}) {
  final normalized = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
    return fallback;
  }
  return Color(int.parse('FF$normalized', radix: 16));
}
