/// Local-only health and safety demonstration domain. It has no backend contract.
enum HealthSafetyCapability {
  sensitiveRead,
  clinicalReview,
  notifications,
  medicationClaim,
  administrationResult,
  guardianConfiguration,
  auditRead,
  exceptionalCorrection,
  recordCreateEdit,
  recordInactivate,
}

enum DemoHealthSafetyProfile { owner, sensitiveReader, minimized }

extension DemoHealthSafetyProfileCapabilities on DemoHealthSafetyProfile {
  Set<HealthSafetyCapability> get capabilities => switch (this) {
    DemoHealthSafetyProfile.owner => const {
      HealthSafetyCapability.sensitiveRead,
      HealthSafetyCapability.auditRead,
      HealthSafetyCapability.exceptionalCorrection,
      HealthSafetyCapability.recordCreateEdit,
      HealthSafetyCapability.recordInactivate,
    },
    DemoHealthSafetyProfile.sensitiveReader => const {HealthSafetyCapability.sensitiveRead},
    DemoHealthSafetyProfile.minimized => const {},
  };

  bool can(HealthSafetyCapability capability) => capabilities.contains(capability);
}

enum HealthSafetyOperationalStatus { active, pending, inactive }

enum HealthMedicationReviewStatus {
  requested,
  underReview,
  approved,
  refused,
  active,
  ended,
  rejected,
  invalidated,
}

enum HealthMedicationDoseSituation {
  scheduled,
  claimed,
  administered,
  notAdministered,
  refused,
  paused,
  late,
}

enum HealthMedicationDoseResult { administered, notAdministered, refused }

enum HealthMedicationClaimStatus { claimed, conflict, released }

enum HealthSafetyAllergyType { medication, food, restriction, other }

enum HealthSafetyAcknowledgementSubject { medication, allergyOrRestriction, careProfile }

enum HealthMedicationPolicyPhase {
  scheduled,
  earlyReminder,
  dueNotification,
  tolerance,
  late,
  escalated,
}

enum HealthSafetyFixtureScenario {
  multiInstitutionChild,
  prescriptionAndDispensing,
  multipleRecipients,
  multipleProfessionals,
  claimConflict,
  lateDose,
  refusedDose,
  activeMedicationAllergy,
  inactiveAllergy,
  pendingAcknowledgement,
  completedAcknowledgement,
  minimizedUser,
  ownerAudit,
  remindersAndEscalation,
}

final class HealthSafetyTimeOfDay {
  HealthSafetyTimeOfDay(this.hour, this.minute) {
    if (hour < 0 || hour > 23) throw ArgumentError.value(hour, 'hour');
    if (minute < 0 || minute > 59) throw ArgumentError.value(minute, 'minute');
  }
  final int hour;
  final int minute;
}

final class HealthSafetyContextLink {
  const HealthSafetyContextLink({
    required this.institutionId,
    this.unitId,
    this.groupOrActivityId,
    this.authorized = true,
    this.active = true,
  });
  final String institutionId;
  final String? unitId;
  final String? groupOrActivityId;
  final bool authorized;
  final bool active;
}

final class HealthSafetyActor {
  HealthSafetyActor({
    required this.id,
    required this.profile,
    this.institutionId,
    Set<String> authorizedChildIds = const {},
    Set<String> responsibleInstitutionIds = const {},
    Set<HealthSafetyCapability> contextualCapabilities = const {},
  }) : authorizedChildIds = Set.unmodifiable(authorizedChildIds),
       responsibleInstitutionIds = Set.unmodifiable(responsibleInstitutionIds),
       contextualCapabilities = Set.unmodifiable(contextualCapabilities);

  final String id;
  final DemoHealthSafetyProfile profile;
  final String? institutionId;
  final Set<String> authorizedChildIds;
  final Set<String> responsibleInstitutionIds;
  final Set<HealthSafetyCapability> contextualCapabilities;

  bool can(HealthSafetyCapability capability) {
    const ownerOnly = {
      HealthSafetyCapability.exceptionalCorrection,
      HealthSafetyCapability.recordCreateEdit,
      HealthSafetyCapability.recordInactivate,
    };
    if (ownerOnly.contains(capability)) return profile == DemoHealthSafetyProfile.owner;
    return profile.can(capability) || contextualCapabilities.contains(capability);
  }

