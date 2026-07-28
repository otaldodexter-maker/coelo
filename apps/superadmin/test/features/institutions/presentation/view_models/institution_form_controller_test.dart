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

  test('postal code accepts exactly eight digits', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);

    for (final invalidValue in ['123', '01310-100', 'CEP 01310100']) {
      controller.setText(InstitutionFormField.postalCode, invalidValue);
      expect(
        controller.errorForForced(InstitutionFormField.postalCode),
        'Informe um CEP com exatamente 8 dígitos.',
        reason: invalidValue,
      );
    }

    controller.setText(InstitutionFormField.postalCode, '01310100');
    expect(controller.errorForForced(InstitutionFormField.postalCode), isNull);
  });

  test('profile bio accepts 220 characters and clips the 221st', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    final exactlyAtLimit = List.filled(220, 'a').join();

    controller.setText(InstitutionFormField.profileBio, exactlyAtLimit);
    expect(controller.text(InstitutionFormField.profileBio), exactlyAtLimit);

    controller.setText(InstitutionFormField.profileBio, '${exactlyAtLimit}b');
    expect(controller.text(InstitutionFormField.profileBio), exactlyAtLimit);
  });

  test('profile links require a complete pair and persist a valid URL', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);

    controller.setText(InstitutionFormField.link1Label, 'Portal');
    expect(controller.errorForForced(InstitutionFormField.link1Url), isNotNull);

    controller.setText(InstitutionFormField.link1Url, 'portal.example');
    expect(controller.errorForForced(InstitutionFormField.link1Url), contains('http://'));

    controller.setText(InstitutionFormField.link1Url, 'https://portal.example');
    expect(controller.errorForForced(InstitutionFormField.link1Url), isNull);

    final saved = controller.toRecord(id: 'new-institution');
    expect(saved.profileLinks, hasLength(1));
    expect(saved.profileLinks.single.label, 'Portal');
    expect(saved.profileLinks.single.url, 'https://portal.example');
  });
}
