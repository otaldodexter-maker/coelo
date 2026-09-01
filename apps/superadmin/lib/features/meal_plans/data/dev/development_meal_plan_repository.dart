import 'dart:convert';

import '../../domain/meal_plan_repository.dart';

/// In-memory data used exclusively by the `/dev` composition root.
final class DevelopmentMealPlanRepository implements MealPlanRepository {
  DevelopmentMealPlanRepository()
    : _plans = [..._developmentPlans],
      _templates = [..._developmentTemplates];

  final List<MealPlan> _plans;
  final List<MealPlanTemplate> _templates;
  final Map<String, String> _requestFingerprints = {};
  final Map<String, ({String fingerprint, MealPlan result})> _responsesByRequest = {};
  final Map<String, ({String fingerprint, MealPlanTemplate result})> _templateResponses = {};

  @override
  Future<MealPlanPage> fetchPage(MealPlanListFilter filter) async {
    final items = _plans.where((item) => _matchesFilter(item, filter)).toList(growable: false);
    return MealPlanPage(
      items: items.skip(filter.offset).take(filter.pageSize).toList(growable: false),
      total: items.length,
      limit: filter.pageSize,
      offset: filter.offset,
    );
  }

  @override
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter filter) async {
    final items = _templates
        .map((item) => item.toDirectoryItem())
        .where((item) => _matchesFilter(item, filter))
        .toList(growable: false);
    return MealPlanPage(
      items: items.skip(filter.offset).take(filter.pageSize).toList(growable: false),
      total: items.length,
      limit: filter.pageSize,
      offset: filter.offset,
    );
  }

  bool _matchesFilter(MealPlan item, MealPlanListFilter filter) {
    final search = filter.search?.trim().toLowerCase();
    if (search != null && search.isNotEmpty && !item.name.toLowerCase().contains(search)) {
      return false;
    }
    if (filter.institutionId != null && item.institutionId != filter.institutionId) return false;
    if (filter.unitId != null && item.unitId != filter.unitId) return false;
    if (filter.classId != null && item.classId != filter.classId) return false;
    if (filter.personId != null && item.personId != filter.personId) return false;
    if (filter.statuses.isNotEmpty && !filter.statuses.contains(item.status)) return false;
    if (filter.sources.isNotEmpty && !filter.sources.contains(item.sourceType)) return false;
    if (filter.hasConflict != null && item.conflictState != filter.hasConflict) return false;
    if (filter.requiresReview != null && item.requiresReview != filter.requiresReview) return false;
    if (filter.periodStart != null && item.endDate.isBefore(filter.periodStart!)) return false;
    if (filter.periodEnd != null && item.startDate.isAfter(filter.periodEnd!)) return false;
    return true;
  }

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