  bool canReadDetail(HealthSafetyChild child) {
    if (!can(HealthSafetyCapability.sensitiveRead) || !authorizedChildIds.contains(child.id)) {
      return false;
    }
    return child.links.any(
      (link) =>
          link.active &&
          link.authorized &&
          (institutionId == null || link.institutionId == institutionId),
    );
  }

  bool isResponsibleFor(String institution) =>
      institutionId == institution && responsibleInstitutionIds.contains(institution);
}

final class HealthSafetyChild {
  HealthSafetyChild({
    required this.id,
    required this.personId,
    required this.displayName,
    required this.operationalStatus,
    List<HealthSafetyContextLink> links = const [],
    List<HealthMedication> medications = const [],
    List<HealthMedicationDose> doses = const [],
    List<HealthSafetyAllergy> allergies = const [],
    List<HealthSafetyCareProfileItem> careProfile = const [],
    List<HealthSafetyAcknowledgement> acknowledgements = const [],
    List<HealthSafetyNotification> notifications = const [],
    List<HealthSafetyAuditEvent> auditEvents = const [],
  }) : links = List.unmodifiable(links),
       medications = List.unmodifiable(medications),
       doses = List.unmodifiable(doses),
       allergies = List.unmodifiable(allergies),
       careProfile = List.unmodifiable(careProfile),
       acknowledgements = List.unmodifiable(acknowledgements),
       notifications = List.unmodifiable(notifications),
       auditEvents = List.unmodifiable(auditEvents);

  final String id;
  final String personId;
  final String displayName;
  final HealthSafetyOperationalStatus operationalStatus;
  final List<HealthSafetyContextLink> links;
  final List<HealthMedication> medications;
  final List<HealthMedicationDose> doses;
  final List<HealthSafetyAllergy> allergies;
  final List<HealthSafetyCareProfileItem> careProfile;
  final List<HealthSafetyAcknowledgement> acknowledgements;
  final List<HealthSafetyNotification> notifications;
  final List<HealthSafetyAuditEvent> auditEvents;

  HealthSafetyChild copyWith({
    List<HealthMedication>? medications,
    List<HealthMedicationDose>? doses,
    List<HealthSafetyAllergy>? allergies,
    List<HealthSafetyCareProfileItem>? careProfile,
    List<HealthSafetyAcknowledgement>? acknowledgements,
    List<HealthSafetyNotification>? notifications,
    List<HealthSafetyAuditEvent>? auditEvents,
  }) => HealthSafetyChild(
    id: id,
    personId: personId,
    displayName: displayName,
    operationalStatus: operationalStatus,
    links: links,
    medications: medications ?? this.medications,
    doses: doses ?? this.doses,
    allergies: allergies ?? this.allergies,
    careProfile: careProfile ?? this.careProfile,
    acknowledgements: acknowledgements ?? this.acknowledgements,
    notifications: notifications ?? this.notifications,
    auditEvents: auditEvents ?? this.auditEvents,
  );
}

final class HealthSafetyChildSummary {
  const HealthSafetyChildSummary({
    required this.id,
    required this.personId,
    required this.displayName,
    required this.operationalStatus,
    required this.medicationCount,
    required this.activeAllergyCount,
    required this.pendingAcknowledgementCount,
  });

  factory HealthSafetyChildSummary.fromChild(
    HealthSafetyChild child, {
    required DemoHealthSafetyProfile profile,
  }) {
    final minimized = profile == DemoHealthSafetyProfile.minimized;
    return HealthSafetyChildSummary(
      id: child.id,
      personId: minimized ? null : child.personId,
      displayName: minimized ? 'Criança protegida' : child.displayName,
      operationalStatus: child.operationalStatus,
      medicationCount: child.medications.length,
      activeAllergyCount: child.allergies.where((item) => item.active).length,
      pendingAcknowledgementCount: child.acknowledgements
          .where((item) => item.receivedAt == null)
          .length,
    );
  }

  final String id;
  final String? personId;
  final String displayName;
  final HealthSafetyOperationalStatus operationalStatus;
  final int medicationCount;
  final int activeAllergyCount;
  final int pendingAcknowledgementCount;
}

