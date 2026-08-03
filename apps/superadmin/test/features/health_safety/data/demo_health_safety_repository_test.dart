import 'package:coelo_superadmin/features/health_safety/data/demo_health_safety_repository.dart';
import 'package:coelo_superadmin/features/health_safety/domain/health_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HealthSafetyActor owner() => HealthSafetyActor(
    id: 'owner-demo',
    profile: DemoHealthSafetyProfile.owner,
    authorizedChildIds: {'child-demo-a'},
  );

  HealthSafetyActor institutional({
    String id = 'professional-demo-professor',
    String institutionId = 'institution-demo-a',
    Set<HealthSafetyCapability> capabilities = const {
      HealthSafetyCapability.sensitiveRead,
      HealthSafetyCapability.clinicalReview,
      HealthSafetyCapability.medicationClaim,
      HealthSafetyCapability.administrationResult,
      HealthSafetyCapability.notifications,
    },
  }) => HealthSafetyActor(
    id: id,
    profile: DemoHealthSafetyProfile.minimized,
    institutionId: institutionId,
    authorizedChildIds: {'child-demo-a'},
    contextualCapabilities: capabilities,
    responsibleInstitutionIds: {institutionId},
  );

  HealthSafetyActor minimizedActor() => HealthSafetyActor(
    id: 'minimized-demo',
    profile: DemoHealthSafetyProfile.minimized,
    authorizedChildIds: {'child-demo-a'},
  );

  group('read authorization and summaries', () {
    test('directory requires actor and derives redaction from that actor', () async {
      final repository = DemoHealthSafetyRepository();
      final page = await repository.fetchDirectory(
        const HealthSafetyDirectoryQuery(childIds: {'child-demo-a', 'child-demo-unauthorized'}),
        actor: minimizedActor(),
      );

      expect(page.items.map((item) => item.id), ['child-demo-a']);
      expect(page.items.single.displayName, isNot('Criança Demo A'));
      expect(page.items.single.personId, isNull);
    });
    test(
      'directory returns summaries only and minimized profile receives no sensitive aggregate',
      () async {
        final repository = DemoHealthSafetyRepository();
        final page = await repository.fetchDirectory(
          const HealthSafetyDirectoryQuery(),
          actor: minimizedActor(),
        );
        expect(page.items, isNotEmpty);
        expect(page.items.first, isA<HealthSafetyChildSummary>());
        expect(page.items.first.medicationCount, greaterThanOrEqualTo(0));
        expect(page.items.map((item) => item.displayName), isNot(contains('Criança Demo A')));
        expect(page.items.map((item) => item.personId), everyElement(isNull));
        final ownerPage = await repository.fetchDirectory(
          const HealthSafetyDirectoryQuery(),
          actor: owner(),
        );
        expect(ownerPage.items.map((item) => item.displayName), contains('Criança Demo A'));
        expect(ownerPage.items.map((item) => item.personId), contains('person-demo-a'));
      },
    );

    test(
      'detail denies minimized, unauthorized, inactive and mismatched institutional contexts',
      () async {
        final repository = DemoHealthSafetyRepository();
        await expectLater(
          repository.findChild(
            'child-demo-a',
            actor: HealthSafetyActor(
              id: 'minimized-demo',
              profile: DemoHealthSafetyProfile.minimized,
              authorizedChildIds: {'child-demo-a'},
            ),
          ),
          throwsStateError,
        );
        await expectLater(
          repository.findChild(
            'child-demo-a',
            actor: HealthSafetyActor(
              id: 'reader-demo',
              profile: DemoHealthSafetyProfile.sensitiveReader,
            ),
          ),
          throwsStateError,
        );
        await expectLater(
          repository.findChild(
            'child-demo-a',
            actor: institutional(institutionId: 'institution-demo-c'),
          ),
          throwsStateError,
        );
        await expectLater(
          repository.findChild('child-demo-unauthorized', actor: institutional()),
          throwsStateError,
        );
        expect((await repository.findChild('child-demo-a', actor: owner()))!.id, 'child-demo-a');
      },
    );

    test(
      'global identity filters precede institution and contextual hierarchy intersects',
      () async {
        final repository = DemoHealthSafetyRepository();
        final global = await repository.fetchDirectory(
          const HealthSafetyDirectoryQuery(
            personIds: {'person-demo-unauthorized'},
            childIds: {'child-demo-unauthorized'},
          ),
          actor: owner(),
        );
        final contextual = await repository.fetchDirectory(
          const HealthSafetyDirectoryQuery(
            childIds: {'child-demo-unauthorized'},
            institutionIds: {'institution-demo-a'},
          ),
          actor: owner(),
        );
        final crossedHierarchy = await repository.fetchDirectory(
          const HealthSafetyDirectoryQuery(
            institutionIds: {'institution-demo-a'},
            unitIds: {'unit-demo-b'},
            groupOrActivityIds: {'group-demo-b'},
          ),
          actor: owner(),
        );

        expect(global.items, isEmpty);
        expect(contextual.items, isEmpty);
        expect(crossedHierarchy.items, isEmpty);
      },
    );

    test('pagination preserves total count and never duplicates items between pages', () async {
      final repository = DemoHealthSafetyRepository();
      final first = await repository.fetchDirectory(
        const HealthSafetyDirectoryQuery(page: 0, pageSize: 1),
        actor: owner(),
      );
      final second = await repository.fetchDirectory(
        const HealthSafetyDirectoryQuery(page: 1, pageSize: 1),
        actor: owner(),
      );

      expect(first.page, 0);
      expect(second.page, 1);
      expect(first.pageSize, 1);
      expect(second.pageSize, 1);
      expect(first.totalCount, 1);
      expect(second.totalCount, 1);
      expect(first.items, hasLength(1));
      expect(second.items, isEmpty);
      expect(
        first.items
            .map((item) => item.id)
            .toSet()
            .intersection(second.items.map((item) => item.id).toSet()),
        isEmpty,
      );
    });
  });

  group('capability-protected writes', () {
    test('owner creates medication and allergy with audit and authorization', () async {
      final repository = DemoHealthSafetyRepository();
      final medication = await repository.createMedication(
        childId: 'child-demo-a',
        name: 'Medicamento Novo',
        dose: '10',
        doseUnit: 'mL',
        route: 'oral',
        startsAt: DateTime.utc(2026, 8, 4),
        endsAt: DateTime.utc(2026, 8, 8),
        documentName: 'receita-demo.pdf',
        documentType: 'application/pdf',
        schedules: [
          HealthMedicationSchedule(id: 'new-home', time: HealthSafetyTimeOfDay(8, 0), atHome: true),
        ],
        actor: owner(),
      );
      final allergy = await repository.createAllergy(
        childId: 'child-demo-a',
        label: 'Látex',
        type: HealthSafetyAllergyType.other,
        actor: owner(),
      );
      final child = await repository.findChild('child-demo-a', actor: owner());

      expect(medication.currentVersion.name, 'Medicamento Novo');
      expect(medication.currentVersion.documentName, 'receita-demo.pdf');
      expect(medication.currentVersion.documentType, 'application/pdf');
      expect(allergy.label, 'Látex');
      expect(child!.medications.map((item) => item.id), contains(medication.id));
      expect(child.allergies.map((item) => item.id), contains(allergy.id));
      expect(
        child.auditEvents.skip(child.auditEvents.length - 2).map((item) => item.actorId),
        everyElement('owner-demo'),
      );

      await expectLater(
        repository.createAllergy(
          childId: 'child-demo-a',
          label: 'Sem permissão',
          type: HealthSafetyAllergyType.other,
          actor: minimizedActor(),
        ),
        throwsStateError,
      );
    });

    test('medication schedules must belong to active authorized child contexts', () async {
      final actorB = HealthSafetyActor(
        id: 'owner-b',
        profile: DemoHealthSafetyProfile.owner,
        authorizedChildIds: {'child-demo-b'},
      );
      await expectLater(
        DemoHealthSafetyRepository().createMedication(
          childId: 'child-demo-b',
          name: 'Inválido',
          dose: '1',
          doseUnit: 'mL',
          route: 'oral',
          startsAt: DateTime.utc(2026, 8, 4),
          endsAt: DateTime.utc(2026, 8, 8),
          schedules: [
            HealthMedicationSchedule(
              id: 'wrong-context',
              time: HealthSafetyTimeOfDay(8, 0),
              institutionId: 'institution-demo-a',
            ),
          ],
          actor: actorB,
        ),
        throwsArgumentError,
      );
    });

    test('relevant correction pauses only future doses of the affected version', () async {
      final repository = DemoHealthSafetyRepository();
      await repository.changeMedicationRelevant(
        childId: 'child-demo-a',
        medicationId: 'medication-demo-a',
        name: 'Medicamento corrigido',
        justification: 'Correção por versão',
        actor: owner(),
      );
      final child = await repository.findChild('child-demo-a', actor: owner());

      expect(
        child!.doses.singleWhere((item) => item.id == 'dose-demo-future').situation,
        HealthMedicationDoseSituation.paused,
      );
      expect(
        child.doses.singleWhere((item) => item.id == 'dose-demo-other-version-future').situation,
        HealthMedicationDoseSituation.scheduled,
      );
    });

    test('care profile update preserves unrelated existing items', () async {
      final repository = DemoHealthSafetyRepository();
      final before = await repository.findChild('child-demo-a', actor: owner());
      await repository.updateCareProfile(
        childId: 'child-demo-a',
        items: [HealthSafetyCareProfileItem(catalogItemId: 'asthma')],
        justification: 'Adicionar apoio sem apagar os demais',
        actor: owner(),
      );
      final after = await repository.findChild('child-demo-a', actor: owner());

      expect(after!.careProfile, hasLength(before!.careProfile.length + 1));
      expect(after.careProfile.map((item) => item.catalogItemId), contains('asthma'));
      expect(
        after.careProfile.map((item) => item.catalogItemId),
        containsAll(before.careProfile.map((item) => item.catalogItemId)),
      );
    });
    test(
      'sensitive reader is read-only and owner cannot perform institutional operations',
      () async {
        final repository = DemoHealthSafetyRepository();
        final reader = HealthSafetyActor(
          id: 'reader-demo',
          profile: DemoHealthSafetyProfile.sensitiveReader,
          authorizedChildIds: {'child-demo-a'},
        );
        await expectLater(
          repository.updateCareProfile(
            childId: 'child-demo-a',
            items: [HealthSafetyCareProfileItem(catalogItemId: 'autism')],
            justification: 'Teste de permissão',
            actor: reader,
          ),
          throwsStateError,
        );
        await expectLater(
          repository.claimDose(doseId: 'dose-demo-future', actor: owner()),
          throwsStateError,
        );
        await expectLater(
          repository.recordDoseResult(
            doseId: 'dose-demo-claimed',
            result: HealthMedicationDoseResult.administered,
            actor: owner(),
          ),
          throwsStateError,
        );
      },
    );

    test(
      'owner correction persists invalidated reviews for every scheduled institution and audit actor',
      () async {
        final repository = DemoHealthSafetyRepository();
        final changed = await repository.changeMedicationRelevant(
          childId: 'child-demo-a',
          medicationId: 'medication-demo-a',
          name: 'Medicamento Demo Atualizado',
          justification: 'Correção demonstrativa',
          actor: owner(),
        );
        final child = await repository.findChild('child-demo-a', actor: owner());
        final medication = child!.medications.single;
        final previous = medication.versions.singleWhere(
          (version) => version.id == 'medication-demo-a-v1',
        );
        expect(changed.invalidatedReviews.map((review) => review.institutionId), {
          'institution-demo-a',
        });
        expect(
          previous.institutionReviews
              .singleWhere((review) => review.institutionId == 'institution-demo-a')
              .status,
          HealthMedicationReviewStatus.invalidated,
        );
        expect(
          previous.institutionReviews
              .singleWhere((review) => review.institutionId == 'institution-demo-b')
              .status,
          HealthMedicationReviewStatus.refused,
        );
        expect(medication.currentVersion.institutionReviews.map((review) => review.institutionId), {
          'institution-demo-a',
          'institution-demo-b',
        });
        expect(child.auditEvents.last.actorId, 'owner-demo');
        expect(child.auditEvents.last.justification, 'Correção demonstrativa');
        expect(
          child.doses.where(
            (dose) =>
                dose.medicationVersionId == previous.id &&
                dose.dueAt.isAfter(repository.clock) &&
                dose.institutionId != null,
          ),
          everyElement(
            isA<HealthMedicationDose>().having(
              (dose) => dose.situation,
              'situation',
              HealthMedicationDoseSituation.paused,
            ),
          ),
        );
        expect(
          child.doses.singleWhere((dose) => dose.id == 'dose-demo-home-future').situation,
          HealthMedicationDoseSituation.scheduled,
        );
      },
    );

    test('institutional review validates capability, context and refusal reason', () async {
      final repository = DemoHealthSafetyRepository();
      await repository.changeMedicationRelevant(
        childId: 'child-demo-a',
        medicationId: 'medication-demo-a',
        name: 'Medicamento em revisão',
        justification: 'Correção para nova análise',
        actor: owner(),
      );
      await expectLater(
        repository.reviewMedication(
          childId: 'child-demo-a',
          medicationId: 'medication-demo-a',
          status: HealthMedicationReviewStatus.refused,
          actor: institutional(),
        ),
        throwsArgumentError,
      );
      final review = await repository.reviewMedication(
        childId: 'child-demo-a',
        medicationId: 'medication-demo-a',
        status: HealthMedicationReviewStatus.refused,
        reason: 'Documento ilegível',
        actor: institutional(),
      );
      expect(review.reason, 'Documento ilegível');
      final child = await repository.findChild('child-demo-a', actor: owner());
      expect(child!.medications.single.currentVersion.status, HealthMedicationReviewStatus.refused);
    });

    test('approving all institution reviews promotes the current version to active', () async {
      final repository = DemoHealthSafetyRepository();
      await repository.changeMedicationRelevant(
        childId: 'child-demo-a',
        medicationId: 'medication-demo-a',
        name: 'Medicamento em revisão',
        justification: 'Correção para nova análise',
        actor: owner(),
      );
      await repository.reviewMedication(
        childId: 'child-demo-a',
        medicationId: 'medication-demo-a',
        status: HealthMedicationReviewStatus.approved,
        actor: institutional(),
      );
      await repository.reviewMedication(
        childId: 'child-demo-a',
        medicationId: 'medication-demo-a',
        status: HealthMedicationReviewStatus.approved,
        actor: institutional(institutionId: 'institution-demo-b'),
      );
      final child = await repository.findChild('child-demo-a', actor: owner());
      expect(child!.medications.single.currentVersion.status, HealthMedicationReviewStatus.active);
    });
  });

  group('dose lifecycle', () {
    test(
      'claim only accepts future approved active institutional pending dose and responsible context',
      () async {
        final repository = DemoHealthSafetyRepository();
        final actor = institutional();
        expect(
          (await repository.claimDose(doseId: 'dose-demo-future', actor: actor)).status,
          HealthMedicationClaimStatus.claimed,
        );
        final child = await repository.findChild('child-demo-a', actor: actor);
        expect(
          child!.doses.singleWhere((dose) => dose.id == 'dose-demo-future').claimExpiresAt,
          repository.clock.add(const Duration(minutes: 7)),
        );
        await expectLater(
          repository.claimDose(doseId: 'dose-demo-home-future', actor: actor),
          throwsStateError,
        );
        await expectLater(
          repository.claimDose(doseId: 'dose-demo-past', actor: actor),
          throwsStateError,
        );
        await expectLater(
          repository.claimDose(doseId: 'dose-demo-paused', actor: actor),
          throwsStateError,
        );
        await expectLater(
          repository.claimDose(doseId: 'dose-demo-institution-b', actor: actor),
          throwsStateError,
        );
      },
    );

    test('claim conflict, release and expiration preserve validated ownership', () async {
      final repository = DemoHealthSafetyRepository();
      final professor = institutional();
      final nurse = institutional(id: 'professional-demo-nurse');
      final conflict = await repository.claimDose(doseId: 'dose-demo-claimed', actor: nurse);
      expect(conflict.status, HealthMedicationClaimStatus.conflict);
      expect(conflict.conflictingProfessionalId, 'professional-demo-professor');
      await expectLater(
        repository.releaseDoseClaim(doseId: 'dose-demo-claimed', actor: nurse),
        throwsStateError,
      );
      expect(
        (await repository.releaseDoseClaim(doseId: 'dose-demo-claimed', actor: professor)).status,
        HealthMedicationClaimStatus.released,
      );
      expect(
        (await repository.expireDoseClaim(doseId: 'dose-demo-expired', actor: nurse)).status,
        HealthMedicationClaimStatus.released,
      );
      await expectLater(
        repository.expireDoseClaim(doseId: 'dose-demo-future', actor: nurse),
        throwsStateError,
      );
    });

    test(
      'result requires capability, responsible context, active claim ownership and reason',
      () async {
        final repository = DemoHealthSafetyRepository();
        final professor = institutional();
        final nurse = institutional(id: 'professional-demo-nurse');
        await expectLater(
          repository.recordDoseResult(
            doseId: 'dose-demo-claimed',
            result: HealthMedicationDoseResult.administered,
            actor: nurse,
          ),
          throwsStateError,
        );
        await expectLater(
          repository.recordDoseResult(
            doseId: 'dose-demo-claimed',
            result: HealthMedicationDoseResult.refused,
            actor: professor,
          ),
          throwsArgumentError,
        );
        final result = await repository.recordDoseResult(
          doseId: 'dose-demo-claimed',
          result: HealthMedicationDoseResult.refused,
          reason: 'Recusa do responsável',
          actor: professor,
        );
        expect(result.authorId, professor.id);
        expect(result.recordedAt, repository.clock);
        expect(result.claimedBy, isNull);
      },
    );
  });

  group('notifications, receipts and fixtures', () {
    test(
      'allergy inactivation emits notification and receipt; acknowledgement updates both',
      () async {
        final repository = DemoHealthSafetyRepository();
        final receipt = await repository.deactivateAllergy(
          childId: 'child-demo-a',
          allergyId: 'allergy-demo-active',
          justification: 'Inativação de teste',
          actor: owner(),
        );
        var child = await repository.findChild('child-demo-a', actor: owner());
        final notification = child!.notifications.last;
        expect(notification.receiptId, receipt.id);
        expect(notification.subject, HealthSafetyAcknowledgementSubject.allergyOrRestriction);
        expect(child.auditEvents.last.actorId, 'owner-demo');

        await expectLater(
          repository.markAcknowledged(notification.id, actor: institutional()),
          throwsStateError,
        );
        final recipient = HealthSafetyActor(
          id: notification.recipientId,
          profile: DemoHealthSafetyProfile.minimized,
          authorizedChildIds: const {'child-demo-a'},
          contextualCapabilities: const {
            HealthSafetyCapability.sensitiveRead,
            HealthSafetyCapability.notifications,
          },
        );
        await repository.markAcknowledged(notification.id, actor: recipient);
        child = await repository.findChild('child-demo-a', actor: owner());
        expect(child!.notifications.last.acknowledgedAt, repository.clock);
        expect(
          child.acknowledgements.singleWhere((item) => item.id == receipt.id).receivedAt,
          repository.clock,
        );
      },
    );

    test('inactivating an already inactive allergy is a persistent no-op', () async {
      final repository = DemoHealthSafetyRepository();
      final first = await repository.deactivateAllergy(
        childId: 'child-demo-a',
        allergyId: 'allergy-demo-active',
        justification: 'Inativação de teste',
        actor: owner(),
      );
      final before = await repository.findChild('child-demo-a', actor: owner());
      final second = await repository.deactivateAllergy(
        childId: 'child-demo-a',
        allergyId: 'allergy-demo-active',
        justification: 'Inativação de teste',
        actor: owner(),
      );
      final after = await repository.findChild('child-demo-a', actor: owner());
      expect(second.id, first.id);
      expect(after!.notifications.length, before!.notifications.length);
      expect(after.acknowledgements.length, before.acknowledgements.length);
      expect(after.auditEvents.length, before.auditEvents.length);
    });

    test('fixtures prove every mandated scenario through concrete properties', () async {
      final repository = DemoHealthSafetyRepository();
      final page = await repository.fetchDirectory(
        const HealthSafetyDirectoryQuery(),
        actor: owner(),
      );
      final child = await repository.findChild('child-demo-a', actor: owner());
      expect(repository.clock, DateTime.utc(2026, 8, 3, 12));
      expect(page.items.map((item) => item.displayName), contains('Criança Demo A'));
      expect(child!.links.map((link) => link.institutionId), {
        'institution-demo-a',
        'institution-demo-b',
      });
      expect(child.medications.single.currentVersion.schedules, hasLength(3));
      expect(child.medications.single.currentVersion.prescriptionReference, isNotNull);
      expect(child.medications.single.currentVersion.dispensedBy, isNotNull);
      expect(child.notifications.map((item) => item.recipientId).toSet().length, greaterThan(1));
      expect(
        child.doses.map((dose) => dose.claimedBy),
        containsAll(['professional-demo-professor', 'professional-demo-nurse']),
      );
      expect(
        child.doses.map((dose) => dose.situation),
        containsAll([HealthMedicationDoseSituation.late, HealthMedicationDoseSituation.refused]),
      );
      expect(
        child.allergies,
        contains(
          isA<HealthSafetyAllergy>().having(
            (item) => item.type,
            'type',
            HealthSafetyAllergyType.medication,
          ),
        ),
      );
      expect(child.acknowledgements.map((item) => item.receivedAt), containsAll([null, isNotNull]));
      expect(
        child.auditEvents,
        contains(
          isA<HealthSafetyAuditEvent>().having((item) => item.actorId, 'actorId', 'owner-demo'),
        ),
      );
      final version = child.medications.single.currentVersion;
      final claimed = child.doses.where(
        (dose) =>
            dose.situation == HealthMedicationDoseSituation.claimed && dose.claimExpiresAt != null,
      );
      final late = child.doses.singleWhere(
        (dose) => dose.situation == HealthMedicationDoseSituation.late,
      );
      final refused = child.doses.singleWhere(
        (dose) => dose.situation == HealthMedicationDoseSituation.refused,
      );
      final activeMedicationAllergy = child.allergies.singleWhere(
        (allergy) => allergy.type == HealthSafetyAllergyType.medication && allergy.active,
      );
      final inactiveAllergy = child.allergies.singleWhere((allergy) => !allergy.active);
      final pendingReceipt = child.acknowledgements.singleWhere(
        (receipt) => receipt.receivedAt == null,
      );
      final completedReceipt = child.acknowledgements.singleWhere(
        (receipt) => receipt.receivedAt != null,
      );
      final minimized = await repository.fetchDirectory(
        const HealthSafetyDirectoryQuery(childIds: {'child-demo-a'}),
        actor: minimizedActor(),
      );

      expect(claimed.map((dose) => dose.claimedBy).toSet(), {
        'professional-demo-professor',
        'professional-demo-nurse',
      });
      expect(
        claimed
            .singleWhere((dose) => dose.claimedBy == 'professional-demo-professor')
            .claimExpiresAt!
            .isAfter(repository.clock),
        isTrue,
      );
      expect(
        claimed
            .singleWhere((dose) => dose.claimedBy == 'professional-demo-nurse')
            .claimExpiresAt!
            .isAfter(repository.clock),
        isFalse,
      );
      expect(late.dueAt.isBefore(repository.clock), isTrue);
      expect(refused.reason, isNotEmpty);
      expect(refused.authorId, isNotEmpty);
      expect(refused.recordedAt, isNotNull);
      expect(activeMedicationAllergy.label, contains('Medicamento'));
      expect(inactiveAllergy.inactivatedAt, isNotNull);
      expect(pendingReceipt.receivedAt, isNull);
      expect(completedReceipt.receivedAt, isNotNull);
      expect(minimized.items.single.displayName, 'Criança protegida');
      expect(minimized.items.single.personId, isNull);
      expect(
        child.auditEvents.singleWhere((event) => event.actorId == 'owner-demo').justification,
        isNotEmpty,
      );
      expect(version.policy, isNotNull);
      expect(version.policy!.recipientIds.length, greaterThan(1));
      expect(version.policy!.escalationRecipientIds, isNotEmpty);
      expect(
        version.policy!.phaseAt(DateTime.utc(2026, 8, 3, 16), DateTime.utc(2026, 8, 3, 15, 40)),
        HealthMedicationPolicyPhase.earlyReminder,
      );
    });
  });
}
