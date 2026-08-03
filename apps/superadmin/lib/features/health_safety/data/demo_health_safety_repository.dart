import '../domain/health_safety.dart';

final class DemoHealthSafetyRepository {
  DemoHealthSafetyRepository() : _children = _demoChildren();

  static final DateTime fixedClock = DateTime.utc(2026, 8, 3, 12);
  final List<HealthSafetyChild> _children;
  DateTime get clock => fixedClock;
  Set<HealthSafetyFixtureScenario> get fixtureScenarios =>
      Set.unmodifiable(HealthSafetyFixtureScenario.values);

  Future<HealthSafetyDirectoryPage> fetchDirectory(
    HealthSafetyDirectoryQuery query, {
    required HealthSafetyActor actor,
  }) async {
    final matches =
        _children
            .where((child) => _isVisibleInDirectory(child, actor))
            .where(query.matches)
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final start = query.offset.clamp(0, matches.length);
    final end = (start + query.pageSize).clamp(start, matches.length);
    return HealthSafetyDirectoryPage(
      items: matches
          .sublist(start, end)
          .map((child) => HealthSafetyChildSummary.fromChild(child, profile: actor.profile))
          .toList(),
      totalCount: matches.length,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  bool _isVisibleInDirectory(HealthSafetyChild child, HealthSafetyActor actor) {
    if (!actor.authorizedChildIds.contains(child.id)) return false;
    return child.links.any(
      (link) =>
          link.active &&
          link.authorized &&
          (actor.institutionId == null || link.institutionId == actor.institutionId),
    );
  }

  Future<HealthSafetyChild?> findChild(String childId, {required HealthSafetyActor actor}) async {
    final child = _children[_childIndex(childId)];
    if (!actor.canReadDetail(child)) throw StateError('Sensitive detail access denied.');
    return child;
  }

  Future<HealthMedication> createMedication({
    required String childId,
    required String name,
    required String dose,
    required String doseUnit,
    required String route,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<HealthMedicationSchedule> schedules,
    String? documentName,
    String? documentType,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.recordCreateEdit);
    final index = _childIndex(childId);
    final child = _children[index];
    if (!actor.canReadDetail(child)) throw StateError('Authorized context required.');
    _validateScheduleContexts(child, schedules);
    final medicationId = 'medication-${child.id}-${child.medications.length + 1}';
    final versionId = '$medicationId-v1';
    final institutionIds = schedules
        .where((schedule) => schedule.institutionId != null)
        .map((schedule) => schedule.institutionId!)
        .toSet();
    final version = HealthMedicationVersion(
      id: versionId,
      medicationId: medicationId,
      version: 1,
      name: name,
      dose: dose,
      doseUnit: doseUnit,
      route: route,
      startsAt: startsAt,
      endsAt: endsAt,
      status: HealthMedicationReviewStatus.requested,
      schedules: schedules,
      documentName: documentName,
      documentType: documentType,
      institutionReviews: institutionIds
          .map(
            (institutionId) => HealthMedicationInstitutionReview(
              id: 'review-$versionId-$institutionId',
              medicationVersionId: versionId,
              institutionId: institutionId,
              status: HealthMedicationReviewStatus.requested,
            ),
          )
          .toList(),
    );
    final medication = HealthMedication(id: medicationId, childId: childId, versions: [version]);
    _children[index] = child.copyWith(
      medications: [...child.medications, medication],
      auditEvents: [
        ...child.auditEvents,
        _audit(child, actor, 'Criação de medicamento', const {}, {'medication': medicationId}),
      ],
    );
    return medication;
  }

  Future<HealthSafetyAllergy> createAllergy({
    required String childId,
    required String label,
    required HealthSafetyAllergyType type,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.recordCreateEdit);
    final index = _childIndex(childId);
    final child = _children[index];
    if (!actor.canReadDetail(child)) throw StateError('Authorized context required.');
    final allergy = HealthSafetyAllergy(
      id: 'allergy-${child.id}-${child.allergies.length + 1}',
      childId: childId,
      label: label,
      type: type,
      active: true,
    );
    final receipt = _receipt(child, HealthSafetyAcknowledgementSubject.allergyOrRestriction);
    _children[index] = child.copyWith(
      allergies: [...child.allergies, allergy],
      acknowledgements: [...child.acknowledgements, receipt],
      notifications: [
        ...child.notifications,
        _notification(
          child,
          receipt,
          allergy.id,
          HealthSafetyAcknowledgementSubject.allergyOrRestriction,
        ),
      ],
      auditEvents: [
        ...child.auditEvents,
        _audit(child, actor, 'Criação de alergia ou restrição', const {}, {'allergy': allergy.id}),
      ],
    );
    return allergy;
  }

  Future<HealthMedicationChangeResult> changeMedicationRelevant({
    required String childId,
    required String medicationId,
    required String name,
    required String justification,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.exceptionalCorrection);
    if (justification.trim().isEmpty) {
      throw ArgumentError('Exceptional corrections require a justification.');
    }
    final childIndex = _childIndex(childId);
    final child = _children[childIndex];
    if (!actor.canReadDetail(child)) throw StateError('Authorized context required.');
    final medicationIndex = child.medications.indexWhere((item) => item.id == medicationId);
    if (medicationIndex < 0) throw ArgumentError.value(medicationId, 'medicationId');
    final medication = child.medications[medicationIndex];
    final previous = medication.currentVersion;
    _validateScheduleContexts(child, previous.schedules);
    final persistedReviews = previous.institutionReviews
        .map((review) => review.invalidateForCorrection())
        .toList();
    final invalidated = persistedReviews
        .where((review) => review.status == HealthMedicationReviewStatus.invalidated)
        .toList();
    final previousPersisted = previous.copyWith(institutionReviews: persistedReviews);
    final institutionIds = previous.schedules
        .where((schedule) => schedule.institutionId != null)
        .map((schedule) => schedule.institutionId!)
        .toSet();
    final nextId = '${medication.id}-v${previous.version + 1}';
    final version = HealthMedicationVersion(
      id: nextId,
      medicationId: medication.id,
      version: previous.version + 1,
      name: name,
      dose: previous.dose,
      doseUnit: previous.doseUnit,
      route: previous.route,
      startsAt: previous.startsAt,
      endsAt: previous.endsAt,
      status: HealthMedicationReviewStatus.underReview,
      schedules: previous.schedules,
      institutionReviews: institutionIds
          .map(
            (id) => HealthMedicationInstitutionReview(
              id: 'review-$nextId-$id',
              medicationVersionId: nextId,
              institutionId: id,
              status: HealthMedicationReviewStatus.underReview,
            ),
          )
          .toList(),
      prescriptionReference: previous.prescriptionReference,
      dispensedBy: previous.dispensedBy,
      policy: previous.policy,
    );
    final medications = [...child.medications];
    medications[medicationIndex] = HealthMedication(
      id: medication.id,
      childId: childId,
      versions: [
        ...medication.versions.where((item) => item.id != previous.id),
        previousPersisted,
        version,
      ],
    );
    final doses = child.doses
        .map(
          (dose) =>
              dose.medicationVersionId == previous.id &&
                  dose.dueAt.isAfter(clock) &&
                  dose.institutionId != null
              ? dose.copyWith(situation: HealthMedicationDoseSituation.paused)
              : dose,
        )
        .toList();
    _children[childIndex] = child.copyWith(
      medications: medications,
      doses: doses,
      auditEvents: [
        ...child.auditEvents,
        _audit(
          child,
          actor,
          justification,
          {'medication_version': previous.version},
          {'medication_version': version.version},
        ),
      ],
    );
    return HealthMedicationChangeResult(version: version, invalidatedReviews: invalidated);
  }

  Future<HealthMedicationInstitutionReview> reviewMedication({
    required String childId,
    required String medicationId,
    required HealthMedicationReviewStatus status,
    String? reason,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.clinicalReview);
    final childIndex = _childIndex(childId);
    final child = _children[childIndex];
    if (!actor.canReadDetail(child) || actor.institutionId == null) {
      throw StateError('Authorized institution context required.');
    }
    final medicationIndex = child.medications.indexWhere((item) => item.id == medicationId);
    if (medicationIndex < 0) throw ArgumentError.value(medicationId, 'medicationId');
    final medication = child.medications[medicationIndex];
    final current = medication.currentVersion;
    final reviewIndex = current.institutionReviews.indexWhere(
      (item) => item.institutionId == actor.institutionId,
    );
    if (reviewIndex < 0) throw StateError('Institution is not responsible for this version.');
    final reviews = [...current.institutionReviews];
    reviews[reviewIndex] = reviews[reviewIndex].transitionTo(status, reason: reason);
    final reviewed = current.copyWith(institutionReviews: reviews);
    final resolved = reviewed.copyWith(status: reviewed.resolveStatusAfterReviews(clock));
    final versions = medication.versions
        .map((item) => item.id == current.id ? resolved : item)
        .toList();
    final medications = [...child.medications];
    medications[medicationIndex] = HealthMedication(
      id: medication.id,
      childId: childId,
      versions: versions,
    );
    _children[childIndex] = child.copyWith(medications: medications);
    return reviews[reviewIndex];
  }

  Future<HealthMedicationClaimResult> claimDose({
    required String doseId,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.medicationClaim);
    final located = _locateDose(doseId);
    final dose = located.dose;
    _requireDoseContext(located, actor);
    if (dose.claimedBy != null &&
        dose.claimExpiresAt != null &&
        dose.claimExpiresAt!.isAfter(clock)) {
      if (dose.claimedBy == actor.id) {
        return HealthMedicationClaimResult(HealthMedicationClaimStatus.claimed, dose: dose);
      }
      return HealthMedicationClaimResult(
        HealthMedicationClaimStatus.conflict,
        dose: dose,
        conflictingProfessionalId: dose.claimedBy,
      );
    }
    if (!dose.dueAt.isAfter(clock) || dose.situation != HealthMedicationDoseSituation.scheduled) {
      throw StateError('Only a future pending dose can be claimed.');
    }
    final claimed = dose.copyWith(
      situation: HealthMedicationDoseSituation.claimed,
      claimedBy: actor.id,
      claimExpiresAt: clock.add(_medicationVersionFor(located).policy!.claimDuration),
    );
    _replaceDose(located, claimed);
    return HealthMedicationClaimResult(HealthMedicationClaimStatus.claimed, dose: claimed);
  }

  Future<HealthMedicationClaimResult> releaseDoseClaim({
    required String doseId,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.medicationClaim);
    final located = _locateDose(doseId);
    _requireDoseContext(located, actor);
    if (located.dose.situation != HealthMedicationDoseSituation.claimed ||
        located.dose.claimedBy != actor.id) {
      throw StateError('Only the active claimant can release a claim.');
    }
    final released = located.dose.clearClaim(situation: HealthMedicationDoseSituation.scheduled);
    _replaceDose(located, released);
    return HealthMedicationClaimResult(HealthMedicationClaimStatus.released, dose: released);
  }

  Future<HealthMedicationClaimResult> expireDoseClaim({
    required String doseId,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.medicationClaim);
    final located = _locateDose(doseId);
    _requireDoseContext(located, actor);
    if (located.dose.situation != HealthMedicationDoseSituation.claimed ||
        located.dose.claimExpiresAt == null ||
        located.dose.claimExpiresAt!.isAfter(clock)) {
      throw StateError('Only an expired active claim can be expired.');
    }
    final released = located.dose.clearClaim(situation: HealthMedicationDoseSituation.scheduled);
    _replaceDose(located, released);
    return HealthMedicationClaimResult(HealthMedicationClaimStatus.released, dose: released);
  }

  Future<HealthMedicationDose> recordDoseResult({
    required String doseId,
    required HealthMedicationDoseResult result,
    String? reason,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.administrationResult);
    final located = _locateDose(doseId);
    _requireDoseContext(located, actor);
    if (located.dose.situation != HealthMedicationDoseSituation.claimed ||
        located.dose.claimedBy != actor.id ||
        located.dose.claimExpiresAt == null ||
        !located.dose.claimExpiresAt!.isAfter(clock)) {
      throw StateError('An active claim owned by the actor is required.');
    }
    final situation = switch (result) {
      HealthMedicationDoseResult.administered => HealthMedicationDoseSituation.administered,
      HealthMedicationDoseResult.notAdministered => HealthMedicationDoseSituation.notAdministered,
      HealthMedicationDoseResult.refused => HealthMedicationDoseSituation.refused,
    };
    final recorded = HealthMedicationDose(
      id: located.dose.id,
      medicationVersionId: located.dose.medicationVersionId,
      dueAt: located.dose.dueAt,
      situation: situation,
      result: result,
      reason: reason,
      scheduleId: located.dose.scheduleId,
      institutionId: located.dose.institutionId,
      authorId: actor.id,
      recordedAt: clock,
    );
    _replaceDose(located, recorded);
    return recorded;
  }

  Future<HealthSafetyAcknowledgement> deactivateAllergy({
    required String childId,
    required String allergyId,
    required String justification,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.recordInactivate);
    if (justification.trim().isEmpty) {
      throw ArgumentError('Allergy inactivation requires an Owner justification.');
    }
    final index = _childIndex(childId);
    final child = _children[index];
    if (!actor.canReadDetail(child)) throw StateError('Authorized context required.');
    final allergyIndex = child.allergies.indexWhere((item) => item.id == allergyId);
    if (allergyIndex < 0) throw ArgumentError.value(allergyId, 'allergyId');
    final allergies = [...child.allergies];
    if (!allergies[allergyIndex].active) {
      return child.acknowledgements.lastWhere(
        (item) => item.subject == HealthSafetyAcknowledgementSubject.allergyOrRestriction,
        orElse: () => HealthSafetyAcknowledgement(
          id: 'ack-${child.id}-inactive-no-op',
          childId: child.id,
          subject: HealthSafetyAcknowledgementSubject.allergyOrRestriction,
          createdAt: allergies[allergyIndex].inactivatedAt ?? clock,
        ),
      );
    }
    allergies[allergyIndex] = allergies[allergyIndex].deactivate(clock);
    final receipt = _receipt(child, HealthSafetyAcknowledgementSubject.allergyOrRestriction);
    final notification = _notification(
      child,
      receipt,
      allergyId,
      HealthSafetyAcknowledgementSubject.allergyOrRestriction,
    );
    _children[index] = child.copyWith(
      allergies: allergies,
      acknowledgements: [...child.acknowledgements, receipt],
      notifications: [...child.notifications, notification],
      auditEvents: [
        ...child.auditEvents,
        _audit(child, actor, justification, {'active': true}, {'active': false}),
      ],
    );
    return receipt;
  }

  Future<HealthSafetyAcknowledgement> updateCareProfile({
    required String childId,
    required List<HealthSafetyCareProfileItem> items,
    required String justification,
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.recordCreateEdit);
    if (justification.trim().isEmpty) {
      throw ArgumentError('Care profile update requires an Owner justification.');
    }
    final index = _childIndex(childId);
    final child = _children[index];
    if (!actor.canReadDetail(child)) throw StateError('Authorized context required.');
    final receipt = _receipt(child, HealthSafetyAcknowledgementSubject.careProfile);
    final notification = _notification(
      child,
      receipt,
      items.isEmpty ? 'care-profile' : items.first.catalogItemId,
      HealthSafetyAcknowledgementSubject.careProfile,
    );
    final mergedItems = <String, HealthSafetyCareProfileItem>{
      for (final item in child.careProfile) item.catalogItemId: item,
      for (final item in items) item.catalogItemId: item,
    }.values.toList();
    _children[index] = child.copyWith(
      careProfile: mergedItems,
      acknowledgements: [...child.acknowledgements, receipt],
      notifications: [...child.notifications, notification],
      auditEvents: [
        ...child.auditEvents,
        _audit(
          child,
          actor,
          justification,
          {'items': child.careProfile.length},
          {'items': items.length},
        ),
      ],
    );
    return receipt;
  }

  Future<HealthSafetyNotification> markAcknowledged(
    String notificationId, {
    required HealthSafetyActor actor,
  }) async {
    _require(actor, HealthSafetyCapability.notifications);
    for (var childIndex = 0; childIndex < _children.length; childIndex++) {
      final child = _children[childIndex];
      final notificationIndex = child.notifications.indexWhere((item) => item.id == notificationId);
      if (notificationIndex < 0) continue;
      if (!actor.canReadDetail(child)) throw StateError('Authorized context required.');
      final notification = child.notifications[notificationIndex];
      if (notification.recipientId != actor.id) {
        throw StateError('Receipt belongs to another recipient.');
      }
      final notifications = [...child.notifications];
      notifications[notificationIndex] = notification.acknowledge(clock);
      final receipts = [...child.acknowledgements];
      final receiptIndex = receipts.indexWhere((item) => item.id == notification.receiptId);
      if (receiptIndex < 0) throw StateError('Notification receipt is missing.');
      receipts[receiptIndex] = receipts[receiptIndex].acknowledge(clock);
      _children[childIndex] = child.copyWith(
        notifications: notifications,
        acknowledgements: receipts,
      );
      return notifications[notificationIndex];
    }
    throw ArgumentError.value(notificationId, 'notificationId');
  }

  void _require(HealthSafetyActor actor, HealthSafetyCapability capability) {
    if (!actor.can(capability)) throw StateError('Missing capability: ${capability.name}.');
  }

  void _validateScheduleContexts(
    HealthSafetyChild child,
    Iterable<HealthMedicationSchedule> schedules,
  ) {
    final allowedInstitutions = child.links
        .where((link) => link.active && link.authorized)
        .map((link) => link.institutionId)
        .toSet();
    final invalid = schedules.any(
      (schedule) =>
          schedule.institutionId != null && !allowedInstitutions.contains(schedule.institutionId),
    );
    if (invalid) throw ArgumentError('Schedule institution is not authorized for this child.');
  }

  int _childIndex(String id) {
    final index = _children.indexWhere((child) => child.id == id);
    if (index < 0) throw ArgumentError.value(id, 'childId');
    return index;
  }

  _DoseLocation _locateDose(String doseId) {
    for (var childIndex = 0; childIndex < _children.length; childIndex++) {
      final doseIndex = _children[childIndex].doses.indexWhere((dose) => dose.id == doseId);
      if (doseIndex >= 0) {
        return _DoseLocation(childIndex, doseIndex, _children[childIndex].doses[doseIndex]);
      }
    }
    throw ArgumentError.value(doseId, 'doseId');
  }

  void _requireDoseContext(_DoseLocation located, HealthSafetyActor actor) {
    final dose = located.dose;
    if (dose.institutionId == null || !actor.isResponsibleFor(dose.institutionId!)) {
      throw StateError('Responsible institutional context required.');
    }
    final child = _children[located.childIndex];
    if (!actor.canReadDetail(child)) throw StateError('Active authorized child context required.');
    final version = child.medications
        .expand((item) => item.versions)
        .where((item) => item.id == dose.medicationVersionId)
        .firstOrNull;
    if (version == null ||
        (version.status != HealthMedicationReviewStatus.approved &&
            version.status != HealthMedicationReviewStatus.active)) {
      throw StateError('Medication version must be approved and active.');
    }
    final review = version.institutionReviews
        .where((item) => item.institutionId == dose.institutionId)
        .firstOrNull;
    if (review == null ||
        (review.status != HealthMedicationReviewStatus.approved &&
            review.status != HealthMedicationReviewStatus.active)) {
      throw StateError('Institutional review must be approved and active.');
    }
  }

  HealthMedicationVersion _medicationVersionFor(_DoseLocation located) {
    final version = _children[located.childIndex].medications
        .expand((item) => item.versions)
        .where((item) => item.id == located.dose.medicationVersionId)
        .firstOrNull;
    if (version == null || version.policy == null) {
      throw StateError('Medication administration policy is required.');
    }
    return version;
  }

  void _replaceDose(_DoseLocation location, HealthMedicationDose dose) {
    final child = _children[location.childIndex];
    final doses = [...child.doses];
    doses[location.doseIndex] = dose;
    _children[location.childIndex] = child.copyWith(doses: doses);
  }

  HealthSafetyAcknowledgement _receipt(
    HealthSafetyChild child,
    HealthSafetyAcknowledgementSubject subject,
  ) => HealthSafetyAcknowledgement(
    id: 'ack-${child.id}-${child.acknowledgements.length + 1}',
    childId: child.id,
    subject: subject,
    createdAt: clock,
  );

  HealthSafetyNotification _notification(
    HealthSafetyChild child,
    HealthSafetyAcknowledgement receipt,
    String itemId,
    HealthSafetyAcknowledgementSubject subject,
  ) => HealthSafetyNotification(
    id: 'notification-${child.id}-${child.notifications.length + 1}',
    childId: child.id,
    subject: subject,
    itemId: itemId,
    recipientId: 'guardian-demo-a',
    receiptId: receipt.id,
    createdAt: clock,
  );

  HealthSafetyAuditEvent _audit(
    HealthSafetyChild child,
    HealthSafetyActor actor,
    String justification,
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) => HealthSafetyAuditEvent(
    id: 'audit-${child.auditEvents.length + 1}',
    actorId: actor.id,
    justification: justification,
    before: before,
    after: after,
    createdAt: clock,
  );
}

final class _DoseLocation {
  const _DoseLocation(this.childIndex, this.doseIndex, this.dose);
  final int childIndex;
  final int doseIndex;
  final HealthMedicationDose dose;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

List<HealthSafetyChild> _demoChildren() {
  final policy = HealthMedicationAdministrationPolicy(
    earlyReminder: const Duration(minutes: 30),
    tolerance: const Duration(minutes: 10),
    escalationAfter: const Duration(minutes: 20),
    claimDuration: const Duration(minutes: 7),
    recipientIds: {'professional-demo-professor', 'professional-demo-nurse'},
    escalationRecipientIds: {'coordinator-demo-a'},
  );
  final schedules = [
    HealthMedicationSchedule(id: 'schedule-home', time: HealthSafetyTimeOfDay(7, 30), atHome: true),
    HealthMedicationSchedule(
      id: 'schedule-institution-a',
      time: HealthSafetyTimeOfDay(16, 0),
      institutionId: 'institution-demo-a',
    ),
    HealthMedicationSchedule(
      id: 'schedule-institution-b',
      time: HealthSafetyTimeOfDay(17, 0),
      institutionId: 'institution-demo-b',
    ),
  ];
  final version = HealthMedicationVersion(
    id: 'medication-demo-a-v1',
    medicationId: 'medication-demo-a',
    version: 1,
    name: 'Medicamento Demo',
    dose: '5',
    doseUnit: 'mL',
    route: 'oral',
    startsAt: DateTime.utc(2026, 8, 1),
    endsAt: DateTime.utc(2026, 8, 10),
    status: HealthMedicationReviewStatus.approved,
    schedules: schedules,
    institutionReviews: const [
      HealthMedicationInstitutionReview(
        id: 'review-a',
        medicationVersionId: 'medication-demo-a-v1',
        institutionId: 'institution-demo-a',
        status: HealthMedicationReviewStatus.approved,
      ),
      HealthMedicationInstitutionReview(
        id: 'review-b',
        medicationVersionId: 'medication-demo-a-v1',
        institutionId: 'institution-demo-b',
        status: HealthMedicationReviewStatus.refused,
        reason: 'Recusa demonstrativa anterior',
      ),
    ],
    approvedAt: DemoHealthSafetyRepository.fixedClock,
    prescriptionReference: 'prescription-demo.pdf',
    dispensedBy: 'guardian-demo-a',
    policy: policy,
  );
  final oldVersion = HealthMedicationVersion(
    id: 'medication-demo-a-v0',
    medicationId: 'medication-demo-a',
    version: 0,
    name: 'Medicamento Demo anterior',
    dose: '5',
    doseUnit: 'mL',
    route: 'oral',
    startsAt: DateTime.utc(2026, 7, 1),
    endsAt: DateTime.utc(2026, 7, 31),
    status: HealthMedicationReviewStatus.ended,
    schedules: schedules,
  );
  return [
    HealthSafetyChild(
      id: 'child-demo-a',
      personId: 'person-demo-a',
      displayName: 'Criança Demo A',
      operationalStatus: HealthSafetyOperationalStatus.active,
      links: const [
        HealthSafetyContextLink(
          institutionId: 'institution-demo-a',
          unitId: 'unit-demo-a',
          groupOrActivityId: 'group-demo-a',
        ),
        HealthSafetyContextLink(
          institutionId: 'institution-demo-b',
          unitId: 'unit-demo-b',
          groupOrActivityId: 'group-demo-b',
        ),
      ],
      medications: [
        HealthMedication(
          id: 'medication-demo-a',
          childId: 'child-demo-a',
          versions: [version, oldVersion],
        ),
      ],
      doses: [
        HealthMedicationDose(
          id: 'dose-demo-past',
          medicationVersionId: version.id,
          dueAt: DateTime.utc(2026, 8, 3, 8),
          situation: HealthMedicationDoseSituation.administered,
          result: HealthMedicationDoseResult.administered,
          scheduleId: 'schedule-institution-a',
          institutionId: 'institution-demo-a',
          authorId: 'professional-demo-nurse',
          recordedAt: DateTime.utc(2026, 8, 3, 8),
        ),
        HealthMedicationDose(
          id: 'dose-demo-claimed',
          medicationVersionId: version.id,
          dueAt: DateTime.utc(2026, 8, 3, 16),
          situation: HealthMedicationDoseSituation.claimed,
          claimedBy: 'professional-demo-professor',
          claimExpiresAt: DateTime.utc(2026, 8, 3, 12, 15),
          scheduleId: 'schedule-institution-a',
          institutionId: 'institution-demo-a',
        ),
        HealthMedicationDose(
          id: 'dose-demo-expired',
          medicationVersionId: version.id,
          dueAt: DateTime.utc(2026, 8, 3, 15),
          situation: HealthMedicationDoseSituation.claimed,
          claimedBy: 'professional-demo-nurse',
          claimExpiresAt: DateTime.utc(2026, 8, 3, 11, 59),
          scheduleId: 'schedule-institution-a',
          institutionId: 'institution-demo-a',
        ),
        HealthMedicationDose(
          id: 'dose-demo-future',
          medicationVersionId: version.id,
          dueAt: DateTime.utc(2026, 8, 3, 18),
          scheduleId: 'schedule-institution-a',
          institutionId: 'institution-demo-a',
        ),
        HealthMedicationDose(
          id: 'dose-demo-other-version-future',
          medicationVersionId: oldVersion.id,
          dueAt: DateTime.utc(2026, 8, 3, 18, 30),
          scheduleId: 'schedule-institution-a',
          institutionId: 'institution-demo-a',
        ),
        HealthMedicationDose(
          id: 'dose-demo-home-future',
          medicationVersionId: version.id,
          dueAt: DateTime.utc(2026, 8, 3, 19),
          scheduleId: 'schedule-home',
        ),
        HealthMedicationDose(
          id: 'dose-demo-paused',
          medicationVersionId: version.id,
          dueAt: DateTime.utc(2026, 8, 3, 20),
          situation: HealthMedicationDoseSituation.paused,
          scheduleId: 'schedule-institution-a',
          institutionId: 'institution-demo-a',
        ),
        HealthMedicationDose(
          id: 'dose-demo-institution-b',
          medicationVersionId: version.id,
          dueAt: DateTime.utc(2026, 8, 3, 20),
          scheduleId: 'schedule-institution-b',
          institutionId: 'institution-demo-b',
        ),
        HealthMedicationDose(
          id: 'dose-demo-late',
          medicationVersionId: version.id,
          dueAt: DateTime.utc(2026, 8, 3, 11, 30),
          situation: HealthMedicationDoseSituation.late,
          scheduleId: 'schedule-institution-a',
          institutionId: 'institution-demo-a',
        ),
        HealthMedicationDose(
          id: 'dose-demo-refused',
          medicationVersionId: version.id,
          dueAt: DateTime.utc(2026, 8, 3, 10),
          situation: HealthMedicationDoseSituation.refused,
          result: HealthMedicationDoseResult.refused,
          reason: 'Recusa demonstrativa',
          scheduleId: 'schedule-institution-a',
          institutionId: 'institution-demo-a',
          authorId: 'professional-demo-professor',
          recordedAt: DateTime.utc(2026, 8, 3, 10),
        ),
      ],
      allergies: [
        HealthSafetyAllergy(
          id: 'allergy-demo-active',
          childId: 'child-demo-a',
          label: 'Alergia Medicamentosa Demo',
          type: HealthSafetyAllergyType.medication,
          active: true,
        ),
        HealthSafetyAllergy(
          id: 'allergy-demo-inactive',
          childId: 'child-demo-a',
          label: 'Restrição Demo',
          type: HealthSafetyAllergyType.restriction,
          active: false,
          inactivatedAt: DemoHealthSafetyRepository.fixedClock,
        ),
      ],
      careProfile: [HealthSafetyCareProfileItem(catalogItemId: 'autism')],
      acknowledgements: [
        HealthSafetyAcknowledgement(
          id: 'ack-pending',
          childId: 'child-demo-a',
          subject: HealthSafetyAcknowledgementSubject.careProfile,
          createdAt: DemoHealthSafetyRepository.fixedClock,
        ),
        HealthSafetyAcknowledgement(
          id: 'ack-completed',
          childId: 'child-demo-a',
          subject: HealthSafetyAcknowledgementSubject.medication,
          createdAt: DateTime.utc(2026, 8, 3, 9),
          receivedAt: DateTime.utc(2026, 8, 3, 9, 5),
        ),
      ],
      notifications: [
        HealthSafetyNotification(
          id: 'notification-professor',
          childId: 'child-demo-a',
          subject: HealthSafetyAcknowledgementSubject.medication,
          itemId: 'dose-demo-future',
          recipientId: 'professional-demo-professor',
          receiptId: 'ack-pending',
          createdAt: DemoHealthSafetyRepository.fixedClock,
        ),
        HealthSafetyNotification(
          id: 'notification-nurse',
          childId: 'child-demo-a',
          subject: HealthSafetyAcknowledgementSubject.medication,
          itemId: 'dose-demo-future',
          recipientId: 'professional-demo-nurse',
          receiptId: 'ack-completed',
          createdAt: DemoHealthSafetyRepository.fixedClock,
          acknowledgedAt: DemoHealthSafetyRepository.fixedClock,
        ),
      ],
      auditEvents: [
        HealthSafetyAuditEvent(
          id: 'audit-owner-fixture',
          actorId: 'owner-demo',
          justification: 'Correção demonstrativa anterior',
          before: const {'status': 'before'},
          after: const {'status': 'after'},
          createdAt: DemoHealthSafetyRepository.fixedClock,
        ),
      ],
    ),
    HealthSafetyChild(
      id: 'child-demo-b',
      personId: 'person-demo-b',
      displayName: 'Criança Demo B',
      operationalStatus: HealthSafetyOperationalStatus.pending,
      links: const [HealthSafetyContextLink(institutionId: 'institution-demo-b')],
    ),
    HealthSafetyChild(
      id: 'child-demo-unauthorized',
      personId: 'person-demo-unauthorized',
      displayName: 'Criança Demo C',
      operationalStatus: HealthSafetyOperationalStatus.active,
      links: const [
        HealthSafetyContextLink(institutionId: 'institution-demo-a', authorized: false),
      ],
    ),
  ];
}
