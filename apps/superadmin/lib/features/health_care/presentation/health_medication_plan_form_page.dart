import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import 'health_care_responsive_surface.dart';
import 'health_medication_form_sections.dart';

enum _Step { medicine, validity, schedule, document, review }

final class HealthMedicationPlanFormPage extends StatefulWidget {
  const HealthMedicationPlanFormPage({
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.medicationId,
    this.childId,
    this.childOptions = const [],
    this.responsibleOptions = const [],
    this.onChangeChild,
    this.onPickMedicationImage,
    this.onPickPrescription,
    super.key,
  });

  final LogoutAction logout;
  final VoidCallback onCancel;
  final Future<void> Function() onSaved;
  final String? medicationId;
  final String? childId;
  final List<HealthCareFormChoice> childOptions;
  final List<HealthCareFormChoice> responsibleOptions;
  final VoidCallback? onChangeChild;
  final VoidCallback? onPickMedicationImage;
  final VoidCallback? onPickPrescription;

  @override
  State<HealthMedicationPlanFormPage> createState() => _HealthMedicationPlanFormPageState();
}

final class _HealthMedicationPlanFormPageState extends State<HealthMedicationPlanFormPage> {
  var _step = _Step.medicine;
  String? _childId;
  var _route = 'oral';
  DateTime? _startsAt;
  DateTime? _endsAt;
  TimeOfDay? _time;
  var _weekdays = <int>{};
  var _responsibles = <String>{};
  var _saving = false;
  double _footerHeight = 0;
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _unit = TextEditingController();

  bool get _editing => widget.medicationId != null;
  bool get _hasExternalChild =>
      _childId != null && widget.childOptions.any((option) => option.id == _childId);

  @override
  void initState() {
    super.initState();
    _childId = widget.childId ?? widget.childOptions.firstOrNull?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _unit.dispose();
    super.dispose();
  }