final class HealthSafetyDirectoryQuery {
  const HealthSafetyDirectoryQuery({
    this.search = '',
    this.personIds = const {},
    this.childIds = const {},
    this.institutionIds = const {},
    this.unitIds = const {},
    this.groupOrActivityIds = const {},
    this.operationalStatuses = const {},
    this.doseSituations = const {},
    this.page = 0,
    this.pageSize = 10,
  }) : assert(page >= 0),
       assert(pageSize > 0);
  final String search;
  final Set<String> personIds;
  final Set<String> childIds;
  final Set<String> institutionIds;
  final Set<String> unitIds;
  final Set<String> groupOrActivityIds;
  final Set<HealthSafetyOperationalStatus> operationalStatuses;
  final Set<HealthMedicationDoseSituation> doseSituations;
  final int page;
  final int pageSize;
  int get offset => page * pageSize;

  bool matches(HealthSafetyChild child) {
    final normalized = search.trim().toLowerCase();
    final matchesIdentity =
        (normalized.isEmpty || child.displayName.toLowerCase().contains(normalized)) &&
        (personIds.isEmpty || personIds.contains(child.personId)) &&
        (childIds.isEmpty || childIds.contains(child.id));
    final hasContextFilter =
        institutionIds.isNotEmpty || unitIds.isNotEmpty || groupOrActivityIds.isNotEmpty;
    final matchesContext =
        !hasContextFilter ||
        child.links.any(
          (link) =>
              link.active &&
              link.authorized &&
              (institutionIds.isEmpty || institutionIds.contains(link.institutionId)) &&
              (unitIds.isEmpty || unitIds.contains(link.unitId)) &&
              (groupOrActivityIds.isEmpty || groupOrActivityIds.contains(link.groupOrActivityId)),
        );
    return matchesIdentity &&
        (operationalStatuses.isEmpty || operationalStatuses.contains(child.operationalStatus)) &&
        (doseSituations.isEmpty ||
            child.doses.any((dose) => doseSituations.contains(dose.situation))) &&
        matchesContext;
  }
}

final class HealthSafetyDirectoryPage {
  HealthSafetyDirectoryPage({
    required List<HealthSafetyChildSummary> items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  }) : items = List.unmodifiable(items);
  final List<HealthSafetyChildSummary> items;
  final int totalCount;
  final int page;
  final int pageSize;
}

final class HealthMedicationSchedule {
  HealthMedicationSchedule({
    required this.id,
    required this.time,
    this.atHome = false,
    this.institutionId,
  }) {
    if (atHome == (institutionId != null)) {
      throw ArgumentError('A schedule must belong exclusively to home or one institution.');
    }
  }
  final String id;
  final HealthSafetyTimeOfDay time;
  final bool atHome;
  final String? institutionId;
}

final class HealthMedicationAdministrationPolicy {
  HealthMedicationAdministrationPolicy({
    required this.earlyReminder,
    required this.tolerance,
    required this.escalationAfter,
    required this.claimDuration,
    required Set<String> recipientIds,
    required Set<String> escalationRecipientIds,
  }) : recipientIds = Set.unmodifiable(recipientIds),
       escalationRecipientIds = Set.unmodifiable(escalationRecipientIds) {
    if (earlyReminder <= Duration.zero ||
        tolerance < Duration.zero ||
        escalationAfter <= tolerance ||
        claimDuration <= Duration.zero) {
      throw ArgumentError('Medication policy durations are inconsistent.');
    }
  }

  final Duration earlyReminder;
  final Duration tolerance;
  final Duration escalationAfter;
  final Duration claimDuration;
  final Set<String> recipientIds;
  final Set<String> escalationRecipientIds;

  HealthMedicationPolicyPhase phaseAt(DateTime dueAt, DateTime now) {
    if (now.isBefore(dueAt.subtract(earlyReminder))) return HealthMedicationPolicyPhase.scheduled;
    if (now.isBefore(dueAt)) return HealthMedicationPolicyPhase.earlyReminder;
    if (now.isAtSameMomentAs(dueAt)) return HealthMedicationPolicyPhase.dueNotification;
    if (!now.isAfter(dueAt.add(tolerance))) return HealthMedicationPolicyPhase.tolerance;
    if (now.isBefore(dueAt.add(escalationAfter))) return HealthMedicationPolicyPhase.late;
    return HealthMedicationPolicyPhase.escalated;
  }
}

final class HealthMedicationInstitutionReview {
  const HealthMedicationInstitutionReview({
    required this.id,
    required this.medicationVersionId,
    required this.institutionId,
    required this.status,
    this.reason,
  });
  final String id;
  final String medicationVersionId;
  final String institutionId;
  final HealthMedicationReviewStatus status;
  final String? reason;

