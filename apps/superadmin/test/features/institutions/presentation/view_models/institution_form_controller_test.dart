import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:coelo_superadmin/features/institutions/presentation/view_models/institution_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create mode starts empty and suggests an editable slug', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);

    controller.setText(InstitutionFormField.publicName, 'Colégio São Lucas');
    expect(controller.text(InstitutionFormField.slug), 'colegio-sao-lucas');

    controller.setText(InstitutionFormField.slug, 'slug-manual', userInitiated: true);
    controller.setText(InstitutionFormField.publicName, 'Outro nome');
    expect(controller.text(InstitutionFormField.slug), 'slug-manual');
  });

  test('edit mode loads one record into the same controller', () {
    final record = FakeInstitutionDirectoryRepository().records.first;
    final controller = InstitutionFormController(record: record);
    addTearDown(controller.dispose);

    expect(controller.text(InstitutionFormField.publicName), record.publicName);
    expect(controller.text(InstitutionFormField.ownerEmail), record.ownerEmail);
    expect(controller.plan, record.plan);
  });

  test('leaving an invalid step marks it with error without blocking navigation', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);

    controller.continueFromCurrentStep();

    expect(controller.currentStep, InstitutionFormStep.profile);
    expect(controller.statusOf(InstitutionFormStep.branding), InstitutionFormStepStatus.error);
  });

  test('trial subscriptions require an end date only at completion', () {
    final controller = InstitutionFormController(
      record: FakeInstitutionDirectoryRepository().records.first,
    );
    addTearDown(controller.dispose);

    controller
      ..setSubscriptionStatus(InstitutionSubscriptionStatus.trial)
      ..setTrialEnd(null)
      ..selectStep(InstitutionFormStep.review);

    expect(controller.validateAll(), isFalse);
    expect(controller.currentStep, InstitutionFormStep.plan);
    expect(controller.trialEndError, 'Selecione quando o período de teste termina.');
  });

  test('starting a trial suggests today and thirty days later', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    controller.setSubscriptionStatus(InstitutionSubscriptionStatus.trial);

    expect(controller.subscriptionStart, today);
    expect(controller.trialEnd, today.add(const Duration(days: 30)));
  });

  test('trial end cannot precede its start', () {
    final controller = InstitutionFormController(
      record: FakeInstitutionDirectoryRepository().records.first,
    );
    addTearDown(controller.dispose);

    controller
      ..setSubscriptionStatus(InstitutionSubscriptionStatus.trial)
      ..setSubscriptionStart(DateTime(2026, 7, 28))
      ..setTrialEnd(DateTime(2026, 7, 27))
      ..selectStep(InstitutionFormStep.plan)
      ..continueFromCurrentStep();

    expect(controller.trialEndError, 'A data final não pode ser anterior à data de início.');
  });
}
