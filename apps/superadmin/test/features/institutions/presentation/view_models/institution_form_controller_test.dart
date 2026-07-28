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

  test('create requires a legal representative while edit accepts none', () {
    final createController = InstitutionFormController()
      ..selectStep(InstitutionFormStep.legalRepresentatives);
    final editController = InstitutionFormController(
      record: FakeInstitutionDirectoryRepository().records.first,
    )..selectStep(InstitutionFormStep.legalRepresentatives);
    addTearDown(createController.dispose);
    addTearDown(editController.dispose);

    expect(createController.validateCurrentStep(), isFalse);
    expect(createController.legalRepresentativesError, isNotNull);

    editController.removeLegalRepresentative(editController.legalRepresentatives.single.id);
    expect(editController.validateCurrentStep(), isTrue);
  });

  test('legal representatives can be added, edited and removed independently', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);

    controller
      ..addLegalRepresentative(
        const InstitutionPersonDraft(
          firstName: 'Ana',
          lastName: 'Souza',
          displayName: 'Ana Souza',
          email: 'ana@example.com',
          mobilePhone: '+55 11 99999-0001',
        ),
      )
      ..addLegalRepresentative(
        const InstitutionPersonDraft(
          firstName: 'Caio',
          lastName: 'Lima',
          displayName: 'Caio Lima',
          email: 'caio@example.com',
          mobilePhone: '+55 11 99999-0002',
        ),
      );

    final ana = controller.legalRepresentatives.first;
    controller.updateLegalRepresentative(ana.id, ana.person.copyWith(displayName: 'Ana S.'));
    controller.removeLegalRepresentative(controller.legalRepresentatives.last.id);

    expect(controller.legalRepresentatives, hasLength(1));
    expect(controller.legalRepresentatives.single.person.displayName, 'Ana S.');
  });

  test('legal representatives become admin master only after explicit confirmation', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    controller.addLegalRepresentative(
      const InstitutionPersonDraft(
        firstName: 'Ana',
        lastName: 'Souza',
        displayName: 'Ana Souza',
        email: 'ana@example.com',
        mobilePhone: '+55 11 99999-0001',
      ),
    );
    final representativeId = controller.legalRepresentatives.single.id;

    expect(controller.recommendedAdministratorRepresentativeIds, {representativeId});
    expect(controller.administrators, isEmpty);

    controller.confirmRepresentativeAdministrators({representativeId});

    expect(controller.administrators, hasLength(1));
    expect(controller.administrators.single.level, InstitutionAdministratorLevel.adminMaster);
    expect(controller.administrators.single.invitationStatus, InstitutionInvitationStatus.notSent);
  });

  test('sending an invitation changes local state and records history', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    controller.addAdministrator(
      const InstitutionPersonDraft(
        firstName: 'Bia',
        lastName: 'Nunes',
        displayName: 'Bia Nunes',
        email: 'bia@example.com',
        mobilePhone: '+55 11 99999-0003',
      ),
      level: InstitutionAdministratorLevel.authorizedAdministrator,
    );
    final administrator = controller.administrators.single;

    controller.sendAdministratorInvitation(administrator.id);

    expect(controller.administrators.single.invitationStatus, InstitutionInvitationStatus.sent);
    expect(controller.administrators.single.invitationHistory, hasLength(1));
    expect(
      controller.administrators.single.invitationHistory.single.status,
      InstitutionInvitationStatus.sent,
    );
  });

  test('removing every representative clears the legacy owner on edit save', () {
    final record = FakeInstitutionDirectoryRepository().records.first;
    final controller = InstitutionFormController(record: record);
    addTearDown(controller.dispose);

    controller.removeLegalRepresentative(controller.legalRepresentatives.single.id);
    final saved = controller.toRecord(id: record.id);

    expect(saved.ownerFirstName, isEmpty);
    expect(saved.ownerLastName, isEmpty);
    expect(saved.ownerDisplayName, isEmpty);
    expect(saved.ownerEmail, isEmpty);
    expect(saved.ownerMobilePhone, isEmpty);
  });

  test('accepted and expired invitation transitions append timestamped history', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    controller.addAdministrator(
      const InstitutionPersonDraft(
        firstName: 'Bia',
        lastName: 'Nunes',
        displayName: 'Bia Nunes',
        email: 'bia@example.com',
        mobilePhone: '+55 11 99999-0003',
      ),
      level: InstitutionAdministratorLevel.authorizedAdministrator,
    );
    final acceptedId = controller.administrators.single.id;
    controller.addAdministrator(
      const InstitutionPersonDraft(
        firstName: 'Davi',
        lastName: 'Reis',
        displayName: 'Davi Reis',
        email: 'davi@example.com',
        mobilePhone: '+55 11 99999-0004',
      ),
      level: InstitutionAdministratorLevel.coordinator,
    );
    final expiredId = controller.administrators.last.id;

    controller
      ..sendAdministratorInvitation(acceptedId)
      ..setAdministratorInvitationStatus(acceptedId, InstitutionInvitationStatus.accepted)
      ..sendAdministratorInvitation(expiredId)
      ..setAdministratorInvitationStatus(expiredId, InstitutionInvitationStatus.expired);

    expect(controller.administrators.first.invitationHistory.map((event) => event.status), [
      InstitutionInvitationStatus.sent,
      InstitutionInvitationStatus.accepted,
    ]);
    expect(controller.administrators.last.invitationHistory.map((event) => event.status), [
      InstitutionInvitationStatus.sent,
      InstitutionInvitationStatus.expired,
    ]);
    expect(
      controller.administrators
          .expand((administrator) => administrator.invitationHistory)
          .every((event) => event.occurredAt.millisecondsSinceEpoch > 0),
      isTrue,
    );
  });

  test('derived admin follows representative edits and removal', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    controller.addLegalRepresentative(
      const InstitutionPersonDraft(
        firstName: 'Ana',
        lastName: 'Souza',
        displayName: 'Ana Souza',
        email: 'ana@example.com',
        mobilePhone: '+55 11 99999-0001',
      ),
    );
    final representative = controller.legalRepresentatives.single;
    controller.confirmRepresentativeAdministrators({representative.id});

    controller.updateLegalRepresentative(
      representative.id,
      representative.person.copyWith(displayName: 'Ana S.'),
    );
    expect(controller.administrators.single.person.displayName, 'Ana S.');

    controller.removeLegalRepresentative(representative.id);
    expect(controller.administrators, isEmpty);
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
