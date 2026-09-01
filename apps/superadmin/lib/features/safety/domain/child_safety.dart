enum ChildSafetyDirectorySegment {
  all('Todos', 'all'),
  awaitingApproval('Aguardando aprovação', 'awaiting_approval'),
  attention('Atenção', 'attention'),
  authorized('Autorizadas', 'authorized'),
  withoutAuthorization('Sem autorização', 'without_authorization');

  const ChildSafetyDirectorySegment(this.label, this.databaseValue);
  final String label;
  final String databaseValue;
}

enum PickupAuthorizationStatus {
  pending('Pendente'),
  approved('Aprovado'),
  rejected('Rejeitado');

  const PickupAuthorizationStatus(this.label);
  final String label;
}

enum PickupAuthorizationLifecycleStatus {
  active('Ativa'),
  suspended('Suspensa'),
  expired('Expirada'),
  revoked('Revogada');

  const PickupAuthorizationLifecycleStatus(this.label);
  final String label;
}

enum PickupAuthorizationOrigin {
  institution('Instituição / unidade'),
  guardian('Responsável');

  const PickupAuthorizationOrigin(this.label);
  final String label;
}

final class PickupAuthorization {
  const PickupAuthorization({
    required this.id,
    required this.name,
    required this.relationship,
    required this.institutionName,
    required this.unitName,
    required this.status,
    required this.origin,
    this.personId,
    this.childContextId,
    this.unitId,
    this.capabilityCodes = const {},
    this.requestReason,
    this.identifier,
    this.startsAt,
    this.endsAt,
    this.lifetime = false,
    this.hasAppAccount = false,
    this.lifecycleStatus = PickupAuthorizationLifecycleStatus.active,
    this.version = 1,
  });

  final String id;
  final String name;
  final String relationship;
  final String institutionName;
  final String unitName;
  final PickupAuthorizationStatus status;
  final PickupAuthorizationOrigin origin;
  final String? personId;
  final String? childContextId;
  final String? unitId;
  final Set<String> capabilityCodes;
  final String? requestReason;
  final String? identifier;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool lifetime;
  final bool hasAppAccount;
  final PickupAuthorizationLifecycleStatus lifecycleStatus;
  final int version;

  PickupAuthorization withStatus(PickupAuthorizationStatus value) => PickupAuthorization(
    id: id,
    name: name,
    relationship: relationship,
    institutionName: institutionName,
    unitName: unitName,
    status: value,
    origin: origin,
    personId: personId,
    childContextId: childContextId,
    unitId: unitId,
    capabilityCodes: capabilityCodes,
    requestReason: requestReason,
    identifier: identifier,
    startsAt: startsAt,
    endsAt: endsAt,
    lifetime: lifetime,
    hasAppAccount: hasAppAccount,
    lifecycleStatus: lifecycleStatus,
    version: version,
  );

  PickupAuthorization withLifecycleStatus(PickupAuthorizationLifecycleStatus value) =>
      PickupAuthorization(
        id: id,
        name: name,
        relationship: relationship,
        institutionName: institutionName,
        unitName: unitName,
        status: status,
        origin: origin,
        personId: personId,
        childContextId: childContextId,
        unitId: unitId,
        capabilityCodes: capabilityCodes,
        requestReason: requestReason,
        identifier: identifier,
        startsAt: startsAt,
        endsAt: endsAt,
        lifetime: lifetime,
        hasAppAccount: hasAppAccount,
        lifecycleStatus: value,
        version: version + 1,
      );
}

final class ChildSafetyRecord {
  const ChildSafetyRecord({
    required this.childId,
    required this.childName,
    required this.internalId,
    required this.institutionName,
    required this.unitName,
    required this.authorizations,
    this.childContextId,
    this.institutionId,
    this.unitId,
    this.directorySegment = ChildSafetyDirectorySegment.withoutAuthorization,
    this.authorizationCount = 0,
    this.directoryPendingCount = 0,
  });

  final String childId;
  final String childName;
  final String internalId;
  final String institutionName;
  final String unitName;
  final List<PickupAuthorization> authorizations;
  final String? childContextId;
  final String? institutionId;
  final String? unitId;
  final ChildSafetyDirectorySegment directorySegment;
  final int authorizationCount;
  final int directoryPendingCount;

  int get pendingCount => authorizations.isEmpty
      ? directoryPendingCount
      : authorizations.where((item) => item.status == PickupAuthorizationStatus.pending).length;

  ChildSafetyRecord withAuthorizations(List<PickupAuthorization> value) => ChildSafetyRecord(
    childId: childId,
    childName: childName,
    internalId: internalId,
    institutionName: institutionName,
    unitName: unitName,
    authorizations: value,
    childContextId: childContextId,
    institutionId: institutionId,
    unitId: unitId,
    directorySegment: value.any((item) => item.status == PickupAuthorizationStatus.pending)
        ? ChildSafetyDirectorySegment.awaitingApproval
        : value.any((item) => item.status == PickupAuthorizationStatus.rejected)
        ? ChildSafetyDirectorySegment.attention
        : value.any((item) => item.status == PickupAuthorizationStatus.approved)
        ? ChildSafetyDirectorySegment.authorized
        : ChildSafetyDirectorySegment.withoutAuthorization,
    authorizationCount: value
        .where((item) => item.status == PickupAuthorizationStatus.approved)
        .length,
    directoryPendingCount: value
        .where((item) => item.status == PickupAuthorizationStatus.pending)
        .length,
  );
}

enum ChildSafetyLoadState { loading, ready, error, unauthorized }
