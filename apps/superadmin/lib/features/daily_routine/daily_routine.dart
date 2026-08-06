import 'dart:collection';

import '../../app/activity/superadmin_activity.dart';

enum DailyRoutineOrigin { institution, unit }

enum DailyRoutineFieldType { shortText, longText, singleChoice, multipleChoice, number, boolean }

enum DailyRoutineStatus { draft, active }

enum DailyRoutineEntryType { model, routine }

enum DailyRoutineFeeling {
  animated('animated', '😊', 'Animado', true),
  calm('calm', '😌', 'Calmo', true),
  sensitive('sensitive', '🥺', 'Sensível', true),
  irritated('irritated', '😠', 'Irritado', true),
  sleepy('sleepy', '😴', 'Sonolento', true),
  sad('sad', '😢', 'Triste', false),
  discouraged('discouraged', '😔', 'Desanimado', false),
  distracted('distracted', '🤔', 'Distraído', false),
  agitated('agitated', '😣', 'Agitado', false);

  const DailyRoutineFeeling(this.id, this.emoji, this.label, this.isPrimary);

  final String id;
  final String emoji;
  final String label;
  final bool isPrimary;

  static List<DailyRoutineFeeling> get primary =>
      values.where((feeling) => feeling.isPrimary).toList(growable: false);

  static List<DailyRoutineFeeling> get additional =>
      values.where((feeling) => !feeling.isPrimary).toList(growable: false);

  static DailyRoutineFeeling? fromId(Object? id) {
    for (final feeling in values) {
      if (feeling.id == id) return feeling;
    }
    return null;
  }
}

enum DailyRoutineFeelingSuggestionStatus { pending }