  HealthMedicationInstitutionReview transitionTo(
    HealthMedicationReviewStatus next, {
    String? reason,
  }) {
    if (next == HealthMedicationReviewStatus.refused && (reason == null || reason.trim().isEmpty)) {
      throw ArgumentError('Medication refusal requires a reason.');
    }
    final allowed = switch (status) {
      HealthMedicationReviewStatus.requested => next == HealthMedicationReviewStatus.underReview,
      HealthMedicationReviewStatus.underReview =>
        next == HealthMedicationReviewStatus.approved ||
            next == HealthMedicationReviewStatus.refused,
      HealthMedicationReviewStatus.approved ||
      HealthMedicationReviewStatus.active => next == HealthMedicationReviewStatus.invalidated,
      _ => false,
    };
    if (!allowed) throw StateError('Invalid institutional review transition.');
    return HealthMedicationInstitutionReview(
      id: id,
      medicationVersionId: medicationVersionId,
      institutionId: institutionId,
      status: next,
      reason: reason,
    );
  }

  HealthMedicationInstitutionReview invalidateForCorrection() =>
      status == HealthMedicationReviewStatus.approved ||
          status == HealthMedicationReviewStatus.active
      ? transitionTo(HealthMedicationReviewStatus.invalidated)
      : this;
}

final class HealthMedicationVersion {
  HealthMedicationVersion({
    required this.id,
    required this.medicationId,
    required this.version,
    required this.name,
    required this.dose,
    required this.doseUnit,
    required this.route,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required List<HealthMedicationSchedule> schedules,
    List<HealthMedicationInstitutionReview> institutionReviews = const [],
    this.approvedAt,
    this.prescriptionReference,
    this.documentName,
    this.documentType,
    this.dispensedBy,
    this.policy,
  }) : schedules = List.unmodifiable(schedules),
       institutionReviews = List.unmodifiable(institutionReviews) {
    if (name.trim().isEmpty ||
        dose.trim().isEmpty ||
        doseUnit.trim().isEmpty ||
        route.trim().isEmpty ||
        schedules.isEmpty) {
      throw ArgumentError('Medication version requires prescription details and one schedule.');
    }
    if (endsAt.isBefore(startsAt)) throw ArgumentError('Medication end cannot precede start.');
    if (institutionReviews.any((review) => review.medicationVersionId != id)) {
      throw ArgumentError('Institution reviews must belong to this medication version.');
    }
  }
  final String id;
  final String medicationId;
  final int version;
  final String name;
  final String dose;
  final String doseUnit;
  final String route;
  final DateTime startsAt;
  final DateTime endsAt;
  final HealthMedicationReviewStatus status;
  final List<HealthMedicationSchedule> schedules;
  final List<HealthMedicationInstitutionReview> institutionReviews;
  final DateTime? approvedAt;
  final String? prescriptionReference;
  final String? documentName;
  final String? documentType;
  final String? dispensedBy;
  final HealthMedicationAdministrationPolicy? policy;
  int get frequencyPerDay => schedules.length;

  HealthMedicationVersion copyWith({
    HealthMedicationReviewStatus? status,
    List<HealthMedicationInstitutionReview>? institutionReviews,
    HealthMedicationAdministrationPolicy? policy,
  }) => HealthMedicationVersion(
    id: id,
    medicationId: medicationId,
    version: version,
    name: name,
    dose: dose,
    doseUnit: doseUnit,
    route: route,
    startsAt: startsAt,
    endsAt: endsAt,
    status: status ?? this.status,
    schedules: schedules,
    institutionReviews: institutionReviews ?? this.institutionReviews,
    approvedAt: approvedAt,
    prescriptionReference: prescriptionReference,
    documentName: documentName,
    documentType: documentType,
    dispensedBy: dispensedBy,
    policy: policy ?? this.policy,
  );