  List<SuperadminFormStep> get _steps => [
    for (final step in _Step.values)
      SuperadminFormStep(
        label: switch (step) {
          _Step.medicine => 'Criança e medicamento',
          _Step.validity => 'Vigência',
          _Step.schedule => 'Horários e responsáveis',
          _Step.document => 'Documento',
          _Step.review => 'Revisão',
        },
        status: step == _step
            ? SuperadminFormStepStatus.current
            : step.index < _step.index
            ? SuperadminFormStepStatus.complete
            : SuperadminFormStepStatus.incomplete,
      ),
  ];

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: 'health-medication-plans',
    title: _editing ? 'Editar plano de medicação' : 'Criar plano de medicação',
    subtitle: 'Organize medicamento, vigência, horários e responsáveis.',
    chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
    child: LayoutBuilder(
      builder: (context, constraints) => SuperadminFormFrame(
        viewportWidth: constraints.maxWidth,
        scrollKey: const Key('health-medication-form-scroll'),
        navigation: SuperadminFormStepNavigation(
          steps: _steps,
          currentIndex: _step.index,
          onStepSelected: (index) => setState(() => _step = _Step.values[index]),
        ),
        body: _body(),
        footer: SuperadminFormActionFooter(
          onHeightChanged: (height) {
            if ((_footerHeight - height).abs() < .5) return;
            setState(() => _footerHeight = height);
          },
          tertiaryAction: TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
          continuationActions: [
            if (_step.index > 0)
              OutlinedButton(
                onPressed: () => setState(() => _step = _Step.values[_step.index - 1]),
                child: const Text('Anterior'),
              ),
            FilledButton(
              onPressed: !_hasExternalChild
                  ? null
                  : _step == _Step.review
                  ? (_saving ? null : _save)
                  : () => setState(() => _step = _Step.values[_step.index + 1]),
              child: Text(
                _step == _Step.review
                    ? (_editing ? 'Salvar alterações' : 'Criar plano')
                    : 'Continuar',
              ),
            ),
          ],
        ),
      ),
    ),
  ).withHealthCareResponsiveSurface();

  Widget _body() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(_title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space1),
      Text(_description, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: CoeloSpacing.space5),
      switch (_step) {
        _Step.medicine => _medicine(),
        _Step.validity => _validity(),
        _Step.schedule => _schedule(),
        _Step.document => _document(),
        _Step.review => _review(),
      },
    ],
  );

  String get _title => switch (_step) {
    _Step.medicine => 'Criança e medicamento',
    _Step.validity => 'Vigência',
    _Step.schedule => 'Horários e responsáveis',
    _Step.document => 'Documento',
    _Step.review => 'Revisão',
  };
  String get _description => switch (_step) {
    _Step.medicine => 'Identifique a criança e informe medicamento, dose, unidade e via.',
    _Step.validity => 'Defina somente as datas de início e término do plano.',
    _Step.schedule => 'Escolha o horário, a periodicidade e adicione responsáveis um por vez.',
    _Step.document => 'Anexe os arquivos privados necessários ao plano.',
    _Step.review => 'Confira as informações antes de salvar.',
  };

  Widget _medicine() => _grid([
    if (_editing)
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Criança',
              prefixIcon: Icon(Icons.lock_outline_rounded),
              enabled: false,
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            child: Text(_choiceLabel(widget.childOptions, _childId)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onChangeChild,
              child: const Text('Trocar de criança'),
            ),
          ),
        ],
      )
    else
      CoeloMedicationChildSelector(
        options: widget.childOptions,
        selectedId: _childId,
        onChanged: (value) => setState(() => _childId = value),
      ),
    CoeloFormTextField(
      controller: _name,
      labelText: 'Nome do medicamento',
      prefixIcon: Icons.medication_outlined,
    ),
    CoeloFormTextField(
      controller: _dose,
      labelText: 'Dose',
      prefixIcon: Icons.straighten_rounded,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    ),
    CoeloFormTextField(controller: _unit, labelText: 'Unidade', prefixIcon: Icons.science_outlined),
    CoeloAdminSingleSelectField<String>(
      label: 'Via',
      value: _route,
      options: const ['oral', 'nasal', 'topical', 'inhaled'],
      optionLabel: _routeLabel,
      onChanged: (value) => setState(() => _route = value),
      prefixIcon: Icons.route_outlined,
    ),
    _attachment(
      'Imagem do medicamento',
      'Imagem privada do medicamento.',
      Icons.add_photo_alternate_outlined,
      widget.onPickMedicationImage,
    ),
  ]);

  Widget _validity() => _grid([
    CoeloMedicationDateField(
      label: 'Data de início',
      value: _startsAt,
      onChanged: (value) => setState(() => _startsAt = value),
    ),
    CoeloMedicationDateField(
      label: 'Data de término',
      value: _endsAt,
      onChanged: (value) => setState(() => _endsAt = value),
    ),
  ]);

  Widget _schedule() => Column(
    children: [
      _grid([
        CoeloMedicationTimeField(value: _time, onChanged: (value) => setState(() => _time = value)),
        CoeloMedicationWeekdaySelector(
          selectedValues: _weekdays,
          onChanged: (values) => setState(() => _weekdays = values),
        ),
      ]),
      const SizedBox(height: CoeloSpacing.space5),
      CoeloMedicationResponsibleSelector(
        options: widget.responsibleOptions,
        selectedIds: _responsibles,
        onChanged: (values) => setState(() => _responsibles = values),
      ),
    ],
  );

  Widget _document() => _attachment(
    'Prescrição',
    'PDF ou imagem privada da prescrição.',
    Icons.upload_file_outlined,
    widget.onPickPrescription,
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _row('Criança', _choiceLabel(widget.childOptions, _childId)),
      _row('Nome do medicamento', _name.text),
      _row('Dose', '${_dose.text} ${_unit.text}'.trim()),
      _row('Via', _routeLabel(_route)),
      _row('Vigência', '${_date(_startsAt)} a ${_date(_endsAt)}'),
      _row('Horário', _time == null ? '' : _time!.format(context)),
      _row('Dias da semana', _weekdays.map(_weekday).join(', ')),
      _row(
        'Responsáveis',
        _responsibles.map((id) => _choiceLabel(widget.responsibleOptions, id)).join(', '),
      ),
    ],
  );

  Widget _grid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1);
      final twoColumns = constraints.maxWidth >= 700 && textScale <= 1.3;
      final width = twoColumns
          ? (constraints.maxWidth - CoeloSpacing.space3) / 2
          : constraints.maxWidth;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space4,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );

  Widget _attachment(String label, String description, IconData icon, VoidCallback? callback) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text(description),
          const SizedBox(height: CoeloSpacing.space2),
          OutlinedButton.icon(
            onPressed: callback,
            icon: Icon(icon),
            label: const Text('Selecionar arquivo'),
          ),
          if (callback == null) const Text('Envio indisponível neste contexto.'),
        ],
      );
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value.trim().isEmpty ? 'Não informado' : value),
      ],
    ),
  );
}

String _choiceLabel(List<HealthCareFormChoice> options, String? id) {
  if (id == null) return 'Não selecionada';
  return options.where((item) => item.id == id).firstOrNull?.label ?? 'Criança indisponível';
}

String _routeLabel(String value) => switch (value) {
  'oral' => 'Oral',
  'nasal' => 'Nasal',
  'topical' => 'Tópica',
  'inhaled' => 'Inalatória',
  _ => 'Outra',
};
String _date(DateTime? value) => value == null
    ? 'Não informada'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _weekday(int value) =>
    const ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'][value - 1];
