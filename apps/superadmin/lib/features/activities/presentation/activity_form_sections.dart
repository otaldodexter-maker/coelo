import 'dart:typed_data';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/widgets/superadmin_advanced_color_picker_dialog.dart';
import '../../../shared/presentation/widgets/avatar_crop_dialog.dart';
import '../../institutions/presentation/widgets/institution_logo_picker_stub.dart'
    if (dart.library.html) '../../institutions/presentation/widgets/institution_logo_picker_web.dart';
import '../domain/activity_directory.dart';
import '../domain/activity_profile_about_repository.dart';
import 'activity_form_controller.dart';
import 'activity_form_draft.dart';
import 'activity_form_page.dart';
import 'activity_pedagogical_configuration_draft.dart';
import 'activity_profile_about_section.dart';

final class ActivityFormSection extends StatefulWidget {
  const ActivityFormSection({
    required this.controller,
    required this.onCreateLocation,
    required this.onRetryCatalogOptions,
    required this.imagePicker,
    required this.aboutRepository,
    required this.activityId,
    super.key,
  });

  final ActivityFormController controller;
  final ActivityLocationCreator onCreateLocation;
  final Future<void> Function() onRetryCatalogOptions;
  final InstitutionLogoPicker imagePicker;
  final ActivityProfileAboutRepository aboutRepository;
  final String? activityId;

  @override
  State<ActivityFormSection> createState() => _ActivityFormSectionState();
}

final class _ActivityFormSectionState extends State<ActivityFormSection> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return KeyedSubtree(
      key: ValueKey(controller.currentStep),
      child:
          (controller.currentStep == ActivityFormStep.links ||
                  controller.currentStep == ActivityFormStep.professionals) &&
              !controller.scopedOptionsAvailable
          ? CoeloStatePanel(
              title: controller.scopedOptionsLoading
                  ? 'Carregando dados da instituição'
                  : controller.scopedOptionsError != null
                  ? 'Não foi possível carregar os vínculos'
                  : 'Selecione uma instituição',
              message: controller.scopedOptionsLoading
                  ? 'Aguarde para configurar estrutura e vínculos.'
                  : controller.scopedOptionsError ??
                        'Volte à identidade e escolha a instituição da atividade.',
              icon: controller.scopedOptionsLoading
                  ? Icons.hourglass_top_rounded
                  : Icons.cloud_off_outlined,
              actionLabel: controller.scopedOptionsError == null ? null : 'Tentar novamente',
              onAction: controller.scopedOptionsError == null
                  ? null
                  : controller.retryScopedOptions,
            )
          : switch (controller.currentStep) {
              ActivityFormStep.identity => _IdentitySection(
                controller: controller,
                imagePicker: widget.imagePicker,
                onRetryCatalogOptions: widget.onRetryCatalogOptions,
              ),
              ActivityFormStep.structure => _StructureSection(
                controller: controller,
                onCreateLocation: widget.onCreateLocation,
              ),
              ActivityFormStep.pedagogical => _PedagogicalSection(controller: controller),
              ActivityFormStep.links => _LinksSection(controller: controller),
              ActivityFormStep.about => ActivityProfileAboutSection(
                controller: controller,
                repository: widget.aboutRepository,
                activityId: widget.activityId,
              ),
              ActivityFormStep.professionals => _ProfessionalsSection(controller: controller),
            },
    );
  }
}

final class _IdentitySection extends StatelessWidget {
  const _IdentitySection({
    required this.controller,
    required this.imagePicker,
    required this.onRetryCatalogOptions,
  });

  final ActivityFormController controller;
  final InstitutionLogoPicker imagePicker;
  final Future<void> Function() onRetryCatalogOptions;

