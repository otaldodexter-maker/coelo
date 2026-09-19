export 'health_medication_plan_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import '../../../shared/presentation/widgets/superadmin_form_section.dart';

import '../../../app/shell/superadmin_shell.dart';
import 'health_care_responsive_surface.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../../auth/domain/logout_action.dart';
import '../domain/health_care.dart';

typedef HealthCareProfileFormSave = Future<void> Function(HealthCareProfileDraft draft);
typedef HealthCareProfileFormLoad = Future<HealthCareProfileDraft?> Function(String childId);

@immutable
final class HealthCareProfileChildOption {
  const HealthCareProfileChildOption({required this.id, required this.label});

  final String id;
  final String label;
}

enum _HealthCareProfileFormStep { child, allergies, guidance, review }

final class HealthCareProfileFormPage extends StatefulWidget {
  const HealthCareProfileFormPage({
    required this.logout,
    required this.onCancel,
    this.onSaved,
    this.onSaveSucceeded,
    this.loadDraft,
    this.childOptions = const [],
    this.childId,
    super.key,
  });

  final LogoutAction logout;
  final VoidCallback onCancel;
  final HealthCareProfileFormSave? onSaved;
  final VoidCallback? onSaveSucceeded;
  final HealthCareProfileFormLoad? loadDraft;
  final List<HealthCareProfileChildOption> childOptions;
  final String? childId;

  @override
  State<HealthCareProfileFormPage> createState() => _HealthCareProfileFormPageState();
}

final class _HealthCareProfileFormPageState extends State<HealthCareProfileFormPage> {
  var _currentStep = _HealthCareProfileFormStep.child;
  late String _childId =
      widget.childId ?? (widget.childOptions.isEmpty ? '' : widget.childOptions.first.id);
  var _allergies = <_AllergyEditor>[_AllergyEditor()];
  var _careItems = <String>{};
  var _saving = false;
  var _loadingDraft = false;
  var _draftReady = false;
  var _dirty = false;
  String? _loadError;
  String? _validationError;
  var _loadGeneration = 0;
  var _commandGeneration = 0;
  final _signs = TextEditingController();
  final _adaptations = TextEditingController();
  final _justification = TextEditingController();

