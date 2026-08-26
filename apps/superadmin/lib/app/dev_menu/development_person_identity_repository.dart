import '../../features/people/domain/person_identity.dart';

final class DevelopmentPersonIdentityRepository implements PersonIdentityRepository {
  const DevelopmentPersonIdentityRepository();

  @override
  Future<List<PersonIdentityCandidate>> resolve({
    required PersonIdentityLookupKind kind,
    required String query,
    String? institutionId,
    String? unitId,
    String? childContextId,
  }) async => const [];

  @override
  Future<PersonHandleCheck> checkHandle({required String handle, String? personId}) async =>
      PersonHandleCheck(handle: handle, availability: PersonHandleAvailability.available);
}