  HealthMedicationReviewStatus resolveStatusAfterReviews(DateTime now) {
    if (institutionReviews.any((review) => review.status == HealthMedicationReviewStatus.refused)) {
      return HealthMedicationReviewStatus.refused;
    }
    final allApproved =
        institutionReviews.isNotEmpty &&
        institutionReviews.every(
          (review) =>
              review.status == HealthMedicationReviewStatus.approved ||
              review.status == HealthMedicationReviewStatus.active,
        );
    if (!allApproved) return HealthMedicationReviewStatus.underReview;
    final withinPeriod = !now.isBefore(startsAt) && !now.isAfter(endsAt);
    return withinPeriod && policy != null
        ? HealthMedicationReviewStatus.active
        : HealthMedicationReviewStatus.approved;
  }

  HealthMedicationVersion transitionTo(HealthMedicationReviewStatus next) {
    const allowed = <HealthMedicationReviewStatus, Set<HealthMedicationReviewStatus>>{
      HealthMedicationReviewStatus.requested: {HealthMedicationReviewStatus.underReview},
      HealthMedicationReviewStatus.underReview: {
        HealthMedicationReviewStatus.approved,
        HealthMedicationReviewStatus.refused,
      },
      HealthMedicationReviewStatus.approved: {
        HealthMedicationReviewStatus.active,
        HealthMedicationReviewStatus.underReview,
      },
      HealthMedicationReviewStatus.active: {
        HealthMedicationReviewStatus.ended,
        HealthMedicationReviewStatus.underReview,
      },
    };
    if (!(allowed[status]?.contains(next) ?? false)) {
      throw StateError('Invalid medication lifecycle transition.');
    }
    return copyWith(status: next);
  }
}

final class HealthMedication {
  HealthMedication({
    required this.id,
    required this.childId,
    required List<HealthMedicationVersion> versions,
  }) : versions = List.unmodifiable(versions) {
    if (versions.isEmpty) throw ArgumentError('Medication requires a version.');
  }
  final String id;
  final String childId;
  final List<HealthMedicationVersion> versions;
  HealthMedicationVersion get currentVersion =>
      versions.reduce((a, b) => a.version > b.version ? a : b);
}

const Object _notProvided = Object();

final class HealthMedicationDose {
  HealthMedicationDose({
    required this.id,
    required this.medicationVersionId,
    required this.dueAt,
    this.situation = HealthMedicationDoseSituation.scheduled,
    this.result,
    this.reason,
    this.claimedBy,
    this.claimExpiresAt,
    this.scheduleId,
    this.institutionId,
    this.authorId,
    this.recordedAt,
  }) {
    if ((result == HealthMedicationDoseResult.notAdministered ||
            result == HealthMedicationDoseResult.refused) &&
        (reason == null || reason!.trim().isEmpty)) {
      throw ArgumentError('A reason is required for this dose result.');
    }
    if (result != null && (authorId == null || authorId!.trim().isEmpty || recordedAt == null)) {
      throw ArgumentError('A dose result requires author and timestamp.');
    }
  }
  final String id;
  final String medicationVersionId;
  final DateTime dueAt;
  final HealthMedicationDoseSituation situation;
  final HealthMedicationDoseResult? result;
  final String? reason;
  final String? claimedBy;
  final DateTime? claimExpiresAt;
  final String? scheduleId;
  final String? institutionId;
  final String? authorId;
  final DateTime? recordedAt;

  HealthMedicationDose copyWith({
    HealthMedicationDoseSituation? situation,
    HealthMedicationDoseResult? result,
    Object? reason = _notProvided,
    Object? claimedBy = _notProvided,
    Object? claimExpiresAt = _notProvided,
    Object? scheduleId = _notProvided,
    Object? institutionId = _notProvided,
    Object? authorId = _notProvided,
    Object? recordedAt = _notProvided,
  }) => HealthMedicationDose(
    id: id,
    medicationVersionId: medicationVersionId,
    dueAt: dueAt,
    situation: situation ?? this.situation,
    result: result ?? this.result,
    reason: identical(reason, _notProvided) ? this.reason : reason as String?,
    claimedBy: identical(claimedBy, _notProvided) ? this.claimedBy : claimedBy as String?,
    claimExpiresAt: identical(claimExpiresAt, _notProvided)
        ? this.claimExpiresAt
        : claimExpiresAt as DateTime?,
    scheduleId: identical(scheduleId, _notProvided) ? this.scheduleId : scheduleId as String?,
    institutionId: identical(institutionId, _notProvided)
        ? this.institutionId
        : institutionId as String?,
    authorId: identical(authorId, _notProvided) ? this.authorId : authorId as String?,
    recordedAt: identical(recordedAt, _notProvided) ? this.recordedAt : recordedAt as DateTime?,
  );

