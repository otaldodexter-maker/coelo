enum MealPlanStatus { draft, inReview, scheduled, published, updated, ended, archived }

enum MealPlanSourceType { global, institution, unit, classLevel, person, exception }

enum MealPlanScopeLevel { global, institution, unit, classLevel, activity, person }

enum MealPlanRecurrenceKind {
  singleWeek,
  interval,
  daily,
  weekly,
  biweekly,
  cycleWeeks,
  specificDates,
}

enum MealPlanConflictType { overlap, sourceOverride, schedulePriority }

enum MealPlanConflictAction { reject, rewrite, prioritize }

enum MealPlanPlanVariant { simple, complete }

enum MealPlanAudienceSegment { students, staff, all }

enum MealPlanVisibilityMode { immediate, scheduled }

enum MealPlanMealScheduleKind { weekdays, specificDates }

final class MealPlanListFilter {
  const MealPlanListFilter({
    this.search,
    this.institutionId,
    this.unitId,
    this.classId,
    this.personId,
    this.periodStart,
    this.periodEnd,
    this.statuses = const {},
    this.sources = const {},
    this.hasConflict,
    this.requiresReview,
    this.page = 0,
    this.pageSize = 12,
  }) : assert(page >= 0),
       assert(pageSize > 0 && pageSize <= 100);
  final String? search, institutionId, unitId, classId, personId;
  final DateTime? periodStart, periodEnd;
  final Set<MealPlanStatus> statuses;
  final Set<MealPlanSourceType> sources;
  final bool? hasConflict, requiresReview;
  final int page, pageSize;
  int get offset => page * pageSize;
  Map<String, Object?> toJson() => {
    'search': search,
    'institutionId': institutionId,
    'unitId': unitId,
    'classId': classId,
    'personId': personId,
    'periodStart': periodStart?.toIso8601String(),
    'periodEnd': periodEnd?.toIso8601String(),
    'statuses': statuses.map((v) => v.name).toList(),
    'sources': sources.map((v) => v.name).toList(),
    'hasConflict': hasConflict,
    'requiresReview': requiresReview,
    'page': page,
    'pageSize': pageSize,
  };
}

final class MealPlanPage {
  const MealPlanPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });
  final List<MealPlan> items;
  final int total, limit, offset;
}

final class MealPlanAttachmentMeta {
  const MealPlanAttachmentMeta({required this.kind, required this.title, required this.reference});
  factory MealPlanAttachmentMeta.fromJson(Map<String, Object?> j) => MealPlanAttachmentMeta(
    kind: (j['kind'] as String?) ?? 'document',
    title: (j['title'] as String?) ?? '',
    reference: (j['reference'] as String?) ?? '',
  );
  final String kind, title, reference;
  Map<String, Object?> toJson() => {'kind': kind, 'title': title, 'reference': reference};
}

final class MealPlanRecurrence {
  MealPlanRecurrence({
    required this.kind,
    this.intervalWeeks,
    this.singleWeekStart,
    this.singleWeekEnd,
    this.cycleWeeks,
    this.weekdays = const {},
    this.specificDates = const [],
    this.excludedDates = const [],
  });
  factory MealPlanRecurrence.fromJson(Map<String, Object?> j) => MealPlanRecurrence(
    kind: _enumByName(MealPlanRecurrenceKind.values, j['kind'], MealPlanRecurrenceKind.singleWeek),
    intervalWeeks: _int(j['intervalWeeks']),
    singleWeekStart: _dateOrNull(j['singleWeekStart']),
    singleWeekEnd: _dateOrNull(j['singleWeekEnd']),
    cycleWeeks: _int(j['cycleWeeks']),
    weekdays: _list(j['weekdays']).map((v) => _int(v) ?? 1).toSet(),
    specificDates: _dateList(j['specificDates']),
    excludedDates: _dateList(j['excludedDates']),
  );
  final MealPlanRecurrenceKind kind;
  final int? intervalWeeks, cycleWeeks;
  final DateTime? singleWeekStart, singleWeekEnd;
  final Set<int> weekdays;
  final List<DateTime> specificDates, excludedDates;
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'intervalWeeks': intervalWeeks,
    'singleWeekStart': _dateValue(singleWeekStart),
    'singleWeekEnd': _dateValue(singleWeekEnd),
    'cycleWeeks': cycleWeeks,
    'weekdays': weekdays.toList()..sort(),
    'specificDates': specificDates.map(_dateValue).toList(),
    'excludedDates': excludedDates.map(_dateValue).toList(),
  };
}

