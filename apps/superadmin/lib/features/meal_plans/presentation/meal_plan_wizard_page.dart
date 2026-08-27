import 'dart:math';
import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../domain/meal_plan_image_repository.dart';
import '../domain/meal_plan_repository.dart';

final class MealPlanWizardPage extends StatefulWidget {
  const MealPlanWizardPage({
    required this.repository,
    required this.imageRepository,
    required this.onSaved,
    required this.onCancel,
    this.mealPlanId,
    this.templatePlanId,
    this.mealPlanModelId,
    this.isTemplate = false,
    this.tenantId = '',
    this.imageSelectionEnabled = true,
    super.key,
  });

  final MealPlanRepository repository;
  final MealPlanImageRepository imageRepository;
  final String? mealPlanId;
  final String? templatePlanId;
  final String? mealPlanModelId;
  final bool isTemplate;
  final String tenantId;
  final bool imageSelectionEnabled;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  State<MealPlanWizardPage> createState() => _MealPlanWizardPageState();
}

final class _MealPlanWizardPageState extends State<MealPlanWizardPage> {
  static const _planSteps = <String>[
    'Identificação',
    'Abrangência',
    'Período e recorrência',
    'Cardápio',
    'Revisão e publicação',
  ];
  static const _templateSteps = <String>['Identificação', 'Modelo', 'Revisão e publicação'];
  static const _weekdays = <String>['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
  static const _mealTypes = <String>[
    'breakfast',
    'brunch',
    'lunch',
    'afternoonSnack',
    'dinner',
    'supper',
    'other',
  ];

  final _name = TextEditingController();
  final _simpleImageAlt = TextEditingController();
  final _simpleNotes = TextEditingController();
  final _priority = TextEditingController(text: '0');
  final _cycleWeeks = TextEditingController(text: '2');
  final _specificDates = TextEditingController();
  final _excludedDates = TextEditingController();
  final _templateName = TextEditingController();

  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  bool _saveAsTemplate = false;
  String? _error;
  String? _persistOperationId;
  MealPlan? _original;
  MealPlanTemplate? _originalTemplate;
  MealPlanAudienceOptions _audienceOptions = const MealPlanAudienceOptions();
  List<MealPlanTemplate> _templates = const [];
  MealPlanPlanVariant _variant = MealPlanPlanVariant.complete;
  MealPlanAudienceSegment _audience = MealPlanAudienceSegment.students;
  MealPlanVisibilityMode _visibility = MealPlanVisibilityMode.immediate;
  MealPlanRecurrenceKind _recurrence = MealPlanRecurrenceKind.weekly;
  DateTimeRange? _period;
  DateTimeRange? _visibleDate;
  String _templateId = '';
  MealPlanAttachmentMeta? _simpleImage;
  _PendingImage? _pendingSimpleImage;
  final Set<int> _recurrenceWeekdays = {1, 2, 3, 4, 5};
  final Set<String> _institutions = {};
  final Set<String> _units = {};
  final Set<String> _groups = {};
  final Set<String> _activities = {};
  final Set<String> _people = {};
  final Set<String> _excludedPeople = {};
  final List<_MealEditor> _meals = [_MealEditor()];
  int _loadGeneration = 0;
  int _commandGeneration = 0;

  List<String> get _steps => widget.isTemplate ? _templateSteps : _planSteps;
  bool get _isSimple => _variant == MealPlanPlanVariant.simple;
  int get _reviewStep => _steps.length - 1;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _period = DateTimeRange(start: today, end: today.add(const Duration(days: 6)));
    _load();
  }