  HealthMedicationDose clearClaim({HealthMedicationDoseSituation? situation}) =>
      copyWith(situation: situation, claimedBy: null, claimExpiresAt: null);
}

final class HealthMedicationClaimResult {
  const HealthMedicationClaimResult(this.status, {this.dose, this.conflictingProfessionalId});
  final HealthMedicationClaimStatus status;
  final HealthMedicationDose? dose;
  final String? conflictingProfessionalId;
}

final class HealthMedicationChangeResult {
  HealthMedicationChangeResult({
    required this.version,
    required List<HealthMedicationInstitutionReview> invalidatedReviews,
  }) : invalidatedReviews = List.unmodifiable(invalidatedReviews);
  final HealthMedicationVersion version;
  final List<HealthMedicationInstitutionReview> invalidatedReviews;
}

final class HealthSafetyAllergy {
  HealthSafetyAllergy({
    required this.id,
    required this.childId,
    required this.label,
    required this.type,
    required this.active,
    this.inactivatedAt,
  }) {
    if (label.trim().isEmpty) throw ArgumentError('Allergy label is required.');
  }
  final String id;
  final String childId;
  final String label;
  final HealthSafetyAllergyType type;
  final bool active;
  final DateTime? inactivatedAt;
  HealthSafetyAllergy deactivate(DateTime when) => !active
      ? this
      : HealthSafetyAllergy(
          id: id,
          childId: childId,
          label: label,
          type: type,
          active: false,
          inactivatedAt: when,
        );
}

final class HealthSafetyCareProfileCatalogGroup {
  const HealthSafetyCareProfileCatalogGroup({
    required this.id,
    required this.label,
    required this.items,
  });
  final String id;
  final String label;
  final List<HealthSafetyCareProfileCatalogItem> items;
}

final class HealthSafetyCareProfileCatalogItem {
  const HealthSafetyCareProfileCatalogItem({required this.id, required this.label});
  final String id;
  final String label;
  @override
  bool operator ==(Object other) =>
      other is HealthSafetyCareProfileCatalogItem && other.id == id && other.label == label;
  @override
  int get hashCode => Object.hash(id, label);
}

const healthSafetyCareProfileCatalog = <HealthSafetyCareProfileCatalogGroup>[
  HealthSafetyCareProfileCatalogGroup(
    id: 'neurodevelopment',
    label: 'Neurodesenvolvimento',
    items: [
      HealthSafetyCareProfileCatalogItem(id: 'autism', label: 'Autismo'),
      HealthSafetyCareProfileCatalogItem(id: 'adhd', label: 'TDAH'),
      HealthSafetyCareProfileCatalogItem(id: 'dyslexia', label: 'Dislexia'),
      HealthSafetyCareProfileCatalogItem(id: 'dyspraxia', label: 'Dispraxia'),
      HealthSafetyCareProfileCatalogItem(id: 'giftedness', label: 'Altas habilidades/superdotação'),
    ],
  ),
  HealthSafetyCareProfileCatalogGroup(
    id: 'motor-mobility',
    label: 'Desenvolvimento motor e mobilidade',
    items: [
      HealthSafetyCareProfileCatalogItem(id: 'motor-disability', label: 'Deficiência motora'),
      HealthSafetyCareProfileCatalogItem(id: 'reduced-mobility', label: 'Mobilidade reduzida'),
      HealthSafetyCareProfileCatalogItem(
        id: 'motor-delay',
        label: 'Atraso no desenvolvimento motor',
      ),
      HealthSafetyCareProfileCatalogItem(id: 'cerebral-palsy', label: 'Paralisia cerebral'),
      HealthSafetyCareProfileCatalogItem(
        id: 'mobility-resource',
        label: 'Uso de cadeira de rodas, órtese, prótese ou recurso de mobilidade',
      ),
    ],
  ),
  HealthSafetyCareProfileCatalogGroup(
    id: 'vision',
    label: 'Visão',
    items: [
      HealthSafetyCareProfileCatalogItem(id: 'myopia', label: 'Miopia'),
      HealthSafetyCareProfileCatalogItem(id: 'hyperopia', label: 'Hipermetropia'),
      HealthSafetyCareProfileCatalogItem(id: 'astigmatism', label: 'Astigmatismo'),
      HealthSafetyCareProfileCatalogItem(id: 'strabismus', label: 'Estrabismo'),
      HealthSafetyCareProfileCatalogItem(id: 'low-vision', label: 'Baixa visão'),
      HealthSafetyCareProfileCatalogItem(id: 'blindness', label: 'Cegueira'),
    ],
  ),
  HealthSafetyCareProfileCatalogGroup(
    id: 'hearing-communication',
    label: 'Audição e comunicação',
    items: [
      HealthSafetyCareProfileCatalogItem(id: 'hearing-disability', label: 'Deficiência auditiva'),
      HealthSafetyCareProfileCatalogItem(id: 'deafness', label: 'Surdez'),
      HealthSafetyCareProfileCatalogItem(
        id: 'speech-support',
        label: 'Apoio na fala ou comunicação',
      ),
      HealthSafetyCareProfileCatalogItem(
        id: 'alternative-communication',
        label: 'Uso de Libras ou comunicação alternativa',
      ),
    ],
  ),
  HealthSafetyCareProfileCatalogGroup(
    id: 'genetic-conditions',
    label: 'Condições genéticas',
    items: [HealthSafetyCareProfileCatalogItem(id: 'down-syndrome', label: 'Síndrome de Down')],
  ),
  HealthSafetyCareProfileCatalogGroup(
    id: 'health-conditions',
    label: 'Condições de saúde',
    items: [
      HealthSafetyCareProfileCatalogItem(id: 'diabetes', label: 'Diabetes'),
      HealthSafetyCareProfileCatalogItem(
        id: 'epilepsy',
        label: 'Epilepsia ou histórico de convulsões',
      ),
      HealthSafetyCareProfileCatalogItem(id: 'asthma', label: 'Asma'),
    ],
  ),
  HealthSafetyCareProfileCatalogGroup(
    id: 'other',
    label: 'Outro',
    items: [HealthSafetyCareProfileCatalogItem(id: 'other', label: 'Outro')],
  ),
];

