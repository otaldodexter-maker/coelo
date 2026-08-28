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

var _medicationFormRequestSequence = 0;

String _nextMedicationFormRequestId() => 'medication-form-${++_medicationFormRequestSequence}';

@immutable
final class HealthMedicationPlanFormDraft {
  const HealthMedicationPlanFormDraft({
    required this.childId,
    required this.medicationName,
    required this.doseAmount,
    required this.doseUnit,
    required this.administrationRoute,
    required this.weekdays,
    required this.responsibleIds,
    this.requestId,
    this.planId,
    this.expectedVersion = 0,
    this.validFrom,
    this.validUntil,
    this.time,
  });

  final String childId;
  final String medicationName;
  final num doseAmount;
  final String doseUnit;
  final String administrationRoute;
  final String? requestId;
  final String? planId;
  final int expectedVersion;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final TimeOfDay? time;
  final Set<int> weekdays;
  final Set<String> responsibleIds;
}

final class HealthMedicationPlanSaveReceipt {
  const HealthMedicationPlanSaveReceipt({required this.planId, required this.version});

  final String planId;
  final int version;
}

typedef HealthMedicationPlanDraftSave =
    Future<HealthMedicationPlanSaveReceipt> Function(HealthMedicationPlanFormDraft draft);

final class HealthMedicationPlanFormPage extends StatefulWidget {
  const HealthMedicationPlanFormPage({
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.medicationId,
    this.childId,
    this.initialDraft,
    this.childOptions = const [],
    this.responsibleOptions = const [],
    this.onDraftSaved,
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
  final HealthMedicationPlanFormDraft? initialDraft;
  final List<HealthCareFormChoice> childOptions;
  final List<HealthCareFormChoice> responsibleOptions;
  final HealthMedicationPlanDraftSave? onDraftSaved;
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
  var _retrySave = false;
  String? _saveError;
  double _footerHeight = 0;
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _unit = TextEditingController();
  late String _requestId;
  var _requestWasSubmitted = false;
  String? _persistedPlanId;
  var _expectedVersion = 0;
  HealthMedicationPlanFormDraft? _pendingSubmission;
  var _draftChangedAfterSubmission = false;

  bool get _editing => widget.medicationId != null;
  bool get _hasExternalChild =>
      _childId != null && widget.childOptions.any((option) => option.id == _childId);
  num? get _parsedDose => num.tryParse(_dose.text.trim().replaceAll(',', '.'));
  DateTime get _effectiveStartsAt => _startsAt ?? DateUtils.dateOnly(DateTime.now());
  String? get _validityError => _endsAt?.isBefore(_effectiveStartsAt) ?? false
      ? 'A data de término não pode ser anterior à data de início.'
      : null;
  bool get _hasValidMedicine =>
      _hasExternalChild &&
      _name.text.trim().isNotEmpty &&
      (_parsedDose ?? 0) > 0 &&
      _unit.text.trim().isNotEmpty;
  bool get _canAdvance => _hasValidMedicine;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _requestId = draft?.requestId ?? _nextMedicationFormRequestId();
    _persistedPlanId = draft?.planId ?? widget.medicationId;
    _expectedVersion = draft?.expectedVersion ?? 0;
    _childId = widget.childId ?? draft?.childId ?? widget.childOptions.firstOrNull?.id;
    if (draft != null) {
      _name.text = draft.medicationName;
      _dose.text = draft.doseAmount.toString();
      _unit.text = draft.doseUnit;
      _route = draft.administrationRoute;
      _startsAt = draft.validFrom;
      _endsAt = draft.validUntil;
      _time = draft.time;
      _weekdays = Set.of(draft.weekdays);
      _responsibles = Set.of(draft.responsibleIds);
    }
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
    final retryWithoutEdits = _retrySave;
    final validityError = _validityError;
    if (validityError != null) {
      setState(() {
        _saveError = validityError;
        _retrySave = false;
      });
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _retrySave = false;
    });
    try {
      final onDraftSaved = widget.onDraftSaved;
      if (onDraftSaved != null) {
        final childId = _childId;
        final medicationName = _name.text.trim();
        final doseAmount = _parsedDose;
        final doseUnit = _unit.text.trim();
        if (childId == null ||
            medicationName.isEmpty ||
            doseAmount == null ||
            doseAmount <= 0 ||
            doseUnit.isEmpty) {
          throw ArgumentError('Invalid medication plan draft.');
        }
        final pendingSubmission = _pendingSubmission;
        if (pendingSubmission != null) {
          final pendingMatchesCurrent =
              retryWithoutEdits &&
              !_draftChangedAfterSubmission &&
              _matchesCurrentDraft(pendingSubmission);
          final receipt = await onDraftSaved(pendingSubmission);
          _applyReceipt(receipt);
          _pendingSubmission = null;
          if (pendingMatchesCurrent) {
            _requestWasSubmitted = false;
            await widget.onSaved();
            return;
          }
          if (pendingSubmission.requestId == _requestId) {
            _requestId = _nextMedicationFormRequestId();
          }
        }
        final draft = HealthMedicationPlanFormDraft(
          requestId: _requestId,
          planId: _persistedPlanId,
          expectedVersion: _expectedVersion,
          childId: childId,
          medicationName: medicationName,
          doseAmount: doseAmount,
          doseUnit: doseUnit,
          administrationRoute: _route,
          validFrom: _effectiveStartsAt,
          validUntil: _endsAt,
          time: _time,
          weekdays: Set.unmodifiable(_weekdays),
          responsibleIds: Set.unmodifiable(_responsibles),
        );
        _requestWasSubmitted = true;
        _pendingSubmission = draft;
        _draftChangedAfterSubmission = false;
        final receipt = await onDraftSaved(draft);
        _applyReceipt(receipt);
        _pendingSubmission = null;
        _draftChangedAfterSubmission = false;
        _requestWasSubmitted = false;
      }
      await widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saveError = 'Não foi possível salvar o plano de medicação. Tente novamente.';
          _retrySave = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyReceipt(HealthMedicationPlanSaveReceipt receipt) {
    _persistedPlanId = receipt.planId;
    _expectedVersion = receipt.version;
  }

  bool _matchesCurrentDraft(HealthMedicationPlanFormDraft draft) =>
      draft.childId == _childId &&
      draft.medicationName == _name.text.trim() &&
      draft.doseAmount == _parsedDose &&
      draft.doseUnit == _unit.text.trim() &&
      draft.administrationRoute == _route &&
      draft.validFrom == _effectiveStartsAt &&
      draft.validUntil == _endsAt &&
      draft.time == _time &&
      _sameValues(draft.weekdays, _weekdays) &&
      _sameValues(draft.responsibleIds, _responsibles);

  void _updateDraft(VoidCallback update) {
    setState(() {
      update();
      if (_pendingSubmission != null) {
        _draftChangedAfterSubmission = true;
        _requestId = _nextMedicationFormRequestId();
        _requestWasSubmitted = false;
      } else if (_requestWasSubmitted) {
        _requestId = _nextMedicationFormRequestId();
        _requestWasSubmitted = false;
      }
      _retrySave = false;
      _saveError = null;
    });
  }

  void _selectStep(int index) {
    setState(() => _step = _Step.values[index]);
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
          onStepSelected: _selectStep,
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
              key: const Key('health-medication-primary-action'),
              onPressed: !_canAdvance
                  ? null
                  : _step == _Step.review
                  ? (_saving ? null : _save)
                  : () => setState(() => _step = _Step.values[_step.index + 1]),
              child: Text(
                _step == _Step.review
                    ? _retrySave
                          ? 'Tentar novamente'
                          : (_editing ? 'Salvar alterações' : 'Criar plano')
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
      if (_saveError case final error?) ...[
        Semantics(
          key: const Key('health-medication-save-error'),
          container: true,
          liveRegion: true,
          label: error,
          child: ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(CoeloRadius.md),
              ),
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
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
        onChanged: (value) => _updateDraft(() => _childId = value),
      ),
    CoeloFormTextField(
      fieldKey: const Key('health-medication-name'),
      controller: _name,
      labelText: 'Nome do medicamento',
      prefixIcon: Icons.medication_outlined,
      onChanged: (_) => _updateDraft(() {}),
    ),
    CoeloFormTextField(
      controller: _dose,
      labelText: 'Dose',
      prefixIcon: Icons.straighten_rounded,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => _updateDraft(() {}),
    ),
    CoeloFormTextField(
      controller: _unit,
      labelText: 'Unidade',
      prefixIcon: Icons.science_outlined,
      onChanged: (_) => _updateDraft(() {}),
    ),
    CoeloAdminSingleSelectField<String>(
      label: 'Via',
      value: _route,
      options: const ['oral', 'nasal', 'topical', 'inhaled'],
      optionLabel: _routeLabel,
      onChanged: (value) => _updateDraft(() => _route = value),
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
      onChanged: (value) => _updateDraft(() => _startsAt = value),
    ),
    CoeloMedicationDateField(
      label: 'Data de término',
      value: _endsAt,
      onChanged: (value) => _updateDraft(() => _endsAt = value),
    ),
  ]);

  Widget _schedule() => Column(
    children: [
      _grid([
        CoeloMedicationTimeField(
          value: _time,
          onChanged: (value) => _updateDraft(() => _time = value),
        ),
        CoeloMedicationWeekdaySelector(
          selectedValues: _weekdays,
          onChanged: (values) => _updateDraft(() => _weekdays = values),
        ),
      ]),
      const SizedBox(height: CoeloSpacing.space5),
      CoeloMedicationResponsibleSelector(
        options: widget.responsibleOptions,
        selectedIds: _responsibles,
        onChanged: (values) => _updateDraft(() => _responsibles = values),
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
      _row('Vigência', '${_date(_effectiveStartsAt)} a ${_date(_endsAt)}'),
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

bool _sameValues<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);
String _date(DateTime? value) => value == null
    ? 'Não informada'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _weekday(int value) =>
    const ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'][value - 1];
