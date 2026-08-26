enum ActivityAssessmentModel { none, gradeOnly, competenciesOnly, gradeAndCompetencies }

enum ActivityAssessmentPeriodicity { bimonthly, trimester, semester, annual }

enum ActivityGradeScale { numeric0To10, numeric0To100, concepts, binary, stars0To5 }

enum ActivityCompetencyScale { oneToFive }

enum ActivityRecoveryRule { none, replaceLowestInstrument, keepHigher, averageOriginalAndRecovery }

enum ActivityAssessmentPeriodStatus { planned, open, closed, published }

enum ActivityAssessmentInstrumentKind {
  exam,
  project,
  participation,
  presentation,
  assignment,
  custom,
}

final class ActivityAssessmentPeriodDraft {
  const ActivityAssessmentPeriodDraft({
    required this.name,
    required this.order,
    required this.startsOn,
    required this.endsOn,
    required this.timezone,
    this.entryDeadlineAt,
    this.familyReleaseAt,
    this.status = ActivityAssessmentPeriodStatus.planned,
  });

  final String name;
  final int order;
  final DateTime startsOn;
  final DateTime endsOn;
  final DateTime? entryDeadlineAt;
  final DateTime? familyReleaseAt;
  final String timezone;
  final ActivityAssessmentPeriodStatus status;

  List<String> get validationErrors {
    final errors = <String>[];
    if (name.trim().isEmpty || order < 1) errors.add('period_identity');
    final deadline = entryDeadlineAt;
    final release = familyReleaseAt;
    if (deadline == null || release == null) {
      errors.add('period_schedule_required');
    } else if (endsOn.isBefore(startsOn) ||
        deadline.isBefore(endsOn) ||
        release.isBefore(deadline)) {
      errors.add('period_date_order');
    }
    if (timezone.trim().isEmpty) errors.add('period_timezone_required');
    return errors;
  }

  ActivityAssessmentPeriodDraft copyWith({
    String? name,
    int? order,
    DateTime? startsOn,
    DateTime? endsOn,
    DateTime? entryDeadlineAt,
    DateTime? familyReleaseAt,
    String? timezone,
    ActivityAssessmentPeriodStatus? status,
  }) => ActivityAssessmentPeriodDraft(
    name: name ?? this.name,
    order: order ?? this.order,
    startsOn: startsOn ?? this.startsOn,
    endsOn: endsOn ?? this.endsOn,
    entryDeadlineAt: entryDeadlineAt ?? this.entryDeadlineAt,
    familyReleaseAt: familyReleaseAt ?? this.familyReleaseAt,
    timezone: timezone ?? this.timezone,
    status: status ?? this.status,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'order': order,
    'starts_on': _date(startsOn),
    'ends_on': _date(endsOn),
    'entry_deadline_at': entryDeadlineAt?.toIso8601String(),
    'family_release_at': familyReleaseAt?.toIso8601String(),
    'timezone': timezone,
    'status': status.name,
  };

  factory ActivityAssessmentPeriodDraft.fromJson(Map<String, dynamic> json) =>
      ActivityAssessmentPeriodDraft(
        name: json['name'] as String,
        order: (json['order'] as num).toInt(),
        startsOn: DateTime.parse(json['starts_on'] as String),
        endsOn: DateTime.parse(json['ends_on'] as String),
        entryDeadlineAt: _nullableDateTime(json['entry_deadline_at']),
        familyReleaseAt: _nullableDateTime(json['family_release_at']),
        timezone: json['timezone'] as String,
        status: ActivityAssessmentPeriodStatus.values.byName(
          json['status'] as String? ?? ActivityAssessmentPeriodStatus.planned.name,
        ),
      );
}

final class ActivityAssessmentInstrumentDraft {
  const ActivityAssessmentInstrumentDraft({
    required this.clientId,
    required this.name,
    required this.kind,
    required this.weight,
    required this.order,
    this.archived = false,
  });

  final String clientId;
  final String name;
  final ActivityAssessmentInstrumentKind kind;
  final double weight;
  final int order;
  final bool archived;

