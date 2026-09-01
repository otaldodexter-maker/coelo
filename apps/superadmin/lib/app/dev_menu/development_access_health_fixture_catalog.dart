import '../../features/institutions/data/fake_institution_directory_repository.dart';

enum DevelopmentSafetyStatus { authorized, awaitingApproval, attention, noAuthorization }

final class DevelopmentChildFixture {
  const DevelopmentChildFixture({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.privateIdentifier,
    required this.institutionId,
    required this.institutionName,
    required this.unitId,
    required this.unitName,
    required this.groupId,
    required this.groupName,
    required this.guardianIds,
  });

  final String id;
  final String name;
  final DateTime birthDate;
  final String privateIdentifier;
  final String institutionId;
  final String institutionName;
  final String unitId;
  final String unitName;
  final String groupId;
  final String groupName;
  final List<String> guardianIds;
}

final class DevelopmentAdultFixture {
  const DevelopmentAdultFixture({
    required this.id,
    required this.name,
    required this.email,
    required this.mobilePhone,
    required this.profileCodes,
    required this.institutionIds,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String email;
  final String mobilePhone;
  final List<String> profileCodes;
  final List<String> institutionIds;
  final double latitude;
  final double longitude;
}

final class DevelopmentSafetyFixture {
  const DevelopmentSafetyFixture({
    required this.id,
    required this.childId,
    required this.status,
    required this.authorizedPeopleCount,
    required this.pendingRequestsCount,
  });

  final String id;
  final String childId;
  final DevelopmentSafetyStatus status;
  final int authorizedPeopleCount;
  final int pendingRequestsCount;
}

final class DevelopmentCareProfileFixture {
  const DevelopmentCareProfileFixture({
    required this.id,
    required this.childId,
    required this.hasAllergies,
    required this.hasRestrictions,
  });

  final String id;
  final String childId;
  final bool hasAllergies;
  final bool hasRestrictions;
}

final class DevelopmentMedicationPlanFixture {
  const DevelopmentMedicationPlanFixture({
    required this.id,
    required this.childId,
    required this.medicationName,
    required this.status,
  });

  final String id;
  final String childId;
  final String medicationName;
  final String status;
}

final class DevelopmentAccessHealthFixtureCatalog {
  const DevelopmentAccessHealthFixtureCatalog({
    required this.institutionIds,
    required this.children,
    required this.guardians,
    required this.teamMembers,
    required this.safetyRecords,
    required this.careProfiles,
    required this.medicationPlans,
  });

  factory DevelopmentAccessHealthFixtureCatalog.standard() {
    final institutions = demoInstitutionRecords;
    final institutionIds = institutions.map((item) => item.id).toSet();
    final guardians = List<DevelopmentAdultFixture>.generate(270, (index) {
      final institution = institutions[index % institutions.length];
      final secondInstitution = institutions[(index + 5) % institutions.length];
      return DevelopmentAdultFixture(
        id: _id('guardian', index),
        name: _adultName(index),
        email: '${_emailName(index)}@familias.coelo.dev',
        mobilePhone:
            '+55 ${11 + index % 79} 9${(81000000 + index * 173).toString().padLeft(8, '0').substring(0, 8)}',
        profileCodes: index < 54
            ? const ['guardian', 'institution_collaborator']
            : const ['guardian'],
        institutionIds: index < 54 ? [institution.id, secondInstitution.id] : [institution.id],
        latitude: _coordinates[institution.state]?.$1 ?? -23.5505,
        longitude: _coordinates[institution.state]?.$2 ?? -46.6333,
      );
    });

    final teamMembers = List<DevelopmentAdultFixture>.generate(42, (index) {
      final institution = institutions[index % institutions.length];
      final guardian = index < 30 ? guardians[index] : null;
      return DevelopmentAdultFixture(
        id: guardian?.id ?? _id('team', index),
        name: guardian?.name ?? _adultName(index + 270),
        email: guardian?.email ?? '${_emailName(index + 270)}@equipe.coelo.dev',
        mobilePhone:
            guardian?.mobilePhone ??
            '+55 11 98${(100000 + index * 311).toString().padLeft(6, '0')}',
        profileCodes: guardian?.profileCodes ?? const ['institution_collaborator'],
        institutionIds: [institution.id],
        latitude: _coordinates[institution.state]?.$1 ?? -23.5505,
        longitude: _coordinates[institution.state]?.$2 ?? -46.6333,
      );
    });

    var guardianCursor = 0;
    final children = List<DevelopmentChildFixture>.generate(180, (index) {
      final institution = institutions[index % institutions.length];
      final unit = institution.units[(index ~/ institutions.length) % institution.units.length];
      final group = unit.groups[(index * 3) % unit.groups.length];
      final guardianCount = index < 72
          ? 1
          : index < 171
          ? 2
          : index < 178
          ? 3
          : 4;
      final guardianIds = List<String>.generate(
        guardianCount,
        (_) => guardians[guardianCursor++ % guardians.length].id,
      );
      return DevelopmentChildFixture(
        id: _id('child', index),
        name: _childName(index),
        birthDate: DateTime(2017 + index % 7, 1 + index % 12, 1 + index % 27),
        privateIdentifier: 'RA-${(41037 + index * 19).toString()}',
        institutionId: institution.id,
        institutionName: institution.publicName,
        unitId: unit.id,
        unitName: unit.name,
        groupId: group.id,
        groupName: group.name,
        guardianIds: List.unmodifiable(guardianIds),
      );
    });

    final safetyRecords = List<DevelopmentSafetyFixture>.generate(164, (index) {
      final status = index < 126
          ? DevelopmentSafetyStatus.authorized
          : index < 144
          ? DevelopmentSafetyStatus.awaitingApproval
          : index < 155
          ? DevelopmentSafetyStatus.attention
          : DevelopmentSafetyStatus.noAuthorization;
      return DevelopmentSafetyFixture(
        id: _id('safety', index),
        childId: children[index].id,
        status: status,
        authorizedPeopleCount: status == DevelopmentSafetyStatus.noAuthorization
            ? 0
            : 1 + index % 3,
        pendingRequestsCount: status == DevelopmentSafetyStatus.awaitingApproval
            ? 1 + index % 2
            : 0,
      );
    });

    final careProfiles = List<DevelopmentCareProfileFixture>.generate(
      147,
      (index) => DevelopmentCareProfileFixture(
        id: _id('care', index),
        childId: children[index].id,
        hasAllergies: index % 7 == 0,
        hasRestrictions: index % 5 == 0,
      ),
    );
    const medications = ['Budesonida', 'Loratadina', 'Insulina', 'Levetiracetam', 'Salbutamol'];
    final medicationPlans = List<DevelopmentMedicationPlanFixture>.generate(
      32,
      (index) => DevelopmentMedicationPlanFixture(
        id: _id('medication', index),
        childId: children[(index * 5) % children.length].id,
        medicationName: medications[index % medications.length],
        status: index % 8 == 0
            ? 'awaiting_approval'
            : index % 11 == 0
            ? 'suspended'
            : 'active',
      ),
    );

    return DevelopmentAccessHealthFixtureCatalog(
      institutionIds: Set.unmodifiable(institutionIds),
      children: List.unmodifiable(children),
      guardians: List.unmodifiable(guardians),
      teamMembers: List.unmodifiable(teamMembers),
      safetyRecords: List.unmodifiable(safetyRecords),
      careProfiles: List.unmodifiable(careProfiles),
      medicationPlans: List.unmodifiable(medicationPlans),
    );
  }

  final Set<String> institutionIds;
  final List<DevelopmentChildFixture> children;
  final List<DevelopmentAdultFixture> guardians;
  final List<DevelopmentAdultFixture> teamMembers;
  final List<DevelopmentSafetyFixture> safetyRecords;
  final List<DevelopmentCareProfileFixture> careProfiles;
  final List<DevelopmentMedicationPlanFixture> medicationPlans;
}

const _adultFirstNames = [
  'Ana',
  'Bruno',
  'Camila',
  'Daniel',
  'Elisa',
  'Felipe',
  'Gabriela',
  'Henrique',
  'Isabela',
  'João',
  'Karina',
  'Lucas',
  'Mariana',
  'Nicolas',
  'Olívia',
  'Paulo',
  'Renata',
  'Sérgio',
  'Talita',
  'Vinícius',
];
const _childFirstNames = [
  'Alice',
  'Arthur',
  'Beatriz',
  'Bento',
  'Cecília',
  'Davi',
  'Elena',
  'Enzo',
  'Helena',
  'Heitor',
  'Júlia',
  'Lorenzo',
  'Lívia',
  'Miguel',
  'Maitê',
  'Noah',
  'Sofia',
  'Theo',
  'Valentina',
  'Vicente',
];
const _surnames = [
  'Almeida',
  'Barbosa',
  'Cardoso',
  'Duarte',
  'Freitas',
  'Gomes',
  'Lima',
  'Martins',
  'Nascimento',
  'Oliveira',
  'Pereira',
  'Queiroz',
  'Ramos',
  'Silva',
  'Teixeira',
];
const _coordinates = <String, (double, double)>{
  'SP': (-23.5505, -46.6333),
  'PR': (-25.4284, -49.2733),
  'MG': (-19.9167, -43.9345),
  'PE': (-8.0476, -34.8770),
  'GO': (-16.6869, -49.2648),
  'SC': (-27.5949, -48.5482),
  'BA': (-12.9777, -38.5016),
  'RJ': (-22.9068, -43.1729),
  'RS': (-30.0346, -51.2177),
  'CE': (-3.7319, -38.5267),
  'DF': (-15.7939, -47.8828),
};

String _id(String kind, int index) => 'dev-$kind-${(index + 1).toString().padLeft(4, '0')}';
String _adultName(int index) =>
    '${_adultFirstNames[index % _adultFirstNames.length]} ${_surnames[(index * 7) % _surnames.length]}';
String _childName(int index) =>
    '${_childFirstNames[index % _childFirstNames.length]} ${_surnames[(index * 11 + 3) % _surnames.length]}';
String _emailName(int index) =>
    '${_adultFirstNames[index % _adultFirstNames.length].toLowerCase()}.${_surnames[(index * 7) % _surnames.length].toLowerCase()}${index + 1}';
