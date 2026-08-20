import 'package:flutter/foundation.dart';

import 'daily_routine.dart';

final class DailyRoutineController extends ChangeNotifier {
  DailyRoutineController({required this.repository, required this.permissions});

  final InMemoryDailyRoutineRepository repository;
  final DailyRoutinePermissions permissions;

  void publishInstitutionUpdate({required bool mandatory}) {
    _requireWrite();
    repository.publishInstitutionUpdate(mandatory: mandatory);
    notifyListeners();
  }

  void applyToParticipants(
    Set<String> participantIds, {
    required String fieldId,
    required Object? value,
    required bool overwrite,
  }) {
    _requireWrite();
    repository.applyToParticipants(
      participantIds,
      fieldId: fieldId,
      value: value,
      overwrite: overwrite,
    );
    notifyListeners();
  }

  void setParticipantFeeling(String participantId, DailyRoutineFeeling feeling) {
    _requireWrite();
    repository.setParticipantFeeling(participantId, feeling);
    notifyListeners();
  }

  void clearParticipantFeeling(String participantId) {
    _requireWrite();
    repository.clearParticipantFeeling(participantId);
    notifyListeners();
  }

  void suggestFeeling(String text) {
    _requireWrite();
    repository.suggestFeeling(text);
    notifyListeners();
  }

  void _requireWrite() {
    if (!permissions.canManage) throw StateError('Modo somente leitura.');
  }
}

enum DailyRoutineFormStep { identity, scope, sectionsAndFields, reviewAndActivation }

final class DailyRoutineFormController extends ChangeNotifier {
  DailyRoutineFormController({
    required this.repository,
    required this.permissions,
    String? modelId,
    DailyRoutineEntryType entryType = DailyRoutineEntryType.model,
  }) {
    final matches = repository.models.where((model) => model.id == modelId);
    final model = matches.isEmpty ? null : matches.first;
    _sourceModel = model;
    _modelId = model?.id;
    _entryType = model?.type ?? entryType;
    _name = model?.name ?? '';
    _description = model?.description ?? '';
    _origin = model?.origin ?? DailyRoutineOrigin.institution;
    _originUnitId = model?.originUnitId ?? 'unit-center';
    _status = model?.status ?? DailyRoutineStatus.draft;
    _sections = List<DailyRoutineSection>.of(model?.sections ?? const []);
    _scopes = List<DailyRoutineScope>.of(
      model?.scopes.isNotEmpty == true
          ? model!.scopes
          : (model?.groupIds ?? const <String>{}).map(
              (groupId) => DailyRoutineScope(
                groupId: groupId,
                activityIds: model?.activityId == null ? const {} : {model!.activityId!},
              ),
            ),
    );
  }

  final InMemoryDailyRoutineRepository repository;
  final DailyRoutinePermissions permissions;

  DailyRoutineModel? _sourceModel;
  String? _modelId;
  late DailyRoutineEntryType _entryType;
  String _name = '';
  String _description = '';
  DailyRoutineOrigin _origin = DailyRoutineOrigin.institution;
  String? _originUnitId = 'unit-center';
  DailyRoutineStatus _status = DailyRoutineStatus.draft;
  List<DailyRoutineSection> _sections = [];
  List<DailyRoutineScope> _scopes = [];
  DailyRoutineFormStep _currentStep = DailyRoutineFormStep.identity;
  final Set<DailyRoutineFormStep> _stepsWithErrors = {};
  bool _isDirty = false;

  String? get modelId => _modelId;
  bool get isEditing => _modelId != null;
  DailyRoutineEntryType get entryType => _entryType;
  bool get isCoeloProvided => _sourceModel?.isCoeloProvided ?? false;
  String get name => _name;
  String get description => _description;
  DailyRoutineOrigin get origin => _origin;
  String? get originUnitId => _originUnitId;
  bool get updateAvailable => _sourceModel?.updateAvailable ?? false;
  String? get baseModelId => _sourceModel?.baseModelId;
  DailyRoutineStatus get status => _status;
  List<DailyRoutineSection> get sections => List.unmodifiable(_sections);
  List<DailyRoutineScope> get scopes => List.unmodifiable(_scopes);
  Set<String> get selectedGroupIds => _scopes.map((scope) => scope.groupId).toSet();
  DailyRoutineFormStep get currentStep => _currentStep;
  bool get isDirty => _isDirty;

  void updateName(String value) {
    if (_name == value) return;
    _name = value;
    _markDirty();
  }

  void updateDescription(String value) {
    if (_description == value) return;
    _description = value;
    _markDirty();
  }

  void updateOrigin(DailyRoutineOrigin value) {
    if (_origin == value) return;
    _origin = value;
    _markDirty();
  }

  void updateOriginUnit(String value) {
    if (_originUnitId == value) return;
    _originUnitId = value;
    _markDirty();
  }

  void updateStatus(DailyRoutineStatus value) {
    if (_status == value) return;
    _status = value;
    _markDirty();
  }