  ActivityAssessmentInstrumentDraft copyWith({
    String? clientId,
    String? name,
    ActivityAssessmentInstrumentKind? kind,
    double? weight,
    int? order,
    bool? archived,
  }) => ActivityAssessmentInstrumentDraft(
    clientId: clientId ?? this.clientId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    weight: weight ?? this.weight,
    order: order ?? this.order,
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toJson() => {
    'client_id': clientId,
    'name': name,
    'kind': kind.name,
    'weight': weight,
    'order': order,
    'archived': archived,
  };

  factory ActivityAssessmentInstrumentDraft.fromJson(Map<String, dynamic> json) =>
      ActivityAssessmentInstrumentDraft(
        clientId: json['client_id'] as String,
        name: json['name'] as String,
        kind: ActivityAssessmentInstrumentKind.values.byName(json['kind'] as String),
        weight: (json['weight'] as num).toDouble(),
        order: (json['order'] as num).toInt(),
        archived: json['archived'] as bool? ?? false,
      );
}

final class ActivityAssessmentCompetencyDraft {
  const ActivityAssessmentCompetencyDraft({
    required this.clientId,
    required this.name,
    required this.order,
    required this.taxonomyVersionId,
  });

  final String clientId;
  final String name;
  final int order;
  final String taxonomyVersionId;

  Map<String, Object?> toJson() => {
    'client_id': clientId,
    'name': name,
    'order': order,
    'taxonomy_version_id': taxonomyVersionId,
  };

  factory ActivityAssessmentCompetencyDraft.fromJson(Map<String, dynamic> json) =>
      ActivityAssessmentCompetencyDraft(
        clientId: json['client_id'] as String,
        name: json['name'] as String,
        order: (json['order'] as num).toInt(),
        taxonomyVersionId: json['taxonomy_version_id'] as String,
      );
}

final class ActivityAssessmentCategoryDraft {
  const ActivityAssessmentCategoryDraft({
    required this.clientId,
    required this.name,
    required this.order,
    required this.taxonomyVersionId,
    required this.competencies,
  });

  final String clientId;
  final String name;
  final int order;
  final String taxonomyVersionId;
  final List<ActivityAssessmentCompetencyDraft> competencies;

  ActivityAssessmentCategoryDraft copyWith({
    String? clientId,
    String? name,
    int? order,
    String? taxonomyVersionId,
    List<ActivityAssessmentCompetencyDraft>? competencies,
  }) => ActivityAssessmentCategoryDraft(
    clientId: clientId ?? this.clientId,
    name: name ?? this.name,
    order: order ?? this.order,
    taxonomyVersionId: taxonomyVersionId ?? this.taxonomyVersionId,
    competencies: competencies ?? this.competencies,
  );

  Map<String, Object?> toJson() => {
    'client_id': clientId,
    'name': name,
    'order': order,
    'taxonomy_version_id': taxonomyVersionId,
    'competencies': competencies.map((item) => item.toJson()).toList(growable: false),
  };

  factory ActivityAssessmentCategoryDraft.fromJson(Map<String, dynamic> json) =>
      ActivityAssessmentCategoryDraft(
        clientId: json['client_id'] as String,
        name: json['name'] as String,
        order: (json['order'] as num).toInt(),
        taxonomyVersionId: json['taxonomy_version_id'] as String,
        competencies: _maps(
          json['competencies'],
        ).map(ActivityAssessmentCompetencyDraft.fromJson).toList(growable: false),
      );
}

final class ActivityPedagogicalConfigurationDraft {
  const ActivityPedagogicalConfigurationDraft({
    required this.enabled,
    this.model = ActivityAssessmentModel.none,
    this.periodicity,
    this.validityStart,
    this.validityEnd,
    this.timezone = 'America/Sao_Paulo',
    this.gradeScale,
    this.competencyScale,
    this.conceptLevels = const [],
    this.periods = const [],
    this.instruments = const [],
    this.taxonomyVersionId,
    this.categories = const [],
    this.recoveryRule = ActivityRecoveryRule.none,
    this.templateId,
    this.templateVersion,
    this.expectedVersion,
    this.usedByResults = false,
    this.changeJustification = '',
  });

  const ActivityPedagogicalConfigurationDraft.disabled() : this(enabled: false);

  final bool enabled;
  final ActivityAssessmentModel model;
  final ActivityAssessmentPeriodicity? periodicity;
  final DateTime? validityStart;
  final DateTime? validityEnd;
  final String timezone;
  final ActivityGradeScale? gradeScale;
  final ActivityCompetencyScale? competencyScale;
  final List<String> conceptLevels;
  final List<ActivityAssessmentPeriodDraft> periods;
  final List<ActivityAssessmentInstrumentDraft> instruments;
  final String? taxonomyVersionId;
  final List<ActivityAssessmentCategoryDraft> categories;
  final ActivityRecoveryRule recoveryRule;
  final String? templateId;
  final int? templateVersion;
  final int? expectedVersion;
  final bool usedByResults;
  final String changeJustification;

