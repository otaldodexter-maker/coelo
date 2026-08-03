enum PlanStatus { active, archived }

enum PlanFeature { communication, agenda, invitations, chat, notices, routine, flow, now, moments }

final class PlanCatalog {
  const PlanCatalog({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.status,
    required this.features,
    required this.unitLimit,
    required this.userLimit,
    required this.guardiansPerChild,
    required this.storageGb,
    required this.mediaGb,
    required this.manualOperation,
    required this.internalNotes,
    this.usedByInstitutionCount = 0,
  });

  final String id, name, code, description, internalNotes;
  final PlanStatus status;
  final Set<PlanFeature> features;
  final int unitLimit, userLimit, guardiansPerChild, storageGb, mediaGb, usedByInstitutionCount;
  final bool manualOperation;

  PlanCatalog copyWith({PlanStatus? status, int? usedByInstitutionCount}) => PlanCatalog(
    id: id,
    name: name,
    code: code,
    description: description,
    status: status ?? this.status,
    features: features,
    unitLimit: unitLimit,
    userLimit: userLimit,
    guardiansPerChild: guardiansPerChild,
    storageGb: storageGb,
    mediaGb: mediaGb,
    manualOperation: manualOperation,
    internalNotes: internalNotes,
    usedByInstitutionCount: usedByInstitutionCount ?? this.usedByInstitutionCount,
  );
}

final class PlanDraft {
  const PlanDraft({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.status,
    required this.features,
    required this.unitLimit,
    required this.userLimit,
    required this.guardiansPerChild,
    required this.storageGb,
    required this.mediaGb,
    required this.manualOperation,
    required this.internalNotes,
  });
  final String id, name, code, description, internalNotes;
  final PlanStatus status;
  final Set<PlanFeature> features;
  final int unitLimit, userLimit, guardiansPerChild, storageGb, mediaGb;
  final bool manualOperation;
  PlanCatalog toPlan({int usedByInstitutionCount = 0}) => PlanCatalog(
    id: id,
    name: name,
    code: code,
    description: description,
    status: status,
    features: features,
    unitLimit: unitLimit,
    userLimit: userLimit,
    guardiansPerChild: guardiansPerChild,
    storageGb: storageGb,
    mediaGb: mediaGb,
    manualOperation: manualOperation,
    internalNotes: internalNotes,
    usedByInstitutionCount: usedByInstitutionCount,
  );
}
