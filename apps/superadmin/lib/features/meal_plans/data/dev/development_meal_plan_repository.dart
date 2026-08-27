import 'dart:convert';

import '../../domain/meal_plan_repository.dart';

/// In-memory data used exclusively by the `/dev` composition root.
final class DevelopmentMealPlanRepository implements MealPlanRepository {
  DevelopmentMealPlanRepository() : _plans = [_samplePlan], _templates = [_sampleTemplate];

  final List<MealPlan> _plans;
  final List<MealPlanTemplate> _templates;
  final Map<String, String> _requestFingerprints = {};
  final Map<String, ({String fingerprint, MealPlan result})> _responsesByRequest = {};
  final Map<String, ({String fingerprint, MealPlanTemplate result})> _templateResponses = {};

  @override
  Future<MealPlanPage> fetchPage(MealPlanListFilter filter) async => MealPlanPage(
    items: _plans.skip(filter.offset).take(filter.pageSize).toList(growable: false),
    total: _plans.length,
    limit: filter.pageSize,
    offset: filter.offset,
  );

  @override
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter filter) async => MealPlanPage(
    items: _templates
        .skip(filter.offset)
        .take(filter.pageSize)
        .map((item) => item.toDirectoryItem())
        .toList(growable: false),
    total: _templates.length,
    limit: filter.pageSize,
    offset: filter.offset,
  );

  @override
  Future<MealPlan> getById(String id) async => _plans.firstWhere(
    (item) => item.id == id,
    orElse: () => throw const MealPlanNotFoundException(),
  );

  @override
  Future<MealPlanTemplate> getTemplateById(String id) async => _templates.firstWhere(
    (item) => item.id == id,
    orElse: () => throw const MealPlanNotFoundException(),
  );

  @override
  Future<MealPlanAudienceOptions> fetchAudienceOptions() async => _audienceOptions;

  @override
  Future<MealPlanTemplate> saveTemplate(
    MealPlanTemplateDraft draft, {
    required bool publish,
  }) async {
    final requestId = draft.requestId;
    if (requestId == null || requestId.trim().isEmpty) {
      throw const MealPlanValidationException('Informe um identificador para a operação local.');
    }
    final fingerprint = 'template:${publish ? 'publish' : 'save'}|${jsonEncode(draft.toJson())}';
    if (_isReplay(requestId, fingerprint)) {
      final previous = _templateResponses[requestId];
      if (previous == null) {
        throw const MealPlanConflictException(
          'A resposta local desta operação não está disponível.',
        );
      }
      return previous.result;
    }
    final existing = draft.id == null
        ? null
        : _templates.where((value) => value.id == draft.id).firstOrNull;
    if (draft.id != null && existing == null) throw const MealPlanNotFoundException();
    if (existing != null && existing.version != draft.expectedVersion) {
      throw const MealPlanConflictException('O modelo foi alterado nesta prévia.');
    }
    final now = DateTime.now();
    final item = MealPlanTemplate(
      id: draft.id ?? 'dev-template-${_templates.length + 1}',
      tenantId: 'dev-tenant',
      institutionId: 'dev-institution',
      name: draft.name,
      planVariant: draft.planVariant,
      audienceSegment: draft.audienceSegment,
      status: publish ? 'published' : 'draft',
      version: draft.expectedVersion + 1,
      payload: draft.payload,
      createdAt: now,
      updatedAt: now,
    );
    _templates.removeWhere((value) => value.id == item.id);
    _templates.add(item);
    _recordRequest(requestId, fingerprint);
    _templateResponses[requestId] = (fingerprint: fingerprint, result: item);
    return item;
  }

  @override
  Future<MealPlan> createOrUpdateDraft(MealPlanDraft draft) async {
    final requestId = draft.requestId;
    if (requestId == null || requestId.trim().isEmpty) {
      throw const MealPlanValidationException('Informe um identificador para a operação local.');
    }
    final fingerprint = 'plan:save|${jsonEncode(draft.toJson())}';
    if (_isReplay(requestId, fingerprint)) {
      final previous = _responsesByRequest[requestId];
      if (previous == null) {
        throw const MealPlanConflictException(
          'A resposta local desta operação não está disponível.',
        );
      }
      return previous.result;
    }
    final existing = draft.mealPlanId == null
        ? null
        : _plans.where((value) => value.id == draft.mealPlanId).firstOrNull;
    if (draft.mealPlanId != null && existing == null) throw const MealPlanNotFoundException();
    if (existing != null && existing.revision != draft.expectedRevision) {
      throw const MealPlanConflictException('O rascunho foi alterado nesta prévia.');
    }
    final conflicts = _findConflicts(
      scopeId: draft.scopeId,
      startDate: draft.startDate,
      endDate: draft.endDate,
      menu: draft.menu,
      excludingId: draft.mealPlanId,
    );
    final item = _fromDraft(
      draft,
      id: draft.mealPlanId ?? 'dev-meal-plan-${_plans.length + 1}',
      conflictState: conflicts.isNotEmpty,
    );
    _plans.removeWhere((value) => value.id == item.id);
    _plans.add(item);
    _recordRequest(requestId, fingerprint);
    _responsesByRequest[requestId] = (fingerprint: fingerprint, result: item);
    return item;
  }

  @override
  Future<MealPlan> submitForReview(
    String mealPlanId,
    String requestId,
    int expectedRevision,
  ) async => _updateStatus(mealPlanId, requestId, expectedRevision, MealPlanStatus.inReview);

  @override
  Future<MealPlan> publish(String mealPlanId, String requestId, int expectedRevision) async =>
      _updateStatus(mealPlanId, requestId, expectedRevision, MealPlanStatus.published);

  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) async => _findConflicts(scopeId: scopeId, startDate: startDate, endDate: endDate, menu: menu);

  @override
  Future<MealPlan> fetchEffectiveSnapshot(MealPlanDraft draft) async =>
      _fromDraft(draft, id: draft.mealPlanId ?? 'dev-effective-preview', conflictState: false);

  MealPlan _updateStatus(String id, String requestId, int expectedRevision, MealPlanStatus status) {
    if (requestId.trim().isEmpty) {
      throw const MealPlanValidationException('Informe um identificador para a operação local.');
    }
    final fingerprint = 'plan:${status.name}|$id|$expectedRevision';
    if (_isReplay(requestId, fingerprint)) {
      final previous = _responsesByRequest[requestId];
      if (previous == null) {
        throw const MealPlanConflictException(
          'A resposta local desta operação não está disponível.',
        );
      }
      return previous.result;
    }
    final index = _plans.indexWhere((item) => item.id == id);
    if (index < 0) throw const MealPlanNotFoundException();
    final item = _plans[index];
    if (item.conflictState) {
      throw const MealPlanConflictException(
        'Resolva os conflitos locais antes de revisar ou publicar.',
      );
    }
    if (item.revision != expectedRevision) {
      throw const MealPlanConflictException('O cardápio foi alterado nesta prévia.');
    }
    final updated = _copy(item, status: status, isDraft: false);
    _plans[index] = updated;
    _recordRequest(requestId, fingerprint);
    _responsesByRequest[requestId] = (fingerprint: fingerprint, result: updated);
    return updated;
  }

  bool _isReplay(String requestId, String fingerprint) {
    final previous = _requestFingerprints[requestId];
    if (previous == null) return false;
    if (previous != fingerprint) {
      throw const MealPlanConflictException(
        'O identificador desta operação já foi usado com outro comando ou conteúdo.',
      );
    }
    return true;
  }

  void _recordRequest(String requestId, String fingerprint) {
    _requestFingerprints[requestId] = fingerprint;
  }

  List<MealPlanConflict> _findConflicts({
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required List<MealPlanMenuEntry> menu,
    String? excludingId,
  }) {
    final mealTypes = menu.map((value) => value.mealType).toSet();
    return [
      for (final plan in _plans)
        if (plan.id != excludingId &&
            !plan.isDraft &&
            plan.scopeId == scopeId &&
            !plan.endDate.isBefore(startDate) &&
            !plan.startDate.isAfter(endDate) &&
            plan.menu.any((value) => mealTypes.contains(value.mealType)))
          MealPlanConflict(
            conflictType: MealPlanConflictType.overlap,
            scopeLevel: plan.scopeLevel.name,
            scopeId: scopeId,
            dateRange: '${startDate.toIso8601String()}/${endDate.toIso8601String()}',
            mealType: plan.menu.firstWhere((value) => mealTypes.contains(value.mealType)).mealType,
            overlapWithIds: [plan.id],
            requiredAction: MealPlanConflictAction.reject,
          ),
    ];
  }
}

