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
    expect(repository.plans.last.mediaGb, 500);
  });

  test('filters plans by search, status and feature', () {
    final result = repository.query(
      search: 'cuidado',
      status: PlanStatus.active,
      feature: PlanFeature.flow,
    );

    expect(result.single.code, 'coelo-care');
  });

  test('creates a plan with exactly one activity and audit event', () {
    repository.create(_draft('novo'));

    expect(repository.findById('novo')?.name, 'Coelo Novo');
    expect(activity.activities, hasLength(1));
    expect(store.auditEvents, hasLength(1));
  });

  test('archives a used plan and blocks permanent deletion', () {
    final used = repository.plans.first.copyWith(usedByInstitutionCount: 1);
    repository.update(used);
    final beforeEvents = store.auditEvents.length;

    expect(repository.delete(used.id), isFalse);
    expect(repository.findById(used.id)?.status, PlanStatus.archived);
    expect(store.auditEvents, hasLength(beforeEvents + 1));
  });

  test('deletes a never used plan after confirmation', () {
    final plan = repository.plans.first;

    expect(repository.delete(plan.id, confirmed: true), isTrue);
    expect(repository.findById(plan.id), isNull);
  });
}

PlanDraft _draft(String id) => PlanDraft(
  id: id,
  name: 'Coelo Novo',
  code: 'coelo-novo',
  description: 'Plano local para demonstracao.',
  status: PlanStatus.active,
  features: {PlanFeature.agenda},
  unitLimit: 1,
  userLimit: 10,
  guardiansPerChild: 1,
  storageGb: 1,
  mediaGb: 1,
  manualOperation: false,
  internalNotes: '',
);