  @override
  void didUpdateWidget(covariant MealPlanWizardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.mealPlanId != widget.mealPlanId ||
        oldWidget.templatePlanId != widget.templatePlanId ||
        oldWidget.mealPlanModelId != widget.mealPlanModelId ||
        oldWidget.isTemplate != widget.isTemplate) {
      _commandGeneration++;
      _resetForLoad();
      _load();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _commandGeneration++;
    for (final controller in <TextEditingController>[
      _name,
      _simpleImageAlt,
      _simpleNotes,
      _priority,
      _cycleWeeks,
      _specificDates,
      _excludedDates,
      _templateName,
    ]) {
      controller.dispose();
    }
    for (final meal in _meals) {
      meal.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading || _saving) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: CoeloSpacing.space4),
          ],
          Text(_title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: CoeloSpacing.space1),
          Text(_subtitle, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: CoeloSpacing.space5),
          if (_error != null) ...[
            CoeloStatePanel(title: 'Revise esta etapa', message: _error!, icon: Icons.info_outline),
            const SizedBox(height: CoeloSpacing.space4),
          ],
          Text(_steps[_step], style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text('Etapa ${_step + 1} de ${_steps.length}'),
          const SizedBox(height: CoeloSpacing.space4),
          if (_loading) const SizedBox(height: 240) else _stepContent(),
        ],
      );
      final navigation = SuperadminFormStepNavigation(
        steps: [
          for (var index = 0; index < _steps.length; index++)
            SuperadminFormStep(
              label: _steps[index],
              status: index == _step
                  ? (_error == null
                        ? SuperadminFormStepStatus.current
                        : SuperadminFormStepStatus.error)
                  : index < _step
                  ? SuperadminFormStepStatus.complete
                  : SuperadminFormStepStatus.incomplete,
              enabled: index <= _step,
            ),
        ],
        currentIndex: _step,
        onStepSelected: (index) {
          if (index <= _step) setState(() => _step = index);
        },
      );
      return SuperadminFormFrame(
        navigation: navigation,
        body: body,
        footer: _footer(),
        viewportWidth: constraints.maxWidth,
      );
    },
  );

  String get _title {
    if (widget.isTemplate) {
      return widget.mealPlanModelId == null
          ? 'Novo modelo de cardápio'
          : 'Editar modelo de cardápio';
    }
    return widget.mealPlanId == null ? 'Novo cardápio' : 'Editar cardápio';
  }

  String get _subtitle => widget.isTemplate
      ? 'Crie uma base reutilizável. Modelos não possuem período nem recorrência.'
      : 'Defina público, abrangência, vigência e refeições antes da publicação.';

  Widget _footer() => SuperadminFormActionFooter(
    tertiaryAction: TextButton(
      onPressed: _saving ? null : widget.onCancel,
      child: const Text('Cancelar'),
    ),
    continuationActions: [
      if (_step > 0)
        OutlinedButton(
          onPressed: _saving ? null : () => setState(() => _step--),
          child: const Text('Anterior'),
        ),
      if (_step < _reviewStep)
        FilledButton(onPressed: _saving ? null : _next, child: const Text('Continuar'))
      else ...[
        OutlinedButton(
          onPressed: _saving ? null : () => _persist(publish: false),
          child: const Text('Salvar rascunho'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _persist(publish: true),
          child: Text(widget.isTemplate ? 'Publicar modelo' : 'Enviar e publicar'),
        ),
      ],
    ],
  );

  Widget _stepContent() {
    if (widget.isTemplate) {
      return switch (_step) {
        0 => _identification(),
        1 => _templateBody(),
        _ => _review(),
      };
    }
    return switch (_step) {
      0 => _identification(),
      1 => _scope(),
      2 => _schedule(),
      3 => _menu(),
      _ => _review(),
    };
  }

  Widget _identification() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloFormTextField(
        controller: _name,
        labelText: widget.isTemplate ? 'Nome do modelo' : 'Nome do cardápio',
        prefixIcon: Icons.restaurant_menu_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<MealPlanPlanVariant>(
        label: 'Tipo de cardápio',
        value: _variant,
        options: MealPlanPlanVariant.values,
        optionLabel: (value) => value == MealPlanPlanVariant.simple ? 'Simples' : 'Completo',
        onChanged: (value) => setState(() => _variant = value),
        prefixIcon: Icons.view_agenda_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<MealPlanAudienceSegment>(
        label: 'Para quem é este cardápio?',
        value: _audience,
        options: MealPlanAudienceSegment.values,
        optionLabel: _audienceLabel,
        onChanged: (value) => setState(() => _audience = value),
        prefixIcon: Icons.groups_outlined,
      ),
      if (!widget.isTemplate) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<String>(
          label: 'Modelo-base',
          value: _templateId,
          options: ['', ..._templates.map((value) => value.id)],
          optionLabel: (id) => id.isEmpty
              ? 'Criar sem modelo'
              : _templates.where((value) => value.id == id).first.name,
          onChanged: _applyTemplate,
          prefixIcon: Icons.library_books_outlined,
        ),
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          'Ao escolher um modelo, o conteúdo é copiado para este cardápio e pode ser editado sem alterar a base.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );

  Widget _templateBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_isSimple) _simpleContent() else _mealEditor(),
      const SizedBox(height: CoeloSpacing.space4),
      Text(
        'O modelo guarda uma base versionada. Novos cardápios recebem uma cópia independente.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _scope() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Selecione um ou mais contextos. Pessoas novas nesses contextos entram apenas nas ocorrências futuras.',
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _choiceGroup('Instituições', _audienceOptions.institutions, _institutions),
      _choiceGroup('Unidades', _filteredUnits, _units),
      _choiceGroup('Turmas', _filteredGroups, _groups),
      _choiceGroup('Atividades', _filteredActivities, _activities),
      _choiceGroup('Pessoas incluídas', _filteredPeople, _people),
      _choiceGroup('Pessoas excluídas', _filteredPeople, _excludedPeople, exclusion: true),
      const SizedBox(height: CoeloSpacing.space2),
      Text(
        'Responsáveis não são público individual elegível. Exclusões explícitas prevalecem sobre inclusões dinâmicas.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  List<MealPlanAudienceOption> get _filteredUnits => _audienceOptions.units
      .where((value) {
        return _institutions.isEmpty ||
            value.institutionId == null ||
            _institutions.contains(value.institutionId);
      })
      .toList(growable: false);

  List<MealPlanAudienceOption> get _filteredGroups => _audienceOptions.groups
      .where((value) {
        return _units.isEmpty || value.unitId == null || _units.contains(value.unitId);
      })
      .toList(growable: false);

  List<MealPlanAudienceOption> get _filteredActivities => _audienceOptions.activities
      .where((value) {
        return _groups.isEmpty || value.groupId == null || _groups.contains(value.groupId);
      })
      .toList(growable: false);

  List<MealPlanAudienceOption> get _filteredPeople => _audienceOptions.people
      .where((value) {
        final segmentMatches =
            _audience == MealPlanAudienceSegment.all ||
            value.audienceSegment == null ||
            value.audienceSegment == _audience;
        final groupMatches =
            _groups.isEmpty || value.groupId == null || _groups.contains(value.groupId);
        final unitMatches = _units.isEmpty || value.unitId == null || _units.contains(value.unitId);
        return segmentMatches && groupMatches && unitMatches;
      })
      .toList(growable: false);

  Widget _choiceGroup(
    String label,
    List<MealPlanAudienceOption> options,
    Set<String> selected, {
    bool exclusion = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: CoeloSpacing.space2),
        if (options.isEmpty)
          Text(
            'Nenhuma opção disponível neste contexto.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(option.label),
                  selected: selected.contains(option.id),
                  avatar: Icon(exclusion ? Icons.person_remove_outlined : Icons.add_circle_outline),
                  onSelected: (enabled) => setState(() {
                    enabled ? selected.add(option.id) : selected.remove(option.id);
                    if (exclusion && enabled) _people.remove(option.id);
                    if (!exclusion && enabled) _excludedPeople.remove(option.id);
                  }),
                ),
            ],
          ),
      ],
    ),
  );

  Widget _schedule() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloDateRangeField(
        value: _period,
        onChanged: (value) => setState(() => _period = value),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        labelText: 'Período do cardápio',
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<MealPlanRecurrenceKind>(
        label: 'Recorrência',
        value: _recurrence,
        options: MealPlanRecurrenceKind.values,
        optionLabel: _recurrenceLabel,
        onChanged: (value) => setState(() => _recurrence = value),
        prefixIcon: Icons.repeat_outlined,
      ),
      if (_recurrence == MealPlanRecurrenceKind.weekly ||
          _recurrence == MealPlanRecurrenceKind.biweekly ||
          _recurrence == MealPlanRecurrenceKind.cycleWeeks) ...[
        const SizedBox(height: CoeloSpacing.space4),
        _weekdayPicker(_recurrenceWeekdays),
      ],
      if (_recurrence == MealPlanRecurrenceKind.cycleWeeks) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: _cycleWeeks,
          labelText: 'Quantidade de semanas do ciclo',
          prefixIcon: Icons.cached_outlined,
        ),
      ],
      if (_recurrence == MealPlanRecurrenceKind.specificDates) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: _specificDates,
          labelText: 'Datas específicas (DD/MM/AAAA, separadas por vírgula)',
          prefixIcon: Icons.event_available_outlined,
        ),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        controller: _excludedDates,
        labelText: 'Datas excluídas (DD/MM/AAAA, separadas por vírgula)',
        prefixIcon: Icons.event_busy_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<MealPlanVisibilityMode>(
        label: 'Quando o cardápio começa a aparecer?',
        value: _visibility,
        options: MealPlanVisibilityMode.values,
        optionLabel: (value) => value == MealPlanVisibilityMode.immediate
            ? 'Imediatamente após publicar'
            : 'Em uma data programada',
        onChanged: (value) => setState(() => _visibility = value),
        prefixIcon: Icons.visibility_outlined,
      ),
      if (_visibility == MealPlanVisibilityMode.scheduled) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloDateRangeField(
          value: _visibleDate,
          onChanged: (value) => setState(() {
            _visibleDate = value == null
                ? null
                : DateTimeRange(start: value.start, end: value.start);
          }),
          firstDate: DateUtils.dateOnly(DateTime.now()),
          lastDate: DateTime(2100),
          showQuickRanges: false,
          labelText: 'Data de início da exibição',
        ),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        controller: _priority,
        labelText: 'Prioridade explícita',
        prefixIcon: Icons.low_priority_outlined,
      ),
    ],
  );

  Widget _menu() => _isSimple ? _simpleContent() : _mealEditor();

  Widget _simpleContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _saving || !widget.imageSelectionEnabled ? null : _pickSimpleImage,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(
          _simpleImage == null && _pendingSimpleImage == null
              ? 'Anexar imagem do cardápio'
              : 'Trocar imagem',
        ),
      ),
      if (!widget.imageSelectionEnabled) const Text('Envio de imagem indisponível nesta prévia.'),
      if (_simpleImage != null || _pendingSimpleImage != null) ...[
        const SizedBox(height: CoeloSpacing.space2),
        Text('Arquivo: ${_pendingSimpleImage?.fileName ?? _simpleImage!.title}'),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        controller: _simpleImageAlt,
        labelText: 'Descrição da imagem para acessibilidade',
        prefixIcon: Icons.accessibility_new_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        controller: _simpleNotes,
        labelText: 'Observações',
        prefixIcon: Icons.notes_outlined,
      ),
    ],
  );

  Widget _mealEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < _meals.length; index++) ...[
        _mealCard(index, _meals[index]),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      OutlinedButton.icon(
        onPressed: _saving ? null : () => setState(() => _meals.add(_MealEditor())),
        icon: const Icon(Icons.add_outlined),
        label: const Text('Adicionar refeição'),
      ),
    ],
  );

  Widget _mealCard(int index, _MealEditor meal) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Refeição ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Mover para cima',
                onPressed: index == 0 ? null : () => _moveMeal(index, index - 1),
                icon: const Icon(Icons.arrow_upward_outlined),
              ),
              IconButton(
                tooltip: 'Mover para baixo',
                onPressed: index == _meals.length - 1 ? null : () => _moveMeal(index, index + 1),
                icon: const Icon(Icons.arrow_downward_outlined),
              ),
              IconButton(
                tooltip: 'Duplicar refeição',
                onPressed: () => setState(() => _meals.insert(index + 1, meal.copy())),
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: 'Remover refeição',
                onPressed: _meals.length == 1 ? null : () => _removeMeal(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space3),
          CoeloAdminSingleSelectField<String>(
            label: 'Tipo de refeição',
            value: meal.type,
            options: _mealTypes,
            optionLabel: _mealTypeLabel,
            onChanged: (value) => setState(() => meal.type = value),
            prefixIcon: Icons.restaurant_outlined,
          ),
          if (meal.type == 'other') ...[
            const SizedBox(height: CoeloSpacing.space3),
            CoeloFormTextField(
              controller: meal.customType,
              labelText: 'Nome do tipo de refeição',
              prefixIcon: Icons.edit_outlined,
            ),
          ],
          const SizedBox(height: CoeloSpacing.space3),
          CoeloAdminToggleField(
            label: 'Definir horário de início e fim',
            description: 'O horário final deve ser posterior ao horário inicial.',
            value: meal.hasTime,
            onChanged: (value) => setState(() => meal.hasTime = value),
          ),
          if (meal.hasTime) ...[
            const SizedBox(height: CoeloSpacing.space3),
            _responsivePair(
              CoeloFormTextField(
                controller: meal.startTime,
                labelText: 'Horário inicial (HH:mm)',
                prefixIcon: Icons.schedule_outlined,
              ),
              CoeloFormTextField(
                controller: meal.endTime,
                labelText: 'Horário final (HH:mm)',
                prefixIcon: Icons.schedule_outlined,
              ),
            ),
          ],
          const SizedBox(height: CoeloSpacing.space3),
          CoeloFormTextField(
            controller: meal.dishName,
            labelText: 'Nome da refeição ou prato',
            prefixIcon: Icons.ramen_dining_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          CoeloFormTextField(
            controller: meal.details,
            labelText: 'Detalhes do prato',
            prefixIcon: Icons.description_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          CoeloAdminToggleField(
            label: 'Cadastrar macros e kcal',
            description: 'Informe valores referentes à gramatura selecionada.',
            value: meal.hasNutrition,
            onChanged: (value) => setState(() => meal.hasNutrition = value),
          ),
          if (meal.hasNutrition) ...[
            const SizedBox(height: CoeloSpacing.space3),
            CoeloAdminSingleSelectField<String>(
              label: 'Gramatura de referência',
              value: meal.portionPreset,
              options: const ['50', '100', '150', '200', '250', '300', 'other'],
              optionLabel: (value) => value == 'other' ? 'Outra' : '$value g',
              onChanged: (value) => setState(() => meal.portionPreset = value),
              prefixIcon: Icons.scale_outlined,
            ),
            if (meal.portionPreset == 'other') ...[
              const SizedBox(height: CoeloSpacing.space3),
              CoeloFormTextField(
                controller: meal.portion,
                labelText: 'Gramatura personalizada',
                prefixIcon: Icons.scale_outlined,
              ),
            ],
            const SizedBox(height: CoeloSpacing.space3),
            _responsivePair(
              CoeloFormTextField(
                controller: meal.kcal,
                labelText: 'Kcal',
                prefixIcon: Icons.local_fire_department_outlined,
              ),
              CoeloFormTextField(
                controller: meal.protein,
                labelText: 'Proteína (g)',
                prefixIcon: Icons.fitness_center_outlined,
              ),
            ),
            const SizedBox(height: CoeloSpacing.space3),
            _responsivePair(
              CoeloFormTextField(
                controller: meal.carbs,
                labelText: 'Carboidrato (g)',
                prefixIcon: Icons.grain_outlined,
              ),
              CoeloFormTextField(
                controller: meal.fat,
                labelText: 'Gordura (g)',
                prefixIcon: Icons.water_drop_outlined,
              ),
            ),
          ],
          const SizedBox(height: CoeloSpacing.space3),
          CoeloFormTextField(
            controller: meal.restrictions,
            labelText: 'Restrições e alertas (separados por vírgula)',
            prefixIcon: Icons.warning_amber_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          OutlinedButton.icon(
            onPressed: widget.imageSelectionEnabled ? () => _pickMealImage(meal) : null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              meal.image == null && meal.pendingImage == null
                  ? 'Anexar imagem do prato'
                  : 'Trocar imagem do prato',
            ),
          ),
          if (!widget.imageSelectionEnabled)
            const Text('Envio de imagem indisponível nesta prévia.'),
          if (meal.image != null || meal.pendingImage != null)
            Text('Arquivo: ${meal.pendingImage?.fileName ?? meal.image!.title}'),
          const SizedBox(height: CoeloSpacing.space3),
          CoeloAdminSingleSelectField<MealPlanMealScheduleKind>(
            label: 'Aplicar por',
            value: meal.scheduleKind,
            options: MealPlanMealScheduleKind.values,
            optionLabel: (value) =>
                value == MealPlanMealScheduleKind.weekdays ? 'Dias da semana' : 'Datas específicas',
            onChanged: (value) => setState(() => meal.scheduleKind = value),
            prefixIcon: Icons.calendar_month_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          if (meal.scheduleKind == MealPlanMealScheduleKind.weekdays)
            _weekdayPicker(meal.weekdays)
          else
            CoeloFormTextField(
              controller: meal.specificDates,
              labelText: 'Datas (DD/MM/AAAA, separadas por vírgula)',
              prefixIcon: Icons.event_available_outlined,
            ),
        ],
      ),
    ),
  );

  Widget _responsivePair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 620) {
        return Column(
          children: [
            first,
            const SizedBox(height: CoeloSpacing.space3),
            second,
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(child: second),
        ],
      );
    },
  );

  Widget _weekdayPicker(Set<int> selected) => Wrap(
    spacing: CoeloSpacing.space2,
    runSpacing: CoeloSpacing.space2,
    children: [
      for (var index = 0; index < _weekdays.length; index++)
        FilterChip(
          label: Text(_weekdays[index]),
          selected: selected.contains(index + 1),
          onSelected: (enabled) =>
              setState(() => enabled ? selected.add(index + 1) : selected.remove(index + 1)),
        ),
    ],
  );

  Widget _review() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _summary(widget.isTemplate ? 'Modelo' : 'Cardápio', _name.text),
      _summary('Tipo', _variant == MealPlanPlanVariant.simple ? 'Simples' : 'Completo'),
      _summary('Público', _audienceLabel(_audience)),
      if (!widget.isTemplate) ...[
        _summary('Abrangência', _scopeSummary),
        _summary(
          'Período',
          _period == null ? 'Não informado' : '${_date(_period!.start)} a ${_date(_period!.end)}',
        ),
        _summary('Recorrência', _recurrenceLabel(_recurrence)),
        _summary(
          'Exibição',
          _visibility == MealPlanVisibilityMode.immediate ? 'Imediata' : 'Programada',
        ),
      ],
      _summary('Conteúdo', _isSimple ? 'Imagem simples' : '${_meals.length} refeição(ões)'),
      if (!widget.isTemplate) ...[
        const SizedBox(height: CoeloSpacing.space3),
        CoeloAdminToggleField(
          label: 'Salvar também como modelo',
          description: 'Cria uma base reutilizável sem período ou recorrência.',
          value: _saveAsTemplate,
          onChanged: (value) => setState(() => _saveAsTemplate = value),
        ),
        if (_saveAsTemplate) ...[
          const SizedBox(height: CoeloSpacing.space3),
          CoeloFormTextField(
            controller: _templateName,
            labelText: 'Nome do novo modelo',
            prefixIcon: Icons.library_add_outlined,
          ),
        ],
      ],
      const SizedBox(height: CoeloSpacing.space4),
      const Text(
        'Possível incompatibilidade com uma restrição registrada. Revise as informações e o protocolo da instituição antes de publicar.',
      ),
      if (!widget.isTemplate) ...[
        const SizedBox(height: CoeloSpacing.space3),
        const Text(
          'A publicação será bloqueada se o backend encontrar conflito sem prioridade explícita.',
        ),
      ],
    ],
  );

  String get _scopeSummary {
    final parts = <String>[];
    if (_institutions.isNotEmpty) parts.add('${_institutions.length} instituição(ões)');
    if (_units.isNotEmpty) parts.add('${_units.length} unidade(s)');
    if (_groups.isNotEmpty) parts.add('${_groups.length} turma(s)');
    if (_activities.isNotEmpty) parts.add('${_activities.length} atividade(s)');
    if (_people.isNotEmpty) parts.add('${_people.length} pessoa(s) incluída(s)');
    if (_excludedPeople.isNotEmpty) parts.add('${_excludedPeople.length} exclusão(ões)');
    return parts.isEmpty ? 'Não informada' : parts.join(' · ');
  }

  Widget _summary(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(child: Text(value.trim().isEmpty ? 'Não informado' : value)),
      ],
    ),
  );

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    final mealPlanId = widget.mealPlanId;
    final templatePlanId = widget.templatePlanId;
    final mealPlanModelId = widget.mealPlanModelId;
    final isTemplate = widget.isTemplate;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait<Object>([
        repository.fetchAudienceOptions(),
        repository.fetchTemplatePage(const MealPlanListFilter(pageSize: 100)),
      ]);
      final audienceOptions = results[0] as MealPlanAudienceOptions;
      final templates = (results[1] as MealPlanPage).items
          .where((value) => value.isTemplate)
          .map(
            (value) => MealPlanTemplate(
              id: value.id,
              tenantId: value.tenantId,
              institutionId: value.institutionId,
              name: value.name,
              planVariant: value.planVariant,
              audienceSegment: value.audienceSegment,
              status: value.isDraft ? 'draft' : 'published',
              version: value.revision,
              payload: {
                'menu': value.menu.map((entry) => entry.toJson()).toList(),
                'simpleImage': value.simpleImage?.toJson(),
                'simpleImageAlt': value.simpleImageAlt,
                'simpleNotes': value.simpleNotes,
              },
              createdAt: value.startDate,
              updatedAt: value.endDate,
            ),
          )
          .toList(growable: false);
      MealPlan? original;
      MealPlanTemplate? originalTemplate;
      MealPlanTemplate? sourceTemplate;
      if (isTemplate && mealPlanModelId != null) {
        originalTemplate = await repository.getTemplateById(mealPlanModelId);
        if (originalTemplate.id != mealPlanModelId) {
          throw const MealPlanUnavailableException('O modelo solicitado não pôde ser validado.');
        }
      } else if (mealPlanId != null) {
        original = await repository.getById(mealPlanId);
        if (original.id != mealPlanId) {
          throw const MealPlanUnavailableException('O cardápio solicitado não pôde ser validado.');
        }
      } else if (templatePlanId != null) {
        sourceTemplate = await repository.getTemplateById(templatePlanId);
        if (sourceTemplate.id != templatePlanId) {
          throw const MealPlanUnavailableException(
            'O modelo-base solicitado não pôde ser validado.',
          );
        }
      }
      if (!_isCurrentLoad(
        generation,
        repository,
        mealPlanId,
        templatePlanId,
        mealPlanModelId,
        isTemplate,
      )) {
        return;
      }
      setState(() {
        _audienceOptions = audienceOptions;
        _templates = templates;
        _original = original;
        _originalTemplate = originalTemplate;
        if (originalTemplate != null) {
          _hydrateTemplate(originalTemplate);
        } else if (original != null) {
          _hydratePlan(original);
        } else if (sourceTemplate != null) {
          _templateId = sourceTemplate.id;
          _hydrateTemplate(sourceTemplate, copyName: false);
        }
      });
    } on MealPlanRepositoryException catch (error) {
      if (_isCurrentLoad(
        generation,
        repository,
        mealPlanId,
        templatePlanId,
        mealPlanModelId,
        isTemplate,
      )) {
        setState(() => _error = error.message);
      }
    } finally {
      if (_isCurrentLoad(
        generation,
        repository,
        mealPlanId,
        templatePlanId,
        mealPlanModelId,
        isTemplate,
      )) {
        setState(() => _loading = false);
      }
    }
  }

  bool _isCurrentLoad(
    int generation,
    MealPlanRepository repository,
    String? mealPlanId,
    String? templatePlanId,
    String? mealPlanModelId,
    bool isTemplate,
  ) =>
      mounted &&
      generation == _loadGeneration &&
      identical(repository, widget.repository) &&
      mealPlanId == widget.mealPlanId &&
      templatePlanId == widget.templatePlanId &&
      mealPlanModelId == widget.mealPlanModelId &&
      isTemplate == widget.isTemplate;

  void _resetForLoad() {
    _step = 0;
    _loading = true;
    _saving = false;
    _saveAsTemplate = false;
    _error = null;
    _persistOperationId = null;
    _original = null;
    _originalTemplate = null;
    _audienceOptions = const MealPlanAudienceOptions();
    _templates = const [];
    _variant = MealPlanPlanVariant.complete;
    _audience = MealPlanAudienceSegment.students;
    _visibility = MealPlanVisibilityMode.immediate;
    _recurrence = MealPlanRecurrenceKind.weekly;
    final today = DateUtils.dateOnly(DateTime.now());
    _period = DateTimeRange(start: today, end: today.add(const Duration(days: 6)));
    _visibleDate = null;
    _templateId = '';
    _simpleImage = null;
    _pendingSimpleImage = null;
    _recurrenceWeekdays
      ..clear()
      ..addAll(const {1, 2, 3, 4, 5});
    for (final values in <Set<String>>[
      _institutions,
      _units,
      _groups,
      _activities,
      _people,
      _excludedPeople,
    ]) {
      values.clear();
    }
    _name.clear();
    _simpleImageAlt.clear();
    _simpleNotes.clear();
    _priority.text = '0';
    _cycleWeeks.text = '2';
    _specificDates.clear();
    _excludedDates.clear();
    _templateName.clear();
    for (final meal in _meals) {
      meal.dispose();
    }
    _meals
      ..clear()
      ..add(_MealEditor());
  }

  void _hydratePlan(MealPlan plan) {
    _name.text = plan.name;
    _variant = plan.planVariant;
    _audience = plan.audienceSegment;
    _visibility = plan.visibilityMode;
    _visibleDate = plan.visibleFrom == null
        ? null
        : DateTimeRange(start: plan.visibleFrom!, end: plan.visibleFrom!);
    _period = DateTimeRange(start: plan.startDate, end: plan.endDate);
    _recurrence = plan.recurrence.kind;
    _recurrenceWeekdays
      ..clear()
      ..addAll(plan.recurrence.weekdays);
    _cycleWeeks.text = '${plan.recurrence.cycleWeeks ?? 2}';
    _excludedDates.text = plan.recurrence.excludedDates.map(_date).join(', ');
    _specificDates.text = plan.recurrence.specificDates.map(_date).join(', ');
    _priority.text = '${plan.priority}';
    _templateId = plan.sourceTemplateId ?? '';
    _simpleImage = plan.simpleImage;
    _simpleImageAlt.text = plan.simpleImageAlt ?? '';
    _simpleNotes.text = plan.simpleNotes ?? '';
    _restoreRules(plan.scopeRules);
    _replaceMeals(plan.menu);
  }

  void _hydrateTemplate(MealPlanTemplate template, {bool copyName = true}) {
    _name.text = copyName ? template.name : '${template.name} (cópia)';
    _variant = template.planVariant;
    _audience = template.audienceSegment;
    final payload = template.payload;
    final image = payload['simpleImage'];
    _simpleImage = image is Map
        ? MealPlanAttachmentMeta.fromJson(Map<String, Object?>.from(image))
        : null;
    _simpleImageAlt.text = payload['simpleImageAlt']?.toString() ?? '';
    _simpleNotes.text = payload['simpleNotes']?.toString() ?? '';
    final rawMenu = payload['menu'];
    if (rawMenu is List) {
      _replaceMeals(
        rawMenu
            .whereType<Map<Object?, Object?>>()
            .map((value) => MealPlanMenuEntry.fromJson(Map<String, Object?>.from(value)))
            .toList(),
      );
    }
  }

  void _restoreRules(Map<String, Object?> rules) {
    void restore(String key, Set<String> target) {
      final value = rules[key];
      if (value is List) {
        target.addAll(value.map((item) => item.toString()));
      }
    }

    restore('institutionIds', _institutions);
    restore('unitIds', _units);
    restore('groupIds', _groups);
    restore('activityIds', _activities);
    restore('includedPersonIds', _people);
    restore('excludedPersonIds', _excludedPeople);
  }

  void _replaceMeals(List<MealPlanMenuEntry> entries) {
    if (entries.isEmpty) return;
    for (final meal in _meals) {
      meal.dispose();
    }
    _meals
      ..clear()
      ..addAll(entries.map(_MealEditor.fromEntry));
  }

  void _applyTemplate(String id) {
    setState(() {
      _templateId = id;
      if (id.isEmpty) return;
      final template = _templates.firstWhere((value) => value.id == id);
      _hydrateTemplate(template, copyName: false);
    });
  }

  Future<void> _pickSimpleImage() async {
    final file = await _pickImage();
    if (file != null && mounted) setState(() => _pendingSimpleImage = file);
  }

  Future<void> _pickMealImage(_MealEditor meal) async {
    final file = await _pickImage();
    if (file != null && mounted) setState(() => meal.pendingImage = file);
  }

  Future<_PendingImage?> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const MealPlanValidationException('Não foi possível ler a imagem selecionada.');
    }
    return _PendingImage(
      bytes: bytes,
      fileName: file.name,
      mimeType: _imageMimeType(file.extension),
    );
  }

  String _imageMimeType(String? extension) => switch (extension?.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => throw const MealPlanValidationException('Use uma imagem JPEG, PNG ou WebP.'),
  };

  bool get _hasPendingImages =>
      _pendingSimpleImage != null || _meals.any((meal) => meal.pendingImage != null);

  Future<bool> _uploadPendingImages({
    required String resourceId,
    required MealPlanImageResourceKind resourceKind,
    required MealPlanImageRepository imageRepository,
    required bool Function() isCurrent,
  }) async {
    Future<MealPlanAttachmentMeta> upload(
      _PendingImage pending, {
      required String slot,
      String? replaceAssetId,
    }) async {
      final asset = await imageRepository.upload(
        MealPlanImageUploadRequest(
          resource: resourceKind == MealPlanImageResourceKind.mealPlan
              ? MealPlanImageResource.mealPlan(resourceId)
              : MealPlanImageResource.template(resourceId),
          fileName: pending.fileName,
          mimeType: pending.mimeType,
          bytes: pending.bytes,
          requestId: _newUuid(),
          replaceAssetId: replaceAssetId,
        ),
      );
      return MealPlanAttachmentMeta(kind: 'image', title: pending.fileName, reference: asset.id);
    }

    final simplePending = _pendingSimpleImage;
    if (simplePending != null) {
      if (!isCurrent()) return false;
      final uploaded = await upload(
        simplePending,
        slot: 'simple-cover',
        replaceAssetId: _simpleImage?.reference,
      );
      if (!isCurrent()) return false;
      _simpleImage = uploaded;
      _pendingSimpleImage = null;
    }
    for (var index = 0; index < _meals.length; index++) {
      final meal = _meals[index];
      final pending = meal.pendingImage;
      if (pending == null) continue;
      if (!isCurrent()) return false;
      final uploaded = await upload(
        pending,
        slot: 'meal-$index',
        replaceAssetId: meal.image?.reference,
      );
      if (!isCurrent()) return false;
      meal.image = uploaded;
      meal.pendingImage = null;
    }
    return true;
  }

  void _moveMeal(int from, int to) => setState(() {
    final meal = _meals.removeAt(from);
    _meals.insert(to, meal);
  });

  void _removeMeal(int index) => setState(() => _meals.removeAt(index).dispose());

  void _next() {
    final message = _validateStep();
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    setState(() {
      _error = null;
      _step = (_step + 1).clamp(0, _reviewStep);
    });
  }

  String? _validateStep() {
    if (_step == 0 && _name.text.trim().isEmpty) return 'Informe o nome.';
    if (!widget.isTemplate &&
        _step == 1 &&
        _institutions.isEmpty &&
        _units.isEmpty &&
        _groups.isEmpty &&
        _activities.isEmpty &&
        _people.isEmpty) {
      return 'Selecione ao menos uma instituição, unidade, turma, atividade ou pessoa.';
    }
    if (!widget.isTemplate && _step == 2) {
      if (_period == null) return 'Informe o período do cardápio.';
      if (_visibility == MealPlanVisibilityMode.scheduled && _visibleDate == null) {
        return 'Informe quando o cardápio começa a aparecer.';
      }
      if ((_recurrence == MealPlanRecurrenceKind.weekly ||
              _recurrence == MealPlanRecurrenceKind.biweekly ||
              _recurrence == MealPlanRecurrenceKind.cycleWeeks) &&
          _recurrenceWeekdays.isEmpty) {
        return 'Selecione ao menos um dia da semana.';
      }
    }
    final contentStep = widget.isTemplate ? 1 : 3;
    if (_step == contentStep) return _validateContent();
    return null;
  }

  String? _validateContent() {
    if (_isSimple) {
      if (_simpleImage == null) return 'Anexe a imagem do cardápio simples.';
      if (_simpleImageAlt.text.trim().isEmpty) return 'Descreva a imagem para acessibilidade.';
      return null;
    }
    for (var index = 0; index < _meals.length; index++) {
      final meal = _meals[index];
      if (meal.dishName.text.trim().isEmpty) return 'Informe o prato da refeição ${index + 1}.';
      if (meal.type == 'other' && meal.customType.text.trim().isEmpty) {
        return 'Informe o tipo da refeição ${index + 1}.';
      }
      if (meal.hasTime && !_validTimeRange(meal.startTime.text, meal.endTime.text)) {
        return 'Na refeição ${index + 1}, o horário final deve ser posterior ao inicial.';
      }
      if (meal.scheduleKind == MealPlanMealScheduleKind.weekdays && meal.weekdays.isEmpty) {
        return 'Selecione os dias da refeição ${index + 1}.';
      }
    }
    return null;
  }

  bool _validTimeRange(String start, String end) {
    final pattern = RegExp(r'^(\d{2}):(\d{2})$');
    final a = pattern.firstMatch(start.trim());
    final b = pattern.firstMatch(end.trim());
    if (a == null || b == null) return false;
    final startMinutes = int.parse(a.group(1)!) * 60 + int.parse(a.group(2)!);
    final endMinutes = int.parse(b.group(1)!) * 60 + int.parse(b.group(2)!);
    return startMinutes >= 0 &&
        startMinutes < 1440 &&
        endMinutes > startMinutes &&
        endMinutes < 1440;
  }

  Future<void> _persist({required bool publish}) async {
    final contentError = _validateContent();
    if (_name.text.trim().isEmpty || contentError != null) {
      setState(() => _error = contentError ?? 'Informe o nome.');
      return;
    }
    if (_saveAsTemplate && _templateName.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome do modelo que será criado.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final generation = ++_commandGeneration;
    final repository = widget.repository;
    final imageRepository = widget.imageRepository;
    final mealPlanId = widget.mealPlanId;
    final templatePlanId = widget.templatePlanId;
    final mealPlanModelId = widget.mealPlanModelId;
    final isTemplate = widget.isTemplate;
    bool isCurrent() => _isCurrentCommand(
      generation,
      repository,
      imageRepository,
      mealPlanId,
      templatePlanId,
      mealPlanModelId,
      isTemplate,
    );
    final operationId = _persistOperationId ??= _newUuid();
    try {
      if (isTemplate) {
        var savedTemplate = await repository.saveTemplate(
          MealPlanTemplateDraft(
            requestId: '$operationId-template-save',
            id: mealPlanModelId,
            name: _name.text.trim(),
            planVariant: _variant,
            audienceSegment: _audience,
            expectedVersion: _originalTemplate?.version ?? 0,
            payload: _templatePayload,
          ),
          publish: publish,
        );
        if (!isCurrent()) return;
        if (mealPlanModelId != null && savedTemplate.id != mealPlanModelId) {
          throw const MealPlanUnavailableException('O modelo salvo não corresponde ao solicitado.');
        }
        if (_hasPendingImages) {
          final uploaded = await _uploadPendingImages(
            resourceId: savedTemplate.id,
            resourceKind: MealPlanImageResourceKind.template,
            imageRepository: imageRepository,
            isCurrent: isCurrent,
          );
          if (!uploaded || !isCurrent()) return;
          final savedTemplateId = savedTemplate.id;
          savedTemplate = await repository.saveTemplate(
            MealPlanTemplateDraft(
              requestId: '$operationId-template-media',
              id: savedTemplate.id,
              name: _name.text.trim(),
              planVariant: _variant,
              audienceSegment: _audience,
              expectedVersion: savedTemplate.version,
              payload: _templatePayload,
            ),
            publish: publish,
          );
          if (!isCurrent()) return;
          if (savedTemplate.id != savedTemplateId) {
            throw const MealPlanUnavailableException(
              'O modelo salvo não corresponde ao solicitado.',
            );
          }
        }
      } else {
        final draft = _buildDraft(requestId: '$operationId-save');
        var saved = await repository.createOrUpdateDraft(draft);
        if (!isCurrent()) return;
        if (mealPlanId != null && saved.id != mealPlanId) {
          throw const MealPlanUnavailableException(
            'O cardápio salvo não corresponde ao solicitado.',
          );
        }
        if (_hasPendingImages) {
          final uploaded = await _uploadPendingImages(
            resourceId: saved.id,
            resourceKind: MealPlanImageResourceKind.mealPlan,
            imageRepository: imageRepository,
            isCurrent: isCurrent,
          );
          if (!uploaded || !isCurrent()) return;
          final savedId = saved.id;
          saved = await repository.createOrUpdateDraft(
            _buildDraft(
              requestId: '$operationId-save-media',
              savedMealPlanId: saved.id,
              expectedRevision: saved.revision,
            ),
          );
          if (!isCurrent()) return;
          if (saved.id != savedId) {
            throw const MealPlanUnavailableException(
              'O cardápio salvo não corresponde ao solicitado.',
            );
          }
        }
        if (publish) {
          final conflicts = await repository.checkConflicts(
            scopeLevel: draft.scopeLevel.name,
            scopeId: draft.scopeId,
            startDate: draft.startDate,
            endDate: draft.endDate,
            recurrence: draft.recurrence,
            menu: draft.menu,
          );
          if (!isCurrent()) return;
          if (conflicts.isNotEmpty) {
            setState(
              () => _error =
                  'Publicação bloqueada: resolva ${conflicts.length} conflito(s) e defina prioridade explícita.',
            );
            _persistOperationId = null;
            return;
          }
          final reviewed = await repository.submitForReview(
            saved.id,
            '$operationId-review',
            saved.revision,
          );
          if (!isCurrent()) return;
          if (reviewed.id != saved.id) {
            throw const MealPlanUnavailableException(
              'O cardápio em revisão não corresponde ao solicitado.',
            );
          }
          final published = await repository.publish(
            reviewed.id,
            '$operationId-publish',
            reviewed.revision,
          );
          if (!isCurrent()) return;
          if (published.id != reviewed.id) {
            throw const MealPlanUnavailableException(
              'O cardápio publicado não corresponde ao solicitado.',
            );
          }
        }
      }
      if (!isCurrent()) return;
      _persistOperationId = null;
      widget.onSaved();
    } on MealPlanRepositoryException catch (error) {
      if (!isCurrent()) return;
      if (error is MealPlanConflictException || error is MealPlanValidationException) {
        _persistOperationId = null;
      }
      setState(() => _error = error.message);
    } on Object catch (error) {
      if (isCurrent()) {
        setState(() => _error = 'Não foi possível enviar a imagem. Tente novamente. ($error)');
      }
    } finally {
      if (isCurrent()) setState(() => _saving = false);
    }
  }

  bool _isCurrentCommand(
    int generation,
    MealPlanRepository repository,
    MealPlanImageRepository imageRepository,
    String? mealPlanId,
    String? templatePlanId,
    String? mealPlanModelId,
    bool isTemplate,
  ) =>
      mounted &&
      generation == _commandGeneration &&
      identical(repository, widget.repository) &&
      identical(imageRepository, widget.imageRepository) &&
      mealPlanId == widget.mealPlanId &&
      templatePlanId == widget.templatePlanId &&
      mealPlanModelId == widget.mealPlanModelId &&
      isTemplate == widget.isTemplate;

  MealPlanDraft _buildDraft({
    required String requestId,
    String? savedMealPlanId,
    int? expectedRevision,
  }) {
    final period = _period!;
    final tenantId = _original?.tenantId ?? widget.tenantId;
    final scopeLevel = _people.isNotEmpty
        ? MealPlanScopeLevel.person
        : _activities.isNotEmpty
        ? MealPlanScopeLevel.activity
        : _groups.isNotEmpty
        ? MealPlanScopeLevel.classLevel
        : _units.isNotEmpty
        ? MealPlanScopeLevel.unit
        : MealPlanScopeLevel.institution;
    final scopeId = switch (scopeLevel) {
      MealPlanScopeLevel.person => _people.first,
      MealPlanScopeLevel.activity => _activities.first,
      MealPlanScopeLevel.classLevel => _groups.first,
      MealPlanScopeLevel.unit => _units.first,
      MealPlanScopeLevel.institution => _institutions.first,
      MealPlanScopeLevel.global => '',
    };
    return MealPlanDraft(
      requestId: requestId,
      mealPlanId: savedMealPlanId ?? widget.mealPlanId,
      tenantId: tenantId,
      institutionId: _institutions.firstOrNull ?? _original?.institutionId,
      unitId: _units.firstOrNull ?? _original?.unitId,
      classId: _groups.firstOrNull ?? _original?.classId,
      personId: _people.firstOrNull ?? _original?.personId,
      name: _name.text.trim(),
      sourceType: _institutions.isEmpty
          ? MealPlanSourceType.global
          : MealPlanSourceType.institution,
      scopeLevel: scopeLevel,
      scopeId: scopeId,
      startDate: period.start,
      endDate: period.end,
      recurrence: MealPlanRecurrence(
        kind: _recurrence,
        cycleWeeks: int.tryParse(_cycleWeeks.text),
        weekdays: _recurrenceWeekdays,
        specificDates: _parseDates(_specificDates.text),
        excludedDates: _parseDates(_excludedDates.text),
      ),
      menu: _isSimple ? const [] : _meals.map((meal) => meal.toEntry()).toList(growable: false),
      priority: int.tryParse(_priority.text.trim()) ?? 0,
      expectedRevision: expectedRevision ?? _original?.revision ?? 0,
      planVariant: _variant,
      audienceSegment: _audience,
      visibilityMode: _visibility,
      visibleFrom: _visibleDate?.start,
      sourceTemplateId: _templateId.isEmpty ? null : _templateId,
      sourceTemplateVersion: _templateId.isEmpty
          ? null
          : _templates.firstWhere((value) => value.id == _templateId).version,
      scopeRules: {
        'institutionIds': _institutions.toList(),
        'unitIds': _units.toList(),
        'groupIds': _groups.toList(),
        'activityIds': _activities.toList(),
        'includedPersonIds': _people.toList(),
        'excludedPersonIds': _excludedPeople.toList(),
        'dynamicFutureMembership': true,
        'historyPolicy': 'from_membership_start',
      },
      simpleImage: _simpleImage,
      simpleImageAlt: _simpleImageAlt.text.trim(),
      simpleNotes: _simpleNotes.text.trim(),
      saveAsTemplate: _saveAsTemplate,
      templateName: _saveAsTemplate ? _templateName.text.trim() : null,
    );
  }

  Map<String, Object?> get _templatePayload => {
    'menu': _isSimple ? <Object?>[] : _meals.map((meal) => meal.toEntry().toJson()).toList(),
    'simpleImage': _simpleImage?.toJson(),
    'simpleImageAlt': _simpleImageAlt.text.trim(),
    'simpleNotes': _simpleNotes.text.trim(),
  };

  List<DateTime> _parseDates(String input) => input
      .split(',')
      .map((value) => value.trim())
      .map((value) {
        final parts = value.split('/');
        if (parts.length != 3) return null;
        return DateTime.tryParse(
          '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}',
        );
      })
      .whereType<DateTime>()
      .toList(growable: false);

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _audienceLabel(MealPlanAudienceSegment value) => switch (value) {
    MealPlanAudienceSegment.students => 'Alunos',
    MealPlanAudienceSegment.staff => 'Funcionários',
    MealPlanAudienceSegment.all => 'Alunos e funcionários',
  };

  static String _recurrenceLabel(MealPlanRecurrenceKind value) => switch (value) {
    MealPlanRecurrenceKind.singleWeek => 'Semana única',
    MealPlanRecurrenceKind.interval => 'Intervalo',
    MealPlanRecurrenceKind.daily => 'Diária',
    MealPlanRecurrenceKind.weekly => 'Semanal',
    MealPlanRecurrenceKind.biweekly => 'Quinzenal',
    MealPlanRecurrenceKind.cycleWeeks => 'Ciclo de N semanas',
    MealPlanRecurrenceKind.specificDates => 'Datas específicas',
  };

  static String _mealTypeLabel(String value) => switch (value) {
    'breakfast' => 'Café da manhã',
    'brunch' => 'Brunch',
    'lunch' => 'Almoço',
    'afternoonSnack' => 'Lanche da tarde',
    'dinner' => 'Jantar',
    'supper' => 'Ceia',
    _ => 'Outro',
  };
}

