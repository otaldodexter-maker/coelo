import 'dart:convert';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';
import '../../institutions/data/fake_institution_directory_repository.dart';
import '../../institutions/domain/institution_record.dart';
import '../../institutions/presentation/widgets/institution_form_dialogs.dart';
import '../../institutions/presentation/widgets/institution_form_sections.dart'
    show showCoeloAdminColorPicker;
import '../domain/unit_directory.dart';

enum UnitFormSaveResult { created, updated }

enum _UnitFormStep {
  branding('Identidade visual'),
  profile('Perfil da unidade'),
  location('Localização e contato'),
  plan('Plano'),
  review('Revisão');

  const _UnitFormStep(this.label);
  final String label;
}

final class UnitFormPage extends StatefulWidget {
  const UnitFormPage({
    required this.institutions,
    required this.repository,
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.unitId,
    this.onDestinationSelected,
    super.key,
  });

  final FakeInstitutionDirectoryRepository institutions;
  final UnitDirectoryRepository repository;
  final LogoutAction logout;
  final VoidCallback onCancel;
  final ValueChanged<UnitFormSaveResult> onSaved;
  final String? unitId;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<UnitFormPage> createState() => _UnitFormPageState();
}

final class _UnitFormPageState extends State<UnitFormPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  late InstitutionRecord _institution;
  UnitRecord? _original;
  _UnitFormStep _step = _UnitFormStep.branding;
  UnitStatus _status = UnitStatus.draft;
  late String _typeId;
  bool _inheritPlan = true;
  InstitutionPlan _plan = InstitutionPlan.essential;
  bool _inheritBranding = true;
  bool _hasLogo = false;
  bool _saving = false;
  bool _dirty = false;

  static const _fields = [
    'brandDisplayName',
    'accentColor',
    'secondaryColor',
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
    _original = widget.unitId == null ? null : widget.repository.findById(widget.unitId!);
    _institution = _original?.institution ?? widget.institutions.records.first;
    _status = _original?.status ?? UnitStatus.draft;
    _typeId = _original?.typeId.isNotEmpty == true ? _original!.typeId : _institution.typeId;
    _inheritPlan = _original?.planOverride == null;
    _plan = _original?.effectivePlan ?? _institution.plan;
    _inheritBranding = _original?.inheritInstitutionBranding ?? true;
    _hasLogo = _original?.hasSimulatedLogo ?? false;
    for (final field in _fields) {
      _controllers[field] = TextEditingController(text: _initialValue(field));
      _controllers[field]!.addListener(_markDirty);
    }
  }

  void _markDirty() {
    _dirty = true;
  }

  String _initialValue(String field) {
    final original = _original;
    if (original == null) {
      return switch (field) {
        'country' => 'Brasil',
        'brandDisplayName' => '',
        'accentColor' => '#D63C00',
        'secondaryColor' => '#3F4549',
        _ => '',
      };
    }
    return switch (field) {
      'brandDisplayName' => original.brandDisplayName,
      'accentColor' => original.accentColor,
      'secondaryColor' => original.secondaryColor,
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
    super.dispose();
  }

  List<InstitutionRecord> get _institutionOptions => widget.institutions.records;
  List<InstitutionRecord> get _typeOptions {
    final values = <String, InstitutionRecord>{};
    for (final institution in widget.institutions.records) {
      values[institution.typeId] = institution;
    }
    return values.values.toList()
      ..sort((first, second) => first.typeName.compareTo(second.typeName));
  }

  void _continue() {
    if (_step == _UnitFormStep.profile && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final next = _step.index + 1;
    if (next < _UnitFormStep.values.length) {
      setState(() => _step = _UnitFormStep.values[next]);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _step = _UnitFormStep.profile);
      return;
    }
    setState(() => _saving = true);
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
      accentColor: _text('accentColor'),
      secondaryColor: _text('secondaryColor'),
      activitiesCount: _original?.activitiesCount ?? 0,
      groups: _original?.unit.groups ?? const [],
    );
    await widget.repository.upsert(UnitRecord(institution: _institution, unit: unit));
    if (!mounted) return;
    _dirty = false;
    setState(() => _saving = false);
    widget.onSaved(_original == null ? UnitFormSaveResult.created : UnitFormSaveResult.updated);
  }

  Future<void> _cancel() async {
    if (_dirty && !await showInstitutionExitDialog(context, entityLabel: 'unidade')) {
      return;
    }
    widget.onCancel();
  }

  Future<void> _selectDestination(String destination) async {
    if (_dirty && !await showInstitutionExitDialog(context, entityLabel: 'unidade')) {
      return;
    }
    widget.onDestinationSelected?.call(destination);
  }

  @override
  Widget build(BuildContext context) {
    final title = _original == null ? 'Criar unidade' : 'Editar unidade';
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: SuperadminShell(
        logout: widget.logout,
        title: title,
        subtitle: _original == null
            ? 'Adicione uma nova unidade ao Coelo.'
            : 'Atualize os dados da unidade selecionada.',
        currentDestination: 'units',
        onDestinationSelected: _selectDestination,
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= CoeloBreakpoints.large.minWidth;
              return Padding(
                padding: EdgeInsets.all(desktop ? CoeloSpacing.space5 : CoeloSpacing.space3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (desktop) ...[
                      SizedBox(width: 220, child: _navigation()),
                      const SizedBox(width: CoeloSpacing.space6),
                    ],
                    Expanded(
                      child: Column(
                        children: [
                          if (!desktop) ...[
                            _navigation(),
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

  Widget _navigation() {
    return Wrap(
      direction: Axis.vertical,
      spacing: CoeloSpacing.space2,
      children: [
        for (final step in _UnitFormStep.values)
          SizedBox(
            width: 210,
            child: ListTile(
              selected: step == _step,
              leading: CircleAvatar(radius: 14, child: Text('${step.index + 1}')),
              title: Text(step.label),
              onTap: () => setState(() => _step = step),
            ),
          ),
      ],
    );
  }

  Widget _section() {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : CoeloMotion.short,
      child: Card(
        key: ValueKey(_step),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space5),
          child: switch (_step) {
            _UnitFormStep.branding => _branding(),
            _UnitFormStep.profile => _profile(),
            _UnitFormStep.location => _location(),
            _UnitFormStep.plan => _planSection(),
            _UnitFormStep.review => _review(),
          },
        ),
      ),
    );
  }

  Widget _heading(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space1),
      Text(description),
      const SizedBox(height: CoeloSpacing.space5),
    ],
  );

  Widget _branding() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Identidade visual', 'Defina como a unidade aparece no Coelo.'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Herdar identidade visual da instituição'),
        value: _inheritBranding,
        onChanged: (value) => setState(() {
          _inheritBranding = value;
          _dirty = true;
        }),
      ),
      if (!_inheritBranding)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: CoeloSize.avatarMd / 2,
                  child: _hasLogo
                      ? const Icon(Icons.apartment_rounded)
                      : const Icon(Icons.image_outlined),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _hasLogo = !_hasLogo;
                    _dirty = true;
                  }),
                  icon: Icon(_hasLogo ? Icons.delete_outline : Icons.upload_outlined),
                  label: Text(_hasLogo ? 'Remover avatar' : 'Selecionar avatar'),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            _responsiveFields([
              _field('brandDisplayName', 'Nome de exibição', Icons.badge_outlined),
              _colorField('accentColor', 'Cor principal'),
              _colorField('secondaryColor', 'Cor secundária'),
            ]),
          ],
        ),
    ],
  );

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
                _dirty = true;
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
            _dirty = true;
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
            _dirty = true;
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
    try {
      final response = await http.get(Uri.https('viacep.com.br', '/ws/$postalCode/json/'));
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['erro'] == true) {
        throw const FormatException();
      }
      _controllers['country']!.text = 'Brasil';
      _controllers['state']!.text = data['uf'] as String? ?? '';
      _controllers['city']!.text = data['localidade'] as String? ?? '';
      _controllers['district']!.text = data['bairro'] as String? ?? '';
      _controllers['street']!.text = data['logradouro'] as String? ?? '';
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não foi possível buscar este CEP.')));
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
            onPressed: _lookupPostalCode,
            icon: const Icon(Icons.travel_explore_rounded),
          ),
        ),
        _field('country', 'País', Icons.public_outlined),
        _field('state', 'UF', Icons.map_outlined),
        _field('city', 'Município', Icons.location_city_outlined),
        _field('district', 'Bairro', Icons.place_outlined),
        _field('street', 'Logradouro', Icons.signpost_outlined),
        _field('addressNumber', 'Número', Icons.numbers_outlined),
        _field('complement', 'Complemento', Icons.add_home_outlined),
        _field('contactEmail', 'E-mail', Icons.email_outlined),
        _field('contactPhone', 'Telefone', Icons.phone_outlined),
        _field('contactMobilePhone', 'Celular', Icons.smartphone_outlined),
      ]),
    ],
  );

  Widget _planSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Plano', 'A unidade pode acompanhar a instituição ou usar um override.'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Herdar plano da instituição'),
        subtitle: Text('Plano institucional: ${_institution.plan.label}'),
        value: _inheritPlan,
        onChanged: (value) => setState(() {
          _inheritPlan = value;
          if (value) _plan = _institution.plan;
          _dirty = true;
        }),
      ),
      if (!_inheritPlan)
        CoeloAdminSingleSelectField<InstitutionPlan>(
          label: 'Plano da unidade',
          value: _plan,
          options: InstitutionPlan.values,
          optionLabel: (value) => value.label,
          onChanged: (value) => setState(() {
            _plan = value;
            _dirty = true;
          }),
          prefixIcon: Icons.sell_outlined,
        ),
    ],
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('Revisão', 'Confira os dados antes de salvar.'),
      _reviewLine('Unidade', _text('name')),
      _reviewLine('Instituição', _institution.publicName),
      _reviewLine('Tipo', _typeOptions.firstWhere((value) => value.typeId == _typeId).typeName),
      _reviewLine('Status', _status.label),
      _reviewLine('Localização', '${_text('district')}, ${_text('city')}/${_text('state')}'),
      _reviewLine('Plano', _inheritPlan ? '${_institution.plan.label} (herdado)' : _plan.label),
      _reviewLine('Branding', _inheritBranding ? 'Herdado da instituição' : 'Personalizado'),
    ],
  );

  Widget _reviewLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Row(
      children: [
        SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
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
      validator: required
          ? (value) {
              final normalized = value?.trim() ?? '';
              if (normalized.isEmpty) return 'Campo obrigatório.';
              if (id == 'slug' &&
                  widget.repository.records.any(
                    (record) =>
                        record.institutionId == _institution.id &&
                        record.id != _original?.id &&
                        record.slug == normalized,
                  )) {
                return 'Identificador já usado nesta instituição.';
              }
              return null;
            }
          : null,
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
          final selected = await showCoeloAdminColorPicker(
            context: context,
            initialColor: color,
            title: label,
            keyPrefix: 'unit',
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
    final previous = _step.index > 0
        ? () => setState(() => _step = _UnitFormStep.values[_step.index - 1])
        : null;
    final primary = _step == _UnitFormStep.review
        ? FilledButton(
            key: const Key('unit-form-save'),
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Salvando…'
                  : _original == null
                  ? 'Criar unidade'
                  : 'Salvar alterações',
            ),
          )
        : FilledButton(
            key: const Key('unit-form-continue'),
            onPressed: _continue,
            child: const Text('Continuar'),
          );
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
            if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  primary,
                  const SizedBox(height: CoeloSpacing.space2),
                  Row(
                    children: [
                      TextButton(onPressed: _cancel, child: const Text('Cancelar')),
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
                TextButton(onPressed: _cancel, child: const Text('Cancelar')),
                const Spacer(),
                if (previous != null) ...[
                  OutlinedButton(onPressed: previous, child: const Text('Anterior')),
                  const SizedBox(width: CoeloSpacing.space2),
                ],
                primary,
              ],
            );
          },
        ),
      ),
    );
  }
}

Color _unitHexColor(String value, {required Color fallback}) {
  final normalized = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
    return fallback;
  }
  return Color(int.parse('FF$normalized', radix: 16));
}
