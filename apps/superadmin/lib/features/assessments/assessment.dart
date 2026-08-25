import 'package:flutter/foundation.dart';

enum AssessmentScaleKind { numeric0To10, numeric0To100, concept, numeric1To5, binary, stars0To5 }

enum AssessmentStudentState { notStarted, pending, complete, absent }

enum AssessmentGradebookStatus { draft, submitted, reviewed, published }

enum AssessmentClosingAction { review, returnToTeacher, publish }

@immutable
final class AssessmentContext {
  const AssessmentContext({
    required this.activityGroupLinkId,
    required this.institutionId,
    required this.institutionName,
    required this.unitId,
    required this.unitName,
    required this.groupId,
    required this.groupName,
    required this.activityId,
    required this.activityName,
    required this.periodId,
    required this.periodName,
  });
  const AssessmentContext.sample()
    : activityGroupLinkId = 'link-1',
      institutionId = 'institution-1',
      institutionName = 'Colégio Horizonte',
      unitId = 'unit-1',
      unitName = 'Unidade Centro',
      groupId = 'group-1',
      groupName = '2º ano A',
      activityId = 'activity-1',
      activityName = 'Inglês',
      periodId = 'period-1',
      periodName = '2º bimestre de 2027';
  final String activityGroupLinkId,
      institutionId,
      institutionName,
      unitId,
      unitName,
      groupId,
      groupName,
      activityId,
      activityName,
      periodId,
      periodName;
}

@immutable
final class AssessmentPeriodOption {
  const AssessmentPeriodOption({
    required this.id,
    required this.name,
    required this.status,
    this.institutionId,
    this.unitId,
  });
  final String id, name, status;
  final String? institutionId, unitId;
  bool get isOpen => status == 'open';
}

@immutable
final class AssessmentContextOptions {
  const AssessmentContextOptions({required this.assignments, required this.periods});
  final List<AssessmentContext> assignments;
  final List<AssessmentPeriodOption> periods;
  bool get isEmpty => assignments.isEmpty;
}

@immutable
final class AssessmentInstrument {
  const AssessmentInstrument({
    required this.id,
    required this.name,
    required this.weight,
    required this.sortOrder,
  });
  final String id, name;
  final double weight;
  final int sortOrder;
}

@immutable
final class AssessmentCompetency {
  const AssessmentCompetency({required this.id, required this.name, required this.category});
  final String id, name, category;
}

@immutable
final class AssessmentConfiguredPeriod {
  const AssessmentConfiguredPeriod({
    required this.id,
    required this.name,
    required this.ordinal,
    required this.academicYear,
    required this.startsOn,
    required this.endsOn,
    required this.entryClosesAt,
    required this.familyReleaseAt,
    this.timezone,
    this.status = 'draft',
  });

  final String id, name, status;
  final String? timezone;
  final int ordinal, academicYear;
  final DateTime startsOn, endsOn, entryClosesAt, familyReleaseAt;

