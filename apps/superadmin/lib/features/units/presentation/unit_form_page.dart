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
import '../domain/unit_directory.dart';
import 'unit_form_controller.dart';
import 'unit_form_navigation.dart';

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
    super.key,
  });

  final UnitDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<UnitFormSaveResult> onSaved;
  final String? unitId;
  final InstitutionLocationService? locationService;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<UnitFormPage> createState() => _UnitFormPageState();
}

final class _UnitFormPageState extends State<UnitFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _footerKey = GlobalKey();
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
  bool _inheritBranding = true;
  bool _hasLogo = false;
  bool _hasCover = false;
  bool _lookingUpPostalCode = false;
  double _footerHeight = 0;
  bool _footerMeasurementScheduled = false;

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
    _inheritBranding = _original?.inheritInstitutionBranding ?? true;
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
    if (!_formController.validateCurrentStep(_formKey)) {
      return;
    }
    _formController.nextStep();
  }

  Future<void> _save() async {
    if (!_formController.validateForSave(_formKey)) {
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
        inheritInstitutionBranding: _inheritBranding,
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
    return LayoutBuilder(
      builder: (context, outerConstraints) => SuperadminShell(
        logout: widget.logout,
        title: title,
        subtitle: widget.unitId == null
            ? 'Adicione uma nova unidade ao Coelo.'
            : 'Atualize os dados da unidade selecionada.',
        currentDestination: 'units',
        onDestinationSelected: _selectDestination,
        chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
        child: AnimatedBuilder(
          animation: _formController,
          builder: (context, child) => _buildState(outerConstraints),
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
    _scheduleFooterMeasurement();
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, child) => PopScope(
        canPop: !_formController.isDirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _cancel();
        },
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = outerConstraints.maxWidth >= CoeloBreakpoints.large.minWidth;
              final contentInset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
                  ? CoeloSpacing.space10
                  : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
                  ? CoeloSpacing.space6
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
                    if (desktop) ...[
                      UnitFormNavigation(controller: _formController),
                      const SizedBox(width: CoeloSpacing.space6),
                    ],
                    Expanded(
                      child: Column(
                        children: [
                          if (!desktop) ...[
                            UnitFormNavigation(controller: _formController),
                            const SizedBox(height: CoeloSpacing.space4),
                          ],
                          Expanded(
                            child: SingleChildScrollView(
                              key: const Key('unit-form-scroll'),
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
      ),
    );
  }

  void _scheduleFooterMeasurement() {
    if (_footerMeasurementScheduled) return;
    _footerMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _footerMeasurementScheduled = false;
      if (!mounted) return;
      final renderObject = _footerKey.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      final nextHeight = renderObject.size.height;
      if ((nextHeight - _footerHeight).abs() < 0.5) return;
      setState(() => _footerHeight = nextHeight);
    });
  }

  Widget _section() {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.short,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(_formController.currentStep),
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
          switch (_formController.currentStep) {
            UnitFormStep.branding => _branding(),
            UnitFormStep.profile => _profile(),
            UnitFormStep.location => _location(),
            UnitFormStep.plan => _planSection(),
            UnitFormStep.review => _review(),
          },
        ],
      ),
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
    final inherited = _inheritBranding;
    final accent = _unitHexColor(
      inherited ? _institution.accentColor : _text('accentColor'),
      fallback: colors.primary,
    );
    final secondary = _unitHexColor(
      inherited ? _institution.secondaryColor : _text('secondaryColor'),
      fallback: colors.secondary,
    );
    final displayName = inherited
        ? (_institution.brandDisplayName.isEmpty
              ? _institution.publicName
              : _institution.brandDisplayName)
        : (_text('brandDisplayName').isEmpty
              ? (_text('name').isEmpty ? 'Nova unidade' : _text('name'))
              : _text('brandDisplayName'));
    final hasLogo = inherited ? _institution.hasSimulatedLogo : _hasLogo;
    final hasCover = inherited ? _institution.hasSimulatedCover : _hasCover;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Identidade visual', 'Defina como a unidade será reconhecida no Coelo.'),
        _UnitBrandPreview(
          displayName: displayName,
          institutionName: _institution.publicName,
          accent: accent,
          secondary: secondary,
          hasLogo: hasLogo,
          hasCover: hasCover,
          inherited: inherited,
        ),
        const SizedBox(height: CoeloSpacing.space5),
        Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space4,
              vertical: CoeloSpacing.space2,
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Herdar identidade visual da instituição'),
              subtitle: Text(
                inherited
                    ? 'Usando foto, capa e cores de ${_institution.publicName}.'
                    : 'A unidade usa uma identidade visual própria.',
              ),
              value: inherited,
              onChanged: (value) => setState(() {
                _inheritBranding = value;
                _formController.markDirty();
              }),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _UnitBrandMediaCard(
          key: const Key('unit-logo-card'),
          title: 'Foto de perfil',
          description: inherited
              ? 'Herdada de ${_institution.publicName}.'
              : 'Imagem quadrada em PNG, JPG ou WebP, com até 2 MB.',
          accent: accent,
          isCover: false,
          selected: hasLogo,
          inherited: inherited,
          onToggle: () => setState(() {
            _hasLogo = !_hasLogo;
            _formController.markDirty();
          }),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _UnitBrandMediaCard(
          key: const Key('unit-cover-card'),
          title: 'Foto de capa',
          description: inherited
              ? 'Herdada de ${_institution.publicName}.'
              : 'Imagem em PNG, JPG ou WebP, com até 2 MB.',
          accent: accent,
          isCover: true,
          selected: hasCover,
          inherited: inherited,
          onToggle: () => setState(() {
            _hasCover = !_hasCover;
            _formController.markDirty();
          }),
        ),
        if (!inherited) ...[
          const SizedBox(height: CoeloSpacing.space5),
          _responsiveFields([
            _field('brandDisplayName', 'Nome de exibição', Icons.badge_outlined),
            _colorField('surfaceColor', 'Cor principal da superfície'),
            _colorField('accentColor', 'Cor principal da marca'),
            _colorField('secondaryColor', 'Cor secundária da marca'),
            _colorField('textColor', 'Cor principal do texto'),
          ]),
        ],
      ],
    );
  }

  Widget _profile() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Perfil da unidade', 'Informe instituição, tipo e status operacional.'),
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

  Widget _location() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Localização e contato', 'Cadastre endereço e canais da unidade.'),
      _responsiveFields([
        _field(
          'postalCode',
          'CEP',
          Icons.location_searching_outlined,
          suffixIcon: IconButton(
            tooltip: 'Buscar CEP',
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
      Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space4,
            vertical: CoeloSpacing.space2,
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Herdar plano da instituição'),
            subtitle: Text('Plano institucional: ${_institution.plan.label}'),
            value: _inheritPlan,
            onChanged: (value) => setState(() {
              _inheritPlan = value;
              if (value) _plan = _institution.plan;
              _formController.markDirty();
            }),
          ),
        ),
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
      _heading('Revisão', 'Confira os dados antes de concluir. Você pode editar qualquer grupo.'),
      _UnitReviewCard(
        editKey: const Key('unit-review-edit-profile'),
        title: 'Perfil da unidade',
        summary:
            '${_text('name')} · ${_institution.publicName}\n'
            '${_typeOptions.firstWhere((value) => value.typeId == _typeId).typeName} · '
            '${_status.label}',
        onEdit: () => _formController.selectStep(UnitFormStep.profile),
      ),
      _UnitReviewCard(
        editKey: const Key('unit-review-edit-location'),
        title: 'Localização e contato',
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
        title: 'Identidade visual',
        summary: _inheritBranding
            ? 'Herdada de ${_institution.publicName}'
            : (_text('brandDisplayName').isEmpty
                  ? 'Identidade própria'
                  : _text('brandDisplayName')),
        onEdit: () => _formController.selectStep(UnitFormStep.branding),
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
          : const Text('Salvar alterações'),
    );
    return SafeArea(
      top: false,
      child: Container(
        key: _footerKey,
        padding: const EdgeInsets.all(CoeloSpacing.space3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_original != null && !last) ...[
                    saveCurrentButton,
                    const SizedBox(height: CoeloSpacing.space2),
                  ],
                  primary,
                  const SizedBox(height: CoeloSpacing.space2),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _formController.isSaving ? null : _cancel,
                        child: const Text('Cancelar'),
                      ),
                      const Spacer(),
                      if (previous != null)
                        OutlinedButton(onPressed: previous, child: const Text('Anterior')),
                    ],
                  ),
                ],
              );
            }
            return Row(
              children: [
                TextButton(
                  onPressed: _formController.isSaving ? null : _cancel,
                  child: const Text('Cancelar'),
                ),
                const Spacer(),
                if (previous != null) ...[
                  OutlinedButton(onPressed: previous, child: const Text('Anterior')),
                  const SizedBox(width: CoeloSpacing.space2),
                ],
                primary,
                if (_original != null && !last) ...[
                  const SizedBox(width: CoeloSpacing.space2),
                  saveCurrentButton,
                ],
              ],
            );
          },
        ),
      ),
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
                      if (selected) TextButton(onPressed: onToggle, child: const Text('Remover')),
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
              backgroundColor: WidgetStatePropertyAll(
                selected ? colors.primaryContainer : colors.surface,
              ),
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