final _developmentPlans = <MealPlan>[
  _fixturePlan(
    id: 'dev-meal-plan',
    name: 'Semana da horta — Turma Girassol',
    scopeId: 'dev-unit',
    unitId: 'dev-unit',
    dish: 'Arroz integral, feijão, abóbora assada e frango desfiado',
    month: 8,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-bercario',
    name: 'Texturas leves do Berçário Nuvem',
    scopeId: 'dev-group-nuvem',
    unitId: 'dev-unit',
    classId: 'dev-group-nuvem',
    scopeLevel: MealPlanScopeLevel.classLevel,
    sourceType: MealPlanSourceType.classLevel,
    dish: 'Purê de mandioquinha, lentilha e carne bem desfiada',
    startDay: 7,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-therapy',
    name: 'Terapia ocupacional — aproximação alimentar de Helena',
    scopeId: 'dev-child',
    unitId: 'dev-unit',
    classId: 'dev-group',
    personId: 'dev-child',
    scopeLevel: MealPlanScopeLevel.person,
    sourceType: MealPlanSourceType.person,
    dish: 'Arroz, almôndega assada e legumes separados por textura',
    startDay: 14,
    status: MealPlanStatus.inReview,
    requiresReview: true,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-integral',
    name: 'Período integral — energia para aprender e brincar',
    scopeId: 'dev-unit-jardim',
    institutionId: 'dev-institution',
    unitId: 'dev-unit-jardim',
    dish: 'Cuscuz com ovos, banana e almoço brasileiro completo',
    startDay: 21,
    status: MealPlanStatus.scheduled,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-lactose',
    name: 'Semana sem lactose — Unidade Centro',
    scopeId: 'dev-unit',
    unitId: 'dev-unit',
    dish: 'Escondidinho de carne com creme vegetal',
    startDay: 28,
    status: MealPlanStatus.updated,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-equipe',
    name: 'Refeições da equipe pedagógica',
    scopeId: 'dev-institution',
    scopeLevel: MealPlanScopeLevel.institution,
    sourceType: MealPlanSourceType.institution,
    dish: 'Arroz, feijão, peixe assado e salada fresca',
    startDay: 4,
    month: 10,
    audience: MealPlanAudienceSegment.staff,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-oficinas',
    name: 'Oficinas de primavera — lanches compartilhados',
    scopeId: 'dev-group-sabiá',
    institutionId: 'dev-institution-aurora',
    unitId: 'dev-unit-lagoa',
    classId: 'dev-group-sabiá',
    scopeLevel: MealPlanScopeLevel.classLevel,
    sourceType: MealPlanSourceType.classLevel,
    dish: 'Pão de queijo, frutas da estação e água saborizada',
    startDay: 11,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-passeio',
    name: 'Passeio ao Jardim Botânico',
    scopeId: 'dev-group-estrelas',
    institutionId: 'dev-institution-aurora',
    unitId: 'dev-unit-lagoa',
    classId: 'dev-group-estrelas',
    scopeLevel: MealPlanScopeLevel.classLevel,
    sourceType: MealPlanSourceType.exception,
    dish: 'Sanduíche natural, maçã, bolo de banana e água',
    startDay: 18,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-cultural',
    name: 'Festival cultural — sabores das famílias',
    scopeId: 'dev-institution-aurora',
    institutionId: 'dev-institution-aurora',
    scopeLevel: MealPlanScopeLevel.institution,
    sourceType: MealPlanSourceType.institution,
    dish: 'Seleção de receitas familiares com alergênicos identificados',
    startDay: 25,
    status: MealPlanStatus.draft,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-adaptado',
    name: 'Adaptação alimentar de Miguel — consistência macia',
    scopeId: 'dev-child-miguel',
    institutionId: 'dev-institution-aurora',
    unitId: 'dev-unit-lagoa',
    classId: 'dev-group-estrelas',
    personId: 'dev-child-miguel',
    scopeLevel: MealPlanScopeLevel.person,
    sourceType: MealPlanSourceType.person,
    dish: 'Polenta cremosa, feijão amassado e carne moída',
    startDay: 2,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-ferias',
    name: 'Colônia de férias — verão com hidratação',
    scopeId: 'dev-unit-jardim',
    unitId: 'dev-unit-jardim',
    dish: 'Macarrão com legumes, melancia e suco sem açúcar',
    startDay: 9,
    status: MealPlanStatus.scheduled,
  ),
  _fixturePlan(
    id: 'dev-meal-plan-formacao',
    name: 'Encontro de formação das educadoras',
    scopeId: 'dev-institution',
    scopeLevel: MealPlanScopeLevel.institution,
    sourceType: MealPlanSourceType.exception,
    dish: 'Mesa de pães, patês, frutas e café',
    startDay: 16,
    month: 10,
    audience: MealPlanAudienceSegment.staff,
  ),
];

final _developmentTemplates = <MealPlanTemplate>[
  _fixtureTemplate('dev-template', 'Semana equilibrada para Educação Infantil'),
  _fixtureTemplate('dev-template-sensory', 'Aproximação alimentar e seletividade sensorial'),
  _fixtureTemplate('dev-template-lactose', 'Rotina sem lactose e derivados'),
  _fixtureTemplate('dev-template-integral', 'Lanches e refeições do período integral'),
  _fixtureTemplate('dev-template-outing', 'Passeios, visitas e atividades externas'),
];