  Future<void> _pickImage(BuildContext context) async {
    final file = await imagePicker();
    if (file == null || !context.mounted) return;
    final result = await showDialog<AvatarCropResult>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => AvatarCropDialog(bytes: file.bytes),
    );
    if (result != null) controller.setImage(name: file.name, bytes: result.bytes);
  }

  Future<void> _pickColor(BuildContext context) async {
    final selected = await showSuperadminAdvancedColorPicker(
      context,
      initialColor: _activityIdentityColor(controller.identityColor),
      title: 'Cor da sigla',
    );
    if (selected == null) return;
    controller.setIdentityColor(
      '#${selected.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader(
        title: 'Identidade da atividade',
        description: 'Defina como a atividade será reconhecida nos contextos da instituição.',
      ),
      if (controller.catalogOptionsLoading || controller.catalogOptionsError != null) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloStatePanel(
          key: const Key('activity-catalog-options-state'),
          title: controller.catalogOptionsLoading
              ? 'Carregando categorias e modelos'
              : 'Categorias e modelos indisponíveis',
          message: controller.catalogOptionsLoading
              ? 'Aguarde enquanto o catálogo é atualizado.'
              : 'Você pode continuar preenchendo a atividade e tentar carregar o catálogo novamente.',
          loading: controller.catalogOptionsLoading,
          icon: controller.catalogOptionsLoading ? null : Icons.cloud_off_outlined,
        ),
        if (!controller.catalogOptionsLoading)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              key: const Key('activity-catalog-options-retry'),
              onPressed: onRetryCatalogOptions,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ),
      ],
      const SizedBox(height: CoeloSpacing.space5),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ActivityAvatar(
            bytes: controller.imageBytes,
            initials: controller.initials.text,
            color: controller.identityColor,
            icon: controller.identityIcon,
          ),
          const SizedBox(width: CoeloSpacing.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Foto de perfil', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: CoeloSpacing.space1),
                Text(
                  'PNG, JPG ou WebP.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space2),
                OutlinedButton.icon(
                  key: const Key('activity-form-image'),
                  onPressed: () => _pickImage(context),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(controller.hasIdentityImage ? 'Trocar foto' : 'Adicionar foto'),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space5),
      _ResponsiveGrid(
        children: [
          CoeloFormTextField(
            fieldKey: const Key('activity-form-name'),
            controller: controller.name,
            labelText: 'Nome',
            hintText: 'Como a atividade aparece no Coelo',
            prefixIcon: Icons.badge_outlined,
            errorText: controller.nameError,
            textInputAction: TextInputAction.next,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoeloFormTextField(
                fieldKey: const Key('activity-form-handle'),
                controller: controller.handleStem,
                labelText: '@ da atividade',
                hintText: controller.name.text.trim().isEmpty
                    ? 'nome-da-atividade'
                    : controller.name.text.trim(),
                prefixIcon: Icons.alternate_email_rounded,
                errorText: controller.handleStemError,
                maxLength: 64,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                'Opcional. O Coelo sugere a partir do nome e aplica o sufixo hierárquico no servidor.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          CoeloFormTextField(
            fieldKey: const Key('activity-form-initials'),
            controller: controller.initials,
            labelText: 'Sigla sem foto',
            hintText: 'RB',
            prefixIcon: Icons.text_fields_rounded,
            maxLength: 4,
            textInputAction: TextInputAction.next,
          ),
          OutlinedButton.icon(
            key: const Key('activity-form-identity-color'),
            onPressed: () => _pickColor(context),
            icon: DecoratedBox(
              decoration: BoxDecoration(
                color: _activityIdentityColor(controller.identityColor),
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: const SizedBox.square(dimension: CoeloSize.iconMd),
            ),
            label: const Text('Escolher cor da sigla'),
          ),
          CoeloAdminSingleSelectField<ActivityIdentityIcon>(
            key: const Key('activity-form-identity-icon'),
            label: 'Ícone sem foto ou sigla',
            value: controller.identityIcon,
            options: ActivityIdentityIcon.values,
            optionLabel: _activityIdentityIconLabel,
            onChanged: controller.selectIdentityIcon,
            prefixIcon: Icons.local_activity_outlined,
          ),
          CoeloAdminSingleSelectField<ActivityGovernance>(
            key: const Key('activity-form-governance'),
            label: 'Tipo da atividade',
            value: controller.governance,
            options: controller.governanceLocked
                ? const [ActivityGovernance.fixed]
                : const [ActivityGovernance.optional, ActivityGovernance.mandatory],
            optionLabel: (value) => switch (value) {
              ActivityGovernance.optional => 'Opcional',
              ActivityGovernance.mandatory => 'Obrigatória',
              ActivityGovernance.fixed => 'Fixa',
            },
            onChanged: controller.selectGovernance,
            enabled: !controller.governanceLocked,
            prefixIcon: Icons.rule_rounded,
          ),
          CoeloAdminSingleSelectField<ActivityTaxonomyOption?>(
            key: const Key('activity-form-category'),
            label: 'Categoria',
            value: controller.taxonomy,
            options: [null, ...controller.taxonomyOptions],
            optionLabel: (value) => value?.label ?? 'Selecione a categoria',
            onChanged: (value) {
              if (value != null) controller.selectTaxonomy(value);
            },
            prefixIcon: Icons.category_outlined,
          ),
          if (controller.subtypeOptions.isNotEmpty)
            CoeloAdminSingleSelectField<ActivityTaxonomySubtypeOption?>(
              key: const Key('activity-form-subtype'),
              label: 'Subtipo',
              value: controller.subtype,
              options: [null, ...controller.subtypeOptions],
              optionLabel: (value) => value?.label ?? 'Sem subtipo',
              onChanged: controller.selectSubtype,
              prefixIcon: Icons.account_tree_outlined,
            ),
          if (controller.taxonomy?.isOther != true && controller.activityTemplates.isNotEmpty)
            CoeloAdminSingleSelectField<ActivityTemplateOption?>(
              key: const Key('activity-form-template'),
              label: 'Atividade',
              value: controller.template,
              options: [null, ...controller.activityTemplates],
              optionLabel: (value) => value?.name ?? 'Sem modelo',
              onChanged: controller.selectTemplate,
              prefixIcon: Icons.local_activity_outlined,
            ),
          if (controller.taxonomy?.isOther == true)
            CoeloFormTextField(
              fieldKey: const Key('activity-form-other'),
              controller: controller.otherActivity,
              labelText: 'Descrição de Outros',
              hintText: 'Descreva a categoria da atividade',
              prefixIcon: Icons.edit_outlined,
            ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        fieldKey: const Key('activity-form-description'),
        controller: controller.description,
        labelText: 'Descrição',
        hintText: 'Descreva o propósito da atividade',
        prefixIcon: Icons.notes_rounded,
        maxLines: 4,
        textInputAction: TextInputAction.newline,
      ),
    ],
  );
}

final class _StructureSection extends StatelessWidget {
  const _StructureSection({required this.controller, required this.onCreateLocation});

  final ActivityFormController controller;
  final ActivityLocationCreator onCreateLocation;

  Future<void> _createLocation(BuildContext context) async {
    final institutionId = controller.selectedInstitutionId;
    if (institutionId == null || controller.selectedUnitIds.isEmpty) return;
    final options = await showDialog<List<ActivityFormLocationOption>>(
      context: context,
      barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
      builder: (context) => _CreateLocationDialog(
        institutionId: institutionId,
        units: controller.units
            .where((unit) => controller.selectedUnitIds.contains(unit.id))
            .toList(growable: false),
        onCreate: onCreateLocation,
      ),
    );
    if (options != null) controller.addLocations(options);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader(
        title: 'Estrutura e locais',
        description: 'A atividade pertence à instituição e precisa de ao menos uma unidade.',
      ),
      const SizedBox(height: CoeloSpacing.space5),
      CoeloAdminSingleSelectField<String>(
        key: const Key('activity-form-institution'),
        label: 'Instituição',
        value: controller.selectedInstitutionId ?? '',
        options: ['', ...controller.options.institutions.map((item) => item.id)],
        optionLabel: (id) => id.isEmpty
            ? 'Selecione a instituição'
            : controller.options.institutions.firstWhere((item) => item.id == id).name,
        onChanged: controller.selectInstitution,
        enabled: !controller.institutionLocked,
        errorText: controller.institutionError,
        prefixIcon: Icons.apartment_outlined,
        searchable: true,
        searchHintText: 'Buscar instituição',
      ),
      if (controller.scopedOptionsLoading) ...[
        const SizedBox(height: CoeloSpacing.space2),
        const LinearProgressIndicator(key: Key('activity-scoped-options-loading')),
      ],
      if (controller.scopedOptionsError != null) ...[
        const SizedBox(height: CoeloSpacing.space2),
        Text(
          controller.scopedOptionsError!,
          key: const Key('activity-scoped-options-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(
          key: const Key('activity-scoped-options-retry'),
          onPressed: controller.retryScopedOptions,
          child: const Text('Tentar novamente'),
        ),
      ],
      const SizedBox(height: CoeloSpacing.space5),
      _SearchableSelectionSection<ActivityFormUnitOption>(
        title: 'Unidades',
        description: 'Selecione todas as unidades em que a atividade estará disponível.',
        error: controller.unitsError,
        items: controller.units,
        itemLabel: (unit) => unit.name,
        searchKey: const Key('activity-units-search'),
        searchHintText: 'Buscar unidade',
        itemBuilder: (unit) => _SelectableCard(
          key: Key('activity-unit-${unit.id}'),
          label: unit.name,
          supportingText: 'Unidade da instituição selecionada',
          selected: controller.selectedUnitIds.contains(unit.id),
          onPressed: () => controller.toggleUnit(unit.id),
        ),
      ),
      const SizedBox(height: CoeloSpacing.space5),
      LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
          final selector = CoeloAdminSingleSelectField<String>(
            key: const Key('activity-form-location'),
            label: 'Local interno (opcional)',
            value: controller.selectedLocationId ?? '',
            options: ['', ...controller.locations.map((item) => item.id)],
            optionLabel: (id) => id.isEmpty
                ? 'Sem local definido'
                : controller.locations.firstWhere((item) => item.id == id).name,
            onChanged: controller.selectLocation,
            enabled: controller.selectedUnitIds.isNotEmpty,
            prefixIcon: Icons.meeting_room_outlined,
          );
          final createAction = OutlinedButton.icon(
            key: const Key('activity-create-location'),
            onPressed: controller.selectedUnitIds.isEmpty ? null : () => _createLocation(context),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Cadastrar local'),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                selector,
                const SizedBox(height: CoeloSpacing.space3),
                SizedBox(width: double.infinity, child: createAction),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: selector),
              const SizedBox(width: CoeloSpacing.space3),
              createAction,
            ],
          );
        },
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(
        'Locais são espaços internos da unidade, como laboratório, quadra ou sala temática.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

final class _PedagogicalSection extends StatefulWidget {
  const _PedagogicalSection({required this.controller});

  final ActivityFormController controller;

  @override
  State<_PedagogicalSection> createState() => _PedagogicalSectionState();
}

final class _PedagogicalSectionState extends State<_PedagogicalSection> {
  final Map<String, TextEditingController> _textControllers = {};

  ActivityPedagogicalConfigurationDraft get value => widget.controller.pedagogicalConfiguration;

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _text(String key, String text) {
    final controller = _textControllers.putIfAbsent(key, () => TextEditingController(text: text));
    if (controller.text != text && !controller.selection.isValid) {
      controller.text = text;
    }
    return controller;
  }

  void _set(ActivityPedagogicalConfigurationDraft next) {
    widget.controller.setPedagogicalConfiguration(next);
  }

  void _toggleEnabled(bool enabled) {
    if (!enabled) {
      _set(const ActivityPedagogicalConfigurationDraft.disabled());
      return;
    }
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31);
    _set(
      ActivityPedagogicalConfigurationDraft(
        enabled: true,
        model: ActivityAssessmentModel.gradeOnly,
        periodicity: ActivityAssessmentPeriodicity.bimonthly,
        validityStart: start,
        validityEnd: end,
        gradeScale: ActivityGradeScale.numeric0To10,
        periods: ActivityPedagogicalConfigurationDraft.suggestPeriods(
          periodicity: ActivityAssessmentPeriodicity.bimonthly,
          validityStart: start,
          validityEnd: end,
          timezone: 'America/Sao_Paulo',
        ),
        instruments: const [
          ActivityAssessmentInstrumentDraft(
            clientId: 'instrument-1',
            name: 'Prova',
            kind: ActivityAssessmentInstrumentKind.exam,
            weight: 100,
            order: 1,
          ),
        ],
      ),
    );
  }

  void _setModel(ActivityAssessmentModel model) {
    final usesGrades =
        model == ActivityAssessmentModel.gradeOnly ||
        model == ActivityAssessmentModel.gradeAndCompetencies;
    final usesCompetencies =
        model == ActivityAssessmentModel.competenciesOnly ||
        model == ActivityAssessmentModel.gradeAndCompetencies;
    _set(
      value.copyWith(
        model: model,
        gradeScale: usesGrades ? value.gradeScale ?? ActivityGradeScale.numeric0To10 : null,
        competencyScale: usesCompetencies ? ActivityCompetencyScale.oneToFive : null,
        instruments: usesGrades && value.instruments.isEmpty
            ? const [
                ActivityAssessmentInstrumentDraft(
                  clientId: 'instrument-1',
                  name: 'Prova',
                  kind: ActivityAssessmentInstrumentKind.exam,
                  weight: 100,
                  order: 1,
                ),
              ]
            : value.instruments,
        taxonomyVersionId: usesCompetencies
            ? value.taxonomyVersionId ?? _communicationTaxonomyVersionId
            : null,
        categories: usesCompetencies && value.categories.isEmpty
            ? const [
                ActivityAssessmentCategoryDraft(
                  clientId: 'communication',
                  name: 'Comunicação',
                  order: 1,
                  taxonomyVersionId: _communicationTaxonomyVersionId,
                  competencies: [
                    ActivityAssessmentCompetencyDraft(
                      clientId: 'speech',
                      name: 'Fala',
                      order: 1,
                      taxonomyVersionId: _communicationTaxonomyVersionId,
                    ),
                  ],
                ),
              ]
            : value.categories,
        recoveryRule: usesGrades ? value.recoveryRule : ActivityRecoveryRule.none,
      ),
    );
  }

  void _applyPreset(String templateId) {
    final preset = _assessmentPresets.firstWhere((item) => item.id == templateId);
    final start = value.validityStart ?? DateTime(DateTime.now().year, 1, 1);
    final end = value.validityEnd ?? DateTime(DateTime.now().year, 12, 31);
    final usesGrades = preset.model != ActivityAssessmentModel.competenciesOnly;
    final usesCompetencies = preset.model != ActivityAssessmentModel.gradeOnly;
    final taxonomyId = usesCompetencies ? preset.taxonomyVersionId : null;
    _set(
      ActivityPedagogicalConfigurationDraft(
        enabled: true,
        model: preset.model,
        periodicity: preset.periodicity,
        validityStart: start,
        validityEnd: end,
        timezone: value.timezone,
        gradeScale: preset.gradeScale,
        competencyScale: usesCompetencies ? ActivityCompetencyScale.oneToFive : null,
        conceptLevels: preset.gradeScale == ActivityGradeScale.concepts
            ? const ['Em desenvolvimento', 'Atendeu', 'Superou']
            : const [],
        periods: ActivityPedagogicalConfigurationDraft.suggestPeriods(
          periodicity: preset.periodicity,
          validityStart: start,
          validityEnd: end,
          timezone: value.timezone,
        ),
        instruments: usesGrades
            ? const [
                ActivityAssessmentInstrumentDraft(
                  clientId: 'preset-instrument-1',
                  name: 'Avaliação',
                  kind: ActivityAssessmentInstrumentKind.exam,
                  weight: 100,
                  order: 1,
                ),
              ]
            : const [],
        taxonomyVersionId: taxonomyId,
        categories: usesCompetencies
            ? [
                ActivityAssessmentCategoryDraft(
                  clientId: 'preset-category-1',
                  name: preset.category,
                  order: 1,
                  taxonomyVersionId: taxonomyId!,
                  competencies: [
                    ActivityAssessmentCompetencyDraft(
                      clientId: 'preset-competency-1',
                      name: preset.competency,
                      order: 1,
                      taxonomyVersionId: taxonomyId,
                    ),
                  ],
                ),
              ]
            : const [],
        recoveryRule: ActivityRecoveryRule.none,
        templateId: templateId,
        templateVersion: 1,
        expectedVersion: value.expectedVersion,
        usedByResults: value.usedByResults,
        changeJustification: value.changeJustification,
      ),
    );
  }

  void _setPeriodicity(ActivityAssessmentPeriodicity periodicity) {
    final start = value.validityStart;
    final end = value.validityEnd;
    _set(
      value.copyWith(
        periodicity: periodicity,
        periods: start == null || end == null
            ? const []
            : ActivityPedagogicalConfigurationDraft.suggestPeriods(
                periodicity: periodicity,
                validityStart: start,
                validityEnd: end,
                timezone: value.timezone,
              ),
      ),
    );
  }

  void _setValidity(DateTimeRange? range) {
    if (range == null) return;
    final periodicity = value.periodicity ?? ActivityAssessmentPeriodicity.bimonthly;
    _set(
      value.copyWith(
        validityStart: range.start,
        validityEnd: range.end,
        periodicity: periodicity,
        periods: ActivityPedagogicalConfigurationDraft.suggestPeriods(
          periodicity: periodicity,
          validityStart: range.start,
          validityEnd: range.end,
          timezone: value.timezone,
        ),
      ),
    );
  }

  void _updatePeriod(int index, ActivityAssessmentPeriodDraft period) {
    final periods = [...value.periods]..[index] = period;
    _set(value.copyWith(periods: periods));
  }

  void _updateInstrument(int index, ActivityAssessmentInstrumentDraft instrument) {
    final instruments = [...value.instruments]..[index] = instrument;
    _set(value.copyWith(instruments: instruments));
  }

  void _moveInstrument(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= value.instruments.length) return;
    final instruments = [...value.instruments];
    final item = instruments.removeAt(index);
    instruments.insert(target, item);
    _set(
      value.copyWith(
        instruments: [
          for (var position = 0; position < instruments.length; position++)
            instruments[position].copyWith(order: position + 1),
        ],
      ),
    );
  }

  void _removeInstrument(int index) {
    final instruments = [...value.instruments]..removeAt(index);
    _set(
      value.copyWith(
        instruments: [
          for (var position = 0; position < instruments.length; position++)
            instruments[position].copyWith(order: position + 1),
        ],
      ),
    );
  }

  void _addInstrument() {
    final order = value.instruments.length + 1;
    _set(
      value.copyWith(
        instruments: [
          ...value.instruments,
          ActivityAssessmentInstrumentDraft(
            clientId: 'instrument-$order',
            name: 'Novo instrumento',
            kind: ActivityAssessmentInstrumentKind.custom,
            weight: 0,
            order: order,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDate = DateTime(DateTime.now().year - 1);
    final lastDate = DateTime(DateTime.now().year + 10, 12, 31);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Configuração pedagógica',
          description:
              'Defina avaliação, períodos, datas e horas, instrumentos, competências e recuperação.',
        ),
        const SizedBox(height: CoeloSpacing.space5),
        CoeloAdminToggleField(
          key: const Key('activity-assessment-enabled'),
          label: 'Habilitar avaliação',
          description: value.enabled
              ? 'A atividade terá acompanhamento avaliativo versionado.'
              : 'A atividade será salva explicitamente sem avaliação.',
          value: value.enabled,
          onChanged: _toggleEnabled,
        ),
        if (!value.enabled) ...[
          const SizedBox(height: CoeloSpacing.space5),
          CoeloStatePanel(
            title: 'Atividade sem avaliação',
            message:
                'Nenhum período, instrumento, competência ou regra de recuperação será criado.',
            icon: Icons.do_not_disturb_alt_outlined,
          ),
        ] else ...[
          const SizedBox(height: CoeloSpacing.space5),
          CoeloAdminSingleSelectField<String>(
            key: const Key('activity-assessment-preset'),
            label: 'Modelo Coelo (opcional)',
            value: value.templateId ?? '',
            options: ['', ..._assessmentPresets.map((item) => item.id)],
            optionLabel: (id) => id.isEmpty
                ? 'Configuração personalizada'
                : _assessmentPresets.firstWhere((item) => item.id == id).label,
            onChanged: (id) {
              if (id.isNotEmpty) _applyPreset(id);
            },
            prefixIcon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          _ResponsiveGrid(
            children: [
              CoeloAdminSingleSelectField<ActivityAssessmentModel>(
                key: const Key('activity-assessment-model'),
                label: 'Modelo de acompanhamento',
                value: value.model,
                options: const [
                  ActivityAssessmentModel.gradeOnly,
                  ActivityAssessmentModel.competenciesOnly,
                  ActivityAssessmentModel.gradeAndCompetencies,
                ],
                optionLabel: _assessmentModelLabel,
                onChanged: _setModel,
                prefixIcon: Icons.fact_check_outlined,
              ),
              CoeloAdminSingleSelectField<ActivityAssessmentPeriodicity>(
                key: const Key('activity-assessment-periodicity'),
                label: 'Periodicidade',
                value: value.periodicity ?? ActivityAssessmentPeriodicity.bimonthly,
                options: ActivityAssessmentPeriodicity.values,
                optionLabel: _periodicityLabel,
                onChanged: _setPeriodicity,
                prefixIcon: Icons.event_repeat_outlined,
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          CoeloDateRangeField(
            key: const Key('activity-assessment-validity'),
            value: value.validityStart == null || value.validityEnd == null
                ? null
                : DateTimeRange(start: value.validityStart!, end: value.validityEnd!),
            onChanged: _setValidity,
            firstDate: firstDate,
            lastDate: lastDate,
            labelText: 'Vigência da configuração',
            errorText: value.validationErrors.contains('assessment_validity_required')
                ? 'Defina a vigência.'
                : null,
          ),
          if (value.usesGrades) ...[const SizedBox(height: CoeloSpacing.space5), _gradeSection()],
          if (value.usesCompetencies) ...[
            const SizedBox(height: CoeloSpacing.space5),
            _competencySection(),
          ],
          const SizedBox(height: CoeloSpacing.space5),
          _periodsSection(firstDate: firstDate, lastDate: lastDate),
          if (value.usedByResults) ...[
            const SizedBox(height: CoeloSpacing.space5),
            CoeloFormTextField(
              controller: _text('assessment-justification', value.changeJustification),
              labelText: 'Justificativa da nova versão',
              prefixIcon: Icons.history_edu_outlined,
              maxLines: 3,
              errorText: value.validationErrors.contains('change_justification_required')
                  ? 'Informe a justificativa porque já existem lançamentos.'
                  : null,
              onChanged: (text) => _set(value.copyWith(changeJustification: text)),
            ),
          ],
          if (widget.controller.pedagogicalError case final error?) ...[
            const SizedBox(height: CoeloSpacing.space4),
            CoeloStatePanel(
              title: 'Revise a configuração',
              message: error,
              icon: Icons.error_outline,
            ),
          ],
          const SizedBox(height: CoeloSpacing.space5),
          _reviewSection(),
        ],
      ],
    );
  }

  Widget _gradeSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionHeader(
        title: 'Notas, instrumentos e pesos',
        description: 'Os pesos ativos precisam totalizar exatamente 100%.',
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<ActivityGradeScale>(
        key: const Key('activity-assessment-grade-scale'),
        label: 'Escala de notas',
        value: value.gradeScale ?? ActivityGradeScale.numeric0To10,
        options: ActivityGradeScale.values,
        optionLabel: _gradeScaleLabel,
        onChanged: (scale) => _set(
          value.copyWith(
            gradeScale: scale,
            recoveryRule:
                scale == ActivityGradeScale.numeric0To10 ||
                    scale == ActivityGradeScale.numeric0To100
                ? value.recoveryRule
                : ActivityRecoveryRule.none,
          ),
        ),
        prefixIcon: Icons.straighten_outlined,
      ),
      if (value.gradeScale == ActivityGradeScale.concepts) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: _text('assessment-concepts', value.conceptLevels.join(', ')),
          labelText: 'Conceitos',
          hintText: 'A, B, C, D',
          prefixIcon: Icons.format_list_bulleted_outlined,
          errorText: value.validationErrors.contains('concept_levels_required')
              ? 'Informe os conceitos manualmente.'
              : null,
          onChanged: (text) => _set(
            value.copyWith(
              conceptLevels: text
                  .split(',')
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false),
            ),
          ),
        ),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      for (var index = 0; index < value.instruments.length; index++) ...[
        _instrumentCard(index),
        const SizedBox(height: CoeloSpacing.space3),
      ],
      Text(
        'Total: ${value.totalInstrumentWeight.toStringAsFixed(0)}%',
        key: const Key('activity-assessment-weight-total'),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: value.validationErrors.contains('instrument_weights_total')
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(height: CoeloSpacing.space3),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          key: const Key('activity-assessment-add-instrument'),
          onPressed: _addInstrument,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar instrumento'),
        ),
      ),
      if (value.hasNumericGradeScale) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminSingleSelectField<ActivityRecoveryRule>(
          key: const Key('activity-assessment-recovery'),
          label: 'Recuperação',
          value: value.recoveryRule,
          options: ActivityRecoveryRule.values,
          optionLabel: _recoveryLabel,
          onChanged: (rule) => _set(value.copyWith(recoveryRule: rule)),
          prefixIcon: Icons.replay_outlined,
        ),
      ],
    ],
  );

  Widget _instrumentCard(int index) {
    final instrument = value.instruments[index];
    return CoeloAdminInteractiveCard(
      semanticLabel: 'Instrumento ${instrument.name}',
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResponsiveGrid(
              children: [
                CoeloFormTextField(
                  controller: _text('instrument-name-${instrument.clientId}', instrument.name),
                  labelText: 'Instrumento ${index + 1}',
                  prefixIcon: Icons.assignment_outlined,
                  onChanged: (text) => _updateInstrument(index, instrument.copyWith(name: text)),
                ),
                CoeloAdminSingleSelectField<ActivityAssessmentInstrumentKind>(
                  label: 'Tipo',
                  value: instrument.kind,
                  options: ActivityAssessmentInstrumentKind.values,
                  optionLabel: _instrumentKindLabel,
                  onChanged: (kind) => _updateInstrument(index, instrument.copyWith(kind: kind)),
                  prefixIcon: Icons.category_outlined,
                ),
                CoeloFormTextField(
                  controller: _text(
                    'instrument-weight-${instrument.clientId}',
                    instrument.weight.toStringAsFixed(0),
                  ),
                  labelText: 'Peso',
                  prefixIcon: Icons.percent_outlined,
                  keyboardType: TextInputType.number,
                  errorText: instrument.weight <= 0 || instrument.weight > 100
                      ? 'Use um peso entre 0 e 100.'
                      : null,
                  onChanged: (text) => _updateInstrument(
                    index,
                    instrument.copyWith(weight: double.tryParse(text.replaceAll(',', '.')) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              children: [
                IconButton(
                  tooltip: 'Mover para cima',
                  onPressed: index == 0 ? null : () => _moveInstrument(index, -1),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  tooltip: 'Mover para baixo',
                  onPressed: index == value.instruments.length - 1
                      ? null
                      : () => _moveInstrument(index, 1),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                IconButton(
                  tooltip: 'Remover instrumento',
                  color: Theme.of(context).colorScheme.error,
                  onPressed: () => _removeInstrument(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _competencySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionHeader(
        title: 'Categorias e competências',
        description: 'A visão geral usa a média das categorias; cada categoria tem o mesmo peso.',
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<ActivityCompetencyScale>(
        key: const Key('activity-assessment-competency-scale'),
        label: 'Escala de competências',
        value: ActivityCompetencyScale.oneToFive,
        options: ActivityCompetencyScale.values,
        optionLabel: (_) => 'Competências 1–5',
        onChanged: (scale) => _set(value.copyWith(competencyScale: scale)),
        prefixIcon: Icons.insights_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      for (var index = 0; index < value.categories.length; index++) ...[
        _categoryCard(index),
        const SizedBox(height: CoeloSpacing.space3),
      ],
    ],
  );

  Widget _categoryCard(int index) {
    final category = value.categories[index];
    return CoeloAdminInteractiveCard(
      semanticLabel: 'Categoria ${category.name}',
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: _ResponsiveGrid(
          children: [
            CoeloFormTextField(
              controller: _text('category-name-${category.clientId}', category.name),
              labelText: 'Categoria ${index + 1}',
              prefixIcon: Icons.account_tree_outlined,
              onChanged: (text) {
                final categories = [...value.categories]..[index] = category.copyWith(name: text);
                _set(value.copyWith(categories: categories));
              },
            ),
            CoeloFormTextField(
              controller: _text(
                'category-competencies-${category.clientId}',
                category.competencies.map((item) => item.name).join(', '),
              ),
              labelText: 'Competências',
              hintText: 'Fala, Audição, Leitura',
              prefixIcon: Icons.checklist_rtl_outlined,
              onChanged: (text) {
                final names = text
                    .split(',')
                    .map((item) => item.trim())
                    .where((item) => item.isNotEmpty)
                    .toList(growable: false);
                final categories = [...value.categories]
                  ..[index] = category.copyWith(
                    competencies: [
                      for (var position = 0; position < names.length; position++)
                        ActivityAssessmentCompetencyDraft(
                          clientId: '${category.clientId}-${position + 1}',
                          name: names[position],
                          order: position + 1,
                          taxonomyVersionId: category.taxonomyVersionId,
                        ),
                    ],
                  );
                _set(value.copyWith(categories: categories));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodsSection({required DateTime firstDate, required DateTime lastDate}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _SectionHeader(
        title: 'Períodos avaliativos',
        description:
            'Ajuste as datas sugeridas e defina prazo de lançamento e liberação para a família com hora.',
      ),
      const SizedBox(height: CoeloSpacing.space4),
      for (var index = 0; index < value.periods.length; index++) ...[
        _periodCard(index, firstDate: firstDate, lastDate: lastDate),
        const SizedBox(height: CoeloSpacing.space3),
      ],
    ],
  );

  Widget _periodCard(int index, {required DateTime firstDate, required DateTime lastDate}) {
    final period = value.periods[index];
    return CoeloAdminInteractiveCard(
      semanticLabel: period.name,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoeloFormTextField(
              controller: _text('period-name-$index', period.name),
              labelText: 'Nome do período',
              prefixIcon: Icons.label_outline,
              onChanged: (text) => _updatePeriod(index, period.copyWith(name: text)),
            ),
            const SizedBox(height: CoeloSpacing.space4),
            CoeloDateRangeField(
              value: DateTimeRange(start: period.startsOn, end: period.endsOn),
              onChanged: (range) {
                if (range != null) {
                  _updatePeriod(index, period.copyWith(startsOn: range.start, endsOn: range.end));
                }
              },
              firstDate: firstDate,
              lastDate: lastDate,
              labelText: 'Início e término',
              showQuickRanges: false,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            _ResponsiveGrid(
              children: [
                CoeloDateTimeField(
                  value: period.entryDeadlineAt,
                  onChanged: (date) {
                    if (date == null || !date.isBefore(period.endsOn)) {
                      _updatePeriod(index, period.copyWith(entryDeadlineAt: date));
                    }
                  },
                  firstDate: period.endsOn,
                  lastDate: lastDate,
                  labelText: 'Prazo de lançamento',
                  emptyLabel: 'Definir prazo',
                ),
                CoeloDateTimeField(
                  value: period.familyReleaseAt,
                  onChanged: (date) {
                    final deadline = period.entryDeadlineAt;
                    if (date == null || deadline == null || !date.isBefore(deadline)) {
                      _updatePeriod(index, period.copyWith(familyReleaseAt: date));
                    }
                  },
                  firstDate: period.entryDeadlineAt ?? period.endsOn,
                  lastDate: lastDate,
                  labelText: 'Liberação para a família',
                  emptyLabel: 'Definir liberação',
                ),
              ],
            ),
            if (period.validationErrors.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Text(
                'Defina início, término, prazo e liberação na ordem correta.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _reviewSection() => CoeloAdminInteractiveCard(
    semanticLabel: 'Revisão da configuração pedagógica',
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revisão da configuração', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space2),
          Text(
            '${_assessmentModelLabel(value.model)} · ${_periodicityLabel(value.periodicity ?? ActivityAssessmentPeriodicity.bimonthly)} · ${value.periods.length} período(s)',
          ),
          if (value.usesGrades)
            Text(
              'Instrumentos: ${value.instruments.length} · Pesos: ${value.totalInstrumentWeight.toStringAsFixed(0)}%',
            ),
          if (value.usesCompetencies) Text('Categorias: ${value.categories.length} · escala 1–5'),
          Text('Timezone: ${value.timezone}'),
        ],
      ),
    ),
  );
}

final class _AssessmentPreset {
  const _AssessmentPreset({
    required this.id,
    required this.label,
    required this.model,
    required this.periodicity,
    required this.gradeScale,
    required this.taxonomyVersionId,
    required this.category,
    required this.competency,
  });

  final String id;
  final String label;
  final ActivityAssessmentModel model;
  final ActivityAssessmentPeriodicity periodicity;
  final ActivityGradeScale? gradeScale;
  final String taxonomyVersionId;
  final String category;
  final String competency;
}

const _communicationTaxonomyVersionId = 'c0e10000-0000-4000-8000-000000000001';
const _childhoodTaxonomyVersionId = 'c0e10000-0000-4000-8000-000000000002';
const _fundamentalTaxonomyVersionId = 'c0e10000-0000-4000-8000-000000000003';
const _languagesTaxonomyVersionId = 'c0e10000-0000-4000-8000-000000000004';
const _sportsTaxonomyVersionId = 'c0e10000-0000-4000-8000-000000000005';
const _balletTaxonomyVersionId = 'c0e10000-0000-4000-8000-000000000006';
const _culturalTaxonomyVersionId = 'c0e10000-0000-4000-8000-000000000007';

const _assessmentPresets = [
  _AssessmentPreset(
    id: 'a5500000-0000-4000-8000-000000000001',
    label: 'Educação infantil',
    model: ActivityAssessmentModel.competenciesOnly,
    periodicity: ActivityAssessmentPeriodicity.semester,
    gradeScale: null,
    taxonomyVersionId: _childhoodTaxonomyVersionId,
    category: 'Desenvolvimento socioemocional',
    competency: 'Interação',
  ),
  _AssessmentPreset(
    id: 'a5500000-0000-4000-8000-000000000002',
    label: 'Ensino fundamental',
    model: ActivityAssessmentModel.gradeAndCompetencies,
    periodicity: ActivityAssessmentPeriodicity.bimonthly,
    gradeScale: ActivityGradeScale.numeric0To10,
    taxonomyVersionId: _fundamentalTaxonomyVersionId,
    category: 'Desenvolvimento cognitivo',
    competency: 'Leitura',
  ),
  _AssessmentPreset(
    id: 'a5500000-0000-4000-8000-000000000003',
    label: 'Idiomas',
    model: ActivityAssessmentModel.gradeAndCompetencies,
    periodicity: ActivityAssessmentPeriodicity.trimester,
    gradeScale: ActivityGradeScale.numeric0To100,
    taxonomyVersionId: _languagesTaxonomyVersionId,
    category: 'Comunicação',
    competency: 'Fala',
  ),
  _AssessmentPreset(
    id: 'a5500000-0000-4000-8000-000000000004',
    label: 'Esportes',
    model: ActivityAssessmentModel.competenciesOnly,
    periodicity: ActivityAssessmentPeriodicity.semester,
    gradeScale: null,
    taxonomyVersionId: _sportsTaxonomyVersionId,
    category: 'Desenvolvimento motor',
    competency: 'Coordenação',
  ),
  _AssessmentPreset(
    id: 'a5500000-0000-4000-8000-000000000005',
    label: 'Dança/Ballet',
    model: ActivityAssessmentModel.competenciesOnly,
    periodicity: ActivityAssessmentPeriodicity.semester,
    gradeScale: null,
    taxonomyVersionId: _balletTaxonomyVersionId,
    category: 'Técnica',
    competency: 'Postura',
  ),
  _AssessmentPreset(
    id: 'a5500000-0000-4000-8000-000000000006',
    label: 'Atividades culturais',
    model: ActivityAssessmentModel.gradeAndCompetencies,
    periodicity: ActivityAssessmentPeriodicity.semester,
    gradeScale: ActivityGradeScale.concepts,
    taxonomyVersionId: _culturalTaxonomyVersionId,
    category: 'Participação',
    competency: 'Expressão',
  ),
];

String _assessmentModelLabel(ActivityAssessmentModel value) => switch (value) {
  ActivityAssessmentModel.none => 'Sem avaliação',
  ActivityAssessmentModel.gradeOnly => 'Somente nota',
  ActivityAssessmentModel.competenciesOnly => 'Somente competências',
  ActivityAssessmentModel.gradeAndCompetencies => 'Nota + competências',
};

String _periodicityLabel(ActivityAssessmentPeriodicity value) => switch (value) {
  ActivityAssessmentPeriodicity.bimonthly => 'Bimestral',
  ActivityAssessmentPeriodicity.trimester => 'Trimestral',
  ActivityAssessmentPeriodicity.semester => 'Semestral',
  ActivityAssessmentPeriodicity.annual => 'Anual',
};

String _gradeScaleLabel(ActivityGradeScale value) => switch (value) {
  ActivityGradeScale.numeric0To10 => 'Numérica 0–10',
  ActivityGradeScale.numeric0To100 => 'Numérica 0–100',
  ActivityGradeScale.concepts => 'Conceitos',
  ActivityGradeScale.binary => 'Binária',
  ActivityGradeScale.stars0To5 => 'Estrelas 0–5',
};

String _recoveryLabel(ActivityRecoveryRule value) => switch (value) {
  ActivityRecoveryRule.none => 'Sem recuperação',
  ActivityRecoveryRule.replaceLowestInstrument => 'Substituir menor nota',
  ActivityRecoveryRule.keepHigher => 'Manter maior resultado',
  ActivityRecoveryRule.averageOriginalAndRecovery => 'Média entre original e recuperação',
};

String _instrumentKindLabel(ActivityAssessmentInstrumentKind value) => switch (value) {
  ActivityAssessmentInstrumentKind.exam => 'Prova',
  ActivityAssessmentInstrumentKind.project => 'Projeto',
  ActivityAssessmentInstrumentKind.participation => 'Participação',
  ActivityAssessmentInstrumentKind.presentation => 'Apresentação',
  ActivityAssessmentInstrumentKind.assignment => 'Trabalho',
  ActivityAssessmentInstrumentKind.custom => 'Personalizado',
};

final class _LinksSection extends StatelessWidget {
  const _LinksSection({required this.controller});

  final ActivityFormController controller;

  @override
  Widget build(BuildContext context) {
    final institution = controller.options.institutions
        .where((item) => item.id == controller.selectedInstitutionId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Vínculo Aluno',
          description: 'Confira a instituição, as unidades e selecione as turmas separadamente.',
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _SummarySurface(
          icon: Icons.apartment_outlined,
          title: 'Instituição',
          value: institution?.name ?? 'Não selecionada',
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _SearchableSelectionSection<ActivityFormUnitOption>(
          title: 'Unidades vinculadas',
          description: 'Ajuste as unidades antes de escolher as turmas.',
          error: controller.unitsError,
          items: controller.units,
          itemLabel: (unit) => unit.name,
          searchKey: const Key('activity-units-search'),
          searchHintText: 'Buscar unidade',
          itemBuilder: (unit) => _SelectableCard(
            label: unit.name,
            supportingText: controller.selectedUnitIds.contains(unit.id)
                ? 'Vinculada'
                : 'Disponível',
            selected: controller.selectedUnitIds.contains(unit.id),
            onPressed: () => controller.toggleUnit(unit.id),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        _SearchableSelectionSection<ActivityFormGroupOption>(
          title: 'Turmas',
          description: 'A atividade só produz efeitos operacionais dentro das turmas vinculadas.',
          error: controller.groupsError,
          items: controller.groups,
          itemLabel: (group) => group.name,
          searchKey: const Key('activity-groups-search'),
          searchHintText: 'Buscar turma',
          itemBuilder: (group) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SelectableCard(
                key: Key('activity-group-${group.id}'),
                label: group.name,
                supportingText: '${group.participantCount} participantes',
                selected: controller.selectedGroupIds.contains(group.id),
                onPressed: () => controller.toggleGroup(group.id),
              ),
              if (controller.selectedGroupIds.contains(group.id)) ...[
                const SizedBox(height: CoeloSpacing.space2),
                CoeloAdminSingleSelectField<ActivityParticipation>(
                  key: Key('activity-participation-${group.id}'),
                  label: 'Participação dos alunos',
                  value: controller.groupParticipation[group.id] ?? ActivityParticipation.all,
                  options: ActivityParticipation.values,
                  optionLabel: (value) => value.label,
                  onChanged: (value) => controller.setGroupParticipation(group.id, value),
                  prefixIcon: Icons.groups_outlined,
                ),
              ],
            ],
          ),
        ),
        if (controller.selectedGroupIds.isNotEmpty && controller.options.students.isNotEmpty) ...[
          const SizedBox(height: CoeloSpacing.space5),
          _StudentLinkTables(controller: controller),
        ],
      ],
    );
  }
}

final class _StudentLinkTables extends StatelessWidget {
  const _StudentLinkTables({required this.controller});

  final ActivityFormController controller;

  @override
  Widget build(BuildContext context) {
    final groups = controller.groups
        .where((group) => controller.selectedGroupIds.contains(group.id))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          title: 'Alunos por turma',
          description: 'Revise individualmente quem pertence à atividade em cada turma.',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        for (final group in groups) ...[
          Text(group.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space2),
          CoeloAdminResizableTable<ActivityFormStudentOption>(
            key: Key('activity-students-${group.id}'),
            items: controller.options.students
                .where((student) => student.groupId == group.id)
                .toList(growable: false),
            rowKey: (student) => 'activity-student-${student.childGroupLinkId}',
            pinnedColumn: CoeloAdminTableColumn(
              id: 'name',
              label: 'Nome',
              initialWidth: 220,
              minWidth: 160,
              maxWidth: 360,
              cellBuilder: (_, student) => Text(student.name),
            ),
            columns: [
              CoeloAdminTableColumn(
                id: 'group',
                label: 'Turma',
                initialWidth: 180,
                minWidth: 140,
                maxWidth: 280,
                cellBuilder: (_, _) => Text(group.name),
              ),
              CoeloAdminTableColumn(
                id: 'age',
                label: 'Idade',
                initialWidth: 96,
                minWidth: 80,
                maxWidth: 140,
                cellBuilder: (_, student) => Text(student.age?.toString() ?? '—'),
              ),
              CoeloAdminTableColumn(
                id: 'gender',
                label: 'Sexo',
                initialWidth: 120,
                minWidth: 100,
                maxWidth: 180,
                cellBuilder: (_, student) => Text(student.gender ?? '—'),
              ),
              CoeloAdminTableColumn(
                id: 'belongs',
                label: 'Pertence',
                initialWidth: 160,
                minWidth: 140,
                maxWidth: 220,
                cellBuilder: (_, student) => CoeloAdminToggleField(
                  key: Key('activity-student-belongs-${student.childGroupLinkId}'),
                  label: 'Pertence: ${student.name}',
                  value:
                      controller.groupParticipation[group.id] == ActivityParticipation.all ||
                      (controller.studentSelection[student.childGroupLinkId] ?? true),
                  onChanged:
                      controller.groupParticipation[group.id] == ActivityParticipation.selected
                      ? (value) => controller.setStudentIncluded(student.childGroupLinkId, value)
                      : null,
                ),
              ),
            ],
            headerHeight: 56,
            rowHeight: 136,
          ),
          const SizedBox(height: CoeloSpacing.space4),
        ],
      ],
    );
  }
}

final class _ProfessionalsSection extends StatelessWidget {
  const _ProfessionalsSection({required this.controller});

  final ActivityFormController controller;

  Future<void> _invite(
    BuildContext context,
    String? groupId, {
    ActivityAssignmentRole role = ActivityAssignmentRole.instructor,
  }) => showDialog<void>(
    context: context,
    barrierColor: Theme.of(context).extension<CoeloOverlayColors>()!.scrim,
    builder: (context) =>
        _ProfessionalPickerDialog(controller: controller, groupId: groupId, role: role),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader(
        title: 'Vínculos Profissionais',
        description: 'Convide profissionais por turma e revise as permissões contextuais.',
      ),
      const SizedBox(height: CoeloSpacing.space3),
      Text(
        'As opções abaixo pertencem à turma. A autorização efetiva futura sempre respeitará a hierarquia da instituição, unidade e turma.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: CoeloSpacing.space5),
      OutlinedButton.icon(
        key: const Key('activity-invite-admin'),
        onPressed: () => _invite(context, null, role: ActivityAssignmentRole.activityAdmin),
        icon: const Icon(Icons.admin_panel_settings_outlined),
        label: const Text('Adicionar administrador da atividade'),
      ),
      for (final assignment in controller.assignments.where(
        (item) => item.role == ActivityAssignmentRole.activityAdmin,
      ))
        Padding(
          padding: const EdgeInsets.only(top: CoeloSpacing.space3),
          child: _SummarySurface(
            icon: Icons.admin_panel_settings_outlined,
            title: controller.options.professionals
                .firstWhere((item) => item.id == assignment.professionalId)
                .name,
            value: ActivityAssignmentRole.activityAdmin.label,
          ),
        ),
      const SizedBox(height: CoeloSpacing.space5),
      for (final group in controller.groups.where(
        (group) => controller.selectedGroupIds.contains(group.id),
      )) ...[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space2,
          children: [
            Text(group.name, style: Theme.of(context).textTheme.titleMedium),
            OutlinedButton.icon(
              key: Key('activity-invite-${group.id}'),
              onPressed: () => _invite(context, group.id),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Convidar profissional'),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        if (!controller.assignments.any(
          (item) => item.groupId == group.id && item.role == ActivityAssignmentRole.instructor,
        ))
          const _SummarySurface(
            icon: Icons.people_outline_rounded,
            title: 'Nenhum profissional convidado',
            value: 'Você pode concluir o vínculo depois.',
          ),
        for (final assignment in controller.assignments.where(
          (item) => item.groupId == group.id && item.role == ActivityAssignmentRole.instructor,
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
            child: _ProfessionalPermissionCard(controller: controller, assignment: assignment),
          ),
        const SizedBox(height: CoeloSpacing.space4),
      ],
      const Divider(),
      const SizedBox(height: CoeloSpacing.space4),
      Text('Revisão', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space3),
      _ResponsiveGrid(
        children: [
          _SummarySurface(
            icon: Icons.apartment_outlined,
            title: 'Instituição',
            value:
                controller.options.institutions
                    .where((item) => item.id == controller.selectedInstitutionId)
                    .firstOrNull
                    ?.name ??
                'Não selecionada',
          ),
          _SummarySurface(
            icon: Icons.business_outlined,
            title: 'Unidades',
            value: '${controller.selectedUnitIds.length} selecionada(s)',
          ),
          _SummarySurface(
            icon: Icons.groups_outlined,
            title: 'Turmas',
            value: '${controller.selectedGroupIds.length} selecionada(s)',
          ),
          _SummarySurface(
            icon: Icons.people_outline_rounded,
            title: 'Profissionais',
            value: '${controller.assignments.length} atribuição(ões)',
          ),
        ],
      ),
    ],
  );
}

final class _CreateLocationDialog extends StatefulWidget {
  const _CreateLocationDialog({
    required this.institutionId,
    required this.units,
    required this.onCreate,
  });

  final String institutionId;
  final List<ActivityFormUnitOption> units;
  final ActivityLocationCreator onCreate;

  @override
  State<_CreateLocationDialog> createState() => _CreateLocationDialogState();
}

final class _CreateLocationDialogState extends State<_CreateLocationDialog> {
  final _name = TextEditingController();
  String? _error;
  bool _saving = false;
  late final Set<String> _unitIds = widget.units.map((unit) => unit.id).toSet();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Informe o nome do local.');
      return;
    }
    setState(() => _saving = true);
    if (_unitIds.isEmpty) {
      setState(() => _error = 'Selecione ao menos uma unidade.');
      return;
    }
    final options = await widget.onCreate(
      ActivityLocationDraft(
        institutionId: widget.institutionId,
        unitIds: Set.unmodifiable(_unitIds),
        name: _name.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop(options);
  }

  @override
  Widget build(BuildContext context) => CoeloAdminDialogShell(
    dialogKey: const Key('activity-create-location-dialog'),
    title: 'Cadastrar novo local',
    closeTooltip: 'Fechar cadastro de local',
    body: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Escolha uma, algumas ou todas as unidades selecionadas.'),
        const SizedBox(height: CoeloSpacing.space3),
        for (final unit in widget.units)
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
            child: _SelectableCard(
              key: Key('activity-location-unit-${unit.id}'),
              label: unit.name,
              supportingText: 'Criar um local irmão nesta unidade',
              selected: _unitIds.contains(unit.id),
              onPressed: () => setState(() {
                if (!_unitIds.add(unit.id)) _unitIds.remove(unit.id);
              }),
            ),
          ),
        const SizedBox(height: CoeloSpacing.space3),
        CoeloFormTextField(
          fieldKey: const Key('activity-location-name'),
          controller: _name,
          labelText: 'Nome do local',
          hintText: 'Ex.: Laboratório de informática',
          prefixIcon: Icons.meeting_room_outlined,
          errorText: _error,
        ),
      ],
    ),
    secondaryAction: OutlinedButton(
      onPressed: _saving ? null : Navigator.of(context).pop,
      child: const Text('Cancelar'),
    ),
    primaryAction: FilledButton(
      key: const Key('activity-location-submit'),
      onPressed: _saving ? null : _submit,
      child: const Text('Cadastrar local'),
    ),
  );
}

final class _ProfessionalPickerDialog extends StatefulWidget {
  const _ProfessionalPickerDialog({
    required this.controller,
    required this.groupId,
    required this.role,
  });

  final ActivityFormController controller;
  final String? groupId;
  final ActivityAssignmentRole role;

  @override
  State<_ProfessionalPickerDialog> createState() => _ProfessionalPickerDialogState();
}

final class _ProfessionalPickerDialogState extends State<_ProfessionalPickerDialog> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _requestSequence = 0;
  List<ActivityFormProfessionalOption> _items = const [];
  bool _loading = false;
  bool _failed = false;

  void _searchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    final sequence = ++_requestSequence;
    if (query.isEmpty) {
      setState(() {
        _items = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await widget.controller.searchProfessionals(query);
        if (!mounted || sequence != _requestSequence) return;
        widget.controller.acceptProfessionalResults(results);
        setState(() {
          _items = results;
          _loading = false;
        });
      } catch (_) {
        if (!mounted || sequence != _requestSequence) return;
        setState(() {
          _items = const [];
          _loading = false;
          _failed = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _requestSequence++;
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoeloAdminDialogShell(
      dialogKey: const Key('activity-professional-dialog'),
      title: widget.role == ActivityAssignmentRole.activityAdmin
          ? 'Adicionar administrador'
          : 'Convidar profissional',
      closeTooltip: 'Fechar convite',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoeloSearchField(
            key: const Key('activity-professional-search'),
            controller: _search,
            hintText: 'Buscar por nome ou @',
            semanticLabel: 'Buscar profissional para a atividade',
            onChanged: _searchChanged,
          ),
          const SizedBox(height: CoeloSpacing.space3),
          if (_loading)
            const LinearProgressIndicator(key: Key('activity-professional-search-loading'))
          else if (_failed)
            Text(
              'Não foi possível buscar profissionais. Tente novamente.',
              key: const Key('activity-professional-search-failure'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (_search.text.trim().isEmpty)
            const Text('Digite um nome ou @ para buscar.')
          else if (_items.isEmpty)
            const Text(
              'Nenhum profissional encontrado.',
              key: Key('activity-professional-search-empty'),
            ),
          for (final professional in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
              child: _SelectableCard(
                key: Key('activity-professional-${professional.id}'),
                label: professional.name,
                supportingText: professional.role,
                selected: widget.controller.assignments.any(
                  (item) =>
                      item.groupId == widget.groupId &&
                      item.professionalId == professional.id &&
                      item.role == widget.role,
                ),
                onPressed: () {
                  setState(
                    () => widget.controller.toggleProfessional(
                      widget.groupId,
                      professional.id,
                      role: widget.role,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      primaryAction: FilledButton(
        onPressed: Navigator.of(context).pop,
        child: const Text('Concluir convite'),
      ),
    );
  }
}

final class _ProfessionalPermissionCard extends StatelessWidget {
  const _ProfessionalPermissionCard({required this.controller, required this.assignment});

  final ActivityFormController controller;
  final ActivityProfessionalAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final professional = controller.options.professionals.firstWhere(
      (item) => item.id == assignment.professionalId,
    );
    Widget permission(
      String id,
      String label,
      ActivityProfessionalAccess value,
      ValueChanged<ActivityProfessionalAccess> onChanged,
    ) => CoeloAdminSingleSelectField<ActivityProfessionalAccess>(
      key: Key('activity-permission-${assignment.groupId}-${assignment.professionalId}-$id'),
      label: label,
      value: value,
      options: ActivityProfessionalAccess.values,
      optionLabel: (option) => option.label,
      onChanged: onChanged,
    );
    return Container(
      key: Key('activity-assignment-${assignment.groupId}-${assignment.professionalId}'),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(professional.name, style: Theme.of(context).textTheme.titleSmall),
          Text(professional.role, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: CoeloSpacing.space3),
          _ResponsiveGrid(
            children: [
              permission('happens', 'Happens', assignment.permissions.happens, (value) {
                controller.setPermission(
                  assignment.groupId,
                  assignment.professionalId,
                  happens: value,
                );
              }),
              permission('now', 'Now', assignment.permissions.now, (value) {
                controller.setPermission(assignment.groupId, assignment.professionalId, now: value);
              }),
              permission('moments', 'Moments', assignment.permissions.moments, (value) {
                controller.setPermission(
                  assignment.groupId,
                  assignment.professionalId,
                  moments: value,
                );
              }),
              permission('chat', 'Chat', assignment.permissions.chat, (value) {
                controller.setPermission(
                  assignment.groupId,
                  assignment.professionalId,
                  chat: value,
                );
              }),
              permission('attendance', 'Chamada', assignment.permissions.attendance, (value) {
                controller.setPermission(
                  assignment.groupId,
                  assignment.professionalId,
                  attendance: value,
                );
              }),
              OutlinedButton.icon(
                key: Key(
                  'activity-permission-${assignment.groupId}-'
                  '${assignment.professionalId}-notes',
                ),
                onPressed: null,
                icon: const Icon(Icons.notes_outlined),
                label: const Text('Notas · Em breve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _ActivityAvatar extends StatelessWidget {
  const _ActivityAvatar({
    required this.bytes,
    required this.initials,
    required this.color,
    required this.icon,
  });

  final Uint8List? bytes;
  final String initials;
  final String color;
  final ActivityIdentityIcon icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    height: 104,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: bytes == null
          ? _activityIdentityColor(color)
          : Theme.of(context).colorScheme.surfaceContainer,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: bytes != null
        ? Image.memory(bytes!, fit: BoxFit.cover)
        : Center(
            child: initials.trim().isNotEmpty
                ? Text(
                    initials.trim().toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _activityIdentityForeground(_activityIdentityColor(color)),
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Icon(
                    _activityIdentityIconData(icon),
                    color: _activityIdentityForeground(_activityIdentityColor(color)),
                  ),
          ),
  );
}

Color _activityIdentityColor(String value) {
  final normalized = value.replaceFirst('#', '');
  final parsed = int.tryParse(normalized, radix: 16);
  return Color(0xFF000000 | (parsed ?? 0xD63C00));
}

Color _activityIdentityForeground(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;

String _activityIdentityIconLabel(ActivityIdentityIcon icon) => switch (icon) {
  ActivityIdentityIcon.activity => 'Atividade',
  ActivityIdentityIcon.sports => 'Esportes',
  ActivityIdentityIcon.music => 'Música',
  ActivityIdentityIcon.science => 'Ciências',
  ActivityIdentityIcon.arts => 'Artes',
};

IconData _activityIdentityIconData(ActivityIdentityIcon icon) => switch (icon) {
  ActivityIdentityIcon.activity => Icons.local_activity_outlined,
  ActivityIdentityIcon.sports => Icons.sports_soccer_outlined,
  ActivityIdentityIcon.music => Icons.music_note_outlined,
  ActivityIdentityIcon.science => Icons.science_outlined,
  ActivityIdentityIcon.arts => Icons.palette_outlined,
};

final class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: CoeloSpacing.space1),
      Text(
        description,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

final class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
      final width = compact
          ? constraints.maxWidth
          : (constraints.maxWidth - CoeloSpacing.space3) / 2;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space4,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );
}

final class _SearchableSelectionSection<T> extends StatefulWidget {
  const _SearchableSelectionSection({
    required this.title,
    required this.description,
    required this.items,
    required this.itemLabel,
    required this.itemBuilder,
    required this.searchKey,
    required this.searchHintText,
    this.error,
  });

  final String title;
  final String description;
  final List<T> items;
  final String Function(T item) itemLabel;
  final Widget Function(T item) itemBuilder;
  final Key searchKey;
  final String searchHintText;
  final String? error;

  @override
  State<_SearchableSelectionSection<T>> createState() => _SearchableSelectionSectionState<T>();
}

final class _SearchableSelectionSectionState<T> extends State<_SearchableSelectionSection<T>> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = widget.items
        .where((item) => widget.itemLabel(item).toLowerCase().contains(query))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.items.length > 6) ...[
          CoeloSearchField(
            key: widget.searchKey,
            controller: _search,
            hintText: widget.searchHintText,
            semanticLabel: widget.searchHintText,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CoeloSpacing.space3),
        ],
        _SelectionSection(
          title: widget.title,
          description: widget.description,
          error: widget.error,
          children: [for (final item in filtered) widget.itemBuilder(item)],
        ),
      ],
    );
  }
}

final class _SelectionSection extends StatelessWidget {
  const _SelectionSection({
    required this.title,
    required this.description,
    required this.children,
    this.error,
  });

  final String title;
  final String description;
  final List<Widget> children;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space1),
      Text(description),
      if (error != null) ...[
        const SizedBox(height: CoeloSpacing.space1),
        Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
      const SizedBox(height: CoeloSpacing.space3),
      _ResponsiveGrid(children: children),
    ],
  );
}

final class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.label,
    required this.supportingText,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String supportingText;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CoeloAdminInteractiveCard(
    semanticLabel: '$label, ${selected ? 'selecionado' : 'não selecionado'}',
    onPressed: onPressed,
    minHeight: 88,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: CoeloSpacing.space1),
                Text(supportingText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );
}

final class _SummarySurface extends StatelessWidget {
  const _SummarySurface({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              Text(value),
            ],
          ),
        ),
      ],
    ),
  );
}