  bool get usesGrades =>
      enabled &&
      (model == ActivityAssessmentModel.gradeOnly ||
          model == ActivityAssessmentModel.gradeAndCompetencies);
  bool get usesCompetencies =>
      enabled &&
      (model == ActivityAssessmentModel.competenciesOnly ||
          model == ActivityAssessmentModel.gradeAndCompetencies);
  bool get hasNumericGradeScale =>
      gradeScale == ActivityGradeScale.numeric0To10 ||
      gradeScale == ActivityGradeScale.numeric0To100;
  double get totalInstrumentWeight =>
      instruments.where((item) => !item.archived).fold(0, (sum, item) => sum + item.weight);

  List<String> get validationErrors {
    if (!enabled) return const [];
    final errors = <String>[];
    if (model == ActivityAssessmentModel.none) errors.add('assessment_model_required');
    if (periodicity == null || validityStart == null || validityEnd == null) {
      errors.add('assessment_validity_required');
    } else if (validityEnd!.isBefore(validityStart!)) {
      errors.add('assessment_validity_order');
    }
    if (timezone.trim().isEmpty) errors.add('assessment_timezone_required');
    if (periods.isEmpty) errors.add('assessment_periods_required');
    for (final period in periods) {
      errors.addAll(period.validationErrors);
    }
    if (usesGrades) {
      if (gradeScale == null) errors.add('grade_scale_required');
      if (gradeScale == ActivityGradeScale.concepts && conceptLevels.isEmpty) {
        errors.add('concept_levels_required');
      }
      if (instruments.isEmpty) errors.add('instruments_required');
      if (instruments.any(
        (item) =>
            item.name.trim().isEmpty || item.order < 1 || item.weight <= 0 || item.weight > 100,
      )) {
        errors.add('instrument_weight_range');
      }
      if ((totalInstrumentWeight - 100).abs() > 0.000001) {
        errors.add('instrument_weights_total');
      }
      if (recoveryRule != ActivityRecoveryRule.none && !hasNumericGradeScale) {
        errors.add('recovery_requires_numeric_scale');
      }
    } else if (recoveryRule != ActivityRecoveryRule.none) {
      errors.add('recovery_requires_numeric_scale');
    }
    if (usesCompetencies) {
      if (competencyScale != ActivityCompetencyScale.oneToFive) {
        errors.add('competency_scale_required');
      }
      if (taxonomyVersionId == null || categories.isEmpty) {
        errors.add('taxonomy_required');
      }
      final versions = <String>{
        ?taxonomyVersionId,
        for (final category in categories) category.taxonomyVersionId,
        for (final category in categories)
          for (final competency in category.competencies) competency.taxonomyVersionId,
      };
      if (versions.length > 1) errors.add('mixed_taxonomy_versions');
    }
    if (usedByResults && changeJustification.trim().isEmpty) {
      errors.add('change_justification_required');
    }
    return List.unmodifiable(errors.toSet());
  }

  bool get isValid => validationErrors.isEmpty;

  ActivityPedagogicalConfigurationDraft copyWith({
    bool? enabled,
    ActivityAssessmentModel? model,
    ActivityAssessmentPeriodicity? periodicity,
    DateTime? validityStart,
    DateTime? validityEnd,
    String? timezone,
    ActivityGradeScale? gradeScale,
    ActivityCompetencyScale? competencyScale,
    List<String>? conceptLevels,
    List<ActivityAssessmentPeriodDraft>? periods,
    List<ActivityAssessmentInstrumentDraft>? instruments,
    String? taxonomyVersionId,
    List<ActivityAssessmentCategoryDraft>? categories,
    ActivityRecoveryRule? recoveryRule,
    String? templateId,
    int? templateVersion,
    int? expectedVersion,
    bool? usedByResults,
    String? changeJustification,
  }) => ActivityPedagogicalConfigurationDraft(
    enabled: enabled ?? this.enabled,
    model: model ?? this.model,
    periodicity: periodicity ?? this.periodicity,
    validityStart: validityStart ?? this.validityStart,
    validityEnd: validityEnd ?? this.validityEnd,
    timezone: timezone ?? this.timezone,
    gradeScale: gradeScale ?? this.gradeScale,
    competencyScale: competencyScale ?? this.competencyScale,
    conceptLevels: conceptLevels ?? this.conceptLevels,
    periods: periods ?? this.periods,
    instruments: instruments ?? this.instruments,
    taxonomyVersionId: taxonomyVersionId ?? this.taxonomyVersionId,
    categories: categories ?? this.categories,
    recoveryRule: recoveryRule ?? this.recoveryRule,
    templateId: templateId ?? this.templateId,
    templateVersion: templateVersion ?? this.templateVersion,
    expectedVersion: expectedVersion ?? this.expectedVersion,
    usedByResults: usedByResults ?? this.usedByResults,
    changeJustification: changeJustification ?? this.changeJustification,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'model': model.name,
    'periodicity': periodicity?.name,
    'validity_start': validityStart == null ? null : _date(validityStart!),
    'validity_end': validityEnd == null ? null : _date(validityEnd!),
    'timezone': timezone,
    'grade_scale': gradeScale?.name,
    'competency_scale': competencyScale?.name,
    'concept_levels': conceptLevels,
    'periods': periods.map((item) => item.toJson()).toList(growable: false),
    'instruments': instruments.map((item) => item.toJson()).toList(growable: false),
    'taxonomy_version_id': taxonomyVersionId,
    'categories': categories.map((item) => item.toJson()).toList(growable: false),
    'recovery_rule': recoveryRule.name,
    'template_id': templateId,
    'template_version': templateVersion,
    'expected_version': expectedVersion,
    'used_by_results': usedByResults,
    'change_justification': changeJustification,
  };

