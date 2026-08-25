enum HealthCareCapability {
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

enum HealthCareAccessProfile { owner, sensitiveReader, minimized }

extension HealthCareAccessProfileCapabilities on HealthCareAccessProfile {
  Set<HealthCareCapability> get capabilities => switch (this) {
    HealthCareAccessProfile.owner => const {
      HealthCareCapability.sensitiveRead,
      HealthCareCapability.auditRead,
      HealthCareCapability.exceptionalCorrection,
      HealthCareCapability.recordCreateEdit,
      HealthCareCapability.recordInactivate,
    },
    HealthCareAccessProfile.sensitiveReader => const {HealthCareCapability.sensitiveRead},
    HealthCareAccessProfile.minimized => const {},
  };

  bool can(HealthCareCapability capability) => capabilities.contains(capability);
}

enum HealthCareOperationalStatus { active, implementation, inactive }

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

enum HealthCareAllergyType { medication, food, restriction, other }

enum HealthCareAllergyStatus { active, monitoring, history }

enum HealthCareEpisodeSeverity { mild, moderate, severe }

enum HealthCareAcknowledgementSubject { medication, allergyOrRestriction, careProfile }

enum HealthMedicationPolicyPhase {
  scheduled,
  earlyReminder,
  dueNotification,
  tolerance,
  late,
  escalated,
}

final class HealthCareTimeOfDay {
  HealthCareTimeOfDay(this.hour, this.minute) {
    if (hour < 0 || hour > 23) throw ArgumentError.value(hour, 'hour');
    if (minute < 0 || minute > 59) throw ArgumentError.value(minute, 'minute');
  }
  final int hour;
  final int minute;
}

final class HealthCareContextLink {
  const HealthCareContextLink({
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

final class HealthCareActor {
  HealthCareActor({
    required this.id,
    required this.profile,
    this.institutionId,
    Set<String> authorizedChildIds = const {},
    Set<String> responsibleInstitutionIds = const {},
    Set<HealthCareCapability> contextualCapabilities = const {},
  }) : authorizedChildIds = Set.unmodifiable(authorizedChildIds),
       responsibleInstitutionIds = Set.unmodifiable(responsibleInstitutionIds),
       contextualCapabilities = Set.unmodifiable(contextualCapabilities);

  final String id;
  final HealthCareAccessProfile profile;
  final String? institutionId;
  final Set<String> authorizedChildIds;
  final Set<String> responsibleInstitutionIds;
  final Set<HealthCareCapability> contextualCapabilities;

  bool can(HealthCareCapability capability) {
    const ownerOnly = {
      HealthCareCapability.exceptionalCorrection,
      HealthCareCapability.recordCreateEdit,
      HealthCareCapability.recordInactivate,
    };
    if (ownerOnly.contains(capability)) return profile == HealthCareAccessProfile.owner;
    return profile.can(capability) || contextualCapabilities.contains(capability);
  }

  bool canReadDetail(HealthCareChild child) {
    if (!can(HealthCareCapability.sensitiveRead) || !authorizedChildIds.contains(child.id)) {
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

final class HealthCareChild {
  HealthCareChild({
    required this.id,
    required this.personId,
    required this.displayName,
    required this.operationalStatus,
    List<HealthCareContextLink> links = const [],
    List<HealthMedication> medications = const [],
    List<HealthMedicationDose> doses = const [],
    List<HealthCareAllergy> allergies = const [],
    List<HealthCareProfileItem> careProfile = const [],
    List<HealthCareAcknowledgement> acknowledgements = const [],
    List<HealthCareNotification> notifications = const [],
    List<HealthCareAuditEvent> auditEvents = const [],
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
  final HealthCareOperationalStatus operationalStatus;
  final List<HealthCareContextLink> links;
  final List<HealthMedication> medications;
  final List<HealthMedicationDose> doses;
  final List<HealthCareAllergy> allergies;
  final List<HealthCareProfileItem> careProfile;
  final List<HealthCareAcknowledgement> acknowledgements;
  final List<HealthCareNotification> notifications;
  final List<HealthCareAuditEvent> auditEvents;

  HealthCareChild copyWith({
    List<HealthMedication>? medications,
    List<HealthMedicationDose>? doses,
    List<HealthCareAllergy>? allergies,
    List<HealthCareProfileItem>? careProfile,
    List<HealthCareAcknowledgement>? acknowledgements,
    List<HealthCareNotification>? notifications,
    List<HealthCareAuditEvent>? auditEvents,
  }) => HealthCareChild(
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

final class HealthCareChildSummary {
  const HealthCareChildSummary({
    required this.id,
    required this.personId,
    required this.displayName,
    required this.operationalStatus,
    required this.medicationCount,
    required this.activeAllergyCount,
    required this.pendingAcknowledgementCount,
  });

  factory HealthCareChildSummary.fromChild(
    HealthCareChild child, {
    required HealthCareAccessProfile profile,
  }) {
    final minimized = profile == HealthCareAccessProfile.minimized;
    return HealthCareChildSummary(
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
  final HealthCareOperationalStatus operationalStatus;
  final int medicationCount;
  final int activeAllergyCount;
  final int pendingAcknowledgementCount;
}

final class HealthCareDirectoryQuery {
  const HealthCareDirectoryQuery({
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
  final Set<HealthCareOperationalStatus> operationalStatuses;
  final Set<HealthMedicationDoseSituation> doseSituations;
  final int page;
  final int pageSize;
  int get offset => page * pageSize;

  bool matches(HealthCareChild child) {
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

final class HealthCareDirectoryPage {
  HealthCareDirectoryPage({
    required List<HealthCareChildSummary> items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  }) : items = List.unmodifiable(items);
  final List<HealthCareChildSummary> items;
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
  final HealthCareTimeOfDay time;
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

final class HealthCareAllergy {
  HealthCareAllergy({
    required this.id,
    required this.childId,
    required this.label,
    required this.type,
    required this.active,
    this.status = HealthCareAllergyStatus.active,
    this.lastEpisodeAt,
    this.episodeSeverity,
    this.observedReaction = '',
    this.guidance = '',
    this.notes = '',
    this.inactivatedAt,
  }) {
    if (label.trim().isEmpty) throw ArgumentError('Allergy label is required.');
  }

  final String id;
  final String childId;
  final String label;
  final HealthCareAllergyType type;
  final bool active;
  final HealthCareAllergyStatus status;
  final DateTime? lastEpisodeAt;
  final HealthCareEpisodeSeverity? episodeSeverity;
  final String observedReaction;
  final String guidance;
  final String notes;
  final DateTime? inactivatedAt;

  HealthCareAllergy deactivate(DateTime when) => !active
      ? this
      : HealthCareAllergy(
          id: id,
          childId: childId,
          label: label,
          type: type,
          active: false,
          status: HealthCareAllergyStatus.history,
          lastEpisodeAt: lastEpisodeAt,
          episodeSeverity: episodeSeverity,
          observedReaction: observedReaction,
          guidance: guidance,
          notes: notes,
          inactivatedAt: when,
        );
}

final class HealthCareProfileCatalogGroup {
  const HealthCareProfileCatalogGroup({required this.id, required this.label, required this.items});
  final String id;
  final String label;
  final List<HealthCareProfileCatalogItem> items;
}

final class HealthCareProfileCatalogItem {
  const HealthCareProfileCatalogItem({required this.id, required this.label});
  final String id;
  final String label;
  @override
  bool operator ==(Object other) =>
      other is HealthCareProfileCatalogItem && other.id == id && other.label == label;
  @override
  int get hashCode => Object.hash(id, label);
}

const healthCareProfileCatalog = <HealthCareProfileCatalogGroup>[
  HealthCareProfileCatalogGroup(
    id: 'neurodevelopment',
    label: 'Neurodesenvolvimento',
    items: [
      HealthCareProfileCatalogItem(id: 'autism', label: 'Autismo'),
      HealthCareProfileCatalogItem(id: 'adhd', label: 'TDAH'),
      HealthCareProfileCatalogItem(id: 'dyslexia', label: 'Dislexia'),
      HealthCareProfileCatalogItem(id: 'dyspraxia', label: 'Dispraxia'),
      HealthCareProfileCatalogItem(id: 'giftedness', label: 'Altas habilidades/superdotação'),
    ],
  ),
  HealthCareProfileCatalogGroup(
    id: 'motor-mobility',
    label: 'Desenvolvimento motor e mobilidade',
    items: [
      HealthCareProfileCatalogItem(id: 'motor-disability', label: 'Deficiência motora'),
      HealthCareProfileCatalogItem(id: 'reduced-mobility', label: 'Mobilidade reduzida'),
      HealthCareProfileCatalogItem(id: 'motor-delay', label: 'Atraso no desenvolvimento motor'),
      HealthCareProfileCatalogItem(id: 'cerebral-palsy', label: 'Paralisia cerebral'),
      HealthCareProfileCatalogItem(
        id: 'mobility-resource',
        label: 'Uso de cadeira de rodas, órtese, prótese ou recurso de mobilidade',
      ),
    ],
  ),
  HealthCareProfileCatalogGroup(
    id: 'vision',
    label: 'Visão',
    items: [
      HealthCareProfileCatalogItem(id: 'myopia', label: 'Miopia'),
      HealthCareProfileCatalogItem(id: 'hyperopia', label: 'Hipermetropia'),
      HealthCareProfileCatalogItem(id: 'astigmatism', label: 'Astigmatismo'),
      HealthCareProfileCatalogItem(id: 'strabismus', label: 'Estrabismo'),
      HealthCareProfileCatalogItem(id: 'low-vision', label: 'Baixa visão'),
      HealthCareProfileCatalogItem(id: 'blindness', label: 'Cegueira'),
    ],
  ),
  HealthCareProfileCatalogGroup(
    id: 'hearing-communication',
    label: 'Audição e comunicação',
    items: [
      HealthCareProfileCatalogItem(id: 'hearing-disability', label: 'Deficiência auditiva'),
      HealthCareProfileCatalogItem(id: 'deafness', label: 'Surdez'),
      HealthCareProfileCatalogItem(id: 'speech-support', label: 'Apoio na fala ou comunicação'),
      HealthCareProfileCatalogItem(
        id: 'alternative-communication',
        label: 'Uso de Libras ou comunicação alternativa',
      ),
    ],
  ),
  HealthCareProfileCatalogGroup(
    id: 'genetic-conditions',
    label: 'Condições genéticas',
    items: [HealthCareProfileCatalogItem(id: 'down-syndrome', label: 'Síndrome de Down')],
  ),
  HealthCareProfileCatalogGroup(
    id: 'health-conditions',
    label: 'Condições de saúde',
    items: [
      HealthCareProfileCatalogItem(id: 'diabetes', label: 'Diabetes'),
      HealthCareProfileCatalogItem(id: 'epilepsy', label: 'Epilepsia ou histórico de convulsões'),
      HealthCareProfileCatalogItem(id: 'asthma', label: 'Asma'),
    ],
  ),
  HealthCareProfileCatalogGroup(
    id: 'other',
    label: 'Outro',
    items: [HealthCareProfileCatalogItem(id: 'other', label: 'Outro')],
  ),
];

final class HealthCareProfileItem {
  HealthCareProfileItem({required this.catalogItemId, this.otherText}) {
    final known = healthCareProfileCatalog
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

final class HealthCareAcknowledgement {
  const HealthCareAcknowledgement({
    required this.id,
    required this.childId,
    required this.subject,
    required this.createdAt,
    this.receivedAt,
  });
  final String id;
  final String childId;
  final HealthCareAcknowledgementSubject subject;
  final DateTime createdAt;
  final DateTime? receivedAt;
  HealthCareAcknowledgement acknowledge(DateTime when) => HealthCareAcknowledgement(
    id: id,
    childId: childId,
    subject: subject,
    createdAt: createdAt,
    receivedAt: when,
  );
}

final class HealthCareNotification {
  const HealthCareNotification({
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
  final HealthCareAcknowledgementSubject subject;
  final String itemId;
  final String recipientId;
  final String receiptId;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  HealthCareNotification acknowledge(DateTime when) => HealthCareNotification(
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

final class HealthCareAuditEvent {
  HealthCareAuditEvent({
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