final class DailyRoutineFeelingSuggestion {
  const DailyRoutineFeelingSuggestion({
    required this.id,
    required this.text,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String text;
  final DailyRoutineFeelingSuggestionStatus status;
  final DateTime createdAt;
}

class DailyRoutinePermissions {
  const DailyRoutinePermissions._(this.canManage);

  static const owner = DailyRoutinePermissions._(true);
  static const readOnly = DailyRoutinePermissions._(false);

  final bool canManage;
}

class DailyRoutineField {
  const DailyRoutineField({
    required this.id,
    required this.label,
    required this.type,
    this.required = false,
    this.initialValue,
    this.options = const [],
  });

  final String id;
  final String label;
  final DailyRoutineFieldType type;
  final bool required;
  final Object? initialValue;
  final List<String> options;
}

class DailyRoutineSection {
  const DailyRoutineSection({required this.id, required this.name, required this.fields});

  final String id;
  final String name;
  final List<DailyRoutineField> fields;
}

class DailyRoutineFieldOverride {
  const DailyRoutineFieldOverride({required this.fieldId, this.required, this.initialValue});

  final String fieldId;
  final bool? required;
  final Object? initialValue;
}

class DailyRoutineScope {
  const DailyRoutineScope({
    required this.groupId,
    this.activityIds = const {},
    this.fieldOverrides = const {},
    this.localSections = const [],
  });

  final String groupId;
  final Set<String> activityIds;
  final Map<String, DailyRoutineFieldOverride> fieldOverrides;
  final List<DailyRoutineSection> localSections;

  bool appliesTo(String? activityId) =>
      activityIds.isEmpty || activityId != null && activityIds.contains(activityId);

  DailyRoutineScope copyWith({
    Set<String>? activityIds,
    Map<String, DailyRoutineFieldOverride>? fieldOverrides,
    List<DailyRoutineSection>? localSections,
  }) => DailyRoutineScope(
    groupId: groupId,
    activityIds: activityIds ?? this.activityIds,
    fieldOverrides: fieldOverrides ?? this.fieldOverrides,
    localSections: localSections ?? this.localSections,
  );
}

class DailyRoutineModel {
  const DailyRoutineModel({
    required this.id,
    required this.name,
    required this.description,
    required this.origin,
    required this.version,
    required this.status,
    required this.sections,
    this.scopes = const [],
    this.originUnitId,
    this.groupIds = const {},
    this.activityId,
    this.baseModelId,
    this.updateAvailable = false,
    this.type = DailyRoutineEntryType.model,
    this.isCoeloProvided = false,
  });

  final String id;
  final String name;
  final String description;
  final DailyRoutineOrigin origin;
  final int version;
  final DailyRoutineStatus status;
  final List<DailyRoutineSection> sections;
  final List<DailyRoutineScope> scopes;
  final String? originUnitId;
  final Set<String> groupIds;
  final String? activityId;
  final String? baseModelId;
  final bool updateAvailable;
  final DailyRoutineEntryType type;
  final bool isCoeloProvided;

  DailyRoutineModel copyWith({
    String? id,
    String? name,
    String? description,
    int? version,
    List<DailyRoutineSection>? sections,
    bool? updateAvailable,
    DailyRoutineStatus? status,
    DailyRoutineEntryType? type,
    bool? isCoeloProvided,
    String? baseModelId,
  }) => DailyRoutineModel(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    origin: origin,
    version: version ?? this.version,
    status: status ?? this.status,
    sections: sections ?? this.sections,
    scopes: scopes,
    originUnitId: originUnitId,
    groupIds: groupIds,
    activityId: activityId,
    baseModelId: baseModelId ?? this.baseModelId,
    updateAvailable: updateAvailable ?? this.updateAvailable,
    type: type ?? this.type,
    isCoeloProvided: isCoeloProvided ?? this.isCoeloProvided,
  );
}

class DailyRoutineSnapshot {
  DailyRoutineSnapshot({
    required this.id,
    required this.modelId,
    required this.version,
    required Map<String, Object?> values,
  }) : values = UnmodifiableMapView(Map<String, Object?>.from(values));

  final String id;
  final String modelId;
  final int version;
  final Map<String, Object?> values;
}

abstract interface class DailyRoutineRepository {
  List<DailyRoutineModel> get models;
  List<DailyRoutineSnapshot> get snapshots;
  bool appliesTo(String modelId, {required String groupId, String? activityId});
  void publishInstitutionUpdate({required bool mandatory});
  void applyToParticipants(
    Set<String> participantIds, {
    required String fieldId,
    required Object? value,
    required bool overwrite,
  });
}

class InMemoryDailyRoutineRepository implements DailyRoutineRepository {
  InMemoryDailyRoutineRepository.empty({SuperadminActivityController? activities})
    : _activities = activities;

  InMemoryDailyRoutineRepository.seeded({SuperadminActivityController? activities})
    : _activities = activities {
    const mood = DailyRoutineField(
      id: 'mood',
      label: 'Como chegou?',
      type: DailyRoutineFieldType.singleChoice,
    );
    const notes = DailyRoutineField(
      id: 'notes',
      label: 'Observações',
      type: DailyRoutineFieldType.longText,
    );
    const baseSection = DailyRoutineSection(id: 'arrival', name: 'Chegada', fields: [mood, notes]);
    _models.addAll([
      const DailyRoutineModel(
        id: 'institution-model',
        name: 'Modelo Berçário',
        description: 'Registro diário de cuidado e comunicação.',
        origin: DailyRoutineOrigin.institution,
        version: 1,
        status: DailyRoutineStatus.active,
        sections: [baseSection],
        groupIds: {'group-a'},
        activityId: 'activity-meal',
        isCoeloProvided: true,
      ),
      const DailyRoutineModel(
        id: 'coelo-fundamental',
        name: 'Modelo Fundamental',
        description: 'Base inicial para a rotina do ensino fundamental.',
        origin: DailyRoutineOrigin.institution,
        version: 1,
        status: DailyRoutineStatus.active,
        sections: [baseSection],
        isCoeloProvided: true,
      ),
      const DailyRoutineModel(
        id: 'coelo-medio',
        name: 'Modelo Médio',
        description: 'Base inicial para a rotina do ensino médio.',
        origin: DailyRoutineOrigin.institution,
        version: 1,
        status: DailyRoutineStatus.active,
        sections: [baseSection],
        isCoeloProvided: true,
      ),
      const DailyRoutineModel(
        id: 'coelo-pre',
        name: 'Modelo Pré',
        description: 'Base inicial para a rotina da pré-escola.',
        origin: DailyRoutineOrigin.institution,
        version: 1,
        status: DailyRoutineStatus.active,
        sections: [baseSection],
        isCoeloProvided: true,
      ),
      const DailyRoutineModel(
        id: 'coelo-maternal',
        name: 'Modelo Maternal',
        description: 'Base inicial para a rotina maternal.',
        origin: DailyRoutineOrigin.institution,
        version: 1,
        status: DailyRoutineStatus.active,
        sections: [baseSection],
        isCoeloProvided: true,
      ),
      const DailyRoutineModel(
        id: 'unit-model',
        name: 'Rotina Unidade Centro',
        description: 'Rotina efetivamente utilizada pela unidade.',
        origin: DailyRoutineOrigin.unit,
        originUnitId: 'unit-center',
        version: 1,
        status: DailyRoutineStatus.active,
        sections: [baseSection],
        groupIds: {'group-a'},
        activityId: 'activity-meal',
        baseModelId: 'institution-model',
        type: DailyRoutineEntryType.routine,
      ),
    ]);
    _snapshots.add(
      DailyRoutineSnapshot(
        id: 'snapshot-1',
        modelId: 'unit-model',
        version: 1,
        values: const {'mood': 'calm'},
      ),
    );
    _participantValues.addAll({
      'participant-1': <String, Object?>{'mood': 'sleepy'},
      'participant-2': <String, Object?>{},
      'participant-3': <String, Object?>{},
    });
  }

  final SuperadminActivityController? _activities;
  final List<DailyRoutineModel> _models = [];
  final List<DailyRoutineModel> _archivedConflicts = [];
  final List<DailyRoutineSnapshot> _snapshots = [];
  final List<DailyRoutineFeelingSuggestion> _feelingSuggestions = [];
  final Map<String, Map<String, Object?>> _participantValues = {};

  @override
  List<DailyRoutineModel> get models => UnmodifiableListView(_models);
  List<DailyRoutineModel> get archivedConflicts => UnmodifiableListView(_archivedConflicts);
  @override
  List<DailyRoutineSnapshot> get snapshots => UnmodifiableListView(_snapshots);
  List<DailyRoutineFeelingSuggestion> get feelingSuggestions =>
      UnmodifiableListView(_feelingSuggestions);
  Map<String, Map<String, Object?>> get participantValues =>
      UnmodifiableMapView(_participantValues);

  @override
  bool appliesTo(String modelId, {required String groupId, String? activityId}) {
    final model = _models.firstWhere((item) => item.id == modelId);
    if (model.scopes.isNotEmpty) {
      final scopes = model.scopes.where((scope) => scope.groupId == groupId);
      return scopes.any((scope) => scope.appliesTo(activityId));
    }
    if (!model.groupIds.contains(groupId)) return false;
    return model.activityId == null || model.activityId == activityId;
  }

  void setParticipantValue(String participantId, String fieldId, Object? value) {
    (_participantValues[participantId] ??= {})[fieldId] = value;
  }

  DailyRoutineFeeling? participantFeeling(String participantId) =>
      DailyRoutineFeeling.fromId(_participantValues[participantId]?['mood']);

  void setParticipantFeeling(String participantId, DailyRoutineFeeling feeling) {
    setParticipantValue(participantId, 'mood', feeling.id);
  }

  void clearParticipantFeeling(String participantId) {
    _participantValues[participantId]?.remove('mood');
  }

  DailyRoutineFeelingSuggestion suggestFeeling(String text, {DateTime? now}) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Informe um sentimento.');
    }
    final suggestion = DailyRoutineFeelingSuggestion(
      id: 'feeling-suggestion-${_feelingSuggestions.length + 1}',
      text: normalized,
      status: DailyRoutineFeelingSuggestionStatus.pending,
      createdAt: now ?? DateTime.now(),
    );
    _feelingSuggestions.add(suggestion);
    return suggestion;
  }

