import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../app/activity/superadmin_activity.dart';
import '../../app/shell/superadmin_shell.dart';
import '../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../auth/domain/logout_action.dart';
import 'daily_routine.dart';
import 'widgets/daily_routine_field_configuration_editor.dart';
import 'widgets/daily_routine_inheritance_summary.dart';
import 'widgets/daily_routine_ordered_editor.dart';

final class DailyRoutineWizardPage extends StatefulWidget {
  const DailyRoutineWizardPage({
    required this.repository,
    required this.logout,
    this.entryId,
    this.entryKind = RoutineEntryKind.model,
    this.duplicateFromModelId,
    this.applicationFromModelId,
    this.activityController,
    this.onDestinationSelected,
    super.key,
  });

  final RoutineRepository repository;
  final LogoutAction logout;
  final String? entryId;
  final RoutineEntryKind entryKind;
  final String? duplicateFromModelId;
  final String? applicationFromModelId;
  final SuperadminActivityController? activityController;
  final ValueChanged<String>? onDestinationSelected;

  @override
  State<DailyRoutineWizardPage> createState() => _DailyRoutineWizardPageState();
}

final class _DailyRoutineWizardPageState extends State<DailyRoutineWizardPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _modelInstitutionId = TextEditingController();
  final _modelOriginUnitId = TextEditingController();
  final _startsAt = TextEditingController();
  final _endsAt = TextEditingController();
  final _validFrom = TextEditingController();
  final _validUntil = TextEditingController();
  Object? _entry;
  Object? _error;
  var _loading = true;
  var _saving = false;
  var _sections = <RoutineSection>[];
  var _modelOriginScope = RoutineModelOriginScope.institution;
  var _applicationStatus = RoutineApplicationStatus.draft;
  var _applicationInheritance = RoutineInheritanceMode.inherited;
  var _applicationVisibility = 'institution';
  var _canManage = false;
  var _loadGeneration = 0;
  var _commandGeneration = 0;
  String? _baseline;
  final _intents = <String, (String, String)>{};
  var _guarded = false;

  @override
  void initState() {
    super.initState();
    for (final controller in _draftControllers) {
      controller.addListener(_handleDraftChanged);
    }
    _load();
  }

  List<TextEditingController> get _draftControllers => [
    _name,
    _description,
    _modelInstitutionId,
    _modelOriginUnitId,
    _startsAt,
    _endsAt,
    _validFrom,
    _validUntil,
  ];

  /// Typing does not call setState, so the exit guard would keep the value it
  /// was built with. Rebuild only when the draft crosses into or out of dirty.
  void _handleDraftChanged() {
    if (!mounted) return;
    final dirty = _isDirty;
    if (dirty != _guarded) setState(() => _guarded = dirty);
  }

  @override
  void didUpdateWidget(covariant DailyRoutineWizardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.entryId != widget.entryId ||
        oldWidget.entryKind != widget.entryKind ||
        oldWidget.duplicateFromModelId != widget.duplicateFromModelId ||
        oldWidget.applicationFromModelId != widget.applicationFromModelId) {
      _commandGeneration += 1;
      _load();
    }
  }

  @override
  void dispose() {
    _loadGeneration += 1;
    _commandGeneration += 1;
    _name.dispose();
    _description.dispose();
    _modelInstitutionId.dispose();
    _modelOriginUnitId.dispose();
    _startsAt.dispose();
    _endsAt.dispose();
    _validFrom.dispose();
    _validUntil.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final repository = widget.repository;
    final entryId = widget.entryId;
    final entryKind = widget.entryKind;
    final duplicateFromModelId = widget.duplicateFromModelId;
    final applicationFromModelId = widget.applicationFromModelId;
    setState(() {
      _loading = true;
      _saving = false;
      _error = null;
    });
    try {
      final entry = entryId == null
          ? await _newEntry(
              repository: repository,
              entryKind: entryKind,
              duplicateFromModelId: duplicateFromModelId,
              applicationFromModelId: applicationFromModelId,
            )
          : switch (entryKind) {
              RoutineEntryKind.model => await repository.fetchModel(entryId),
              RoutineEntryKind.application => await repository.fetchApplication(entryId),
              RoutineEntryKind.launch => await repository.fetchLaunch(entryId),
            };
      if (!_isCurrentLoad(
        generation,
        repository: repository,
        entryId: entryId,
        entryKind: entryKind,
        duplicateFromModelId: duplicateFromModelId,
        applicationFromModelId: applicationFromModelId,
      )) {
        return;
      }
      _validateLoadedEntryIdentity(entry, entryId: entryId, entryKind: entryKind);
      _bind(entry);
      setState(() {
        _entry = entry;
        _canManage = switch (entry) {
          RoutineModel value => value.canManage,
          RoutineApplication value => value.canManage,
          RoutineLaunch value => value.canManage,
          _ => false,
        };
        _loading = false;
      });
      _baseline = _draftSignature();
      _guarded = false;
    } on Object catch (error) {
      if (!_isCurrentLoad(
        generation,
        repository: repository,
        entryId: entryId,
        entryKind: entryKind,
        duplicateFromModelId: duplicateFromModelId,
        applicationFromModelId: applicationFromModelId,
      )) {
        return;
      }
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  bool _isCurrentLoad(
    int generation, {
    required RoutineRepository repository,
    required String? entryId,
    required RoutineEntryKind entryKind,
    required String? duplicateFromModelId,
    required String? applicationFromModelId,
  }) =>
      mounted &&
      generation == _loadGeneration &&
      identical(repository, widget.repository) &&
      entryId == widget.entryId &&
      entryKind == widget.entryKind &&
      duplicateFromModelId == widget.duplicateFromModelId &&
      applicationFromModelId == widget.applicationFromModelId;

  void _validateLoadedEntryIdentity(
    Object entry, {
    required String? entryId,
    required RoutineEntryKind entryKind,
  }) {
    if (entryId == null) return;
    final matches = switch ((entryKind, entry)) {
      (RoutineEntryKind.model, final RoutineModel value) => value.id == entryId,
      (RoutineEntryKind.application, final RoutineApplication value) => value.id == entryId,
      (RoutineEntryKind.launch, final RoutineLaunch value) => value.id == entryId,
      _ => false,
    };
    if (matches) return;
    throw FormatException(switch (entryKind) {
      RoutineEntryKind.model => 'O modelo solicitado não pôde ser validado.',
      RoutineEntryKind.application => 'A rotina aplicada solicitada não pôde ser validada.',
      RoutineEntryKind.launch => 'O lançamento solicitado não pôde ser validado.',
    });
  }

  bool _isCurrentCommand(
    int generation, {
    required RoutineRepository repository,
    required Object entry,
  }) =>
      mounted &&
      generation == _commandGeneration &&
      identical(repository, widget.repository) &&
      identical(entry, _entry);

  Future<Object> _newEntry({
    required RoutineRepository repository,
    required RoutineEntryKind entryKind,
    required String? duplicateFromModelId,
    required String? applicationFromModelId,
  }) async {
    final duplicateId = duplicateFromModelId;
    if (duplicateId != null) {
      final source = await repository.fetchModel(duplicateId);
      if (source.id != duplicateId) {
        throw const FormatException('O modelo de origem não pôde ser validado.');
      }
      return RoutineModel(
        id: '',
        name: '${source.name} (cópia)',
        description: source.description,
        version: 1,
        status: RoutineModelStatus.draft,
        sections: source.sections,
        expectedVersion: 0,
        originScope: source.originScope,
        institutionId: source.institutionId,
        originUnitId: source.originUnitId,
        canManage: source.canManage,
      );
    }
    final applicationModelId = applicationFromModelId;
    if (applicationModelId != null) {
      final source = await repository.fetchModel(applicationModelId);
      if (source.id != applicationModelId) {
        throw const FormatException('O modelo de origem não pôde ser validado.');
      }
      return RoutineApplication(
        id: '',
        modelVersionId: '${source.id}:v${source.version}',
        institutionId: source.institutionId ?? '',
        unitId: source.originUnitId,
        status: RoutineApplicationStatus.draft,
        inheritanceMode: RoutineInheritanceMode.inherited,
        effectiveVersion: source.version,
        expectedVersion: 0,
        canManage: source.canManage,
      );
    }
    return switch (entryKind) {
      RoutineEntryKind.model => () async {
        final capability = await repository.fetchPage(
          const RoutineDirectoryQuery(kind: RoutineEntryKind.model, pageSize: 1),
        );
        return RoutineModel(
          id: '',
          name: '',
          description: '',
          version: 1,
          status: RoutineModelStatus.draft,
          sections: [],
          expectedVersion: 0,
          canManage: capability.canManage,
        );
      }(),
      RoutineEntryKind.application => throw const FormatException(
        'Crie uma rotina aplicada a partir de um contexto autorizado.',
      ),
      RoutineEntryKind.launch => throw const FormatException(
        'Selecione uma rotina aplicada autorizada para criar o lançamento.',
      ),
    };
  }

  void _bind(Object entry) {
    if (entry case final RoutineModel model) {
      _name.text = model.name;
      _description.text = model.description;
      _modelOriginScope = model.originScope;
      _modelInstitutionId.text = model.institutionId ?? '';
      _modelOriginUnitId.text = model.originUnitId ?? '';
      _sections = List.of(model.sections);
    } else if (entry case final RoutineApplication application) {
      _validFrom.text = _dateText(application.validFrom);
      _validUntil.text = _dateText(application.validUntil);
      _startsAt.text = application.startsAt ?? '';
      _endsAt.text = application.endsAt ?? '';
      _applicationStatus = application.status;
      _applicationInheritance = application.inheritanceMode;
      _applicationVisibility = application.visibility;
    }
  }

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: widget.logout,
    currentDestination: 'daily-routine',
    onDestinationSelected: widget.onDestinationSelected == null ? null : _selectDestination,
    title: _title,
    subtitle: 'Configuração versionada e validada no servidor.',
    activityController: widget.activityController,
    child: PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SuperadminFormFrame(
          viewportWidth: MediaQuery.sizeOf(context).width,
          navigation: const SizedBox.shrink(),
          scrollKey: const Key('daily-routine-editor-scroll'),
          body: _body(),
          footer: _footer(),
        ),
      ),
    ),
  );

  /// The draft is compared against the state captured when it finished loading,
  /// so no editing path has to remember to flag itself as dirty.
  String _draftSignature() => [
    _name.text,
    _description.text,
    _modelInstitutionId.text,
    _modelOriginUnitId.text,
    _startsAt.text,
    _endsAt.text,
    _validFrom.text,
    _validUntil.text,
    _modelOriginScope.name,
    _applicationStatus.name,
    _applicationInheritance.name,
    _applicationVisibility,
    for (final section in _sections)
      '${section.id}|${section.name}|${section.sortOrder}|'
          '${section.fields.map(_fieldSignature).join(',')}',
  ].join(String.fromCharCode(31));

  String _fieldSignature(RoutineField field) =>
      '${field.id}:${field.label}:${field.kind.name}:${field.sortOrder}:'
      '${field.isRequired}:${field.initialValue}:${field.minimumValue}:${field.maximumValue}:'
      '${field.options.map((option) => '${option.id}=${option.label}=${option.sortOrder}').join('+')}:'
      '${field.conditions.length}';

  /// A retry of the same draft is the same intent, so it must carry the same
  /// request id; editing the draft first makes it a different one.
  String _requestIdFor(String intent) {
    final signature = _draftSignature();
    final held = _intents[intent];
    if (held != null && held.$1 == signature) return held.$2;
    final id = '$intent-${DateTime.now().microsecondsSinceEpoch}';
    _intents[intent] = (signature, id);
    return id;
  }

  void _completeIntent(String intent) => _intents.remove(intent);

  bool get _isDirty =>
      _canManage && !_saving && _baseline != null && _draftSignature() != _baseline;

  /// The shell can leave the editor without popping the route, so the same
  /// confirmation has to guard it. Five other Superadmin forms do exactly this.
  Future<void> _selectDestination(String destination) async {
    final callback = widget.onDestinationSelected;
    if (callback == null) return;
    if (!_isDirty) {
      callback(destination);
      return;
    }
    if (await _confirmDiscard()) callback(destination);
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        dialogKey: const Key('daily-routine-exit-dialog'),
        title: 'Sair sem salvar?',
        body: const Text(
          'As alterações feitas nesta rotina serão perdidas se você sair agora.',
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Continuar editando'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sair sem salvar'),
        ),
      ),
    );
    return (discard ?? false) && mounted;
  }

  Future<void> _confirmExit() async {
    final navigator = Navigator.of(context);
    if (await _confirmDiscard()) navigator.pop();
  }

  String get _title => switch (widget.entryKind) {
    RoutineEntryKind.model => widget.entryId == null ? 'Criar modelo' : 'Editar modelo',
    RoutineEntryKind.application => 'Rotina aplicada',
    RoutineEntryKind.launch => 'Lançamento da rotina',
  };

  Widget _body() {
    if (_loading) {
      return const CoeloStatePanel(
        key: Key('daily-routine-editor-loading'),
        title: 'Carregando configuração',
        message: 'Aguarde enquanto os dados autorizados são carregados.',
        loading: true,
      );
    }
    if (_error != null) {
      return CoeloStatePanel(
        key: const Key('daily-routine-editor-error'),
        title: 'Não foi possível abrir esta configuração',
        message: _error is FormatException
            ? (_error! as FormatException).message
            : 'O recurso não existe ou não está disponível para este acesso.',
        icon: Icons.error_outline_rounded,
        actionLabel: widget.entryId == null ? null : 'Tentar novamente',
        onAction: widget.entryId == null ? null : _load,
      );
    }
    return switch (_entry) {
      final RoutineModel model => _modelEditor(model),
      final RoutineApplication application => _applicationView(application),
      final RoutineLaunch launch => _launchView(launch),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _modelEditor(RoutineModel model) => Column(
    key: const Key('daily-routine-model-editor'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Identificação', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        key: const Key('daily-routine-name'),
        controller: _name,
        labelText: 'Nome',
        prefixIcon: Icons.title_rounded,
        enabled: _canManage && !_saving,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        key: const Key('daily-routine-description'),
        controller: _description,
        labelText: 'Descrição',
        prefixIcon: Icons.notes_rounded,
        maxLines: 4,
        enabled: _canManage && !_saving,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<RoutineModelOriginScope>(
        key: const Key('daily-routine-model-origin-scope'),
        label: 'Origem do modelo',
        value: _modelOriginScope,
        options: RoutineModelOriginScope.values,
        optionLabel: (value) => switch (value) {
          RoutineModelOriginScope.institution => 'Instituição',
          RoutineModelOriginScope.unit => 'Unidade',
        },
        onChanged: _canManage && !_saving
            ? (value) => setState(() {
                _modelOriginScope = value;
                if (value == RoutineModelOriginScope.institution) {
                  _modelOriginUnitId.clear();
                }
              })
            : (_) {},
        enabled: _canManage && !_saving,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        key: const Key('daily-routine-model-institution'),
        controller: _modelInstitutionId,
        labelText: 'Instituição de origem',
        prefixIcon: Icons.account_balance_outlined,
        enabled: _canManage && !_saving,
      ),

      if (_modelOriginScope == RoutineModelOriginScope.unit) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          key: const Key('daily-routine-model-origin-unit'),
          controller: _modelOriginUnitId,
          labelText: 'Unidade de origem',
          prefixIcon: Icons.apartment_outlined,
          enabled: _canManage && !_saving,
        ),
      ],
      const SizedBox(height: CoeloSpacing.space6),
      DailyRoutineOrderedEditor(
        sections: _sections,
        enabled: _canManage && !_saving,
        onEditSection: _editSection,
        onDuplicateSection: _duplicateSection,
        onRemoveSection: _removeSection,
        onReorderSections: _reorderSections,
        onAddSection: _addSection,
        onAddField: _addField,
        onReorderFields: _reorderFields,
        onAddChildField: _addChildField,
        onEditField: _editField,
        onDuplicateField: _duplicateField,
        onRemoveField: _removeField,
      ),
    ],
  );

  RoutineApplication _applicationDraft(RoutineApplication current) => RoutineApplication(
    id: current.id,
    modelVersionId: current.modelVersionId,
    institutionId: current.institutionId,
    unitId: current.unitId,
    groupId: current.groupId,
    parentApplicationId: current.parentApplicationId,
    activityId: current.activityId,
    status: _applicationStatus,
    inheritanceMode: _applicationInheritance,
    effectiveVersion: current.effectiveVersion,
    expectedVersion: current.expectedVersion,
    validFrom: _parseDate(_validFrom.text, 'início da validade'),
    validUntil: _parseDate(_validUntil.text, 'fim da validade'),
    startsAt: _optional(_startsAt.text),
    endsAt: _optional(_endsAt.text),
    visibility: _applicationVisibility,
    canManage: current.canManage,
    assignees: current.assignees,
  );

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _dateText(DateTime? value) => value == null
      ? ''
      : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final parsed = DateTime.tryParse(normalized);
    if (parsed == null || _dateText(parsed) != normalized) {
      throw FormatException('Informe $label no formato AAAA-MM-DD.');
    }
    return parsed;
  }

  Widget _applicationView(RoutineApplication application) => Column(
    key: const Key('daily-routine-application-editor'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DailyRoutineInheritanceSummary(
        application: _applicationDraft(application),
        originLabel: application.parentApplicationId == null
            ? 'Configuração original da instituição'
            : 'Rotina de origem vinculada',
        inheritedLabel: 'Versão ${application.effectiveVersion}',
        effectiveLabel: 'Versão ${application.effectiveVersion}',
        enabled: _canManage && !_saving,
        onModeChanged: _saveApplicationMode,
        onRevert: _resetInheritance,
      ),
      const SizedBox(height: CoeloSpacing.space6),
      Text('Aplicação e escopo', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space4),
      _applicationReferenceSummary(application),
      const SizedBox(height: CoeloSpacing.space5),
      Text('Validade e horario', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space4),
      LayoutBuilder(
        builder: (context, constraints) {
          final fields = [
            CoeloFormTextField(
              key: const Key('daily-routine-application-valid-from'),
              controller: _validFrom,
              labelText: 'Início da validade (AAAA-MM-DD)',
              prefixIcon: Icons.event_available_outlined,
              enabled: _canManage && !_saving,
            ),
            CoeloFormTextField(
              key: const Key('daily-routine-application-valid-until'),
              controller: _validUntil,
              labelText: 'Fim da validade (AAAA-MM-DD)',
              prefixIcon: Icons.event_busy_outlined,
              enabled: _canManage && !_saving,
            ),
            CoeloFormTextField(
              key: const Key('daily-routine-application-starts-at'),
              controller: _startsAt,
              labelText: 'Horario inicial (HH:MM)',
              prefixIcon: Icons.schedule_outlined,
              enabled: _canManage && !_saving,
            ),
            CoeloFormTextField(
              key: const Key('daily-routine-application-ends-at'),
              controller: _endsAt,
              labelText: 'Horario final (HH:MM)',
              prefixIcon: Icons.schedule_rounded,
              enabled: _canManage && !_saving,
            ),
          ];
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                for (final field in fields) ...[field, const SizedBox(height: CoeloSpacing.space4)],
              ],
            );
          }
          return Wrap(
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space4,
            children: [
              for (final field in fields)
                SizedBox(width: (constraints.maxWidth - CoeloSpacing.space3) / 2, child: field),
            ],
          );
        },
      ),
      const SizedBox(height: CoeloSpacing.space5),
      CoeloAdminSingleSelectField<RoutineApplicationStatus>(
        key: const Key('daily-routine-application-status'),
        label: 'Status da rotina',
        value: _applicationStatus,
        options: RoutineApplicationStatus.values,
        optionLabel: (value) => switch (value) {
          RoutineApplicationStatus.draft => 'Rascunho',
          RoutineApplicationStatus.active => 'Ativa',
          RoutineApplicationStatus.inactive => 'Inativa',
          RoutineApplicationStatus.archived => 'Arquivada',
        },
        prefixIcon: Icons.toggle_on_outlined,
        enabled: _canManage && !_saving,
        onChanged: (value) => setState(() => _applicationStatus = value),
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<String>(
        key: const Key('daily-routine-application-visibility'),
        label: 'Visibilidade',
        value: _applicationVisibility,
        options: const ['staff_only', 'authorized_guardians'],
        optionLabel: (value) => switch (value) {
          'staff_only' => 'Somente equipe',
          _ => 'Responsaveis autorizados',
        },
        prefixIcon: Icons.visibility_outlined,
        enabled: _canManage && !_saving,
        onChanged: (value) => setState(() => _applicationVisibility = value),
      ),
    ],
  );

  Widget _applicationReferenceSummary(RoutineApplication application) {
    final responsibilities = application.assignees
        .map(
          (assignee) => switch (assignee.responsibility) {
            RoutineApplicationResponsibility.record => 'Registro',
            RoutineApplicationResponsibility.review => 'Revisao',
            RoutineApplicationResponsibility.publish => 'Publicacao',
          },
        )
        .toSet()
        .join(' · ');
    final scope = application.groupId != null
        ? 'Turma'
        : application.unitId != null
        ? 'Unidade'
        : 'Instituição';
    return Semantics(
      container: true,
      label:
          'Modelo e escopo vinculados. Escopo: $scope. ${application.activityId == null ? 'Sem atividade vinculada.' : 'Atividade vinculada.'}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(CoeloRadius.lg),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Modelo vinculado · versão ${application.effectiveVersion}'),
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                'Escopo: $scope${application.activityId == null ? '' : ' · Atividade vinculada'}',
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                application.assignees.isEmpty
                    ? 'Sem responsaveis vinculados.'
                    : 'Responsabilidades vinculadas: $responsibilities',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _launchView(RoutineLaunch launch) => Column(
    key: const Key('daily-routine-launch-editor'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Resumo do lançamento', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: CoeloSpacing.space4),
      Text('Data: ${routineCivilDate(launch.serviceDate.toLocal())}'),
      Text('Status: ${routineStatusLabel(launch.status.name)}'),
      Text('Versão esperada: ${launch.expectedVersion}'),
    ],
  );

  Widget _footer() {
    if (_loading || _entry == null) return const SizedBox.shrink();
    final continuationActions = <Widget>[
      if (_canManage && _entry is RoutineModel)
        FilledButton(
          key: const Key('daily-routine-save'),
          onPressed: _saving ? null : _saveModel,
          child: Text(_saving ? 'Salvando...' : 'Salvar'),
        ),
      if (_canManage && _entry is RoutineApplication)
        FilledButton(
          key: const Key('daily-routine-application-save'),
          onPressed: _saving ? null : _saveApplication,
          child: Text(_saving ? 'Salvando...' : 'Salvar rotina'),
        ),
    ];
    if (continuationActions.isEmpty) return const SizedBox.shrink();
    return SuperadminFormActionFooter(
      surfaceKey: const Key('daily-routine-form-footer'),
      tertiaryAction: const SizedBox.shrink(),
      continuationActions: continuationActions,
    );
  }

  Future<void> _editSection(RoutineSection section) async {
    final controller = TextEditingController(text: section.name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        title: 'Editar seção',
        body: CoeloFormTextField(
          controller: controller,
          labelText: 'Nome da seção',
          prefixIcon: Icons.view_agenda_outlined,
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Salvar'),
        ),
      ),
    );
    controller.dispose();
    if (!mounted || result == null || result.isEmpty) return;
    setState(() {
      _sections = [
        for (final item in _sections)
          item.id == section.id
              ? RoutineSection(
                  id: item.id,
                  name: result,
                  sortOrder: item.sortOrder,
                  fields: item.fields,
                )
              : item,
      ];
    });
  }

  Future<void> _editField(RoutineSection section, RoutineField field) async {
    var draft = field;
    final parents = _sections
        .expand((item) => item.fields)
        .where((item) => item.id != field.id)
        .toList(growable: false);
    final result = await showDialog<RoutineField>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        title: 'Configurar campo',
        body: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
          child: SingleChildScrollView(
            child: DailyRoutineFieldConfigurationEditor(
              field: field,
              availableParents: parents,
              enabled: true,
              onChanged: (value) => draft = value,
            ),
          ),
        ),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          key: const Key('daily-routine-field-save'),
          onPressed: () {
            try {
              draft.validate();
              Navigator.pop(dialogContext, draft);
            } on FormatException catch (error) {
              ScaffoldMessenger.of(
                dialogContext,
              ).showSnackBar(SnackBar(content: Text(error.message)));
            }
          },
          child: const Text('Salvar campo'),
        ),
      ),
    );
    if (!mounted || result == null) return;
    _replaceSection(section, [
      for (final item in section.fields)
        if (item.id == field.id) result else item,
    ]);
  }

  void _addChildField(RoutineSection section, RoutineField parent) {
    final optionId = parent.kind == RoutineFieldKind.singleChoice && parent.options.isNotEmpty
        ? parent.options.first.id
        : null;
    final booleanValue = parent.kind == RoutineFieldKind.boolean ? true : null;
    if (optionId == null && booleanValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use Sim/Não ou escolha única com opções para ramificar.')),
      );
      return;
    }
    final depth = parent.conditions.fold<int>(
      1,
      (value, condition) => condition.depth >= value ? condition.depth + 1 : value,
    );
    if (depth > 4) return;
    final id = 'field-${DateTime.now().microsecondsSinceEpoch}';
    final child = RoutineField(
      id: id,
      label: 'Pergunta dependente',
      kind: RoutineFieldKind.shortText,
      sortOrder: section.fields.length,
      conditions: [
        RoutineCondition(
          id: 'condition-$id',
          parentFieldId: parent.id,
          targetFieldId: id,
          depth: depth,
          optionId: optionId,
          booleanValue: booleanValue,
        ),
      ],
    );
    _replaceSection(section, [...section.fields, child]);
  }

  void _reorderSections(int oldIndex, int newIndex) {
    final ordered = [..._sections]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (newIndex > oldIndex) newIndex--;
    final moved = ordered.removeAt(oldIndex);
    ordered.insert(newIndex, moved);
    setState(() {
      _sections = [
        for (var index = 0; index < ordered.length; index++)
          RoutineSection(
            id: ordered[index].id,
            name: ordered[index].name,
            sortOrder: index,
            fields: ordered[index].fields,
          ),
      ];
    });
  }

  void _reorderFields(RoutineSection section, int oldIndex, int newIndex) {
    final fields = [...section.fields]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (newIndex > oldIndex) newIndex--;
    final moved = fields.removeAt(oldIndex);
    fields.insert(newIndex, moved);
    _replaceSection(section, fields);
  }

  void _duplicateSection(RoutineSection section) {
    final id = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _sections = [
        ..._sections,
        RoutineSection(
          id: 'section-$id',
          name: '${section.name} (cópia)',
          sortOrder: _sections.length,
          fields: [
            for (var index = 0; index < section.fields.length; index++)
              RoutineField(
                id: 'field-$id-$index',
                label: section.fields[index].label,
                kind: section.fields[index].kind,
                sortOrder: index,
                isRequired: section.fields[index].isRequired,
                initialValue: section.fields[index].initialValue,
                minimumValue: section.fields[index].minimumValue,
                maximumValue: section.fields[index].maximumValue,
                options: section.fields[index].options,
              ),
          ],
        ),
      ];
    });
  }

  void _removeSection(RoutineSection section) {
    setState(() => _sections = _sections.where((item) => item.id != section.id).toList());
  }

  void _addSection() {
    final index = _sections.length;
    setState(() {
      _sections = [
        ..._sections,
        RoutineSection(
          id: 'section-${DateTime.now().microsecondsSinceEpoch}',
          name: 'Nova seção',
          sortOrder: index,
          fields: const [],
        ),
      ];
    });
  }

  void _addField(RoutineSection section) {
    final field = RoutineField(
      id: 'field-${DateTime.now().microsecondsSinceEpoch}',
      label: 'Novo campo',
      kind: RoutineFieldKind.shortText,
      sortOrder: section.fields.length,
    );
    _replaceSection(section, [...section.fields, field]);
  }

  void _duplicateField(RoutineSection section, RoutineField field) {
    final copy = RoutineField(
      id: 'field-${DateTime.now().microsecondsSinceEpoch}',
      label: '${field.label} (copia)',
      kind: field.kind,
      sortOrder: section.fields.length,
      isRequired: field.isRequired,
      initialValue: field.initialValue,
      minimumValue: field.minimumValue,
      maximumValue: field.maximumValue,
      options: field.options,
      conditions: const [],
    );
    _replaceSection(section, [...section.fields, copy]);
  }

  void _removeField(RoutineSection section, RoutineField field) {
    _replaceSection(section, section.fields.where((item) => item.id != field.id).toList());
  }

  void _replaceSection(RoutineSection section, List<RoutineField> fields) {
    setState(() {
      _sections = [
        for (final item in _sections)
          if (item.id == section.id)
            RoutineSection(
              id: item.id,
              name: item.name,
              sortOrder: item.sortOrder,
              fields: [
                for (var index = 0; index < fields.length; index++)
                  RoutineField(
                    id: fields[index].id,
                    label: fields[index].label,
                    kind: fields[index].kind,
                    sortOrder: index,
                    isRequired: fields[index].isRequired,
                    initialValue: fields[index].initialValue,
                    minimumValue: fields[index].minimumValue,
                    maximumValue: fields[index].maximumValue,
                    options: fields[index].options,
                    conditions: fields[index].conditions,
                  ),
              ],
            )
          else
            item,
      ];
    });
  }

  Future<void> _saveModel() async {
    final current = _entry! as RoutineModel;
    final repository = widget.repository;
    final generation = ++_commandGeneration;
    final model = RoutineModel(
      id: current.id,
      name: _name.text.trim(),
      description: _description.text.trim(),
      version: current.version,
      status: current.status,
      sections: _sections,
      expectedVersion: current.expectedVersion,
      originScope: _modelOriginScope,
      institutionId: _optional(_modelInstitutionId.text),
      originUnitId: _modelOriginScope == RoutineModelOriginScope.unit
          ? _optional(_modelOriginUnitId.text)
          : null,
    );
    try {
      model.validate();
      setState(() => _saving = true);
      final id = await repository.saveModel(
        model,
        requestId: _requestIdFor('save-model'),
      );
      if (!_isCurrentCommand(generation, repository: repository, entry: current)) return;
      if (id.trim().isEmpty) {
        throw const FormatException('O modelo salvo não pôde ser validado.');
      }
      if (current.id.isNotEmpty && id != current.id) {
        throw const FormatException('O modelo salvo não corresponde ao solicitado.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modelo salvo.')));
      _completeIntent('save-model');
      _baseline = _draftSignature();
      if (current.id.isEmpty) {
        setState(() {
          _entry = RoutineModel(
            id: id,
            name: model.name,
            description: model.description,
            version: model.version,
            status: model.status,
            sections: model.sections,
            expectedVersion: model.expectedVersion,
            originScope: model.originScope,
            institutionId: model.institutionId,
            originUnitId: model.originUnitId,
            canManage: _canManage,
          );
          _saving = false;
        });
      }
    } on FormatException catch (error) {
      if (mounted && _isCurrentCommand(generation, repository: repository, entry: current)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object {
      if (mounted && _isCurrentCommand(generation, repository: repository, entry: current)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não foi possível salvar o modelo.')));
      }
    } finally {
      if (_isCurrentCommand(generation, repository: repository, entry: current)) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveApplication() async {
    final current = _entry! as RoutineApplication;
    final repository = widget.repository;
    final generation = ++_commandGeneration;
    try {
      final application = _applicationDraft(current);
      if (application.modelVersionId.isEmpty || application.institutionId.isEmpty) {
        throw const FormatException('Informe a versão do modelo e a instituição.');
      }
      application.validate();
      setState(() => _saving = true);
      final id = await repository.saveApplication(
        application,
        requestId: _requestIdFor('save-application'),
      );
      if (!_isCurrentCommand(generation, repository: repository, entry: current)) return;
      if (id.trim().isEmpty) {
        throw const FormatException('A rotina aplicada salva não pôde ser validada.');
      }
      if (current.id.isNotEmpty && id != current.id) {
        throw const FormatException('A rotina aplicada salva não corresponde à solicitada.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rotina aplicada salva.')));
      if (current.id.isEmpty) {
        setState(() {
          _entry = RoutineApplication(
            id: id,
            modelVersionId: application.modelVersionId,
            institutionId: application.institutionId,
            unitId: application.unitId,
            groupId: application.groupId,
            parentApplicationId: application.parentApplicationId,
            activityId: application.activityId,
            status: application.status,
            inheritanceMode: application.inheritanceMode,
            effectiveVersion: application.effectiveVersion,
            expectedVersion: application.expectedVersion,
            validFrom: application.validFrom,
            validUntil: application.validUntil,
            startsAt: application.startsAt,
            endsAt: application.endsAt,
            visibility: application.visibility,
            assignees: application.assignees,
            canManage: application.canManage,
          );
          _saving = false;
        });
      }
    } on FormatException catch (error) {
      if (mounted && _isCurrentCommand(generation, repository: repository, entry: current)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on Object {
      if (mounted && _isCurrentCommand(generation, repository: repository, entry: current)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não foi possível salvar a rotina aplicada.')));
      }
    } finally {
      if (mounted && _isCurrentCommand(generation, repository: repository, entry: current)) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveApplicationMode(RoutineInheritanceMode mode) async {
    final current = _entry! as RoutineApplication;
    final repository = widget.repository;
    final generation = ++_commandGeneration;
    setState(() {
      _applicationInheritance = mode;
      _saving = true;
    });
    try {
      final updated = _applicationDraft(current);
      updated.validate();
      final id = await repository.saveApplication(
        updated,
        requestId: _requestIdFor('save-application-mode'),
      );
      if (!_isCurrentCommand(generation, repository: repository, entry: current)) return;
      if (id != current.id) {
        throw const FormatException('A rotina aplicada salva não corresponde à solicitada.');
      }
      setState(() => _saving = false);
      await _load();
    } on Object {
      if (!mounted) return;
      if (_isCurrentCommand(generation, repository: repository, entry: current)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não foi possível alterar a herança.')));
      }
    } finally {
      if (_isCurrentCommand(generation, repository: repository, entry: current)) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _resetInheritance() async {
    final application = _entry! as RoutineApplication;
    final repository = widget.repository;
    final generation = ++_commandGeneration;
    setState(() => _saving = true);
    try {
      final id = await repository.revertApplicationCustomization(
        applicationId: application.id,
        expectedVersion: application.expectedVersion,
        requestId: _requestIdFor('revert-application'),
      );
      if (!_isCurrentCommand(generation, repository: repository, entry: application)) return;
      if (id != application.id) {
        throw const FormatException('A rotina aplicada revertida não corresponde à solicitada.');
      }
      setState(() => _saving = false);
      await _load();
    } on Object {
      if (mounted && _isCurrentCommand(generation, repository: repository, entry: application)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível reverter a personalização.')),
        );
      }
    } finally {
      if (_isCurrentCommand(generation, repository: repository, entry: application)) {
        setState(() => _saving = false);
      }
    }
  }
}
