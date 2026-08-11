import 'dart:typed_data';

import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:coelo_superadmin/features/institutions/presentation/view_models/institution_form_controller.dart';
import 'package:flutter/material.dart';
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

  test('create and edit require at least one representative and administrator', () {
    final createController = InstitutionFormController()
      ..selectStep(InstitutionFormStep.legalRepresentatives);
    final editController = InstitutionFormController(
      record: FakeInstitutionDirectoryRepository().records.first,
    )..selectStep(InstitutionFormStep.legalRepresentatives);
    addTearDown(createController.dispose);
    addTearDown(editController.dispose);

    expect(createController.validateCurrentStep(), isFalse);
    expect(createController.legalRepresentativesError, isNotNull);

    expect(
      editController.removeLegalRepresentative(editController.legalRepresentatives.single.id),
      isFalse,
    );
    expect(editController.legalRepresentatives, hasLength(1));

    editController.selectStep(InstitutionFormStep.administrators);
    expect(editController.validateCurrentStep(), isFalse);
    expect(editController.administratorsError, isNotNull);
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

  test('the last representative cannot be removed', () {
    final record = FakeInstitutionDirectoryRepository().records.first;
    final controller = InstitutionFormController(record: record);
    addTearDown(controller.dispose);

    expect(
      controller.removeLegalRepresentative(controller.legalRepresentatives.single.id),
      isFalse,
    );
    expect(controller.peopleRuleMessage, contains('outro representante'));
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

  test('derived admin remains independent and synchronizes only on request', () {
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
    expect(controller.administrators.single.person.displayName, 'Ana Souza');

    final administrator = controller.administrators.single;
    controller.syncRepresentativeToAdministrator(administrator.id);
    expect(controller.administrators.single.person.displayName, 'Ana S.');

    controller.updateAdministrator(
      administrator.id,
      person: administrator.person.copyWith(displayName: 'Ana Admin'),
      level: administrator.level,
    );
    expect(controller.legalRepresentatives.single.person.displayName, 'Ana S.');

    controller.syncAdministratorToRepresentative(administrator.id);
    expect(controller.legalRepresentatives.single.person.displayName, 'Ana Admin');
  });

  test('optional contact fields validate only when filled and CPF is formatted', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    const minimal = InstitutionPersonDraft(
      firstName: 'Ana',
      lastName: 'Souza',
      displayName: 'Ana Souza',
      email: '',
      mobilePhone: '',
    );

    expect(controller.isPersonValid(minimal), isTrue);
    expect(
      controller.personError(minimal.copyWith(email: 'invalido'), InstitutionPersonField.email),
      isNotNull,
    );
    expect(
      controller.personError(
        minimal.copyWith(mobilePhone: '123'),
        InstitutionPersonField.mobilePhone,
      ),
      isNotNull,
    );
    expect(controller.formatCpf('52998224725'), '529.982.247-25');
    expect(
      controller.personError(minimal.copyWith(cpf: '111.111.111-11'), InstitutionPersonField.cpf),
      isNotNull,
    );
  });

  test('administrator handles are unique, accentless and stable after edits', () {
    final controller = InstitutionFormController(reservedHandles: const {'@ana-souza'});
    addTearDown(controller.dispose);
    const person = InstitutionPersonDraft(
      firstName: 'Ana',
      lastName: 'Souza',
      displayName: 'Ána Souza',
      email: '',
      mobilePhone: '',
    );

    controller
      ..addAdministrator(person, level: InstitutionAdministratorLevel.authorizedAdministrator)
      ..addAdministrator(person, level: InstitutionAdministratorLevel.coordinator);

    expect(controller.administrators.map((administrator) => administrator.handle), [
      '@ana-souza-2',
      '@ana-souza-3',
    ]);
    final first = controller.administrators.first;
    controller.updateAdministrator(
      first.id,
      person: first.person.copyWith(displayName: 'Outro nome'),
      level: first.level,
    );
    expect(controller.administrators.first.handle, '@ana-souza-2');

    final ownSlugController = InstitutionFormController();
    addTearDown(ownSlugController.dispose);
    ownSlugController
      ..setText(InstitutionFormField.slug, 'ana-souza')
      ..addAdministrator(person, level: InstitutionAdministratorLevel.authorizedAdministrator);
    expect(ownSlugController.administrators.single.handle, '@ana-souza-2');

    ownSlugController.setText(InstitutionFormField.slug, 'ana-souza-2');
    ownSlugController.validateCurrentStep();
    expect(ownSlugController.errorFor(InstitutionFormField.slug), 'Este @ já está em uso.');
  });

  test('role removal detaches the link without deleting the other role', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    const ana = InstitutionPersonDraft(
      firstName: 'Ana',
      lastName: 'Souza',
      displayName: 'Ana Souza',
      email: '',
      mobilePhone: '',
    );
    const bia = InstitutionPersonDraft(
      firstName: 'Bia',
      lastName: 'Nunes',
      displayName: 'Bia Nunes',
      email: '',
      mobilePhone: '',
    );
    controller
      ..addLegalRepresentative(ana)
      ..addLegalRepresentative(bia);
    final anaId = controller.legalRepresentatives.first.id;
    controller.confirmRepresentativeAdministrators({anaId});
    controller.addAdministrator(bia, level: InstitutionAdministratorLevel.coordinator);

    expect(controller.removeLegalRepresentative(anaId), isTrue);
    expect(controller.administrators, hasLength(2));
    expect(controller.administrators.first.sourceRepresentativeId, isNull);
  });

  test('invite without email requests editing and valid save sends immediately', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    controller.addAdministrator(
      const InstitutionPersonDraft(
        firstName: 'Ana',
        lastName: 'Souza',
        displayName: 'Ana Souza',
        email: '',
        mobilePhone: '',
      ),
      level: InstitutionAdministratorLevel.adminMaster,
    );
    final administrator = controller.administrators.single;

    expect(controller.sendAdministratorInvitation(administrator.id), isFalse);
    expect(controller.administratorNeedingEmailId, administrator.id);

    controller.updateAdministrator(
      administrator.id,
      person: administrator.person,
      level: administrator.level,
      sendInvitationAfterSave: true,
    );
    expect(controller.administrators.single.invitationStatus, InstitutionInvitationStatus.notSent);
    expect(controller.administratorNeedingEmailId, administrator.id);

    controller.updateAdministrator(
      administrator.id,
      person: administrator.person.copyWith(email: 'ana@example.com'),
      level: administrator.level,
      sendInvitationAfterSave: true,
    );
    expect(controller.administrators.single.invitationStatus, InstitutionInvitationStatus.sent);
    expect(controller.administratorNeedingEmailId, isNull);
  });

  test('people lists and secondary surface persist in the in-memory record', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    const person = InstitutionPersonDraft(
      firstName: 'Ana',
      lastName: 'Souza',
      displayName: 'Ana Souza',
      email: '',
      mobilePhone: '',
    );
    controller
      ..addLegalRepresentative(person)
      ..addAdministrator(person, level: InstitutionAdministratorLevel.adminMaster)
      ..setText(InstitutionFormField.secondarySurfaceColor, '#F4F5F5');

    final record = controller.toRecord(id: 'institution-local');
    expect(record.legalRepresentatives, hasLength(1));
    expect(record.administrators, hasLength(1));
    expect(record.secondarySurfaceColor, '#F4F5F5');

    final restored = InstitutionFormController(record: record);
    addTearDown(restored.dispose);
    expect(restored.legalRepresentatives, hasLength(1));
    expect(restored.administrators, hasLength(1));
    expect(restored.administrators.single.handle, controller.administrators.single.handle);
  });

  test('restored people ids continue after the greatest persisted suffix', () {
    const person = InstitutionPersonDraft(
      firstName: 'Ana',
      lastName: 'Souza',
      displayName: 'Ana Souza',
    );
    final record = FakeInstitutionDirectoryRepository().records.first.copyWith(
      legalRepresentatives: const [
        InstitutionLegalRepresentative(id: 'representative-7', person: person),
      ],
    );
    final controller = InstitutionFormController(record: record);
    addTearDown(controller.dispose);

    controller.addLegalRepresentative(person);

    expect(controller.legalRepresentatives.last.id, 'representative-8');
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

    controller.confirmRepresentativeAdministrators({controller.legalRepresentatives.single.id});
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

  test('profile bio inserts an emoji at the cursor and counts graphemes', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    controller.setText(InstitutionFormField.profileBio, 'Olá mundo');
    controller.controllerOf(InstitutionFormField.profileBio).selection =
        const TextSelection.collapsed(offset: 4);

    controller.insertProfileBioEmoji('👨‍👩‍👧‍👦');

    expect(controller.text(InstitutionFormField.profileBio), 'Olá 👨‍👩‍👧‍👦mundo');
    expect(controller.profileBioLength, 10);
    expect(
      controller.controllerOf(InstitutionFormField.profileBio).selection.baseOffset,
      4 + '👨‍👩‍👧‍👦'.length,
    );
  });

  test('administrator avatar remains local and persists in the in-memory record', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    controller.addAdministrator(
      const InstitutionPersonDraft(firstName: 'Ana', lastName: 'Souza', displayName: 'Ana Souza'),
      level: InstitutionAdministratorLevel.adminMaster,
    );
    final administrator = controller.administrators.single;

    controller.setAdministratorAvatar(
      administrator.id,
      bytes: Uint8List.fromList(const [1, 2, 3]),
      fileName: 'avatar.png',
    );

    final saved = controller.toRecord(id: 'institution-local');
    expect(saved.administrators.single.avatarFileName, 'avatar.png');
    expect(saved.administrators.single.avatarBytes, [1, 2, 3]);

    final restored = InstitutionFormController(record: saved);
    addTearDown(restored.dispose);
    expect(restored.isDirty, isFalse);
    restored.setAdministratorAvatar(
      restored.administrators.single.id,
      bytes: Uint8List.fromList(const [4, 5, 6]),
      fileName: 'avatar.png',
    );
    expect(restored.isDirty, isTrue);

    controller.removeAdministratorAvatar(administrator.id);
    expect(controller.administrators.single.avatarBytes, isNull);
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

  test('loads masked contacts and persists phone and celular as E.164', () {
    final source = FakeInstitutionDirectoryRepository().records.first;
    final controller = InstitutionFormController(record: source);
    addTearDown(controller.dispose);

    expect(controller.text(InstitutionFormField.contactPhone), startsWith('+55 ('));
    controller.setText(InstitutionFormField.contactPhone, '+55 (11) 3333-4444');
    controller.setText(InstitutionFormField.whatsappNumber, '+55 (11) 99999-4444');

    final saved = controller.toRecord(id: source.id);
    expect(saved.contactPhone, '+551133334444');
    expect(saved.whatsappNumber, '+5511999994444');
  });
  test('new core record does not invent units and edit preserves loaded units', () {
    final createController = InstitutionFormController();
    final source = FakeInstitutionDirectoryRepository().records.first;
    final editController = InstitutionFormController(record: source);
    addTearDown(createController.dispose);
    addTearDown(editController.dispose);

    expect(createController.toRecord(id: '').units, isEmpty);
    expect(editController.toRecord(id: source.id).units, same(source.units));
  });

  test('detects every local media kind that has no persistence contract', () {
    final controller = InstitutionFormController();
    addTearDown(controller.dispose);
    expect(controller.hasUnpersistedMedia, isFalse);
    expect(controller.saveContractError, isNull);

    controller.logoBytes = Uint8List.fromList(const [1]);
    expect(controller.hasUnpersistedMedia, isTrue);
    controller.logoBytes = null;

    controller.coverBytes = Uint8List.fromList(const [2]);
    expect(controller.hasUnpersistedMedia, isTrue);
    controller.coverBytes = null;

    controller.addAdministrator(
      const InstitutionPersonDraft(firstName: 'Ana', lastName: 'Souza', displayName: 'Ana Souza'),
      level: InstitutionAdministratorLevel.adminMaster,
      avatarBytes: Uint8List.fromList(const [3]),
      avatarFileName: 'avatar.png',
    );
    expect(controller.hasUnpersistedMedia, isTrue);
  });
}