MealPlan _fixturePlan({
  required String id,
  required String name,
  required String scopeId,
  required String dish,
  String institutionId = 'dev-institution',
  String? unitId,
  String? classId,
  String? personId,
  MealPlanScopeLevel scopeLevel = MealPlanScopeLevel.unit,
  MealPlanSourceType sourceType = MealPlanSourceType.unit,
  MealPlanStatus status = MealPlanStatus.published,
  MealPlanAudienceSegment audience = MealPlanAudienceSegment.students,
  int startDay = 24,
  int month = 9,
  bool requiresReview = false,
}) => MealPlan(
  id: id,
  tenantId: 'dev-tenant',
  institutionId: institutionId,
  unitId: unitId,
  classId: classId,
  personId: personId,
  name: name,
  status: status,
  sourceType: sourceType,
  scopeLevel: scopeLevel,
  scopeId: scopeId,
  startDate: DateTime(2026, month, startDay),
  endDate: DateTime(2026, month, startDay + 4),
  recurrence: MealPlanRecurrence(
    kind: MealPlanRecurrenceKind.weekly,
    weekdays: const {1, 2, 3, 4, 5},
  ),
  menu: [MealPlanMenuEntry(mealType: 'lunch', dishName: dish)],
  allergens: const [],
  alerts: const [],
  attachments: const [],
  priority: 10,
  conflictState: false,
  revision: 1,
  isDraft: status == MealPlanStatus.draft,
  requiresReview: requiresReview,
  createdBy: 'dev-user-nutrition',
  updatedBy: 'dev-user-nutrition',
  audienceSegment: audience,
);

MealPlanTemplate _fixtureTemplate(String id, String name) => MealPlanTemplate(
  id: id,
  tenantId: 'dev-tenant',
  institutionId: 'dev-institution',
  name: name,
  planVariant: MealPlanPlanVariant.complete,
  audienceSegment: MealPlanAudienceSegment.students,
  status: 'published',
  version: 1,
  payload: {
    'menu': [MealPlanMenuEntry(mealType: 'lunch', dishName: 'Prato principal').toJson()],
  },
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 28),
);

const _audienceOptions = MealPlanAudienceOptions(
  institutions: [
    MealPlanAudienceOption(id: 'dev-institution', label: 'Colégio Coelo'),
    MealPlanAudienceOption(id: 'dev-institution-horizonte', label: 'Instituto Horizonte'),
    MealPlanAudienceOption(id: 'dev-institution-aurora', label: 'Escola Aurora'),
  ],
  units: [
    MealPlanAudienceOption(
      id: 'dev-unit',
      label: 'Unidade Centro',
      institutionId: 'dev-institution',
    ),
    MealPlanAudienceOption(
      id: 'dev-unit-jardim',
      label: 'Unidade Jardim',
      institutionId: 'dev-institution',
    ),
    MealPlanAudienceOption(
      id: 'dev-unit-lagoa',
      label: 'Unidade Lagoa',
      institutionId: 'dev-institution-aurora',
    ),
  ],
  groups: [
    MealPlanAudienceOption(
      id: 'dev-group',
      label: 'Turma Girassol',
      institutionId: 'dev-institution',
      unitId: 'dev-unit',
    ),
    MealPlanAudienceOption(
      id: 'dev-group-nuvem',
      label: 'Berçário Nuvem',
      institutionId: 'dev-institution',
      unitId: 'dev-unit',
    ),
    MealPlanAudienceOption(
      id: 'dev-group-estrelas',
      label: 'Turma Estrelas',
      institutionId: 'dev-institution-aurora',
      unitId: 'dev-unit-lagoa',
    ),
    MealPlanAudienceOption(
      id: 'dev-group-sabiá',
      label: 'Turma Sabiá',
      institutionId: 'dev-institution-aurora',
      unitId: 'dev-unit-lagoa',
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
    MealPlanAudienceOption(
      id: 'dev-child-miguel',
      label: 'Miguel Nascimento',
      institutionId: 'dev-institution-aurora',
      unitId: 'dev-unit-lagoa',
      groupId: 'dev-group-estrelas',
      audienceSegment: MealPlanAudienceSegment.students,
    ),
  ],
);
