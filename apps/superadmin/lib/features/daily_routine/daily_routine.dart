import 'dart:collection';

export 'domain/routine_contract.dart';

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

final class DailyRoutineFieldOption {
  const DailyRoutineFieldOption({required this.id, required this.label, required this.sortOrder});
  final String id;
  final String label;
  final int sortOrder;
}

abstract final class DailyRoutineDirectoryState {}

enum DailyRoutineDirectoryStatus {
  loading,
  data,
  empty,
  noResults,
  failure,
  unauthorized,
  notFound,
  conflict,
}
