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
import 'health_care_catalog_picker.dart';

typedef HealthCareProfileFormSave = Future<void> Function(HealthCareProfileDraft draft);
typedef HealthCareProfileFormLoad = Future<HealthCareProfileDraft?> Function(String childId);

@immutable
final class HealthCareProfileChildOption {
  const HealthCareProfileChildOption({required this.id, required this.label});

  final String id;
  final String label;
}

enum _HealthCareProfileFormStep { child, foods, restrictions, guidance, review }

final class HealthCareProfileFormPage extends StatefulWidget {
  const HealthCareProfileFormPage({
    required this.logout,
    required this.onCancel,
    this.onSaved,
    this.onSaveSucceeded,
    this.loadDraft,
    this.loadCatalog,
    this.childOptions = const [],
    this.childId,
    super.key,
  });

  final LogoutAction logout;
  final VoidCallback onCancel;
  final HealthCareProfileFormSave? onSaved;
  final VoidCallback? onSaveSucceeded;
  final HealthCareProfileFormLoad? loadDraft;

  /// Catálogo categorizado (spec 065). Sem leitor, o seletor oferece só "Outro".
  final HealthCareCatalogLoad? loadCatalog;
  final List<HealthCareProfileChildOption> childOptions;
  final String? childId;

  @override
  State<HealthCareProfileFormPage> createState() => _HealthCareProfileFormPageState();
}