final class _MealEditor {
  _MealEditor({
    this.type = 'lunch',
    this.hasTime = false,
    this.hasNutrition = false,
    this.portionPreset = '100',
    this.scheduleKind = MealPlanMealScheduleKind.weekdays,
    Set<int>? weekdays,
    this.image,
  }) : weekdays = weekdays ?? {1, 2, 3, 4, 5};

  factory _MealEditor.fromEntry(MealPlanMenuEntry entry) {
    final editor = _MealEditor(
      type: entry.mealType,
      hasTime: entry.hasTime,
      hasNutrition: entry.hasNutrition,
      portionPreset:
          entry.portionGrams != null &&
              const [50, 100, 150, 200, 250, 300].contains(entry.portionGrams!.round())
          ? '${entry.portionGrams!.round()}'
          : 'other',
      scheduleKind: entry.scheduleKind,
      weekdays: {...entry.weekdays},
      image: entry.image,
    );
    editor.customType.text = entry.customMealType ?? '';
    editor.startTime.text = entry.startTime ?? '';
    editor.endTime.text = entry.endTime ?? '';
    editor.dishName.text = entry.dishName;
    editor.details.text = entry.details ?? '';
    editor.portion.text = entry.portionGrams?.toString() ?? '';
    editor.kcal.text = entry.energyKcal?.toString() ?? '';
    editor.protein.text = entry.proteinG?.toString() ?? '';
    editor.carbs.text = entry.carbohydrateG?.toString() ?? '';
    editor.fat.text = entry.fatG?.toString() ?? '';
    editor.restrictions.text = entry.restrictions.join(', ');
    editor.specificDates.text = entry.specificDates.map(_MealPlanWizardPageState._date).join(', ');
    return editor;
  }

