import '../../../app/activity/superadmin_activity.dart';
import '../../../app/prototype/superadmin_prototype_store.dart';
import '../domain/plan_catalog.dart';

final class FakePlanCatalogRepository {
  FakePlanCatalogRepository({required this.store}) : _plans = List.of(_fixtures);
  final SuperadminPrototypeStore store;
  final List<PlanCatalog> _plans;
  List<PlanCatalog> get plans => List.unmodifiable(_plans);
  PlanCatalog? findById(String id) => _plans.where((plan) => plan.id == id).firstOrNull;
  List<PlanCatalog> query({String search = '', PlanStatus? status, PlanFeature? feature}) {
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

  void create(PlanDraft draft) {
    _plans.add(draft.toPlan());
    _emit('criou', draft.id, draft.name, after: {'name': draft.name, 'code': draft.code});
  }

  void update(PlanCatalog plan) {
    final index = _plans.indexWhere((item) => item.id == plan.id);
    if (index < 0) return;
    _plans[index] = plan;
    _emit('atualizou', plan.id, plan.name, after: {'name': plan.name, 'status': plan.status.name});
  }

  bool delete(String id, {bool confirmed = false}) {
    final plan = findById(id);
    if (plan == null) return false;
    if (plan.usedByInstitutionCount > 0) {
      if (plan.status != PlanStatus.archived) update(plan.copyWith(status: PlanStatus.archived));
      return false;
    }
    if (!confirmed) return false;
    _plans.remove(plan);
    _emit('excluiu', plan.id, plan.name, before: {'name': plan.name});
    return true;
  }

  void _emit(
    String action,
    String id,
    String name, {
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
      after: after,
    );
  }
}

const _fixtures = [
  PlanCatalog(
    id: 'coelo-essential',
    name: 'Coelo Essencial',
    code: 'coelo-essential',
    description: 'Comunicação, agenda e convites.',
    status: PlanStatus.active,
    features: {PlanFeature.communication, PlanFeature.agenda, PlanFeature.invitations},
    unitLimit: 2,
    userLimit: 500,
    guardiansPerChild: 2,
    storageGb: 25,
    mediaGb: 5,
    manualOperation: false,
    internalNotes: '',
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
    unitLimit: 5,
    userLimit: 1500,
    guardiansPerChild: 3,
    storageGb: 100,
    mediaGb: 20,
    manualOperation: false,
    internalNotes: '',
  ),
  PlanCatalog(
    id: 'coelo-care',
    name: 'Coelo Cuidado',
    code: 'coelo-care',
    description: 'Rotina, Flow e Now.',
    status: PlanStatus.active,
    features: {
      PlanFeature.communication,
      PlanFeature.agenda,
      PlanFeature.invitations,
      PlanFeature.chat,
      PlanFeature.notices,
      PlanFeature.routine,
      PlanFeature.flow,
      PlanFeature.now,
    },
    unitLimit: 15,
    userLimit: 5000,
    guardiansPerChild: 4,
    storageGb: 500,
    mediaGb: 100,
    manualOperation: false,
    internalNotes: '',
  ),
  PlanCatalog(
    id: 'coelo-integral',
    name: 'Coelo Integral',
    code: 'coelo-integral',
    description: 'Todos os módulos.',
    status: PlanStatus.active,
    features: {
      PlanFeature.communication,
      PlanFeature.agenda,
      PlanFeature.invitations,
      PlanFeature.chat,
      PlanFeature.notices,
      PlanFeature.routine,
      PlanFeature.flow,
      PlanFeature.now,
      PlanFeature.moments,
    },
    unitLimit: 50,
    userLimit: 20000,
    guardiansPerChild: 6,
    storageGb: 2000,
    mediaGb: 500,
    manualOperation: false,
    internalNotes: '',
  ),
];
