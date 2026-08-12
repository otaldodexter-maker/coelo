export 'health_medication_plan_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import 'health_care_responsive_surface.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import 'widgets/health_care_profile_draft_fields.dart';

typedef HealthCareFormSave = Future<void> Function();

enum _HealthCareProfileFormStep { child, allergies, guidance, review }

@immutable
final class HealthCareProfileFormTaxonomy {
  const HealthCareProfileFormTaxonomy({
    required this.childLabels,
    required this.allergyItems,
    required this.allergyLabels,
    required this.otherAllergyItemId,
    required this.careItemLabels,
  });

  final Map<String, String> childLabels;
  final Map<HealthCareAllergyKind, List<String>> allergyItems;
  final Map<String, String> allergyLabels;
  final String otherAllergyItemId;
  final Map<String, String> careItemLabels;
}

final class HealthCareProfileFormPage extends StatefulWidget {
  const HealthCareProfileFormPage({
    required this.logout,
    required this.onCancel,
    required this.onSaved,
    this.taxonomy,
    this.childId,
    super.key,
  });

  final LogoutAction logout;
  final VoidCallback onCancel;
  final HealthCareFormSave onSaved;
  final HealthCareProfileFormTaxonomy? taxonomy;
  final String? childId;

  @override
  State<HealthCareProfileFormPage> createState() => _HealthCareProfileFormPageState();
}

final class _HealthCareProfileFormPageState extends State<HealthCareProfileFormPage> {
  var _currentStep = _HealthCareProfileFormStep.child;
  String? _childId;
  var _allergies = <HealthCareAllergyDraft>[];
  var _careItems = <String>{};
  var _careDrafts = <HealthCareCareItemDraft>[];
  var _saving = false;

  HealthCareProfileFormTaxonomy? get _taxonomy => widget.taxonomy;
  bool get _taxonomyAvailable =>
      _taxonomy != null &&
      _taxonomy!.childLabels.isNotEmpty &&
      _taxonomy!.allergyItems.values.every((items) => items.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _initializeFromInputs();
  }