  void updateSelectedGroups(Set<String> groupIds) {
    final byGroup = {for (final scope in _scopes) scope.groupId: scope};
    _scopes = [
      for (final groupId in groupIds) byGroup[groupId] ?? DailyRoutineScope(groupId: groupId),
    ];
    _markDirty();
  }

  void updateGroupActivities(String groupId, Set<String> activityIds) {
    _scopes = [
      for (final scope in _scopes)
        if (scope.groupId == groupId) scope.copyWith(activityIds: activityIds) else scope,
    ];
    _markDirty();
  }

  void addSection(DailyRoutineSection section) {
    _sections = [..._sections, section];
    _markDirty();
  }

  String upsertSection({String? sectionId, required String name}) {
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError.value(name, 'name');
    final id = sectionId ?? 'section-${_sections.length + 1}';
    final index = _sections.indexWhere((section) => section.id == id);
    final fields = index < 0 ? const <DailyRoutineField>[] : _sections[index].fields;
    final section = DailyRoutineSection(id: id, name: normalized, fields: fields);
    if (index < 0) {
      _sections = [..._sections, section];
    } else {
      _sections = [..._sections]..[index] = section;
    }
    _markDirty();
    return id;
  }

  void removeSection(String sectionId) {
    final removed = _sections.where((section) => section.id == sectionId);
    final fieldIds = removed.expand((section) => section.fields).map((field) => field.id).toSet();
    _sections = _sections.where((section) => section.id != sectionId).toList();
    _scopes = [
      for (final scope in _scopes)
        scope.copyWith(
          fieldOverrides: Map<String, DailyRoutineFieldOverride>.of(scope.fieldOverrides)
            ..removeWhere((fieldId, _) => fieldIds.contains(fieldId)),
        ),
    ];
    _markDirty();
  }

  String upsertField({
    required String sectionId,
    String? fieldId,
    required String label,
    required DailyRoutineFieldType type,
    required bool required,
    Object? initialValue,
    List<String> options = const [],
  }) {
    final sectionIndex = _sections.indexWhere((section) => section.id == sectionId);
    if (sectionIndex < 0) throw StateError('Seção não encontrada.');
    final normalized = label.trim();
    if (normalized.isEmpty) throw ArgumentError.value(label, 'label');
    final fields = List<DailyRoutineField>.of(_sections[sectionIndex].fields);
    final id = fieldId ?? 'field-${fields.length + 1}-${_sections.length}';
    final fieldIndex = fields.indexWhere((field) => field.id == id);
    final normalizedOptions = options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toSet()
        .toList(growable: false);
    _validateChoiceInitialValue(type, initialValue, normalizedOptions);
    final field = DailyRoutineField(
      id: id,
      label: normalized,
      type: type,
      required: required,
      initialValue: initialValue,
      options: List.unmodifiable(normalizedOptions),
    );
    if (fieldIndex < 0) {
      fields.add(field);
    } else {
      fields[fieldIndex] = field;
    }
    _sections = [..._sections]
      ..[sectionIndex] = DailyRoutineSection(
        id: _sections[sectionIndex].id,
        name: _sections[sectionIndex].name,
        fields: fields,
      );
    _markDirty();
    return id;
  }

  void removeField(String sectionId, String fieldId) {
    final sectionIndex = _sections.indexWhere((section) => section.id == sectionId);
    if (sectionIndex < 0) return;
    final section = _sections[sectionIndex];
    _sections = [..._sections]
      ..[sectionIndex] = DailyRoutineSection(
        id: section.id,
        name: section.name,
        fields: section.fields.where((field) => field.id != fieldId).toList(),
      );
    _scopes = [
      for (final scope in _scopes)
        scope.copyWith(
          fieldOverrides: Map<String, DailyRoutineFieldOverride>.of(scope.fieldOverrides)
            ..remove(fieldId),
        ),
    ];
    _markDirty();
  }

  void setScopeFieldOverride(String groupId, DailyRoutineFieldOverride override) {
    _scopes = [
      for (final scope in _scopes)
        if (scope.groupId == groupId)
          scope.copyWith(
            fieldOverrides: Map<String, DailyRoutineFieldOverride>.of(scope.fieldOverrides)
              ..[override.fieldId] = override,
          )
        else
          scope,
    ];
    _markDirty();
  }

  void removeScopeFieldOverride(String groupId, String fieldId) {
    _scopes = [
      for (final scope in _scopes)
        if (scope.groupId == groupId)
          scope.copyWith(
            fieldOverrides: Map<String, DailyRoutineFieldOverride>.of(scope.fieldOverrides)
              ..remove(fieldId),
          )
        else
          scope,
    ];
    _markDirty();
  }