final class MealPlanMenuEntry {
  MealPlanMenuEntry({
    required this.mealType,
    this.dayContents = const ['', '', '', '', '', '', ''],
    this.customMealType,
    this.hasTime = false,
    this.startTime,
    this.endTime,
    this.dishName = '',
    this.details,
    this.hasNutrition = false,
    this.portionGrams,
    this.energyKcal,
    this.proteinG,
    this.carbohydrateG,
    this.fatG,
    this.restrictions = const [],
    this.image,
    this.scheduleKind = MealPlanMealScheduleKind.weekdays,
    this.weekdays = const {},
    this.specificDates = const [],
  }) : assert(dayContents.length == 7);
  factory MealPlanMenuEntry.empty() => MealPlanMenuEntry(mealType: 'lunch');
  factory MealPlanMenuEntry.fromJson(Map<String, Object?> j) => MealPlanMenuEntry(
    mealType: (j['mealType'] as String?) ?? '',
    dayContents: List<String>.generate(7, (i) {
      final values = j['dayContents'];
      return values is List && i < values.length ? values[i]?.toString() ?? '' : '';
    }),
    customMealType: j['customMealType'] as String?,
    hasTime: _bool(j['hasTime']) ?? false,
    startTime: j['startTime'] as String?,
    endTime: j['endTime'] as String?,
    dishName: (j['dishName'] as String?) ?? '',
    details: j['details'] as String?,
    hasNutrition: _bool(j['hasNutrition']) ?? false,
    portionGrams: _double(j['portionGrams']),
    energyKcal: _double(j['energyKcal']),
    proteinG: _double(j['proteinG']),
    carbohydrateG: _double(j['carbohydrateG']),
    fatG: _double(j['fatG']),
    restrictions: _list(j['restrictions']).map((v) => v.toString()).toList(),
    image: j['image'] is Map ? MealPlanAttachmentMeta.fromJson(_map(j['image'])) : null,
    scheduleKind: _enumByName(
      MealPlanMealScheduleKind.values,
      j['scheduleKind'],
      MealPlanMealScheduleKind.weekdays,
    ),
    weekdays: _list(j['weekdays']).map((v) => _int(v) ?? 1).toSet(),
    specificDates: _dateList(j['specificDates']),
  );
  final String mealType, dishName;
  final List<String> dayContents, restrictions;
  final String? customMealType, startTime, endTime, details;
  final bool hasTime, hasNutrition;
  final double? portionGrams, energyKcal, proteinG, carbohydrateG, fatG;
  final MealPlanAttachmentMeta? image;
  final MealPlanMealScheduleKind scheduleKind;
  final Set<int> weekdays;
  final List<DateTime> specificDates;
  Map<String, Object?> toJson() => {
    'mealType': mealType,
    'dayContents': dayContents,
    'customMealType': customMealType,
    'hasTime': hasTime,
    'startTime': startTime,
    'endTime': endTime,
    'dishName': dishName,
    'details': details,
    'hasNutrition': hasNutrition,
    'portionGrams': portionGrams,
    'energyKcal': energyKcal,
    'proteinG': proteinG,
    'carbohydrateG': carbohydrateG,
    'fatG': fatG,
    'restrictions': restrictions,
    'image': image?.toJson(),
    'scheduleKind': scheduleKind.name,
    'weekdays': weekdays.toList()..sort(),
    'specificDates': specificDates.map(_dateValue).toList(),
  };
}