  void applyInitialValues(String modelId, Set<String> participantIds) {
    final model = _models.firstWhere((item) => item.id == modelId);
    for (final field in model.sections.expand((section) => section.fields)) {
      if (field.initialValue != null) {
        applyToParticipants(
          participantIds,
          fieldId: field.id,
          value: field.initialValue,
          overwrite: false,
        );
      }
    }
  }

  @override
  void applyToParticipants(
    Set<String> participantIds, {
    required String fieldId,
    required Object? value,
    required bool overwrite,
  }) {
    for (final participantId in participantIds) {
      final values = _participantValues[participantId] ??= {};
      if (overwrite || !values.containsKey(fieldId)) values[fieldId] = value;
    }
  }

  @override
  void publishInstitutionUpdate({required bool mandatory}) {
    final institutionIndex = _models.indexWhere((model) => model.id == 'institution-model');
    final institution = _models[institutionIndex];
    _models[institutionIndex] = institution.copyWith(version: institution.version + 1);
    final unitIndex = _models.indexWhere((model) => model.id == 'unit-model');
    final unit = _models[unitIndex];
    if (!mandatory) {
      _models[unitIndex] = unit.copyWith(updateAvailable: true);
      return;
    }
    _archivedConflicts.add(unit);
    _models[unitIndex] = unit.copyWith(version: unit.version + 1, updateAvailable: false);
    _activities?.addActivity(
      SuperadminActivity.routineUpdate(
        id: 'routine-mandatory-${institution.version + 1}',
        subject: 'Mudança obrigatória na rotina',
        summary: 'Conflitos locais foram arquivados para revisão.',
        destination: '/daily-routine/unit-model/edit',
      ),
    );
  }