  @override
  void didUpdateWidget(covariant HealthCareProfileFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taxonomy != widget.taxonomy || oldWidget.childId != widget.childId) {
      _initializeFromInputs();
    }
  }

  void _initializeFromInputs() {
    final taxonomy = _taxonomy;
    _childId = widget.childId ?? taxonomy?.childLabels.keys.firstOrNull;
    if (taxonomy == null || taxonomy.allergyItems[HealthCareAllergyKind.food]?.isEmpty != false) {
      _allergies = [];
      return;
    }
    if (_allergies.isEmpty) {
      _allergies = [
        HealthCareAllergyDraft(
          id: 'new-0',
          itemId: taxonomy.allergyItems[HealthCareAllergyKind.food]!.first,
        ),
      ];
    }
  }

  Future<void> _save() async {
    if (_saving || !_taxonomyAvailable || _childId == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSaved();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<SuperadminFormStep> get _steps => [
    for (final step in _HealthCareProfileFormStep.values)
      SuperadminFormStep(
        label: switch (step) {
          _HealthCareProfileFormStep.child => 'Criança',
          _HealthCareProfileFormStep.allergies => 'Alergias e restrições',
          _HealthCareProfileFormStep.guidance => 'Orientações de cuidado',
          _HealthCareProfileFormStep.review => 'Revisão',
        },
        status: step == _currentStep
            ? SuperadminFormStepStatus.current
            : step.index < _currentStep.index
            ? SuperadminFormStepStatus.complete
            : SuperadminFormStepStatus.incomplete,
      ),
  ];

  void _selectStep(int index) =>
      setState(() => _currentStep = _HealthCareProfileFormStep.values[index]);

  void _previousStep() {
    if (_currentStep.index > 0) _selectStep(_currentStep.index - 1);
  }

  void _continue() {
    if (_currentStep.index < _HealthCareProfileFormStep.values.length - 1) {
      _selectStep(_currentStep.index + 1);
    }
  }

  void _setCareItems(Set<String> values) {
    final labels = _taxonomy!.careItemLabels;
    setState(() {
      _careItems = values;
      _careDrafts = [
        for (final id in values)
          _careDrafts.where((draft) => draft.id == id).firstOrNull ??
              HealthCareCareItemDraft(id: id, label: labels[id] ?? id),
      ];
    });
  }

  @override
  Widget build(BuildContext context) => _HealthCareFormFrame(
    logout: widget.logout,
    currentDestination: 'health-care-profiles',
    title: widget.childId == null ? 'Criar perfil de cuidado' : 'Editar perfil de cuidado',
    subtitle: 'Registre apenas informações permanentes de saúde e cuidado da criança.',
    onCancel: widget.onCancel,
    onSave: _saving || !_taxonomyAvailable ? null : _save,
    saveLabel: widget.childId == null ? 'Criar perfil' : 'Salvar alterações',
    saving: _saving,
    currentStep: _currentStep.index,
    steps: _steps,
    onStepSelected: _selectStep,
    onPrevious: _currentStep.index == 0 ? null : _previousStep,
    onContinue: _continue,
    child: _profileStep(),
  );

  Widget _profileStep() {
    final taxonomy = _taxonomy;
    if (!_taxonomyAvailable || taxonomy == null) {
      return const CoeloStatePanel(
        title: 'Opções indisponíveis',
        message: 'Não foi possível carregar crianças e taxonomias de cuidado.',
      );
    }
    return switch (_currentStep) {
      _HealthCareProfileFormStep.child => _FormSection(
        title: 'Criança',
        description: widget.childId == null
            ? 'Selecione a criança que receberá o perfil.'
            : 'A identidade permanece bloqueada durante a edição.',
        child: widget.childId == null
            ? CoeloAdminSingleSelectField<String>(
                label: 'Criança',
                value: _childId!,
                options: taxonomy.childLabels.keys.toList(growable: false),
                optionLabel: (id) => taxonomy.childLabels[id] ?? id,
                onChanged: (value) => setState(() => _childId = value),
                prefixIcon: Icons.child_care_rounded,
              )
            : _LockedIdentity(label: 'Criança', value: taxonomy.childLabels[_childId] ?? _childId!),
      ),
      _HealthCareProfileFormStep.allergies => _FormSection(
        title: 'Alergias e restrições',
        description:
            'Cadastre cada item separadamente. A gravidade descreve apenas o episódio registrado.',
        child: HealthCareAllergyDraftsEditor(
          drafts: _allergies,
          itemOptions: taxonomy.allergyItems,
          itemLabel: (id) => taxonomy.allergyLabels[id] ?? id,
          otherItemId: taxonomy.otherAllergyItemId,
          onChanged: (index, value) => setState(() => _allergies[index] = value),
          onAdd: () => setState(() {
            _allergies.add(
              HealthCareAllergyDraft(
                id: 'new-${_allergies.length}',
                itemId: taxonomy.allergyItems[HealthCareAllergyKind.food]!.first,
              ),
            );
          }),
          onRemove: (index) => setState(() => _allergies.removeAt(index)),
        ),
      ),
      _HealthCareProfileFormStep.guidance => _FormSection(
        title: 'Perfil de cuidado',
        description: 'Registre sinais e adaptações de cada característica selecionada.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoeloAdminMultiSelectField<String>(
              label: 'Características de cuidado',
              options: taxonomy.careItemLabels.keys.toList(growable: false),
              selectedValues: _careItems,
              optionLabel: (id) => taxonomy.careItemLabels[id] ?? id,
              onChanged: _setCareItems,
              searchable: true,
              searchHintText: 'Buscar característica',
            ),
            if (_careDrafts.isNotEmpty) ...[
              const SizedBox(height: CoeloSpacing.space5),
              HealthCareCareItemDraftsEditor(
                drafts: _careDrafts,
                onChanged: (index, value) => setState(() => _careDrafts[index] = value),
              ),
            ],
          ],
        ),
      ),
      _HealthCareProfileFormStep.review => Column(
        children: [
          _ReviewSection(
            title: 'Criança',
            onEdit: () => _selectStep(_HealthCareProfileFormStep.child.index),
            rows: [('Criança', taxonomy.childLabels[_childId] ?? _childId!)],
          ),
          const SizedBox(height: CoeloSpacing.space5),
          _ReviewSection(
            title: 'Alergias e restrições',
            onEdit: () => _selectStep(_HealthCareProfileFormStep.allergies.index),
            rows: [
              for (final item in _allergies)
                (
                  taxonomy.allergyLabels[item.itemId] ?? item.otherItem,
                  '${_severityDraftLabel(item.severity)} · ${item.reaction}',
                ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space5),
          _ReviewSection(
            title: 'Orientações de cuidado',
            onEdit: () => _selectStep(_HealthCareProfileFormStep.guidance.index),
            rows: [
              for (final item in _careDrafts) (item.label, '${item.signs} · ${item.adaptations}'),
            ],
          ),
        ],
      ),
    };
  }
}