  AssessmentConfiguredPeriod copyWith({
    String? name,
    int? ordinal,
    int? academicYear,
    DateTime? startsOn,
    DateTime? endsOn,
    DateTime? entryClosesAt,
    DateTime? familyReleaseAt,
  }) => AssessmentConfiguredPeriod(
    id: id,
    name: name ?? this.name,
    ordinal: ordinal ?? this.ordinal,
    academicYear: academicYear ?? this.academicYear,
    startsOn: startsOn ?? this.startsOn,
    endsOn: endsOn ?? this.endsOn,
    entryClosesAt: entryClosesAt ?? this.entryClosesAt,
    familyReleaseAt: familyReleaseAt ?? this.familyReleaseAt,
    timezone: timezone,
    status: status,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'ordinal': ordinal,
    'academic_year': academicYear,
    'starts_on': _date(startsOn),
    'ends_on': _date(endsOn),
    'entry_closes_at': entryClosesAt.toIso8601String(),
    'family_release_at': familyReleaseAt.toIso8601String(),
    if (timezone != null) 'timezone': timezone,
    'status': status,
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

@immutable
final class AssessmentConfiguration {
  const AssessmentConfiguration({
    required this.id,
    required this.activityId,
    required this.institutionId,
    required this.periodicity,
    required this.scaleKind,
    required this.version,
    required this.status,
    required this.instruments,
    required this.competencies,
    this.unitId,
    this.allowFinalOverride = false,
    this.concepts = const [],
    this.numericStep = 0.01,
    this.availableCompetencies = const [],
    this.periods = const [],
  });
  final String id, activityId, institutionId, periodicity, status;
  final String? unitId;
  final AssessmentScaleKind scaleKind;
  final int version;
  final bool allowFinalOverride;
  final List<String> concepts;
  final double numericStep;
  final List<AssessmentInstrument> instruments;
  final List<AssessmentCompetency> competencies;
  final List<AssessmentCompetency> availableCompetencies;
  final List<AssessmentConfiguredPeriod> periods;
  bool get isActive => status == 'active';
  double get totalWeight => instruments.fold(0, (sum, item) => sum + item.weight);
  AssessmentConfiguration copyWith({
    String? id,
    int? version,
    String? status,
    String? periodicity,
    AssessmentScaleKind? scaleKind,
    List<AssessmentInstrument>? instruments,
    List<AssessmentCompetency>? competencies,
    List<String>? concepts,
    double? numericStep,
    List<AssessmentConfiguredPeriod>? periods,
  }) => AssessmentConfiguration(
    id: id ?? this.id,
    activityId: activityId,
    institutionId: institutionId,
    periodicity: periodicity ?? this.periodicity,
    scaleKind: scaleKind ?? this.scaleKind,
    version: version ?? this.version,
    status: status ?? this.status,
    instruments: instruments ?? this.instruments,
    competencies: competencies ?? this.competencies,
    availableCompetencies: availableCompetencies,
    periods: periods ?? this.periods,
    unitId: unitId,
    allowFinalOverride: allowFinalOverride,
    concepts: concepts ?? this.concepts,
    numericStep: numericStep ?? this.numericStep,
  );
}

@immutable
final class AssessmentInstrumentEntry {
  const AssessmentInstrumentEntry({
    required this.instrumentId,
    this.numericValue,
    this.conceptCode,
    this.booleanValue,
    this.absent = false,
  });
  final String instrumentId;
  final double? numericValue;
  final String? conceptCode;
  final bool? booleanValue;
  final bool absent;
  Map<String, Object?> toJson() => {
    'instrument_id': instrumentId,
    'numeric_value': numericValue,
    'concept_code': conceptCode,
    'boolean_value': booleanValue,
    'absent': absent,
  };
}

@immutable
final class AssessmentCompetencyEntry {
  const AssessmentCompetencyEntry({required this.competencyId, required this.score});
  final String competencyId;
  final double score;
  Map<String, Object?> toJson() => {'competency_id': competencyId, 'score': score};
}

@immutable
final class AssessmentStudentEntry {
  const AssessmentStudentEntry({
    required this.id,
    required this.childContextId,
    required this.name,
    this.state = AssessmentStudentState.notStarted,
    this.suggestedScore,
    this.finalNumericValue,
    this.finalConceptCode,
    this.finalBooleanValue,
    this.overrideReason = '',
    this.familyComment = '',
    this.internalNote = '',
    this.instruments = const [],
    this.competencies = const [],
  });
  final String id, childContextId, name;
  final AssessmentStudentState state;
  final double? suggestedScore, finalNumericValue;
  final String? finalConceptCode;
  final bool? finalBooleanValue;
  final String overrideReason, familyComment, internalNote;
  final List<AssessmentInstrumentEntry> instruments;
  final List<AssessmentCompetencyEntry> competencies;
  bool get isResolved =>
      state == AssessmentStudentState.complete || state == AssessmentStudentState.absent;
  AssessmentStudentEntry copyWith({
    AssessmentStudentState? state,
    double? suggestedScore,
    double? finalNumericValue,
    String? finalConceptCode,
    bool? finalBooleanValue,
    String? overrideReason,
    bool clearFinalNumericValue = false,
    bool clearFinalConceptCode = false,
    bool clearFinalBooleanValue = false,
    String? familyComment,
    String? internalNote,
    List<AssessmentInstrumentEntry>? instruments,
    List<AssessmentCompetencyEntry>? competencies,
  }) => AssessmentStudentEntry(
    id: id,
    childContextId: childContextId,
    name: name,
    state: state ?? this.state,
    suggestedScore: suggestedScore ?? this.suggestedScore,
    finalNumericValue: clearFinalNumericValue ? null : finalNumericValue ?? this.finalNumericValue,
    finalConceptCode: clearFinalConceptCode ? null : finalConceptCode ?? this.finalConceptCode,
    finalBooleanValue: clearFinalBooleanValue ? null : finalBooleanValue ?? this.finalBooleanValue,
    overrideReason: overrideReason ?? this.overrideReason,
    familyComment: familyComment ?? this.familyComment,
    internalNote: internalNote ?? this.internalNote,
    instruments: instruments ?? this.instruments,
    competencies: competencies ?? this.competencies,
  );
  Map<String, Object?> toJson() => {
    'child_context_id': childContextId,
    'state': state.name == 'notStarted' ? 'not_started' : state.name,
    'final_numeric_value': finalNumericValue,
    'final_concept_code': finalConceptCode,
    'final_boolean_value': finalBooleanValue,
    'override_reason': overrideReason,
    'family_comment': familyComment,
    'internal_note': internalNote,
    'instruments': instruments.map((item) => item.toJson()).toList(),
    'competencies': competencies.map((item) => item.toJson()).toList(),
  };
}

@immutable
final class AssessmentGradebookEvent {
  const AssessmentGradebookEvent({
    required this.id,
    required this.kind,
    required this.actorPersonId,
    required this.version,
    required this.createdAt,
    this.reason = '',
  });

  final String id, kind, actorPersonId, reason;
  final int version;
  final DateTime createdAt;
}

@immutable
final class AssessmentGradebook {
  const AssessmentGradebook({
    required this.id,
    required this.version,
    required this.status,
    required this.context,
    required this.students,
    this.configuration,
    this.familyReleaseAt,
    this.publishScheduledAt,
    this.publishedAt,
    this.events = const [],
  });
  final String id;
  final int version;
  final AssessmentGradebookStatus status;
  final AssessmentContext context;
  final AssessmentConfiguration? configuration;
  final DateTime? familyReleaseAt;
  final DateTime? publishScheduledAt;
  final DateTime? publishedAt;
  final List<AssessmentStudentEntry> students;
  final List<AssessmentGradebookEvent> events;
  int get resolvedCount => students.where((item) => item.isResolved).length;
  bool get hasPending => students.any((item) => !item.isResolved);
  AssessmentGradebook copyWith({
    int? version,
    AssessmentGradebookStatus? status,
    List<AssessmentStudentEntry>? students,
    DateTime? familyReleaseAt,
    DateTime? publishScheduledAt,
    DateTime? publishedAt,
    List<AssessmentGradebookEvent>? events,
  }) => AssessmentGradebook(
    id: id,
    version: version ?? this.version,
    status: status ?? this.status,
    context: context,
    students: students ?? this.students,
    configuration: configuration,
    familyReleaseAt: familyReleaseAt ?? this.familyReleaseAt,
    publishScheduledAt: publishScheduledAt ?? this.publishScheduledAt,
    publishedAt: publishedAt ?? this.publishedAt,
    events: events ?? this.events,
  );
  Map<String, Object?> toPayload() => {
    'activity_group_link_id': context.activityGroupLinkId,
    'period_id': context.periodId,
    'configuration_id': configuration?.id,
    'students': students.map((item) => item.toJson()).toList(),
  };
}

@immutable
final class AssessmentClosingItem {
  const AssessmentClosingItem({
    required this.id,
    required this.status,
    required this.version,
    required this.institutionName,
    required this.unitName,
    required this.groupName,
    required this.activityName,
    required this.periodName,
    required this.pendingCount,
  });
  final String id, institutionName, unitName, groupName, activityName, periodName;
  final AssessmentGradebookStatus status;
  final int version, pendingCount;
}

abstract interface class AssessmentRepository {
  Future<AssessmentContextOptions> fetchContextOptions();
  Future<AssessmentConfiguration?> fetchConfiguration(String activityId, {String? unitId});
  Future<AssessmentGradebook> createOrResumeGradebook(
    AssessmentContext context,
    AssessmentConfiguration configuration,
  );
  Future<AssessmentGradebook?> fetchGradebook(String id);
  Future<List<AssessmentClosingItem>> fetchClosingQueue();
  Future<AssessmentConfiguration> saveConfiguration(AssessmentConfiguration value);
  Future<AssessmentConfiguration> activateConfiguration(AssessmentConfiguration value);
  Future<AssessmentGradebook> saveGradebook(AssessmentGradebook value, {String? reason});
  Future<AssessmentGradebook> submitGradebook(AssessmentGradebook value);
  Future<AssessmentGradebook> transitionGradebook(
    AssessmentGradebook value,
    AssessmentClosingAction action,
    String reason,
  );
  Future<AssessmentGradebook> schedulePublication(
    AssessmentGradebook value,
    DateTime publishAt,
    String reason,
  );
}

final class AssessmentUnauthorizedException implements Exception {
  const AssessmentUnauthorizedException();
}

final class AssessmentVersionConflictException implements Exception {
  const AssessmentVersionConflictException();
}

final class AssessmentOfflineException implements Exception {
  const AssessmentOfflineException();
}

final class UnavailableAssessmentRepository implements AssessmentRepository {
  const UnavailableAssessmentRepository();
  Never _fail() => throw const AssessmentOfflineException();
  @override
  Future<AssessmentContextOptions> fetchContextOptions() async => _fail();
  @override
  Future<AssessmentConfiguration?> fetchConfiguration(String activityId, {String? unitId}) async =>
      _fail();
  @override
  Future<AssessmentGradebook> createOrResumeGradebook(
    AssessmentContext context,
    AssessmentConfiguration configuration,
  ) async => _fail();
  @override
  Future<AssessmentGradebook?> fetchGradebook(String id) async => _fail();
  @override
  Future<List<AssessmentClosingItem>> fetchClosingQueue() async => _fail();
  @override
  Future<AssessmentConfiguration> saveConfiguration(AssessmentConfiguration value) async => _fail();
  @override
  Future<AssessmentConfiguration> activateConfiguration(AssessmentConfiguration value) async =>
      _fail();
  @override
  Future<AssessmentGradebook> saveGradebook(AssessmentGradebook value, {String? reason}) async =>
      _fail();
  @override
  Future<AssessmentGradebook> submitGradebook(AssessmentGradebook value) async => _fail();
  @override
  Future<AssessmentGradebook> transitionGradebook(
    AssessmentGradebook value,
    AssessmentClosingAction action,
    String reason,
  ) async => _fail();
  @override
  Future<AssessmentGradebook> schedulePublication(
    AssessmentGradebook value,
    DateTime publishAt,
    String reason,
  ) async => _fail();
}