final class MealPlanConflict {
  const MealPlanConflict({
    required this.conflictType,
    required this.scopeLevel,
    required this.scopeId,
    required this.dateRange,
    required this.mealType,
    required this.overlapWithIds,
    required this.requiredAction,
  });
  factory MealPlanConflict.fromJson(Map<String, Object?> j) => MealPlanConflict(
    conflictType: _enumByName(
      MealPlanConflictType.values,
      j['conflictType'],
      MealPlanConflictType.overlap,
    ),
    scopeLevel: (j['scopeLevel'] as String?) ?? 'global',
    scopeId: j['scopeId'] as String?,
    dateRange: (j['dateRange'] as String?) ?? '',
    mealType: (j['mealType'] as String?) ?? '',
    overlapWithIds: _list(j['overlapWithIds']).map((v) => v.toString()).toList(),
    requiredAction: _enumByName(
      MealPlanConflictAction.values,
      j['requiredAction'],
      MealPlanConflictAction.reject,
    ),
  );
  final MealPlanConflictType conflictType;
  final String scopeLevel, dateRange, mealType;
  final String? scopeId;
  final List<String> overlapWithIds;
  final MealPlanConflictAction requiredAction;
}

final class MealPlan {
  const MealPlan({
    required this.id,
    required this.tenantId,
    this.institutionId,
    this.unitId,
    this.classId,
    this.personId,
    required this.name,
    required this.status,
    required this.sourceType,
    required this.scopeLevel,
    required this.scopeId,
    required this.startDate,
    required this.endDate,
    required this.recurrence,
    required this.menu,
    required this.allergens,
    required this.alerts,
    required this.attachments,
    required this.priority,
    required this.conflictState,
    required this.revision,
    required this.isDraft,
    required this.requiresReview,
    required this.createdBy,
    required this.updatedBy,
    this.inheritanceOriginId,
    this.planVariant = MealPlanPlanVariant.complete,
    this.audienceSegment = MealPlanAudienceSegment.students,
    this.visibilityMode = MealPlanVisibilityMode.immediate,
    this.visibleFrom,
    this.sourceTemplateId,
    this.sourceTemplateVersion,
    this.sourceTemplateName,
    this.scopeRules = const {},
    this.simpleImage,
    this.simpleImageAlt,
    this.simpleNotes,
    this.isTemplate = false,
  });
  factory MealPlan.fromJson(Map<String, Object?> j) => MealPlan(
    id: j['id'].toString(),
    tenantId: (j['tenantId'] as String?) ?? (j['tenant_id'] as String?) ?? '',
    institutionId: j['institutionId'] as String? ?? j['institution_id'] as String?,
    unitId: j['unitId'] as String? ?? j['unit_id'] as String?,
    classId: j['classId'] as String? ?? j['class_id'] as String?,
    personId: j['personId'] as String? ?? j['person_id'] as String?,
    name: (j['name'] as String?) ?? 'Sem nome',
    status: _status((j['status'] as String?) ?? 'draft'),
    sourceType: _enumByName(
      MealPlanSourceType.values,
      j['sourceType'] ?? j['source_type'],
      MealPlanSourceType.institution,
    ),
    scopeLevel: _enumByName(
      MealPlanScopeLevel.values,
      j['scopeLevel'] ?? j['scope_level'],
      MealPlanScopeLevel.institution,
    ),
    scopeId: (j['scopeId'] as String?) ?? (j['scope_id'] as String?) ?? '',
    startDate: _date(j['startDate'] ?? j['start_date'] ?? DateTime.now()),
    endDate: _date(j['endDate'] ?? j['end_date'] ?? DateTime.now()),
    recurrence: MealPlanRecurrence.fromJson(_map(j['recurrence'])),
    menu: _menuList(j['menu']),
    allergens: _list(j['allergens']).map((v) => v.toString()).toList(),
    alerts: _list(j['alerts']).map((v) => v.toString()).toList(),
    attachments: _list(
      j['attachmentsMeta'] ?? j['attachments_meta'],
    ).map((v) => MealPlanAttachmentMeta.fromJson(_map(v))).toList(),
    priority: _int(j['priority']) ?? 0,
    conflictState: _bool(j['hasConflict'] ?? j['conflict_state']) ?? false,
    revision: _int(j['revision']) ?? 1,
    isDraft: _bool(j['isDraft'] ?? j['is_draft']) ?? true,
    requiresReview: _bool(j['requiresReview'] ?? j['requires_review']) ?? false,
    createdBy: j['createdBy'] as String? ?? j['created_by'] as String?,
    updatedBy: j['updatedBy'] as String? ?? j['updated_by'] as String?,
    inheritanceOriginId:
        j['inheritanceOriginId'] as String? ?? j['inheritance_origin_id'] as String?,
    planVariant: _enumByName(
      MealPlanPlanVariant.values,
      j['planVariant'] ?? j['plan_variant'],
      MealPlanPlanVariant.complete,
    ),
    audienceSegment: _enumByName(
      MealPlanAudienceSegment.values,
      j['audienceSegment'] ?? j['audience_segment'],
      MealPlanAudienceSegment.students,
    ),
    visibilityMode: _enumByName(
      MealPlanVisibilityMode.values,
      j['visibilityMode'] ?? j['visibility_mode'],
      MealPlanVisibilityMode.immediate,
    ),
    visibleFrom: _dateOrNull(j['visibleFrom'] ?? j['visible_from']),
    sourceTemplateId: j['sourceTemplateId'] as String? ?? j['source_template_id'] as String?,
    sourceTemplateVersion: _int(j['sourceTemplateVersion'] ?? j['source_template_version']),
    sourceTemplateName: j['sourceTemplateName'] as String? ?? j['source_template_name'] as String?,
    scopeRules: _map(j['scopeRules'] ?? j['scope_rules']),
    simpleImage: (j['simpleImage'] ?? j['simple_image_meta']) is Map
        ? MealPlanAttachmentMeta.fromJson(_map(j['simpleImage'] ?? j['simple_image_meta']))
        : null,
    simpleImageAlt: j['simpleImageAlt'] as String? ?? j['simple_image_alt'] as String?,
    simpleNotes: j['simpleNotes'] as String? ?? j['simple_notes'] as String?,
    isTemplate: _bool(j['isTemplate'] ?? j['is_template']) ?? false,
  );
  final String id, tenantId, name, scopeId;
  final String? institutionId,
      unitId,
      classId,
      personId,
      createdBy,
      updatedBy,
      inheritanceOriginId,
      sourceTemplateId,
      sourceTemplateName,
      simpleImageAlt,
      simpleNotes;
  final MealPlanStatus status;
  final MealPlanSourceType sourceType;
  final MealPlanScopeLevel scopeLevel;
  final DateTime startDate, endDate;
  final MealPlanRecurrence recurrence;
  final List<MealPlanMenuEntry> menu;
  final List<String> allergens, alerts;
  final List<MealPlanAttachmentMeta> attachments;
  final int priority, revision;
  final bool conflictState, isDraft, requiresReview, isTemplate;
  final MealPlanPlanVariant planVariant;
  final MealPlanAudienceSegment audienceSegment;
  final MealPlanVisibilityMode visibilityMode;
  final DateTime? visibleFrom;
  final int? sourceTemplateVersion;
  final Map<String, Object?> scopeRules;
  final MealPlanAttachmentMeta? simpleImage;
}

