/// Value intentionally kept masked in UI responses.  The raw identifying
/// value remains server-side and is never reconstructed by Flutter.
enum PersonIdentityLookupKind {
  handle('handle'),
  email('email'),
  phone('phone'),
  cpf('cpf'),
  name('name');

  const PersonIdentityLookupKind(this.databaseValue);
  final String databaseValue;
}

enum PersonIdentityResolutionAccess {
  editGlobal('edit_global'),
  linkOnly('link_only'),
  recovery('recovery'),
  noAccess('no_access');

  const PersonIdentityResolutionAccess(this.databaseValue);
  final String databaseValue;
}

/// A minimally disclosed candidate returned from an authorized resolver.
///
/// A name lookup is contextual; exact identifiers are still returned masked
/// and never indicate whether an authentication account exists to an actor
/// without the matching capability.
final class PersonIdentityCandidate {
  const PersonIdentityCandidate({
    required this.personId,
    required this.displayName,
    required this.personType,
    required this.matchedBy,
    required this.maskedMatch,
    required this.access,
  });

  final String personId;
  final String displayName;
  final String personType;
  final PersonIdentityLookupKind matchedBy;
  final String maskedMatch;
  final PersonIdentityResolutionAccess access;

  factory PersonIdentityCandidate.fromJson(Map<String, dynamic> json) => PersonIdentityCandidate(
    personId: json['person_id'] as String,
    displayName: json['display_name'] as String,
    personType: json['person_type'] as String,
    matchedBy: PersonIdentityLookupKind.values.firstWhere(
      (value) => value.databaseValue == json['matched_by'],
    ),
    maskedMatch: json['masked_match'] as String,
    access: PersonIdentityResolutionAccess.values.firstWhere(
      (value) => value.databaseValue == json['access'],
    ),
  );
}

enum PersonHandleAvailability { available, unavailable, cooldown, forbidden }

final class PersonHandleCheck {
  const PersonHandleCheck({required this.handle, required this.availability, this.nextChangeAt});

  final String handle;
  final PersonHandleAvailability availability;
  final DateTime? nextChangeAt;

  factory PersonHandleCheck.fromJson(Map<String, dynamic> json) => PersonHandleCheck(
    handle: json['handle'] as String,
    availability: PersonHandleAvailability.values.firstWhere(
      (value) => value.name == json['availability'],
    ),
    nextChangeAt: json['next_change_at'] == null
        ? null
        : DateTime.parse(json['next_change_at'] as String).toUtc(),
  );
}

/// Commands stay outside [PersonDirectoryRepository] so a directory query
/// implementation cannot accidentally gain authority to mutate identities.
abstract interface class PersonIdentityRepository {
  Future<List<PersonIdentityCandidate>> resolve({
    required PersonIdentityLookupKind kind,
    required String query,
    String? institutionId,
    String? unitId,
    String? childContextId,
  });

  Future<PersonHandleCheck> checkHandle({required String handle, String? personId});
}

final class PersonIdentityAccessDeniedException implements Exception {
  const PersonIdentityAccessDeniedException();
}

final class PersonIdentityUnavailableException implements Exception {
  const PersonIdentityUnavailableException();
}

final class UnavailablePersonIdentityRepository implements PersonIdentityRepository {
  const UnavailablePersonIdentityRepository();

  Never _unavailable() => throw const PersonIdentityUnavailableException();

  @override
  Future<PersonHandleCheck> checkHandle({required String handle, String? personId}) async =>
      _unavailable();

  @override
  Future<List<PersonIdentityCandidate>> resolve({
    required PersonIdentityLookupKind kind,
    required String query,
    String? institutionId,
    String? unitId,
    String? childContextId,
  }) async => _unavailable();
}
