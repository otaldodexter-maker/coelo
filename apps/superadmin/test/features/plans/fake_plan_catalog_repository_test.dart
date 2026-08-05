import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/plans/data/fake_plan_catalog_repository.dart';
import 'package:coelo_superadmin/features/plans/domain/plan_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SuperadminActivityController activity;
  late SuperadminPrototypeStore store;
  late FakePlanCatalogRepository repository;

  setUp(() {
    activity = SuperadminActivityController();
    store = SuperadminPrototypeStore(activityController: activity);
    repository = FakePlanCatalogRepository(store: store);
  });

  test('exposes the four approved catalog fixtures', () {
    expect(repository.plans.map((plan) => plan.code), [
      'coelo-essential',
      'coelo-connect',
      'coelo-care',
      'coelo-integral',
    ]);
    expect(repository.plans.last.limits.mediaGb, 500);
  });

  test('filters plans by search, status and feature', () {
    final result = repository.query(
      search: 'cuidado',
      status: PlanStatus.active,
      feature: PlanFeature.happens,
    );

    expect(result.single.code, 'coelo-care');
  });

  test('paginates independently for cards and table queries', () {
    final page = repository.queryPage(const PlanQuery(page: 1, pageSize: 2));

    expect(page.items, hasLength(2));
    expect(page.totalItems, 4);
    expect(page.totalPages, 2);
  });

  test('creates a plan with exactly one activity and audit event', () {
    repository.create(_draft('novo'), reason: 'Novo catálogo aprovado.');

    expect(repository.findById('novo')?.name, 'Coelo Novo');
    expect(activity.activities, hasLength(1));
    expect(store.auditEvents, hasLength(1));
  });

  test('archives and restores a used plan with an audit reason', () {
    final used = repository.plans.first.copyWith(usedByInstitutionCount: 1);
    repository.update(used, reason: 'Atualização inicial.');
    final beforeEvents = store.auditEvents.length;

    repository.archive(used.id, reason: 'Plano substituído.');
    expect(repository.findById(used.id)?.status, PlanStatus.archived);
    expect(store.auditEvents, hasLength(beforeEvents + 1));

    repository.restore(used.id, reason: 'Plano disponível novamente.');
    expect(repository.findById(used.id)?.status, PlanStatus.active);
  });

  test('rejects audited mutations without a reason', () {
    expect(() => repository.archive(repository.plans.first.id, reason: '  '), throwsArgumentError);
  });

  test('rejects a stale edit and preserves the current plan', () {
    final staleDraft = repository.plans.first;
    repository.update(staleDraft.copyWith(name: 'Nome atual'), reason: 'Primeira edição.');

    expect(
      () => repository.update(staleDraft.copyWith(name: 'Nome antigo'), reason: 'Edição obsoleta.'),
      throwsA(isA<PlanConflictException>()),
    );
    expect(repository.findById(staleDraft.id)?.name, 'Nome atual');
  });

  test('exposes linked institutions as read-only subscription summaries', () {
    final links = repository.linkedInstitutions('coelo-essential');

    expect(links, isNotEmpty);
    expect(links.first.subscriptionStatus, isNotEmpty);
    expect(links.first.unitsWithOverride, greaterThanOrEqualTo(0));
  });
}

PlanDraft _draft(String id) => PlanDraft(
  id: id,
  name: 'Coelo Novo',
  code: 'coelo-novo',
  description: 'Plano local para demonstracao.',
  status: PlanStatus.active,
  features: {PlanFeature.agenda},
  limits: const PlanLimits(units: 1, memberships: 10, storageGb: 1, mediaGb: 1),
);