MealPlan _fromDraft(MealPlanDraft draft, {required String id, required bool conflictState}) =>
    MealPlan(
      id: id,
      tenantId: draft.tenantId,
      institutionId: draft.institutionId,
      unitId: draft.unitId,
      classId: draft.classId,
      personId: draft.personId,
      name: draft.name,
      status: MealPlanStatus.draft,
      sourceType: draft.sourceType,
      scopeLevel: draft.scopeLevel,
      scopeId: draft.scopeId,
      startDate: draft.startDate,
      endDate: draft.endDate,
      recurrence: draft.recurrence,
      menu: draft.menu,
      allergens: draft.allergens,
      alerts: draft.alerts,
      attachments: draft.attachments,
      priority: draft.priority,
      conflictState: conflictState,
      revision: draft.expectedRevision + 1,
      isDraft: true,
      requiresReview: false,
      createdBy: 'dev-user',
      updatedBy: 'dev-user',
      inheritanceOriginId: draft.inheritanceOriginId,
      planVariant: draft.planVariant,
      audienceSegment: draft.audienceSegment,
      visibilityMode: draft.visibilityMode,
      visibleFrom: draft.visibleFrom,
      sourceTemplateId: draft.sourceTemplateId,
      sourceTemplateVersion: draft.sourceTemplateVersion,
      scopeRules: draft.scopeRules,
      simpleImage: draft.simpleImage,
      simpleImageAlt: draft.simpleImageAlt,
      simpleNotes: draft.simpleNotes,
    );