  Iterable<TextEditingController> get _textControllers => [
    _signs,
    _adaptations,
    _justification,
    for (final allergy in _allergies) ...allergy.controllers,
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in _textControllers) {
      controller.addListener(_markDirty);
    }
    if (widget.childId case final childId?) {
      _loadDraft(childId);
    } else {
      _draftReady = true;
    }
  }

  @override
  void didUpdateWidget(covariant HealthCareProfileFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final loadIdentityChanged =
        oldWidget.childId != widget.childId || oldWidget.loadDraft != widget.loadDraft;
    final commandIdentityChanged =
        oldWidget.onSaved != widget.onSaved || oldWidget.onSaveSucceeded != widget.onSaveSucceeded;
    if (!loadIdentityChanged && !commandIdentityChanged) return;
    _commandGeneration++;
    _saving = false;
    if (!loadIdentityChanged) return;
    _loadGeneration++;
    _resetDraft();
    _draftReady = widget.childId == null;
    _loadingDraft = false;
    _loadError = null;
    _validationError = null;
    _dirty = false;
    if (widget.childId case final childId?) _loadDraft(childId);
  }

  @override
  void dispose() {
    _loadGeneration++;
    _commandGeneration++;
    for (final allergy in _allergies) {
      allergy.dispose();
    }
    _signs.dispose();
    _adaptations.dispose();
    _justification.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final onSaved = widget.onSaved;
    if (_saving || onSaved == null) return;
    if (_justification.text.trim().isEmpty) {
      setState(() => _validationError = 'Informe a justificativa antes de salvar.');
      return;
    }
    setState(() {
      _saving = true;
      _validationError = null;
    });
    final generation = ++_commandGeneration;
    final requestedChildId = widget.childId;
    final onSaveSucceeded = widget.onSaveSucceeded;
    try {
      await onSaved(_draft);
      if (!_isCurrentCommand(generation, requestedChildId, onSaved)) return;
      setState(() => _dirty = false);
      onSaveSucceeded?.call();
    } catch (_) {
      if (_isCurrentCommand(generation, requestedChildId, onSaved)) {
        setState(() {
          _validationError = 'Não foi possível salvar. Revise os dados e tente novamente.';
        });
      }
    } finally {
      if (_isCurrentCommand(generation, requestedChildId, onSaved)) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _loadDraft(String childId) async {
    final loadDraft = widget.loadDraft;
    if (loadDraft == null) return;
    final generation = ++_loadGeneration;
    setState(() {
      _loadingDraft = true;
      _loadError = null;
    });
    try {
      final draft = await loadDraft(childId);
      if (!mounted || generation != _loadGeneration || widget.childId != childId) return;
      if (draft == null || draft.childId != childId) {
        setState(() {
          _loadingDraft = false;
          _loadError = draft == null
              ? 'O perfil solicitado não foi encontrado.'
              : 'O perfil retornado não corresponde à criança solicitada.';
        });
        return;
      }
      _applyDraft(draft);
      setState(() {
        _loadingDraft = false;
        _draftReady = true;
        _dirty = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration || widget.childId != childId) return;
      setState(() {
        _loadingDraft = false;
        _loadError = 'Não foi possível carregar o perfil de cuidado.';
      });
    }
  }

  void _applyDraft(HealthCareProfileDraft draft) {
    _childId = draft.childId;
    _loadedChildLabel = draft.childLabel;
    _replaceAllergies(draft.allergies);
    _careItems = Set.of(draft.careItemIds);
    _signs.text = draft.importantSigns;
    _adaptations.text = draft.adaptations;
    _justification.text = draft.justification;
  }

  bool _isCurrentCommand(
    int generation,
    String? requestedChildId,
    HealthCareProfileFormSave onSaved,
  ) =>
      mounted &&
      generation == _commandGeneration &&
      widget.childId == requestedChildId &&
      identical(widget.onSaved, onSaved);

  void _resetDraft() {
    _currentStep = _HealthCareProfileFormStep.child;
    _childId = widget.childId ?? (widget.childOptions.isEmpty ? '' : widget.childOptions.first.id);
    _replaceAllergies(const []);
    _careItems = <String>{};
    for (final controller in _textControllers) {
      controller.clear();
    }
  }

  HealthCareProfileDraft get _draft {
    final allergies = [for (final allergy in _allergies) allergy.toDraft()];
    final first = allergies.first;
    return HealthCareProfileDraft(
      childId: _childId,
      allergyType: first.allergyType,
      allergyStatus: first.allergyStatus,
      lastEpisode: first.lastEpisode,
      severity: first.severity,
      observedReaction: first.observedReaction,
      allergyGuidance: first.allergyGuidance,
      allergyNotes: first.allergyNotes,
      allergies: allergies,
      careItemIds: _careItems,
      importantSigns: _signs.text,
      adaptations: _adaptations.text,
      justification: _justification.text,
    );
  }

  void _markDirty() {
    if (_draftReady && !_dirty && mounted) setState(() => _dirty = true);
  }

  void _change(VoidCallback change) => setState(() {
    change();
    _dirty = true;
  });

  void _replaceAllergies(Iterable<HealthCareAllergyDraft> drafts) {
    for (final allergy in _allergies) {
      allergy.dispose();
    }
    _allergies = [for (final draft in drafts) _AllergyEditor(draft)];
    if (_allergies.isEmpty) _allergies = [_AllergyEditor()];
    for (final allergy in _allergies) {
      for (final controller in allergy.controllers) {
        controller.addListener(_markDirty);
      }
    }
  }

  void _addAllergy() => _change(() {
    final allergy = _AllergyEditor();
    for (final controller in allergy.controllers) {
      controller.addListener(_markDirty);
    }
    _allergies = [..._allergies, allergy];
  });

  void _removeAllergy(int index) {
    if (_allergies.length == 1) return;
    _change(() {
      _allergies.removeAt(index).dispose();
    });
  }

  Future<void> _requestCancel() async {
    if (!_dirty) {
      widget.onCancel();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      barrierColor: context.coeloScrim,
      builder: (dialogContext) => CoeloAdminDialogShell(
        dialogKey: const Key('health-care-profile-confirm-exit-dialog'),
        title: 'Sair sem salvar?',
        closeTooltip: 'Fechar confirmação',
        body: const Text('As alterações feitas neste perfil de cuidado serão descartadas.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Continuar editando'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: coeloDestructiveFilledButtonStyle(dialogContext),
          child: const Text('Sair sem salvar'),
        ),
      ),
    );
    if (discard == true && mounted) widget.onCancel();
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
    if (_currentStep.index == 0) return;
    _selectStep(_currentStep.index - 1);
  }

  void _continue() {
    if (_currentStep.index == _HealthCareProfileFormStep.values.length - 1) return;
    _selectStep(_currentStep.index + 1);
  }

  bool get _hasRequiredContract =>
      widget.onSaved != null &&
      _draftReady &&
      widget.childOptions.isNotEmpty &&
      widget.childOptions.any((option) => option.id == _childId);

  String? _loadedChildLabel;

  String _childLabel(String value) {
    final loaded = _loadedChildLabel;
    if (value == _childId && loaded != null) return loaded;
    for (final option in widget.childOptions) {
      if (option.id == value) return option.label;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDraft) {
      return SuperadminShell(
        logout: widget.logout,
        currentDestination: 'health-care-profiles',
        title: 'Editar perfil de cuidado',
        subtitle: 'Registre apenas informações permanentes de saúde e cuidado da criança.',
        child: const Center(child: CircularProgressIndicator()),
      ).withHealthCareResponsiveSurface();
    }
    if (!_hasRequiredContract) {
      return SuperadminShell(
        logout: widget.logout,
        currentDestination: 'health-care-profiles',
        title: widget.childId == null ? 'Criar perfil de cuidado' : 'Editar perfil de cuidado',
        subtitle: 'Registre apenas informações permanentes de saúde e cuidado da criança.',
        child: CoeloStatePanel(
          key: const Key('health-care-profile-form-unavailable'),
          title: 'Cadastro indisponível',
          message:
              _loadError ??
              'Os dados das crianças e o comando de persistência ainda não estão disponíveis.',
          icon: Icons.cloud_off_outlined,
          actionLabel: _loadError != null ? 'Tentar novamente' : 'Voltar a Perfis de cuidado',
          onAction: _loadError != null && widget.childId != null
              ? () => _loadDraft(widget.childId!)
              : widget.onCancel,
        ),
      ).withHealthCareResponsiveSurface();
    }

    return _HealthCareFormFrame(
      logout: widget.logout,
      currentDestination: 'health-care-profiles',
      title: widget.childId == null ? 'Criar perfil de cuidado' : 'Editar perfil de cuidado',
      subtitle: 'Registre apenas informações permanentes de saúde e cuidado da criança.',
      onCancel: _requestCancel,
      onSave: _saving ? null : _save,
      saveLabel: widget.childId == null ? 'Criar perfil' : 'Salvar alterações',
      saving: _saving,
      currentStep: _currentStep.index,
      steps: _steps,
      onStepSelected: _selectStep,
      onPrevious: _currentStep.index == 0 ? null : _previousStep,
      onContinue: _continue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_currentStep == _HealthCareProfileFormStep.child)
            SuperadminFormSection(
              title: 'Criança',
              description: widget.childId == null
                  ? 'Selecione a criança que receberá o perfil.'
                  : 'A identidade permanece bloqueada durante a edição.',
              child: widget.childId == null
                  ? CoeloAdminSingleSelectField<String>(
                      label: 'Criança',
                      value: _childId,
                      options: widget.childOptions
                          .map((option) => option.id)
                          .toList(growable: false),
                      optionLabel: _childLabel,
                      onChanged: (value) => _change(() => _childId = value),
                      prefixIcon: Icons.child_care_rounded,
                    )
                  : _LockedIdentity(label: 'Criança', value: _childLabel(_childId)),
            ),
          if (_currentStep == _HealthCareProfileFormStep.allergies)
            SuperadminFormSection(
              title: 'Alergias e restrições',
              description:
                  'A gravidade descreve somente o episódio registrado e não prevê reações futuras.',
              child: Column(
                children: [
                  for (final entry in _allergies.indexed) ...[
                    _AllergyEditorCard(
                      key: Key('health-care-allergy-card-${entry.$1}'),
                      index: entry.$1,
                      editor: entry.$2,
                      canRemove: _allergies.length > 1,
                      onChanged: _change,
                      onRemove: () => _removeAllergy(entry.$1),
                    ),
                    if (entry.$1 < _allergies.length - 1)
                      const SizedBox(height: CoeloSpacing.space4),
                  ],
                  const SizedBox(height: CoeloSpacing.space4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('health-care-profile-add-allergy'),
                      onPressed: _addAllergy,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar alergia ou restrição'),
                    ),
                  ),
                ],
              ),
            ),
          if (_currentStep == _HealthCareProfileFormStep.guidance)
            SuperadminFormSection(
              title: 'Perfil de cuidado',
              description:
                  'Use características e orientações objetivas, sem classificação por semáforo.',
              child: Column(
                children: [
                  CoeloAdminMultiSelectField<String>(
                    label: 'Caracter\u00edsticas de cuidado',
                    options: healthCareProfileCatalog
                        .expand((group) => group.items)
                        .map((item) => item.id)
                        .toList(growable: false),
                    selectedValues: _careItems,
                    optionLabel: _careItemLabel,
                    onChanged: (values) => _change(() => _careItems = values),
                    searchable: true,
                    searchHintText: 'Buscar característica',
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _ResponsiveFields(
                    children: [
                      CoeloFormTextField(
                        controller: _signs,
                        labelText: 'Sinais importantes',
                        prefixIcon: Icons.sign_language_outlined,
                        maxLines: 3,
                      ),
                      CoeloFormTextField(
                        controller: _adaptations,
                        labelText: 'Adaptações e orientações',
                        prefixIcon: Icons.accessibility_new_rounded,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloFormTextField(
                    key: Key('health-care-profile-justification'),
                    controller: _justification,
                    labelText: widget.childId == null
                        ? 'Justificativa do cadastro'
                        : 'Justificativa da alteração',
                    prefixIcon: Icons.edit_note_outlined,
                    maxLines: 3,
                    errorText: _validationError,
                  ),
                ],
              ),
            ),
          if (_currentStep == _HealthCareProfileFormStep.review)
            Column(
              children: [
                if (_validationError case final message?) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const Key('health-care-profile-save-error'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(CoeloSpacing.space4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(CoeloRadius.md),
                      ),
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                ],
                _ReviewSection(
                  title: 'Criança',
                  onEdit: () => _selectStep(_HealthCareProfileFormStep.child.index),
                  rows: [('Criança', _childLabel(_childId))],
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _ReviewSection(
                  title: 'Alergias e restrições',
                  onEdit: () => _selectStep(_HealthCareProfileFormStep.allergies.index),
                  rows: [
                    for (final entry in _allergies.indexed) ...[
                      ('Registro ${entry.$1 + 1}', _allergyTypeLabel(entry.$2.allergyType)),
                      ('Status', _allergyStatusLabel(entry.$2.allergyStatus)),
                      ('Gravidade do episódio', _severityLabel(entry.$2.severity)),
                      ('Último episódio registrado', entry.$2.lastEpisode.text),
                      ('Reação observada', entry.$2.reaction.text),
                      ('Orientação de cuidado', entry.$2.guidance.text),
                      ('Observações', entry.$2.notes.text),
                    ],
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _ReviewSection(
                  title: 'Orientações de cuidado',
                  onEdit: () => _selectStep(_HealthCareProfileFormStep.guidance.index),
                  rows: [
                    (
                      'Características de cuidado',
                      _careItems.isEmpty ? '' : _careItems.map(_careItemLabel).join(', '),
                    ),
                    ('Sinais importantes', _signs.text),
                    ('Adaptações e orientações', _adaptations.text),
                    ('Justificativa', _justification.text),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

final class _AllergyEditor {
  _AllergyEditor([HealthCareAllergyDraft? draft])
    : id = draft?.id,
      allergyType = draft?.allergyType ?? HealthCareAllergyType.food,
      allergyStatus = draft?.allergyStatus ?? HealthCareAllergyStatus.active,
      severity = draft?.severity ?? HealthCareEpisodeSeverity.moderate,
      lastEpisode = TextEditingController(text: draft?.lastEpisode ?? ''),
      reaction = TextEditingController(text: draft?.observedReaction ?? ''),
      guidance = TextEditingController(text: draft?.allergyGuidance ?? ''),
      notes = TextEditingController(text: draft?.allergyNotes ?? '');

  final String? id;
  HealthCareAllergyType allergyType;
  HealthCareAllergyStatus allergyStatus;
  HealthCareEpisodeSeverity severity;
  final TextEditingController lastEpisode;
  final TextEditingController reaction;
  final TextEditingController guidance;
  final TextEditingController notes;

  Iterable<TextEditingController> get controllers => [lastEpisode, reaction, guidance, notes];

  HealthCareAllergyDraft toDraft() => HealthCareAllergyDraft(
    id: id,
    allergyType: allergyType,
    allergyStatus: allergyStatus,
    lastEpisode: lastEpisode.text,
    severity: severity,
    observedReaction: reaction.text,
    allergyGuidance: guidance.text,
    allergyNotes: notes.text,
  );

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

final class _AllergyEditorCard extends StatelessWidget {
  const _AllergyEditorCard({
    required this.index,
    required this.editor,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int index;
  final _AllergyEditor editor;
  final bool canRemove;
  final ValueChanged<VoidCallback> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(CoeloSpacing.space4),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Registro ${index + 1}', style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              key: Key('health-care-profile-remove-allergy-$index'),
              onPressed: canRemove ? onRemove : null,
              tooltip: 'Remover registro ${index + 1}',
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _ResponsiveFields(
          children: [
            CoeloAdminSingleSelectField<HealthCareAllergyType>(
              label: 'Tipo',
              value: editor.allergyType,
              options: HealthCareAllergyType.values,
              optionLabel: _allergyTypeLabel,
              onChanged: (value) => onChanged(() => editor.allergyType = value),
              prefixIcon: Icons.health_and_safety_outlined,
            ),
            CoeloAdminSingleSelectField<HealthCareAllergyStatus>(
              label: 'Status',
              value: editor.allergyStatus,
              options: HealthCareAllergyStatus.values,
              optionLabel: _allergyStatusLabel,
              onChanged: (value) => onChanged(() => editor.allergyStatus = value),
              prefixIcon: Icons.flag_outlined,
            ),
            CoeloFormTextField(
              controller: editor.lastEpisode,
              labelText: 'Último episódio registrado',
              prefixIcon: Icons.event_outlined,
            ),
            CoeloAdminSingleSelectField<HealthCareEpisodeSeverity>(
              label: 'Gravidade do episódio',
              value: editor.severity,
              options: HealthCareEpisodeSeverity.values,
              optionLabel: _severityLabel,
              onChanged: (value) => onChanged(() => editor.severity = value),
              prefixIcon: Icons.monitor_heart_outlined,
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _ResponsiveFields(
          children: [
            CoeloFormTextField(
              key: Key('health-care-allergy-reaction-$index'),
              controller: editor.reaction,
              labelText: 'Reação observada',
              prefixIcon: Icons.visibility_outlined,
              maxLines: 3,
            ),
            CoeloFormTextField(
              key: Key('health-care-allergy-guidance-$index'),
              controller: editor.guidance,
              labelText: 'Orientação de cuidado',
              prefixIcon: Icons.assignment_outlined,
              maxLines: 3,
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: editor.notes,
          labelText: 'Observações',
          prefixIcon: Icons.notes_rounded,
          maxLines: 3,
        ),
      ],
    ),
  );
}

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
            if ((_footerHeight - height).abs() < .5) return;
            setState(() => _footerHeight = height);
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
  Widget build(BuildContext context) => SuperadminFormSection(
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

final class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoColumns = constraints.maxWidth >= 700;
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

String _allergyTypeLabel(HealthCareAllergyType value) => switch (value) {
  HealthCareAllergyType.medication => 'Medicamento',
  HealthCareAllergyType.food => 'Alimento',
  HealthCareAllergyType.restriction => 'Restrição',
  HealthCareAllergyType.other => 'Outro',
};

String _allergyStatusLabel(HealthCareAllergyStatus value) => switch (value) {
  HealthCareAllergyStatus.active => 'Ativo',
  HealthCareAllergyStatus.monitoring => 'Em acompanhamento',
  HealthCareAllergyStatus.history => 'Histórico',
};

String _severityLabel(HealthCareEpisodeSeverity value) => switch (value) {
  HealthCareEpisodeSeverity.mild => 'Leve',
  HealthCareEpisodeSeverity.moderate => 'Moderada',
  HealthCareEpisodeSeverity.severe => 'Grave',
};

String _careItemLabel(String id) {
  for (final item in healthCareProfileCatalog.expand((group) => group.items)) {
    if (item.id == id) return item.label;
  }
  return id;
}