final class MealPlanDraft {
  const MealPlanDraft({
    this.requestId,
    this.mealPlanId,
    required this.tenantId,
    this.institutionId,
    this.unitId,
    this.classId,
    this.personId,
    required this.name,
    required this.sourceType,
    required this.scopeLevel,
    required this.scopeId,
    required this.startDate,
    required this.endDate,
    required this.recurrence,
    required this.menu,
    this.allergens = const [],
    this.alerts = const [],
    this.attachments = const [],
    required this.priority,
    required this.expectedRevision,
    this.inheritanceOriginId,
    this.planVariant = MealPlanPlanVariant.complete,
    this.audienceSegment = MealPlanAudienceSegment.students,
    this.visibilityMode = MealPlanVisibilityMode.immediate,
    this.visibleFrom,
    this.sourceTemplateId,
    this.sourceTemplateVersion,
    this.scopeRules = const {},
    this.simpleImage,
    this.simpleImageAlt,
    this.simpleNotes,
    this.saveAsTemplate = false,
    this.templateName,
  });
  final String? requestId,
      mealPlanId,
      institutionId,
      unitId,
      classId,
      personId,
      inheritanceOriginId,
      sourceTemplateId,
      simpleImageAlt,
      simpleNotes,
      templateName;
  final String tenantId, name, scopeId;
  final MealPlanSourceType sourceType;
  final MealPlanScopeLevel scopeLevel;
  final DateTime startDate, endDate;
  final MealPlanRecurrence recurrence;
  final List<MealPlanMenuEntry> menu;
  final List<String> allergens, alerts;
  final List<MealPlanAttachmentMeta> attachments;
  final int priority, expectedRevision;
  final MealPlanPlanVariant planVariant;
  final MealPlanAudienceSegment audienceSegment;
  final MealPlanVisibilityMode visibilityMode;
  final DateTime? visibleFrom;
  final int? sourceTemplateVersion;
  final Map<String, Object?> scopeRules;
  final MealPlanAttachmentMeta? simpleImage;
  final bool saveAsTemplate;
  Map<String, Object?> toJson() => {
    'tenantId': tenantId,
    'institutionId': institutionId,
    'unitId': unitId,
    'classId': classId,
    'personId': personId,
    'name': name,
    'sourceType': sourceType.name,
    'scopeLevel': scopeLevel.name,
    'scopeId': scopeId,
    'startDate': _dateValue(startDate),
    'endDate': _dateValue(endDate),
    'recurrence': recurrence.toJson(),
    'menu': menu.map((v) => v.toJson()).toList(),
    'allergens': allergens,
    'alerts': alerts,
    'attachments': attachments.map((v) => v.toJson()).toList(),
    'priority': priority,
    'expectedRevision': expectedRevision,
    'inheritanceOriginId': inheritanceOriginId,
    'planVariant': planVariant.name,
    'audienceSegment': audienceSegment.name,
    'visibilityMode': visibilityMode.name,
    'visibleFrom': visibleFrom?.toIso8601String(),
    'sourceTemplateId': sourceTemplateId,
    'sourceTemplateVersion': sourceTemplateVersion,
    'scopeRules': scopeRules,
    'simpleImage': simpleImage?.toJson(),
    'simpleImageAlt': simpleImageAlt,
    'simpleNotes': simpleNotes,
    'saveAsTemplate': saveAsTemplate,
    'templateName': templateName,
  };
}

