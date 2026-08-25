import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HealthMedicationSchedule homeSchedule() =>
      HealthMedicationSchedule(id: 'home', time: HealthCareTimeOfDay(8, 0), atHome: true);

  HealthMedicationVersion version({
    HealthMedicationReviewStatus status = HealthMedicationReviewStatus.approved,
    List<HealthMedicationInstitutionReview> reviews = const [],
  }) => HealthMedicationVersion(
    id: 'version-a',
    medicationId: 'medication-a',
    version: 1,
    name: 'Medicamento Demo',
    dose: '5',
    doseUnit: 'mL',
    route: 'oral',
    startsAt: DateTime.utc(2026, 8, 1),
    endsAt: DateTime.utc(2026, 8, 10),
    status: status,
    schedules: [homeSchedule()],
    institutionReviews: reviews,
    prescriptionReference: 'prescription-demo.pdf',
    dispensedBy: 'guardian-demo-a',
  );

  test('allergy status is independent from recorded episode severity', () {
    final allergy = HealthCareAllergy(
      id: 'allergy-a',
      childId: 'child-a',
      label: 'Amendoim',
      type: HealthCareAllergyType.food,
      active: true,
      status: HealthCareAllergyStatus.monitoring,
      lastEpisodeAt: DateTime.utc(2026, 7, 2),
      episodeSeverity: HealthCareEpisodeSeverity.moderate,
      observedReaction: 'Urticaria',
      guidance: 'Seguir o plano de cuidado.',
      notes: 'Episodio informado pela familia.',
    );

    expect(allergy.status, HealthCareAllergyStatus.monitoring);
    expect(allergy.episodeSeverity, HealthCareEpisodeSeverity.moderate);

    final historical = allergy.deactivate(DateTime.utc(2026, 8, 1));
    expect(historical.status, HealthCareAllergyStatus.history);
    expect(historical.episodeSeverity, HealthCareEpisodeSeverity.moderate);
    expect(historical.observedReaction, 'Urticaria');
  });

  group('directory query scope', () {
    test('person and child filters are global and match a child without context links', () {
      final child = HealthCareChild(
        id: 'child-no-context',
        personId: 'person-no-context',
        displayName: 'Criança sem contexto',
        operationalStatus: HealthCareOperationalStatus.implementation,
      );

      expect(
        const HealthCareDirectoryQuery(personIds: {'person-no-context'}).matches(child),
        isTrue,
      );
      expect(const HealthCareDirectoryQuery(childIds: {'child-no-context'}).matches(child), isTrue);
      expect(
        const HealthCareDirectoryQuery(
          childIds: {'child-no-context'},
          institutionIds: {'institution-a'},
        ).matches(child),
        isFalse,
      );
    });

    test('institution, unit and group intersect on one active authorized context', () {
      final query = const HealthCareDirectoryQuery(
        institutionIds: {'institution-a'},
        unitIds: {'unit-a'},
        groupOrActivityIds: {'group-a'},
      );
      HealthCareChild child(List<HealthCareContextLink> links) => HealthCareChild(
        id: 'child-a',
        personId: 'person-a',
        displayName: 'Criança A',
        operationalStatus: HealthCareOperationalStatus.active,
        links: links,
      );

      expect(
        query.matches(
          child(const [
            HealthCareContextLink(
              institutionId: 'institution-a',
              unitId: 'unit-a',
              groupOrActivityId: 'group-a',
              active: false,
            ),
            HealthCareContextLink(
              institutionId: 'institution-a',
              unitId: 'unit-a',
              groupOrActivityId: 'group-a',
              authorized: false,
            ),
            HealthCareContextLink(
              institutionId: 'institution-a',
              unitId: 'unit-a',
              groupOrActivityId: 'group-a',
            ),
          ]),
        ),
        isTrue,
      );
      expect(
        query.matches(
          child(const [
            HealthCareContextLink(
              institutionId: 'institution-a',
              unitId: 'unit-a',
              groupOrActivityId: 'group-b',
            ),
            HealthCareContextLink(
              institutionId: 'institution-b',
              unitId: 'unit-b',
              groupOrActivityId: 'group-a',
            ),
          ]),
        ),
        isFalse,
      );
    });
  });

  group('runtime value safety', () {
    test('time rejects invalid values with ArgumentError at runtime', () {
      expect(() => HealthCareTimeOfDay(-1, 0), throwsArgumentError);
      expect(() => HealthCareTimeOfDay(24, 0), throwsArgumentError);
      expect(() => HealthCareTimeOfDay(12, 60), throwsArgumentError);
    });

    test('medication version defensively freezes schedules', () {
      final mutable = [homeSchedule()];
      final medication = HealthMedicationVersion(
        id: 'immutable-version',
        medicationId: 'immutable-medication',
        version: 1,
        name: 'Medicamento',
        dose: '5',
        doseUnit: 'mL',
        route: 'oral',
        startsAt: DateTime.utc(2026, 8, 1),
        endsAt: DateTime.utc(2026, 8, 10),
        status: HealthMedicationReviewStatus.requested,
        schedules: mutable,
      );

      mutable.clear();
      expect(medication.schedules, hasLength(1));
      expect(() => medication.schedules.add(homeSchedule()), throwsUnsupportedError);
    });
  });

  group('permissions and contextual visibility', () {
    test('owner can correct, create/edit and inactivate but cannot review, claim or result', () {
      expect(
        HealthCareAccessProfile.owner.capabilities,
        containsAll(<HealthCareCapability>[
          HealthCareCapability.sensitiveRead,
          HealthCareCapability.auditRead,
          HealthCareCapability.exceptionalCorrection,
          HealthCareCapability.recordCreateEdit,
          HealthCareCapability.recordInactivate,
        ]),
      );
      expect(HealthCareAccessProfile.owner.can(HealthCareCapability.clinicalReview), isFalse);
      expect(HealthCareAccessProfile.owner.can(HealthCareCapability.medicationClaim), isFalse);
      expect(HealthCareAccessProfile.owner.can(HealthCareCapability.administrationResult), isFalse);
      expect(
        HealthCareAccessProfile.sensitiveReader.capabilities,
        equals({HealthCareCapability.sensitiveRead}),
      );
    });

    test('actor requires active authorized child context even for global sensitive reading', () {
      final actor = HealthCareActor(
        id: 'reader-a',
        profile: HealthCareAccessProfile.sensitiveReader,
        authorizedChildIds: {'child-a'},
      );
      final child = HealthCareChild(
        id: 'child-a',
        personId: 'person-a',
        displayName: 'Criança A',
        operationalStatus: HealthCareOperationalStatus.active,
        links: const [HealthCareContextLink(institutionId: 'institution-a', active: false)],
      );
      expect(actor.canReadDetail(child), isFalse);
      expect(
        actor.canReadDetail(
          HealthCareChild(
            id: 'child-a',
            personId: 'person-a',
            displayName: 'Criança A',
            operationalStatus: HealthCareOperationalStatus.active,
            links: const [HealthCareContextLink(institutionId: 'institution-a')],
          ),
        ),
        isTrue,
      );
    });

    test('institutional actor must match an active authorized institution context', () {
      final actor = HealthCareActor(
        id: 'reader-a',
        profile: HealthCareAccessProfile.sensitiveReader,
        institutionId: 'institution-b',
        authorizedChildIds: {'child-a'},
      );
      final child = HealthCareChild(
        id: 'child-a',
        personId: 'person-a',
        displayName: 'Criança A',
        operationalStatus: HealthCareOperationalStatus.active,
        links: const [HealthCareContextLink(institutionId: 'institution-a')],
      );
      expect(actor.canReadDetail(child), isFalse);
    });

    test('contextual capabilities can never grant Owner-only mutations', () {
      final actor = HealthCareActor(
        id: 'institution-operator',
        profile: HealthCareAccessProfile.minimized,
        contextualCapabilities: const {
          HealthCareCapability.exceptionalCorrection,
          HealthCareCapability.recordCreateEdit,
          HealthCareCapability.recordInactivate,
        },
      );
      expect(actor.can(HealthCareCapability.exceptionalCorrection), isFalse);
      expect(actor.can(HealthCareCapability.recordCreateEdit), isFalse);
      expect(actor.can(HealthCareCapability.recordInactivate), isFalse);
    });
  });

  group('medication rules', () {
    test('required prescription fields have no defaults', () {
      expect(
        () => HealthMedicationVersion(
          id: 'version-a',
          medicationId: 'medication-a',
          version: 1,
          name: 'Medicamento Demo',
          dose: '',
          doseUnit: 'mL',
          route: 'oral',
          startsAt: DateTime.utc(2026, 8, 1),
          endsAt: DateTime.utc(2026, 8, 10),
          status: HealthMedicationReviewStatus.requested,
          schedules: [homeSchedule()],
        ),
        throwsArgumentError,
      );
      expect(version().frequencyPerDay, 1);
    });

    test('schedule belongs to exactly home or one institution', () {
      expect(
        () => HealthMedicationSchedule(id: 'invalid', time: HealthCareTimeOfDay(8, 0)),
        throwsArgumentError,
      );
      expect(
        () => HealthMedicationSchedule(
          id: 'invalid',
          time: HealthCareTimeOfDay(8, 0),
          atHome: true,
          institutionId: 'institution-a',
        ),
        throwsArgumentError,
      );
    });

    test('institution review refusal requires a reason and review belongs to a version', () {
      const review = HealthMedicationInstitutionReview(
        id: 'review-a',
        medicationVersionId: 'version-a',
        institutionId: 'institution-a',
        status: HealthMedicationReviewStatus.underReview,
      );
      expect(() => review.transitionTo(HealthMedicationReviewStatus.refused), throwsArgumentError);
      final refused = review.transitionTo(
        HealthMedicationReviewStatus.refused,
        reason: 'Prescrição incompleta',
      );
      expect(refused.reason, 'Prescrição incompleta');
      expect(
        version(reviews: [refused]).institutionReviews.single.medicationVersionId,
        'version-a',
      );
    });

    test('dose copyWith preserves claim until it is explicitly cleared', () {
      final claimed = HealthMedicationDose(
        id: 'dose-a',
        medicationVersionId: 'version-a',
        dueAt: DateTime.utc(2026, 8, 3, 13),
        situation: HealthMedicationDoseSituation.claimed,
        claimedBy: 'professional-a',
        claimExpiresAt: DateTime.utc(2026, 8, 3, 13, 15),
        institutionId: 'institution-a',
      );
      expect(
        claimed.copyWith(situation: HealthMedicationDoseSituation.paused).claimedBy,
        'professional-a',
      );
      expect(claimed.clearClaim().claimedBy, isNull);
      expect(claimed.clearClaim().claimExpiresAt, isNull);
    });

    test('refused and not administered results require reason, author and timestamp', () {
      expect(
        () => HealthMedicationDose(
          id: 'dose-a',
          medicationVersionId: 'version-a',
          dueAt: DateTime.utc(2026, 8, 3, 12),
          situation: HealthMedicationDoseSituation.refused,
          result: HealthMedicationDoseResult.refused,
          reason: 'Recusa',
        ),
        throwsArgumentError,
      );
      expect(
        HealthMedicationDose(
          id: 'dose-a',
          medicationVersionId: 'version-a',
          dueAt: DateTime.utc(2026, 8, 3, 12),
          situation: HealthMedicationDoseSituation.refused,
          result: HealthMedicationDoseResult.refused,
          reason: 'Recusa',
          authorId: 'professional-a',
          recordedAt: DateTime.utc(2026, 8, 3, 12, 1),
        ).reason,
        'Recusa',
      );
    });

    test('policy classifies early reminder, due, tolerance, late and escalation', () {
      final due = DateTime.utc(2026, 8, 3, 12);
      final policy = HealthMedicationAdministrationPolicy(
        earlyReminder: const Duration(minutes: 30),
        tolerance: const Duration(minutes: 10),
        escalationAfter: const Duration(minutes: 20),
        claimDuration: const Duration(minutes: 7),
        recipientIds: {'professional-a', 'professional-b'},
        escalationRecipientIds: {'coordinator-a'},
      );
      expect(
        policy.phaseAt(due, due.subtract(const Duration(minutes: 20))),
        HealthMedicationPolicyPhase.earlyReminder,
      );
      expect(policy.phaseAt(due, due), HealthMedicationPolicyPhase.dueNotification);
      expect(
        policy.phaseAt(due, due.add(const Duration(minutes: 5))),
        HealthMedicationPolicyPhase.tolerance,
      );
      expect(
        policy.phaseAt(due, due.add(const Duration(minutes: 15))),
        HealthMedicationPolicyPhase.late,
      );
      expect(
        policy.phaseAt(due, due.add(const Duration(minutes: 20))),
        HealthMedicationPolicyPhase.escalated,
      );
      expect(policy.claimDuration, const Duration(minutes: 7));
    });

    test('review resolution promotes to approved, active or refused', () {
      final policy = HealthMedicationAdministrationPolicy(
        earlyReminder: const Duration(minutes: 30),
        tolerance: const Duration(minutes: 10),
        escalationAfter: const Duration(minutes: 20),
        claimDuration: const Duration(minutes: 15),
        recipientIds: const {'professional-a'},
        escalationRecipientIds: const {'coordinator-a'},
      );
      const approved = HealthMedicationInstitutionReview(
        id: 'review-a',
        medicationVersionId: 'version-a',
        institutionId: 'institution-a',
        status: HealthMedicationReviewStatus.approved,
      );
      final reviewed = version(reviews: const [approved]).copyWith(policy: policy);
      expect(
        reviewed.resolveStatusAfterReviews(DateTime.utc(2026, 8, 3)),
        HealthMedicationReviewStatus.active,
      );
      expect(
        reviewed.resolveStatusAfterReviews(DateTime.utc(2026, 7, 31)),
        HealthMedicationReviewStatus.approved,
      );
      const refused = HealthMedicationInstitutionReview(
        id: 'review-a',
        medicationVersionId: 'version-a',
        institutionId: 'institution-a',
        status: HealthMedicationReviewStatus.refused,
        reason: 'Documento incompleto',
      );
      expect(
        version(reviews: const [refused]).resolveStatusAfterReviews(DateTime.utc(2026, 8, 3)),
        HealthMedicationReviewStatus.refused,
      );
    });

    test('correction invalidates only approved or active reviews', () {
      const approved = HealthMedicationInstitutionReview(
        id: 'approved',
        medicationVersionId: 'version-a',
        institutionId: 'institution-a',
        status: HealthMedicationReviewStatus.approved,
      );
      const underReview = HealthMedicationInstitutionReview(
        id: 'pending',
        medicationVersionId: 'version-a',
        institutionId: 'institution-b',
        status: HealthMedicationReviewStatus.underReview,
      );
      const refused = HealthMedicationInstitutionReview(
        id: 'refused',
        medicationVersionId: 'version-a',
        institutionId: 'institution-c',
        status: HealthMedicationReviewStatus.refused,
        reason: 'Recusado',
      );
      expect(approved.invalidateForCorrection().status, HealthMedicationReviewStatus.invalidated);
      expect(identical(underReview.invalidateForCorrection(), underReview), isTrue);
      expect(identical(refused.invalidateForCorrection(), refused), isTrue);
    });
  });

  test('care catalog has exactly the seven approved groups and examples', () {
    expect(healthCareProfileCatalog.map((group) => group.label).toList(), [
      'Neurodesenvolvimento',
      'Desenvolvimento motor e mobilidade',
      'Visão',
      'Audição e comunicação',
      'Condições genéticas',
      'Condições de saúde',
      'Outro',
    ]);
    final labels = healthCareProfileCatalog
        .expand((group) => group.items)
        .map((item) => item.label);
    expect(
      labels,
      containsAll([
        'Autismo',
        'TDAH',
        'Dislexia',
        'Dispraxia',
        'Altas habilidades/superdotação',
        'Deficiência motora',
        'Mobilidade reduzida',
        'Atraso no desenvolvimento motor',
        'Paralisia cerebral',
        'Uso de cadeira de rodas, órtese, prótese ou recurso de mobilidade',
        'Miopia',
        'Hipermetropia',
        'Astigmatismo',
        'Estrabismo',
        'Baixa visão',
        'Cegueira',
        'Deficiência auditiva',
        'Surdez',
        'Apoio na fala ou comunicação',
        'Uso de Libras ou comunicação alternativa',
        'Síndrome de Down',
        'Diabetes',
        'Epilepsia ou histórico de convulsões',
        'Asma',
        'Outro',
      ]),
    );
    expect(() => HealthCareProfileItem(catalogItemId: 'other'), throwsArgumentError);
    expect(
      HealthCareProfileItem(catalogItemId: 'other', otherText: 'Apoio individual').otherText,
      'Apoio individual',
    );
  });

  test('aggregate and policy collections are immutable defensive copies', () {
    final links = <HealthCareContextLink>[
      const HealthCareContextLink(institutionId: 'institution-a'),
    ];
    final child = HealthCareChild(
      id: 'child-a',
      personId: 'person-a',
      displayName: 'Criança A',
      operationalStatus: HealthCareOperationalStatus.active,
      links: links,
    );
    links.clear();
    expect(child.links, hasLength(1));
    expect(
      () => child.links.add(const HealthCareContextLink(institutionId: 'institution-b')),
      throwsUnsupportedError,
    );

    final recipients = <String>{'professional-a'};
    final policy = HealthMedicationAdministrationPolicy(
      earlyReminder: const Duration(minutes: 30),
      tolerance: const Duration(minutes: 10),
      escalationAfter: const Duration(minutes: 20),
      claimDuration: const Duration(minutes: 15),
      recipientIds: recipients,
      escalationRecipientIds: const {},
    );
    recipients.clear();
    expect(policy.recipientIds, {'professional-a'});
    expect(() => policy.recipientIds.add('professional-b'), throwsUnsupportedError);
  });
}
