import '../../features/people/domain/person_identity.dart';
import 'development_access_health_fixture_catalog.dart';

final class DevelopmentPersonIdentityRepository implements PersonIdentityRepository {
  const DevelopmentPersonIdentityRepository({this.catalog});

  final DevelopmentAccessHealthFixtureCatalog? catalog;

  DevelopmentAccessHealthFixtureCatalog get _catalog =>
      catalog ?? DevelopmentAccessHealthFixtureCatalog.standard();

  @override
  Future<List<PersonIdentityCandidate>> resolve({
    required PersonIdentityLookupKind kind,
    required String query,
    String? institutionId,
    String? unitId,
    String? childContextId,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty || kind == PersonIdentityLookupKind.cpf) return const [];
    final data = _catalog;
    final childrenByGuardian = <String, List<DevelopmentChildFixture>>{};
    for (final child in data.children) {
      for (final guardianId in child.guardianIds) {
        childrenByGuardian.putIfAbsent(guardianId, () => []).add(child);
      }
    }

    bool childScope(DevelopmentChildFixture child) =>
        (institutionId == null || child.institutionId == institutionId) &&
        (unitId == null || child.unitId == unitId) &&
        (childContextId == null || child.id == childContextId);

    bool adultScope(DevelopmentAdultFixture adult) {
      final children = childrenByGuardian[adult.id] ?? const <DevelopmentChildFixture>[];
      final contextualInstitutionIds = {
        ...adult.institutionIds,
        ...children.map((child) => child.institutionId),
      };
      if (institutionId != null && !contextualInstitutionIds.contains(institutionId)) return false;
      if (unitId != null && !children.any((child) => child.unitId == unitId)) return false;
      if (childContextId != null && !children.any((child) => child.id == childContextId)) {
        return false;
      }
      return true;
    }

    bool matchesAdult(DevelopmentAdultFixture adult) => switch (kind) {
      PersonIdentityLookupKind.name => adult.name.toLowerCase().contains(normalized),
      PersonIdentityLookupKind.email => adult.email.toLowerCase() == normalized,
      PersonIdentityLookupKind.phone => _digits(adult.mobilePhone) == _digits(normalized),
      PersonIdentityLookupKind.handle =>
        adult.email
            .substring(0, adult.email.indexOf('@'))
            .toLowerCase()
            .contains(normalized.replaceFirst('@', '')),
      PersonIdentityLookupKind.cpf => false,
    };

    bool matchesChild(DevelopmentChildFixture child) => switch (kind) {
      PersonIdentityLookupKind.name => child.name.toLowerCase().contains(normalized),
      PersonIdentityLookupKind.handle ||
      PersonIdentityLookupKind.email ||
      PersonIdentityLookupKind.phone ||
      PersonIdentityLookupKind.cpf => false,
    };

    final adultsById = <String, DevelopmentAdultFixture>{
      for (final adult in data.guardians) adult.id: adult,
      for (final adult in data.teamMembers) adult.id: adult,
    };
    return [
      for (final adult in adultsById.values)
        if (adultScope(adult) && matchesAdult(adult))
          PersonIdentityCandidate(
            personId: adult.id,
            displayName: adult.name,
            personType: 'adult',
            matchedBy: kind,
            maskedMatch: switch (kind) {
              PersonIdentityLookupKind.email => _maskedEmail(adult.email),
              PersonIdentityLookupKind.phone => _maskedPhone(adult.mobilePhone),
              PersonIdentityLookupKind.handle => '@${adult.email[0]}***',
              PersonIdentityLookupKind.name => adult.name,
              PersonIdentityLookupKind.cpf => '***',
            },
            access: PersonIdentityResolutionAccess.linkOnly,
          ),
      for (final child in data.children)
        if (childScope(child) && matchesChild(child))
          PersonIdentityCandidate(
            personId: child.id,
            displayName: child.name,
            personType: 'child',
            matchedBy: kind,
            maskedMatch: child.name,
            access: PersonIdentityResolutionAccess.linkOnly,
          ),
    ];
  }

  @override
  Future<PersonHandleCheck> checkHandle({required String handle, String? personId}) async =>
      PersonHandleCheck(handle: handle, availability: PersonHandleAvailability.available);
}

String _digits(String value) => value.replaceAll(RegExp(r'\D'), '');

String _maskedEmail(String value) {
  final at = value.indexOf('@');
  if (at <= 0) return '***';
  return '${value[0]}***${value.substring(at)}';
}

String _maskedPhone(String value) {
  final digits = _digits(value);
  if (digits.length < 4) return '***';
  return '(**) *****-${digits.substring(digits.length - 4)}';
}