final class MealPlanTemplate {
  const MealPlanTemplate({
    required this.id,
    required this.name,
    required this.planVariant,
    required this.audienceSegment,
    required this.status,
    required this.version,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.tenantId,
    this.institutionId,
  });
  factory MealPlanTemplate.fromJson(Map<String, Object?> j) => MealPlanTemplate(
    id: j['id'].toString(),
    tenantId: j['tenant_id'] as String?,
    institutionId: j['institution_id'] as String?,
    name: (j['name'] as String?) ?? 'Sem nome',
    planVariant: _enumByName(
      MealPlanPlanVariant.values,
      j['plan_variant'],
      MealPlanPlanVariant.complete,
    ),
    audienceSegment: _enumByName(
      MealPlanAudienceSegment.values,
      j['audience_segment'],
      MealPlanAudienceSegment.students,
    ),
    status: (j['status'] as String?) ?? 'draft',
    version: _int(j['version']) ?? 1,
    payload: _map(j['payload']),
    createdAt: _date(j['created_at'] ?? DateTime.now()),
    updatedAt: _date(j['updated_at'] ?? DateTime.now()),
  );
  final String id, name, status;
  final String? tenantId, institutionId;
  final MealPlanPlanVariant planVariant;
  final MealPlanAudienceSegment audienceSegment;
  final int version;
  final Map<String, Object?> payload;
  final DateTime createdAt, updatedAt;
  MealPlan toDirectoryItem() => MealPlan(
    id: id,
    tenantId: tenantId ?? '',
    institutionId: institutionId,
    name: name,
    status: status == 'active'
        ? MealPlanStatus.published
        : status == 'archived'
        ? MealPlanStatus.archived
        : MealPlanStatus.draft,
    sourceType: MealPlanSourceType.global,
    scopeLevel: MealPlanScopeLevel.global,
    scopeId: '',
    startDate: createdAt,
    endDate: updatedAt,
    recurrence: MealPlanRecurrence(kind: MealPlanRecurrenceKind.singleWeek),
    menu: _menuList(payload['menu']),
    allergens: const [],
    alerts: const [],
    attachments: const [],
    priority: 0,
    conflictState: false,
    revision: version,
    isDraft: status == 'draft',
    requiresReview: false,
    createdBy: null,
    updatedBy: null,
    planVariant: planVariant,
    audienceSegment: audienceSegment,
    simpleImage: payload['simpleImage'] is Map
        ? MealPlanAttachmentMeta.fromJson(_map(payload['simpleImage']))
        : null,
    simpleImageAlt: payload['simpleImageAlt'] as String?,
    simpleNotes: payload['simpleNotes'] as String?,
    isTemplate: true,
  );
}