  String type;
  bool hasTime;
  bool hasNutrition;
  String portionPreset;
  MealPlanMealScheduleKind scheduleKind;
  final Set<int> weekdays;
  MealPlanAttachmentMeta? image;
  _PendingImage? pendingImage;
  final customType = TextEditingController();
  final startTime = TextEditingController();
  final endTime = TextEditingController();
  final dishName = TextEditingController();
  final details = TextEditingController();
  final portion = TextEditingController();
  final kcal = TextEditingController();
  final protein = TextEditingController();
  final carbs = TextEditingController();
  final fat = TextEditingController();
  final restrictions = TextEditingController();
  final specificDates = TextEditingController();

  _MealEditor copy() => _MealEditor.fromEntry(toEntry());

  MealPlanMenuEntry toEntry() {
    double? number(TextEditingController controller) =>
        double.tryParse(controller.text.trim().replaceAll(',', '.'));
    List<String> list(TextEditingController controller) => controller.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    List<DateTime> dates(TextEditingController controller) => controller.text
        .split(',')
        .map((value) {
          final parts = value.trim().split('/');
          return parts.length == 3
              ? DateTime.tryParse(
                  '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}',
                )
              : null;
        })
        .whereType<DateTime>()
        .toList(growable: false);
    return MealPlanMenuEntry(
      mealType: type,
      customMealType: type == 'other' ? customType.text.trim() : null,
      hasTime: hasTime,
      startTime: hasTime ? startTime.text.trim() : null,
      endTime: hasTime ? endTime.text.trim() : null,
      dishName: dishName.text.trim(),
      details: details.text.trim(),
      hasNutrition: hasNutrition,
      portionGrams: hasNutrition
          ? (portionPreset == 'other' ? number(portion) : double.tryParse(portionPreset))
          : null,
      energyKcal: hasNutrition ? number(kcal) : null,
      proteinG: hasNutrition ? number(protein) : null,
      carbohydrateG: hasNutrition ? number(carbs) : null,
      fatG: hasNutrition ? number(fat) : null,
      restrictions: list(restrictions),
      image: image,
      scheduleKind: scheduleKind,
      weekdays: scheduleKind == MealPlanMealScheduleKind.weekdays ? weekdays : const {},
      specificDates: scheduleKind == MealPlanMealScheduleKind.specificDates
          ? dates(specificDates)
          : const [],
    );
  }

  void dispose() {
    for (final controller in <TextEditingController>[
      customType,
      startTime,
      endTime,
      dishName,
      details,
      portion,
      kcal,
      protein,
      carbs,
      fat,
      restrictions,
      specificDates,
    ]) {
      controller.dispose();
    }
  }
}

final class _PendingImage {
  const _PendingImage({required this.bytes, required this.fileName, required this.mimeType});

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

String _newUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