final class HealthSafetyCareProfileItem {
  HealthSafetyCareProfileItem({required this.catalogItemId, this.otherText}) {
    final known = healthSafetyCareProfileCatalog
        .expand((group) => group.items)
        .any((item) => item.id == catalogItemId);
    if (!known) throw ArgumentError.value(catalogItemId, 'catalogItemId');
    if (catalogItemId == 'other' && (otherText == null || otherText!.trim().isEmpty)) {
      throw ArgumentError('Other care profile items require free text.');
    }
  }
  final String catalogItemId;
  final String? otherText;
}

final class HealthSafetyAcknowledgement {
  const HealthSafetyAcknowledgement({
    required this.id,
    required this.childId,
    required this.subject,
    required this.createdAt,
    this.receivedAt,
  });
  final String id;
  final String childId;
  final HealthSafetyAcknowledgementSubject subject;
  final DateTime createdAt;
  final DateTime? receivedAt;
  HealthSafetyAcknowledgement acknowledge(DateTime when) => HealthSafetyAcknowledgement(
    id: id,
    childId: childId,
    subject: subject,
    createdAt: createdAt,
    receivedAt: when,
  );
}

final class HealthSafetyNotification {
  const HealthSafetyNotification({
    required this.id,
    required this.childId,
    required this.subject,
    required this.itemId,
    required this.recipientId,
    required this.receiptId,
    required this.createdAt,
    this.acknowledgedAt,
  });
  final String id;
  final String childId;
  final HealthSafetyAcknowledgementSubject subject;
  final String itemId;
  final String recipientId;
  final String receiptId;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  HealthSafetyNotification acknowledge(DateTime when) => HealthSafetyNotification(
    id: id,
    childId: childId,
    subject: subject,
    itemId: itemId,
    recipientId: recipientId,
    receiptId: receiptId,
    createdAt: createdAt,
    acknowledgedAt: when,
  );
}

final class HealthSafetyAuditEvent {
  HealthSafetyAuditEvent({
    required this.id,
    required this.actorId,
    required this.justification,
    required Map<String, Object?> before,
    required Map<String, Object?> after,
    required this.createdAt,
  }) : before = Map.unmodifiable(before),
       after = Map.unmodifiable(after);
  final String id;
  final String actorId;
  final String justification;
  final Map<String, Object?> before;
  final Map<String, Object?> after;
  final DateTime createdAt;
}