  factory ActivityPedagogicalConfigurationDraft.fromJson(Map<String, dynamic> json) =>
      ActivityPedagogicalConfigurationDraft(
        enabled: json['enabled'] as bool? ?? false,
        model: ActivityAssessmentModel.values.byName(
          json['model'] as String? ?? ActivityAssessmentModel.none.name,
        ),
        periodicity: _enumOrNull(ActivityAssessmentPeriodicity.values, json['periodicity']),
        validityStart: _nullableDateTime(json['validity_start']),
        validityEnd: _nullableDateTime(json['validity_end']),
        timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
        gradeScale: _enumOrNull(ActivityGradeScale.values, json['grade_scale']),
        competencyScale: _enumOrNull(ActivityCompetencyScale.values, json['competency_scale']),
        conceptLevels: (json['concept_levels'] as List? ?? const []).cast<String>(),
        periods: _maps(
          json['periods'],
        ).map(ActivityAssessmentPeriodDraft.fromJson).toList(growable: false),
        instruments: _maps(
          json['instruments'],
        ).map(ActivityAssessmentInstrumentDraft.fromJson).toList(growable: false),
        taxonomyVersionId: json['taxonomy_version_id'] as String?,
        categories: _maps(
          json['categories'],
        ).map(ActivityAssessmentCategoryDraft.fromJson).toList(growable: false),
        recoveryRule: ActivityRecoveryRule.values.byName(
          json['recovery_rule'] as String? ?? ActivityRecoveryRule.none.name,
        ),
        templateId: json['template_id'] as String?,
        templateVersion: (json['template_version'] as num?)?.toInt(),
        expectedVersion: (json['expected_version'] as num?)?.toInt(),
        usedByResults: json['used_by_results'] as bool? ?? false,
        changeJustification: json['change_justification'] as String? ?? '',
      );

  static List<ActivityAssessmentPeriodDraft> suggestPeriods({
    required ActivityAssessmentPeriodicity periodicity,
    required DateTime validityStart,
    required DateTime validityEnd,
    required String timezone,
  }) {
    if (validityEnd.isBefore(validityStart)) return const [];
    final count = switch (periodicity) {
      ActivityAssessmentPeriodicity.bimonthly => 4,
      ActivityAssessmentPeriodicity.trimester => 3,
      ActivityAssessmentPeriodicity.semester => 2,
      ActivityAssessmentPeriodicity.annual => 1,
    };
    final totalDays = validityEnd.difference(validityStart).inDays + 1;
    return List.generate(count, (index) {
      final startOffset = (totalDays * index) ~/ count;
      final nextOffset = (totalDays * (index + 1)) ~/ count;
      return ActivityAssessmentPeriodDraft(
        name: count == 1 ? 'Período anual' : '${index + 1}º período',
        order: index + 1,
        startsOn: validityStart.add(Duration(days: startOffset)),
        endsOn: validityStart.add(Duration(days: nextOffset - 1)),
        timezone: timezone,
      );
    }, growable: false);
  }
}

String _date(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

DateTime? _nullableDateTime(Object? value) =>
    value is String && value.isNotEmpty ? DateTime.parse(value) : null;

List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();

T? _enumOrNull<T extends Enum>(List<T> values, Object? name) =>
    name is String ? values.where((value) => value.name == name).firstOrNull : null;