MealPlan _copy(MealPlan item, {required MealPlanStatus status, required bool isDraft}) => MealPlan(
  id: item.id,
  tenantId: item.tenantId,
  institutionId: item.institutionId,
  unitId: item.unitId,
  classId: item.classId,
  personId: item.personId,
  name: item.name,
  status: status,
  sourceType: item.sourceType,
  scopeLevel: item.scopeLevel,
  scopeId: item.scopeId,
  startDate: item.startDate,
  endDate: item.endDate,
  recurrence: item.recurrence,
  menu: item.menu,
  allergens: item.allergens,
  alerts: item.alerts,
  attachments: item.attachments,
  priority: item.priority,
  conflictState: item.conflictState,
  revision: item.revision + 1,
  isDraft: isDraft,
  requiresReview: status == MealPlanStatus.inReview,
  createdBy: item.createdBy,
  updatedBy: item.updatedBy,
  inheritanceOriginId: item.inheritanceOriginId,
  planVariant: item.planVariant,
  audienceSegment: item.audienceSegment,
  visibilityMode: item.visibilityMode,
  visibleFrom: item.visibleFrom,
  sourceTemplateId: item.sourceTemplateId,
  sourceTemplateVersion: item.sourceTemplateVersion,
  sourceTemplateName: item.sourceTemplateName,
  scopeRules: item.scopeRules,
  simpleImage: item.simpleImage,
  simpleImageAlt: item.simpleImageAlt,
  simpleNotes: item.simpleNotes,
  isTemplate: item.isTemplate,
);

final _samplePlan = MealPlan(
  id: 'dev-meal-plan',
  tenantId: 'dev-tenant',
  institutionId: 'dev-institution',
  unitId: 'dev-unit',
  name: 'Cardápio semanal de demonstração',
  status: MealPlanStatus.published,
  sourceType: MealPlanSourceType.institution,
  scopeLevel: MealPlanScopeLevel.unit,
  scopeId: 'dev-unit',
  startDate: DateTime(2026, 8, 24),
  endDate: DateTime(2026, 8, 28),
  recurrence: MealPlanRecurrence(
    kind: MealPlanRecurrenceKind.weekly,
    weekdays: const {1, 2, 3, 4, 5},
  ),
  menu: [MealPlanMenuEntry(mealType: 'lunch', dishName: 'Arroz, feijão e legumes')],
  allergens: const [],
  alerts: const [],
  attachments: const [],
  priority: 10,
  conflictState: false,
  revision: 1,
  isDraft: false,
  requiresReview: false,
  createdBy: 'dev-user',
  updatedBy: 'dev-user',
);

final _sampleTemplate = MealPlanTemplate(
  id: 'dev-template',
  tenantId: 'dev-tenant',
  institutionId: 'dev-institution',
  name: 'Modelo semanal equilibrado',
  planVariant: MealPlanPlanVariant.complete,
  audienceSegment: MealPlanAudienceSegment.students,
  status: 'published',
  version: 1,
  payload: {
    'menu': [MealPlanMenuEntry(mealType: 'lunch', dishName: 'Prato principal').toJson()],
  },
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 20),
);

const _audienceOptions = MealPlanAudienceOptions(
  institutions: [MealPlanAudienceOption(id: 'dev-institution', label: 'Colégio Coelo')],
  units: [
    MealPlanAudienceOption(
      id: 'dev-unit',
      label: 'Unidade Centro',
      institutionId: 'dev-institution',
    ),
  ],
  groups: [
    MealPlanAudienceOption(
      id: 'dev-group',
      label: 'Turma Girassol',
      institutionId: 'dev-institution',
      unitId: 'dev-unit',
    ),
  ],
  people: [
    MealPlanAudienceOption(
      id: 'dev-child',
      label: 'Helena Silva',
      institutionId: 'dev-institution',
      unitId: 'dev-unit',
      groupId: 'dev-group',
      audienceSegment: MealPlanAudienceSegment.students,
    ),
  ],
);