final class MealPlanTemplateDraft {
  const MealPlanTemplateDraft({
    this.requestId,
    this.id,
    required this.name,
    required this.planVariant,
    required this.audienceSegment,
    required this.payload,
    this.expectedVersion = 0,
  });
  final String? requestId, id;
  final String name;
  final MealPlanPlanVariant planVariant;
  final MealPlanAudienceSegment audienceSegment;
  final Map<String, Object?> payload;
  final int expectedVersion;
  Map<String, Object?> toJson() => {
    'requestId': requestId,
    'name': name,
    'planVariant': planVariant.name,
    'audienceSegment': audienceSegment.name,
    'payload': payload,
  };
}

final class MealPlanAudienceOption {
  const MealPlanAudienceOption({
    required this.id,
    required this.label,
    this.institutionId,
    this.unitId,
    this.groupId,
    this.audienceSegment,
  });
  factory MealPlanAudienceOption.fromJson(Map<String, Object?> j) => MealPlanAudienceOption(
    id: j['id'].toString(),
    label: (j['label'] as String?) ?? 'Sem nome',
    institutionId: j['institutionId'] as String? ?? j['institution_id'] as String?,
    unitId: j['unitId'] as String? ?? j['unit_id'] as String?,
    groupId: j['groupId'] as String? ?? j['group_id'] as String?,
    audienceSegment: j['audienceSegment'] == null
        ? null
        : _enumByName(
            MealPlanAudienceSegment.values,
            j['audienceSegment'],
            MealPlanAudienceSegment.students,
          ),
  );
  final String id, label;
  final String? institutionId, unitId, groupId;
  final MealPlanAudienceSegment? audienceSegment;
}

final class MealPlanAudienceOptions {
  const MealPlanAudienceOptions({
    this.institutions = const [],
    this.units = const [],
    this.groups = const [],
    this.activities = const [],
    this.people = const [],
  });
  factory MealPlanAudienceOptions.fromJson(Map<String, Object?> j) => MealPlanAudienceOptions(
    institutions: _options(j['institutions']),
    units: _options(j['units']),
    groups: _options(j['groups']),
    activities: _options(j['activities']),
    people: _options(j['people']),
  );
  final List<MealPlanAudienceOption> institutions, units, groups, activities, people;
}

sealed class MealPlanRepositoryException implements Exception {
  const MealPlanRepositoryException(this.message);
  final String message;
}

final class MealPlanUnauthorizedException extends MealPlanRepositoryException {
  const MealPlanUnauthorizedException() : super('Voce nao tem acesso aos cardapios.');
}

final class MealPlanNotFoundException extends MealPlanRepositoryException {
  const MealPlanNotFoundException() : super('Cardapio nao encontrado.');
}

final class MealPlanConflictException extends MealPlanRepositoryException {
  const MealPlanConflictException(super.message);
}