  void save(DailyRoutineModel model) {
    _validateChoiceInitialValues(model);
    final index = _models.indexWhere((item) => item.id == model.id);
    if (index < 0) {
      _models.add(model);
    } else {
      if (_models[index].isCoeloProvided) {
        throw StateError('Modelos fornecidos pelo Coelo não podem ser editados.');
      }
      _models[index] = model;
    }
  }

  void remove(String modelId) {
    final model = _models.firstWhere((item) => item.id == modelId);
    if (model.isCoeloProvided) {
      throw StateError('Modelos fornecidos pelo Coelo não podem ser excluídos.');
    }
    _models.remove(model);
  }

  DailyRoutineModel duplicate(String modelId) {
    final source = _models.firstWhere((item) => item.id == modelId);
    final baseName = source.name.replaceFirst(RegExp(r' \(\d+\)$'), '');
    var suffix = 2;
    while (_models.any((item) => item.name == '$baseName ($suffix)')) {
      suffix++;
    }
    final copy = source.copyWith(
      id: _nextId(),
      name: '$baseName ($suffix)',
      isCoeloProvided: false,
    );
    _models.add(copy);
    return copy;
  }

  DailyRoutineModel createRoutineFromModel(String modelId) {
    final source = _models.firstWhere((item) => item.id == modelId);
    if (source.type != DailyRoutineEntryType.model) {
      throw ArgumentError.value(modelId, 'modelId', 'A origem deve ser um modelo.');
    }
    final routine = source.copyWith(
      id: _nextId(),
      type: DailyRoutineEntryType.routine,
      isCoeloProvided: false,
      baseModelId: source.id,
    );
    _models.add(routine);
    return routine;
  }

  String _nextId() {
    var suffix = _models.length + 1;
    var candidate = 'daily-routine-$suffix';
    while (_models.any((item) => item.id == candidate)) {
      suffix++;
      candidate = 'daily-routine-$suffix';
    }
    return candidate;
  }

  void _validateChoiceInitialValues(DailyRoutineModel model) {
    for (final field in model.sections.expand((section) => section.fields)) {
      if (field.initialValue == null) continue;
      final valid = switch (field.type) {
        DailyRoutineFieldType.singleChoice =>
          field.initialValue is String && field.options.contains(field.initialValue),
        DailyRoutineFieldType.multipleChoice =>
          field.initialValue is Iterable &&
              (field.initialValue! as Iterable).every(field.options.contains),
        _ => true,
      };
      if (!valid) {
        throw ArgumentError.value(
          field.initialValue,
          'initialValue',
          'O valor inicial deve ser uma das opções cadastradas.',
        );
      }
    }
  }
}