  void addScopeLocalField(
    String groupId, {
    required String label,
    required DailyRoutineFieldType type,
    required bool required,
    Object? initialValue,
    List<String> options = const [],
  }) {
    final normalizedLabel = label.trim();
    if (normalizedLabel.isEmpty) return;
    final scopeIndex = _scopes.indexWhere((scope) => scope.groupId == groupId);
    if (scopeIndex < 0) return;
    final scope = _scopes[scopeIndex];
    final localSections = [...scope.localSections];
    final section = localSections.isEmpty
        ? DailyRoutineSection(id: 'local-$groupId', name: 'Campos desta turma', fields: const [])
        : localSections.first;
    final field = DailyRoutineField(
      id: 'local-$groupId-${DateTime.now().microsecondsSinceEpoch}',
      label: normalizedLabel,
      type: type,
      required: required,
      initialValue: initialValue,
      options: List.unmodifiable(options),
    );
    final updatedSection = DailyRoutineSection(
      id: section.id,
      name: section.name,
      fields: [...section.fields, field],
    );
    if (localSections.isEmpty) {
      localSections.add(updatedSection);
    } else {
      localSections[0] = updatedSection;
    }
    _scopes = [..._scopes]..[scopeIndex] = scope.copyWith(localSections: localSections);
    _markDirty();
  }

  void removeScopeLocalField(String groupId, String fieldId) {
    _scopes = [
      for (final scope in _scopes)
        if (scope.groupId == groupId)
          scope.copyWith(
            localSections: [
              for (final section in scope.localSections)
                DailyRoutineSection(
                  id: section.id,
                  name: section.name,
                  fields: section.fields.where((field) => field.id != fieldId).toList(),
                ),
            ].where((section) => section.fields.isNotEmpty).toList(),
          )
        else
          scope,
    ];
    _markDirty();
  }

  bool get canActivate =>
      _name.trim().isNotEmpty &&
      (_origin != DailyRoutineOrigin.unit || _originUnitId != null) &&
      _scopes.isNotEmpty &&
      _sections.any((section) => section.fields.isNotEmpty);

  DailyRoutineModel? save({required bool activate}) {
    if (!permissions.canManage || !_validate(DailyRoutineFormStep.identity)) {
      return null;
    }
    if (activate && !canActivate) {
      if (_scopes.isEmpty) {
        _stepsWithErrors.add(DailyRoutineFormStep.scope);
      }
      if (!_sections.any((section) => section.fields.isNotEmpty)) {
        _stepsWithErrors.add(DailyRoutineFormStep.sectionsAndFields);
      }
      notifyListeners();
      return null;
    }
    _modelId ??= 'daily-routine-${repository.models.length + 1}';
    _status = activate ? DailyRoutineStatus.active : DailyRoutineStatus.draft;
    final model = DailyRoutineModel(
      id: _modelId!,
      name: _name.trim(),
      description: _description.trim(),
      origin: _origin,
      originUnitId: _origin == DailyRoutineOrigin.unit ? _originUnitId : null,
      version: _sourceModel?.version ?? 1,
      status: _status,
      sections: List.unmodifiable(_sections),
      scopes: List.unmodifiable(_scopes),
      baseModelId: _sourceModel?.baseModelId,
      updateAvailable: _sourceModel?.updateAvailable ?? false,
      type: _entryType,
      isCoeloProvided: false,
    );
    repository.save(model);
    _sourceModel = model;
    _isDirty = false;
    notifyListeners();
    return model;
  }

  bool continueFromCurrentStep() {
    if (!_validate(_currentStep)) return false;
    if (_currentStep.index < DailyRoutineFormStep.values.length - 1) {
      _currentStep = DailyRoutineFormStep.values[_currentStep.index + 1];
      notifyListeners();
    }
    return true;
  }

  void previousStep() {
    if (_currentStep.index == 0) return;
    _currentStep = DailyRoutineFormStep.values[_currentStep.index - 1];
    notifyListeners();
  }

  void goToStep(DailyRoutineFormStep step) {
    _currentStep = step;
    notifyListeners();
  }

  bool stepHasError(DailyRoutineFormStep step) => _stepsWithErrors.contains(step);

  bool _validate(DailyRoutineFormStep step) {
    final valid = switch (step) {
      DailyRoutineFormStep.identity =>
        _name.trim().isNotEmpty && (_origin != DailyRoutineOrigin.unit || _originUnitId != null),
      DailyRoutineFormStep.scope => _scopes.isNotEmpty,
      DailyRoutineFormStep.sectionsAndFields => _sections.any(
        (section) => section.fields.isNotEmpty,
      ),
      DailyRoutineFormStep.reviewAndActivation => true,
    };
    if (valid) {
      _stepsWithErrors.remove(step);
    } else {
      _stepsWithErrors.add(step);
    }
    notifyListeners();
    return valid;
  }

  void _validateChoiceInitialValue(
    DailyRoutineFieldType type,
    Object? initialValue,
    List<String> options,
  ) {
    if (initialValue == null) return;
    final valid = switch (type) {
      DailyRoutineFieldType.singleChoice =>
        initialValue is String && options.contains(initialValue),
      DailyRoutineFieldType.multipleChoice =>
        initialValue is Iterable && initialValue.every(options.contains),
      _ => true,
    };
    if (!valid) {
      throw ArgumentError.value(
        initialValue,
        'initialValue',
        'O valor inicial deve ser uma das opções cadastradas.',
      );
    }
  }

  void _markDirty() {
    _isDirty = true;
    _stepsWithErrors.remove(_currentStep);
    notifyListeners();
  }
}