final class _HealthCareProfileFormPageState extends State<HealthCareProfileFormPage> {
  var _currentStep = _HealthCareProfileFormStep.child;
  late String _childId =
      widget.childId ?? (widget.childOptions.isEmpty ? '' : widget.childOptions.first.id);
  var _allergies = <_AllergyEditor>[];
  var _careItems = <HealthCareProfileItemDraft>[];
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
    } catch (error) {
      if (_isCurrentCommand(generation, requestedChildId, onSaved)) {
        setState(() {
          // O repositório traduz o erro do servidor numa mensagem segura
          // (conflito de versão, criança já com perfil, dados obrigatórios).
          _validationError = error is StateError
              ? error.message
              : 'Não foi possível salvar. Revise os dados e tente novamente.';
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
    _replaceAllergies(draft.allergies.where((item) => item.hasContent));
    _careItems = List.of(draft.careItems);
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
    _careItems = <HealthCareProfileItemDraft>[];
    for (final controller in _textControllers) {
      controller.clear();
    }
  }

  HealthCareProfileDraft get _draft {
    // Alimentos primeiro, depois restrições: a posição persistida é a ordem da lista.
    final allergies = [
      for (final allergy in _foods) allergy.toDraft(),
      for (final allergy in _restrictions) allergy.toDraft(),
    ];
    final first = allergies.firstOrNull ?? HealthCareAllergyDraft();
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
      careItems: _careItems,
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
    for (final allergy in _allergies) {
      for (final controller in allergy.controllers) {
        controller.addListener(_markDirty);
      }
    }
  }

  List<_AllergyEditor> get _foods =>
      _allergies.where((item) => item.allergyType == HealthCareAllergyType.food).toList();
  List<_AllergyEditor> get _restrictions =>
      _allergies.where((item) => item.allergyType != HealthCareAllergyType.food).toList();

  HealthCareCatalogCollection _collectionOf(HealthCareAllergyType type) =>
      type == HealthCareAllergyType.food
      ? HealthCareCatalogCollection.food
      : HealthCareCatalogCollection.restriction;

  /// "+ Adicionar": abre o catálogo da coleção e cria UMA linha (spec 065 §5.1).
  Future<void> _addAllergy(HealthCareAllergyType type) async {
    final choice = await showHealthCareCatalogPicker(
      context,
      collection: _collectionOf(type),
      loadCatalog: widget.loadCatalog,
    );
    if (choice == null || !mounted) return;
    _change(() {
      final allergy = _AllergyEditor(
        HealthCareAllergyDraft(
          allergyType: type,
          catalogItemId: choice.catalogItemId,
          otherText: choice.otherText,
          label: choice.label,
        ),
      );
      for (final controller in allergy.controllers) {
        controller.addListener(_markDirty);
      }
      _allergies = [..._allergies, allergy];
    });
  }

  void _removeAllergy(_AllergyEditor editor) => _change(() {
    _allergies = [..._allergies]..remove(editor);
    editor.dispose();
  });

  /// Move dentro da própria coleção; a ordem global (alimentos, depois
  /// restrições) é recomposta em [_draft].
  void _moveAllergy(_AllergyEditor editor, int delta) {
    final isFood = editor.allergyType == HealthCareAllergyType.food;
    final siblings = isFood ? _foods : _restrictions;
    final others = isFood ? _restrictions : _foods;
    final from = siblings.indexOf(editor);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= siblings.length) return;
    _change(() {
      siblings.removeAt(from);
      siblings.insert(to, editor);
      _allergies = isFood ? [...siblings, ...others] : [...others, ...siblings];
    });
  }

  Future<void> _addCareItem() async {
    final choice = await showHealthCareCatalogPicker(
      context,
      collection: HealthCareCatalogCollection.guidance,
      loadCatalog: widget.loadCatalog,
    );
    if (choice == null || !mounted) return;
    if (!choice.isOther && _careItems.any((item) => item.catalogItemId == choice.catalogItemId)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${choice.label} já está na lista.')));
      return;
    }
    _change(() {
      _careItems = [
        ..._careItems,
        HealthCareProfileItemDraft(
          catalogItemId: choice.catalogItemId,
          otherText: choice.otherText,
          label: choice.label,
        ),
      ];
    });
  }

  void _moveCareItem(int from, int delta) {
    final to = from + delta;
    if (to < 0 || to >= _careItems.length) return;
    _change(() {
      final items = [..._careItems];
      final item = items.removeAt(from);
      items.insert(to, item);
      _careItems = items;
    });
  }

  void _removeCareItem(int index) => _change(() {
    _careItems = [..._careItems]..removeAt(index);
  });

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
          _HealthCareProfileFormStep.foods => 'Alimentos',
          _HealthCareProfileFormStep.restrictions => 'Restrições',
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
          if (_currentStep == _HealthCareProfileFormStep.foods)
            _CollectionStep(
              title: 'Alimentos',
              description:
                  'Alergias e intolerâncias alimentares, uma por linha. '
                  'A gravidade descreve somente o episódio registrado.',
              collectionKey: 'food',
              editors: _foods,
              emptyLabel: 'Nenhum alimento registrado.',
              addLabel: 'Adicionar alimento',
              whatToDoLabel: 'O que fazer se consumido?',
              onAdd: () => _addAllergy(HealthCareAllergyType.food),
              onChanged: _change,
              onRemove: _removeAllergy,
              onMove: _moveAllergy,
            ),
          if (_currentStep == _HealthCareProfileFormStep.restrictions)
            _CollectionStep(
              title: 'Restrições',
              description: 'Contato, ambiente, medicamentos e dieta por regra, uma por linha.',
              collectionKey: 'restriction',
              editors: _restrictions,
              emptyLabel: 'Nenhuma restrição registrada.',
              addLabel: 'Adicionar restrição',
              whatToDoLabel: 'O que fazer se exposto?',
              onAdd: () => _addAllergy(HealthCareAllergyType.restriction),
              onChanged: _change,
              onRemove: _removeAllergy,
              onMove: _moveAllergy,
            ),
          if (_currentStep == _HealthCareProfileFormStep.guidance)
            SuperadminFormSection(
              title: 'Perfil de cuidado',
              description:
                  'Use características e orientações objetivas, sem classificação por semáforo.',
              child: Column(
                children: [
                  _OrderedList(
                    collectionKey: 'guidance',
                    emptyLabel: 'Nenhuma orientação registrada.',
                    addLabel: 'Adicionar orientação',
                    onAdd: _addCareItem,
                    children: [
                      for (final entry in _careItems.indexed)
                        _OrderedRow(
                          key: Key('health-care-guidance-card-${entry.$1}'),
                          index: entry.$1,
                          total: _careItems.length,
                          title: entry.$2.displayLabel,
                          collectionKey: 'guidance',
                          onMoveUp: () => _moveCareItem(entry.$1, -1),
                          onMoveDown: () => _moveCareItem(entry.$1, 1),
                          onRemove: () => _removeCareItem(entry.$1),
                        ),
                    ],
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
                  title: 'Alimentos',
                  onEdit: () => _selectStep(_HealthCareProfileFormStep.foods.index),
                  rows: [
                    if (_foods.isEmpty) ('Alimentos', 'Nenhum'),
                    for (final entry in _foods.indexed) ...[
                      (
                        '${entry.$1 + 1}. ${entry.$2.title}',
                        _allergyStatusLabel(entry.$2.allergyStatus),
                      ),
                      ('O que fazer se consumido?', entry.$2.whatToDo.text),
                      ('Observações', entry.$2.notes.text),
                    ],
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space4),
                _ReviewSection(
                  title: 'Restrições',
                  onEdit: () => _selectStep(_HealthCareProfileFormStep.restrictions.index),
                  rows: [
                    if (_restrictions.isEmpty) ('Restrições', 'Nenhuma'),
                    for (final entry in _restrictions.indexed) ...[
                      (
                        '${entry.$1 + 1}. ${entry.$2.title}',
                        _allergyStatusLabel(entry.$2.allergyStatus),
                      ),
                      ('O que fazer se exposto?', entry.$2.whatToDo.text),
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
                      'Orientações',
                      _careItems.isEmpty
                          ? 'Nenhuma'
                          : _careItems.map((item) => item.displayLabel).join(', '),
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
      catalogItemId = draft?.catalogItemId,
      otherText = draft?.otherText,
      label = draft?.label,
      allergyStatus = draft?.allergyStatus ?? HealthCareAllergyStatus.active,
      severity = draft?.severity ?? HealthCareEpisodeSeverity.moderate,
      lastEpisode = TextEditingController(text: draft?.lastEpisode ?? ''),
      reaction = TextEditingController(text: draft?.observedReaction ?? ''),
      guidance = TextEditingController(text: draft?.allergyGuidance ?? ''),
      whatToDo = TextEditingController(text: draft?.whatToDo ?? ''),
      notes = TextEditingController(text: draft?.allergyNotes ?? '');

  final String? id;
  final HealthCareAllergyType allergyType;
  final String? catalogItemId;
  final String? otherText;
  final String? label;
  HealthCareAllergyStatus allergyStatus;
  HealthCareEpisodeSeverity severity;
  final TextEditingController lastEpisode;
  final TextEditingController reaction;
  final TextEditingController guidance;
  final TextEditingController whatToDo;
  final TextEditingController notes;

  /// Nome da linha: catálogo/"Outro" ou, em registro legado sem item, o tipo.
  String get title {
    final resolved = label ?? (catalogItemId == 'other' ? otherText : null);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return _allergyTypeLabel(allergyType);
  }

  Iterable<TextEditingController> get controllers => [
    lastEpisode,
    reaction,
    guidance,
    whatToDo,
    notes,
  ];

  HealthCareAllergyDraft toDraft() => HealthCareAllergyDraft(
    id: id,
    allergyType: allergyType,
    catalogItemId: catalogItemId,
    otherText: otherText,
    label: label,
    allergyStatus: allergyStatus,
    lastEpisode: lastEpisode.text,
    severity: severity,
    observedReaction: reaction.text,
    allergyGuidance: guidance.text,
    whatToDo: whatToDo.text,
    allergyNotes: notes.text,
  );

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

/// Passo de coleção (Alimentos ou Restrições): lista ordenada de linhas, cada
/// uma vinda do catálogo, com mover/remover e "+ Adicionar" (spec 065).
final class _CollectionStep extends StatelessWidget {
  const _CollectionStep({
    required this.title,
    required this.description,
    required this.collectionKey,
    required this.editors,
    required this.emptyLabel,
    required this.addLabel,
    required this.whatToDoLabel,
    required this.onAdd,
    required this.onChanged,
    required this.onRemove,
    required this.onMove,
  });

  final String title;
  final String description;
  final String collectionKey;
  final List<_AllergyEditor> editors;
  final String emptyLabel;
  final String addLabel;
  final String whatToDoLabel;
  final VoidCallback onAdd;
  final ValueChanged<VoidCallback> onChanged;
  final ValueChanged<_AllergyEditor> onRemove;
  final void Function(_AllergyEditor editor, int delta) onMove;

  @override
  Widget build(BuildContext context) => SuperadminFormSection(
    title: title,
    description: description,
    child: _OrderedList(
      collectionKey: collectionKey,
      emptyLabel: emptyLabel,
      addLabel: addLabel,
      onAdd: onAdd,
      children: [
        for (final entry in editors.indexed)
          _AllergyEditorCard(
            key: Key('health-care-$collectionKey-card-${entry.$1}'),
            index: entry.$1,
            total: editors.length,
            collectionKey: collectionKey,
            editor: entry.$2,
            whatToDoLabel: whatToDoLabel,
            onChanged: onChanged,
            onRemove: () => onRemove(entry.$2),
            onMoveUp: () => onMove(entry.$2, -1),
            onMoveDown: () => onMove(entry.$2, 1),
          ),
      ],
    ),
  );
}

final class _OrderedList extends StatelessWidget {
  const _OrderedList({
    required this.collectionKey,
    required this.emptyLabel,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });

  final String collectionKey;
  final String emptyLabel;
  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (children.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
          child: Text(
            emptyLabel,
            key: Key('health-care-$collectionKey-empty'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      for (final entry in children.indexed) ...[
        entry.$2,
        if (entry.$1 < children.length - 1) const SizedBox(height: CoeloSpacing.space3),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: Key('health-care-profile-add-$collectionKey'),
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
      ),
    ],
  );
}

/// Cabeçalho de linha ordenável: posição, nome, mover para cima/baixo, remover.
/// Botões, não só arrasto (spec 065 §5.4), para teclado e leitor de tela.
final class _OrderedRowHeader extends StatelessWidget {
  const _OrderedRowHeader({
    required this.index,
    required this.total,
    required this.title,
    required this.collectionKey,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final int total;
  final String title;
  final String collectionKey;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.secondaryContainer,
          foregroundColor: theme.colorScheme.onSecondaryContainer,
          child: Text('${index + 1}', style: theme.textTheme.labelLarge),
        ),
        const SizedBox(width: CoeloSpacing.space3),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          key: Key('health-care-$collectionKey-up-$index'),
          onPressed: index == 0 ? null : onMoveUp,
          tooltip: 'Mover para cima',
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
        IconButton(
          key: Key('health-care-$collectionKey-down-$index'),
          onPressed: index >= total - 1 ? null : onMoveDown,
          tooltip: 'Mover para baixo',
          icon: const Icon(Icons.arrow_downward_rounded),
        ),
        IconButton(
          key: Key('health-care-$collectionKey-remove-$index'),
          onPressed: onRemove,
          tooltip: 'Remover $title',
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

final class _OrderedRow extends StatelessWidget {
  const _OrderedRow({
    required this.index,
    required this.total,
    required this.title,
    required this.collectionKey,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    super.key,
  });

  final int index;
  final int total;
  final String title;
  final String collectionKey;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: CoeloSpacing.space3,
      vertical: CoeloSpacing.space2,
    ),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.md),
    ),
    child: _OrderedRowHeader(
      index: index,
      total: total,
      title: title,
      collectionKey: collectionKey,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
    ),
  );
}

final class _AllergyEditorCard extends StatelessWidget {
  const _AllergyEditorCard({
    required this.index,
    required this.total,
    required this.collectionKey,
    required this.editor,
    required this.whatToDoLabel,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final int index;
  final int total;
  final String collectionKey;
  final _AllergyEditor editor;
  final String whatToDoLabel;
  final ValueChanged<VoidCallback> onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

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
        _OrderedRowHeader(
          index: index,
          total: total,
          title: editor.title,
          collectionKey: collectionKey,
          onMoveUp: onMoveUp,
          onMoveDown: onMoveDown,
          onRemove: onRemove,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _ResponsiveFields(
          children: [
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
            CoeloFormTextField(
              key: Key('health-care-$collectionKey-reaction-$index'),
              controller: editor.reaction,
              labelText: 'Reação observada',
              prefixIcon: Icons.visibility_outlined,
              maxLines: 3,
            ),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          key: Key('health-care-$collectionKey-what-to-do-$index'),
          controller: editor.whatToDo,
          labelText: whatToDoLabel,
          prefixIcon: Icons.medical_services_outlined,
          maxLines: 3,
        ),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          key: Key('health-care-$collectionKey-notes-$index'),
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