final class MealPlanValidationException extends MealPlanRepositoryException {
  const MealPlanValidationException([super.message = 'Revise os dados do cardapio.']);
}

final class MealPlanUnavailableException extends MealPlanRepositoryException {
  const MealPlanUnavailableException([super.message = 'Cardapios indisponiveis no momento.']);
}

abstract interface class MealPlanRepository {
  Future<MealPlanPage> fetchPage(MealPlanListFilter filter);
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter filter);
  Future<MealPlan> getById(String id);
  Future<MealPlanTemplate> getTemplateById(String id);
  Future<MealPlanTemplate> saveTemplate(MealPlanTemplateDraft draft, {required bool publish});
  Future<MealPlanAudienceOptions> fetchAudienceOptions();
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft);
  Future<MealPlan> submitForReview(String mealPlanId, String requestId, int expectedRevision);
  Future<MealPlan> publish(String mealPlanId, String requestId, int expectedRevision);
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  });
  Future<MealPlan> fetchEffectiveSnapshot(MealPlanDraft draft);
}

final class UnavailableMealPlanRepository implements MealPlanRepository {
  const UnavailableMealPlanRepository();
  Never _fail() => throw const MealPlanUnavailableException();
  @override
  Future<MealPlanPage> fetchPage(MealPlanListFilter f) async => throw _fail();
  @override
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter f) async => throw _fail();
  @override
  Future<MealPlan> getById(String id) async => throw _fail();
  @override
  Future<MealPlanTemplate> getTemplateById(String id) async => throw _fail();
  @override
  Future<MealPlanTemplate> saveTemplate(MealPlanTemplateDraft d, {required bool publish}) async =>
      throw _fail();
  @override
  Future<MealPlanAudienceOptions> fetchAudienceOptions() async => throw _fail();
  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft d) async => throw _fail();
  @override
  Future<MealPlan> submitForReview(String id, String requestId, int rev) async => throw _fail();
  @override
  Future<MealPlan> publish(String id, String requestId, int rev) async => throw _fail();
  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) async => throw _fail();
  @override
  Future<MealPlan> fetchEffectiveSnapshot(MealPlanDraft d) async => throw _fail();
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.firstWhere((v) => v.name == raw?.toString(), orElse: () => fallback);
MealPlanStatus _status(String value) => switch (value) {
  'inReview' || 'in_review' => MealPlanStatus.inReview,
  'scheduled' => MealPlanStatus.scheduled,
  'published' || 'active' => MealPlanStatus.published,
  'updated' => MealPlanStatus.updated,
  'ended' => MealPlanStatus.ended,
  'archived' => MealPlanStatus.archived,
  _ => MealPlanStatus.draft,
};
DateTime _date(Object? value) => value is DateTime ? value : DateTime.parse(value.toString());
DateTime? _dateOrNull(Object? value) =>
    value == null || value.toString().isEmpty ? null : _date(value);
List<DateTime> _dateList(Object? v) => _list(v).map(_date).toList();
String? _dateValue(DateTime? v) => v == null
    ? null
    : '${v.year.toString().padLeft(4, '0')}-${v.month.toString().padLeft(2, '0')}-'
          '${v.day.toString().padLeft(2, '0')}';
Map<String, Object?> _map(Object? v) => v is Map ? Map<String, Object?>.from(v) : const {};
List<Object?> _list(Object? v) => List<Object?>.from(v as List? ?? const []);
List<MealPlanMenuEntry> _menuList(Object? v) =>
    _list(v).map((x) => MealPlanMenuEntry.fromJson(_map(x))).toList();
List<MealPlanAudienceOption> _options(Object? v) =>
    _list(v).map((x) => MealPlanAudienceOption.fromJson(_map(x))).toList();
int? _int(Object? v) => v == null ? null : int.tryParse(v.toString());
double? _double(Object? v) => v == null ? null : double.tryParse(v.toString());
bool? _bool(Object? v) => v is bool
    ? v
    : v == null
    ? null
    : v.toString() == 'true';
