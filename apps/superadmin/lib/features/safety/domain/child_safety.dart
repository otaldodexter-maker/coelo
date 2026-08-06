import 'package:flutter/foundation.dart';

enum PickupAuthorizationStatus {
  pending('Pendente'),
  approved('Aprovado'),
  rejected('Rejeitado');

  const PickupAuthorizationStatus(this.label);
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
    this.identifier,
    this.startsAt,
    this.endsAt,
    this.lifetime = false,
    this.hasAppAccount = false,
  });

  final String id;
  final String name;
  final String relationship;
  final String institutionName;
  final String unitName;
  final PickupAuthorizationStatus status;
  final PickupAuthorizationOrigin origin;
  final String? identifier;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool lifetime;
  final bool hasAppAccount;

  PickupAuthorization withStatus(PickupAuthorizationStatus value) => PickupAuthorization(
    id: id,
    name: name,
    relationship: relationship,
    institutionName: institutionName,
    unitName: unitName,
    status: value,
    origin: origin,
    identifier: identifier,
    startsAt: startsAt,
    endsAt: endsAt,
    lifetime: lifetime,
    hasAppAccount: hasAppAccount,
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
  });

  final String childId;
  final String childName;
  final String internalId;
  final String institutionName;
  final String unitName;
  final List<PickupAuthorization> authorizations;

  int get pendingCount =>
      authorizations.where((item) => item.status == PickupAuthorizationStatus.pending).length;

  ChildSafetyRecord withAuthorizations(List<PickupAuthorization> value) => ChildSafetyRecord(
    childId: childId,
    childName: childName,
    internalId: internalId,
    institutionName: institutionName,
    unitName: unitName,
    authorizations: value,
  );
}

enum ChildSafetyLoadState { loading, ready, error, unauthorized }

final class ChildSafetyStore extends ChangeNotifier {
  ChildSafetyStore._(this._records, {this.state = ChildSafetyLoadState.ready});

  factory ChildSafetyStore.demo() => ChildSafetyStore._([..._demoRecords]);

  factory ChildSafetyStore.seeded(List<ChildSafetyRecord> records) =>
      ChildSafetyStore._([...records]);

  factory ChildSafetyStore.loading() =>
      ChildSafetyStore._(const [], state: ChildSafetyLoadState.loading);

  factory ChildSafetyStore.failure() =>
      ChildSafetyStore._(const [], state: ChildSafetyLoadState.error);

  factory ChildSafetyStore.unauthorized() =>
      ChildSafetyStore._(const [], state: ChildSafetyLoadState.unauthorized);

  final ChildSafetyLoadState state;
  final List<ChildSafetyRecord> _records;
  List<ChildSafetyRecord> get records => List.unmodifiable(_records);

  ChildSafetyRecord? findChild(String childId) {
    for (final record in _records) {
      if (record.childId == childId) return record;
    }
    return null;
  }

  void save(String childId, PickupAuthorization authorization) {
    final childIndex = _records.indexWhere((item) => item.childId == childId);
    if (childIndex < 0) return;
    final values = [..._records[childIndex].authorizations];
    final index = values.indexWhere((item) => item.id == authorization.id);
    if (index < 0) {
      values.add(authorization);
    } else {
      values[index] = authorization;
    }
    _records[childIndex] = _records[childIndex].withAuthorizations(values);
    notifyListeners();
  }

  void setStatus(String childId, String authorizationId, PickupAuthorizationStatus status) {
    final child = findChild(childId);
    final index = child?.authorizations.indexWhere((item) => item.id == authorizationId) ?? -1;
    if (child == null || index < 0) return;
    save(childId, child.authorizations[index].withStatus(status));
  }

  void remove(String childId, String authorizationId) {
    final index = _records.indexWhere((item) => item.childId == childId);
    if (index < 0) return;
    _records[index] = _records[index].withAuthorizations(
      _records[index].authorizations.where((item) => item.id != authorizationId).toList(),
    );
    notifyListeners();
  }
}

final _demoRecords = <ChildSafetyRecord>[
  ChildSafetyRecord(
    childId: 'person-1',
    childName: 'Criança Coelo 2',
    internalId: 'RA 2026-014',
    institutionName: 'Instituição 2',
    unitName: 'Unidade 2',
    authorizations: [
      PickupAuthorization(
        id: 'authorization-1',
        name: 'Marina Coelo',
        relationship: 'Mãe',
        institutionName: 'Instituição 2',
        unitName: 'Unidade 2',
        status: PickupAuthorizationStatus.approved,
        origin: PickupAuthorizationOrigin.institution,
        identifier: '@marinacoelo',
        startsAt: DateTime(2026, 1, 20),
        lifetime: true,
        hasAppAccount: true,
      ),
      PickupAuthorization(
        id: 'authorization-2',
        name: 'Carlos Lima',
        relationship: 'Avô',
        institutionName: 'Instituição 2',
        unitName: 'Unidade 2',
        status: PickupAuthorizationStatus.pending,
        origin: PickupAuthorizationOrigin.guardian,
        identifier: '(11) 9****-4821',
        startsAt: DateTime(2026, 8, 1),
        endsAt: DateTime(2026, 12, 20),
      ),
    ],
  ),
  ChildSafetyRecord(
    childId: 'person-4',
    childName: 'Criança Coelo 5',
    internalId: 'RA 2026-027',
    institutionName: 'Instituição 1',
    unitName: 'Unidade 2',
    authorizations: [
      PickupAuthorization(
        id: 'authorization-3',
        name: 'Rafael Souza',
        relationship: 'Pai',
        institutionName: 'Instituição 1',
        unitName: 'Unidade 2',
        status: PickupAuthorizationStatus.approved,
        origin: PickupAuthorizationOrigin.institution,
        identifier: 'r***@exemplo.test',
        startsAt: DateTime(2026, 2, 1),
        lifetime: true,
        hasAppAccount: true,
      ),
    ],
  ),
  const ChildSafetyRecord(
    childId: 'person-7',
    childName: 'Criança Coelo 8',
    internalId: 'RA 2026-031',
    institutionName: 'Instituição 2',
    unitName: 'Unidade 2',
    authorizations: [],
  ),
];