String _severityDraftLabel(HealthCareSeverityLevel value) => switch (value) {
  HealthCareSeverityLevel.veryMild => 'Muito leve',
  HealthCareSeverityLevel.mild => 'Leve',
  HealthCareSeverityLevel.moderate => 'Moderada',
  HealthCareSeverityLevel.severe => 'Grave',
  HealthCareSeverityLevel.verySevere => 'Muito grave',
};

// ignore: unused_element
final class _HealthCareFormFrame extends StatefulWidget {
  const _HealthCareFormFrame({
    required this.logout,
    required this.currentDestination,
    required this.title,
    required this.subtitle,
    required this.onCancel,
    required this.onSave,
    required this.saveLabel,
    required this.saving,
    required this.currentStep,
    required this.steps,
    required this.onStepSelected,
    required this.onPrevious,
    required this.onContinue,
    required this.child,
  });
  final LogoutAction logout;
  final String currentDestination;
  final String title;
  final String subtitle;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final String saveLabel;
  final bool saving;
  final int currentStep;
  final List<SuperadminFormStep> steps;
  final ValueChanged<int> onStepSelected;
  final VoidCallback? onPrevious;
  final VoidCallback onContinue;
  final Widget child;
  @override
  State<_HealthCareFormFrame> createState() => _HealthCareFormFrameState();
}

final class _HealthCareFormFrameState extends State<_HealthCareFormFrame> {
  double _footerHeight = 0;
  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: widget.currentDestination,
    title: widget.title,
    subtitle: widget.subtitle,
    chatLauncherBottomInset: _footerHeight == 0 ? 0 : _footerHeight + CoeloSpacing.space4,
    child: LayoutBuilder(
      builder: (context, constraints) => SuperadminFormFrame(
        viewportWidth: constraints.maxWidth,
        scrollKey: const Key('health-care-form-scroll'),
        navigation: SuperadminFormStepNavigation(
          steps: widget.steps,
          currentIndex: widget.currentStep,
          onStepSelected: widget.onStepSelected,
        ),
        body: widget.child,
        footer: SuperadminFormActionFooter(
          onHeightChanged: (height) {
            if ((_footerHeight - height).abs() >= .5) setState(() => _footerHeight = height);
          },
          tertiaryAction: TextButton(onPressed: widget.onCancel, child: const Text('Cancelar')),
          continuationActions: [
            if (widget.onPrevious != null)
              OutlinedButton(onPressed: widget.onPrevious, child: const Text('Anterior')),
            if (widget.currentStep < widget.steps.length - 1)
              FilledButton(onPressed: widget.onContinue, child: const Text('Continuar'))
            else
              FilledButton(
                onPressed: widget.onSave,
                child: widget.saving
                    ? const SizedBox.square(
                        dimension: CoeloSize.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.saveLabel),
              ),
          ],
        ),
      ),
    ),
  ).withHealthCareResponsiveSurface();
}

final class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.rows, required this.onEdit});

  final String title;
  final List<(String, String)> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => _FormSection(
    title: title,
    description: 'Confira as informações antes de salvar.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          Text(row.$1, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: CoeloSpacing.spaceHalf),
          Text(
            row.$2.trim().isEmpty ? 'Não informado' : row.$2,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: CoeloSpacing.space3),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onEdit, child: const Text('Editar')),
        ),
      ],
    ),
  );
}

final class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.description, required this.child});
  final String title;
  final String description;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space1),
      Text(description, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: CoeloSpacing.space5),
      child,
    ],
  );
}

final class _LockedIdentity extends StatelessWidget {
  const _LockedIdentity({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline_rounded),
      enabled: false,
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    child: Text(value),
  );
}
