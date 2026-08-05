import '../../../app/activity/superadmin_activity.dart';
import '../../../app/prototype/superadmin_prototype_store.dart';
import '../domain/plan_catalog.dart';

final class FakePlanCatalogRepository {
  FakePlanCatalogRepository({
    required this.store,
    this.state = PlanDataState.ready,
    List<PlanCatalog>? plans,
  }) : _plans = List.of(plans ?? _fixtures);

  final SuperadminPrototypeStore store;
  final PlanDataState state;
  final List<PlanCatalog> _plans;

  List<PlanCatalog> get plans => List.unmodifiable(_plans);

  PlanCatalog? findById(String id) => _plans.where((plan) => plan.id == id).firstOrNull;

  List<PlanCatalog> query({String search = '', PlanStatus? status, PlanFeature? feature}) =>
      _filtered(search: search, status: status, feature: feature);

  PlanPage queryPage(PlanQuery query) {
    final filtered = _filtered(search: query.search, status: query.status, feature: query.feature);
    final start = ((query.page - 1) * query.pageSize).clamp(0, filtered.length);
    final end = (start + query.pageSize).clamp(start, filtered.length);
    return PlanPage(
      items: filtered.sublist(start, end),
      totalItems: filtered.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  List<PlanCatalog> _filtered({required String search, PlanStatus? status, PlanFeature? feature}) {
    final term = search.trim().toLowerCase();
    return _plans
        .where(
          (plan) =>
              (term.isEmpty || '${plan.name} ${plan.code}'.toLowerCase().contains(term)) &&
              (status == null || plan.status == status) &&
              (feature == null || plan.features.contains(feature)),
        )
        .toList();
  }

  void create(PlanDraft draft, {required String reason}) {
    _validateReason(reason);
    if (_plans.any((plan) => plan.code == draft.code)) {
      throw StateError('Já existe um plano com este código.');
    }
    _plans.add(draft.toPlan());
    _emit('criou', draft.id, draft.name, reason: reason, after: {'code': draft.code});
  }

  void update(PlanCatalog plan, {required String reason}) {
    _validateReason(reason);
    final index = _plans.indexWhere((item) => item.id == plan.id);
    if (index < 0) throw StateError('Plano não encontrado.');
    final current = _plans[index];
    if (current.revision != plan.revision) throw const PlanConflictException();
    _plans[index] = plan.copyWith(revision: plan.revision + 1);
    _emit(
      'atualizou',
      plan.id,
      plan.name,
      reason: reason,
      before: {'status': current.status.name},
      after: {'status': plan.status.name},
    );
  }

  void archive(String id, {required String reason}) =>
      _changeStatus(id, PlanStatus.archived, action: 'arquivou', reason: reason);

  void restore(String id, {required String reason}) =>
      _changeStatus(id, PlanStatus.active, action: 'restaurou', reason: reason);

  void _changeStatus(
    String id,
    PlanStatus status, {
    required String action,
    required String reason,
  }) {
    _validateReason(reason);
    final index = _plans.indexWhere((plan) => plan.id == id);
    if (index < 0) throw StateError('Plano não encontrado.');
    final current = _plans[index];
    if (current.status == status) return;
    _plans[index] = current.copyWith(status: status, revision: current.revision + 1);
    _emit(
      action,
      current.id,
      current.name,
      reason: reason,
      before: {'status': current.status.name},
      after: {'status': status.name},
    );
  }

  List<PlanLinkedInstitution> linkedInstitutions(String planId) =>
      List.unmodifiable(_linkedInstitutions[planId] ?? const []);

  void _validateReason(String reason) {
    if (reason.trim().isEmpty) throw ArgumentError.value(reason, 'reason', 'Informe o motivo.');
  }

  void _emit(
    String action,
    String id,
    String name, {
    required String reason,
    Map<String, String> before = const {},
    Map<String, String> after = const {},
  }) {
    store.recordActivity(
      kind: SuperadminActivityKind.announcement,
      subject: 'Planos',
      summary: 'Plano $name: $action.',
    );
    store.recordAuditEvent(
      module: 'Planos',
      action: action,
      objectType: 'plano',
      objectId: id,
      risk: PrototypeAuditRisk.medium,
      before: before,
      after: {...after, 'reason': reason.trim()},
    );
  }
}

final class PlanConflictException implements Exception {
  const PlanConflictException();
}

const _fixtures = [
  PlanCatalog(
    id: 'coelo-essential',
    name: 'Coelo Essencial',
    code: 'coelo-essential',
    description: 'Comunicação, agenda e convites.',
    status: PlanStatus.active,
    features: {PlanFeature.communication, PlanFeature.agenda, PlanFeature.invitations},
    limits: PlanLimits(units: 2, memberships: 500, storageGb: 25, mediaGb: 5),
    usedByInstitutionCount: 2,
  ),
  PlanCatalog(
    id: 'coelo-connect',
    name: 'Coelo Conecta',
    code: 'coelo-connect',
    description: 'Chat e avisos segmentados.',
    status: PlanStatus.active,
    features: {
      PlanFeature.communication,
      PlanFeature.agenda,
      PlanFeature.invitations,
      PlanFeature.chat,
      PlanFeature.notices,
    },
    limits: PlanLimits(units: 5, memberships: 1500, storageGb: 100, mediaGb: 20),
    usedByInstitutionCount: 1,
  ),
  PlanCatalog(
    id: 'coelo-care',
    name: 'Coelo Cuidado',
    code: 'coelo-care',
    description: 'Rotina, Happens e Now.',
    status: PlanStatus.active,
    features: {
      PlanFeature.communication,
      PlanFeature.agenda,
      PlanFeature.invitations,
      PlanFeature.chat,
      PlanFeature.notices,
      PlanFeature.routine,
      PlanFeature.happens,
      PlanFeature.now,
    },
    limits: PlanLimits(units: 15, memberships: 5000, storageGb: 500, mediaGb: 100),
    usedByInstitutionCount: 1,
  ),
  PlanCatalog(
    id: 'coelo-integral',
    name: 'Coelo Integral',
    code: 'coelo-integral',
    description: 'Todas as capacidades locais disponíveis.',
    status: PlanStatus.archived,
    features: {
      PlanFeature.communication,
      PlanFeature.agenda,
      PlanFeature.invitations,
      PlanFeature.chat,
      PlanFeature.notices,
      PlanFeature.routine,
      PlanFeature.happens,
      PlanFeature.now,
      PlanFeature.moments,
    },
    limits: PlanLimits(units: 50, memberships: 20000, storageGb: 2000, mediaGb: 500),
  ),
];

final _linkedInstitutions = <String, List<PlanLinkedInstitution>>{
  'coelo-essential': [
    PlanLinkedInstitution(
      id: 'casa-nuvem',
      name: 'Casa Nuvem',
      subscriptionStatus: 'Ativa',
      startsAt: DateTime.utc(2026, 1, 15),
      unitsWithOverride: 0,
    ),
    PlanLinkedInstitution(
      id: 'escola-estacao',
      name: 'Escola Estação',
      subscriptionStatus: 'Em teste',
      startsAt: DateTime.utc(2026, 7, 1),
      unitsWithOverride: 1,
    ),
  ],
  'coelo-connect': [
    PlanLinkedInstitution(
      id: 'centro-bem-te-vi',
      name: 'Centro Bem-Te-Vi',
      subscriptionStatus: 'Ativa',
      startsAt: DateTime.utc(2026, 3, 10),
      unitsWithOverride: 0,
    ),
  ],
  'coelo-care': [
    PlanLinkedInstitution(
      id: 'colegio-raizes',
      name: 'Colégio Raízes',
      subscriptionStatus: 'Ativa',
      startsAt: DateTime.utc(2026, 2, 20),
      unitsWithOverride: 2,
    ),
  ],
};
