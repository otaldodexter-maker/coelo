import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/principal_profile_repository.dart';

/// Production adapter for the institutional profile.
///
/// It holds the client so the transport is already in place, and it deliberately
/// does not call anything: the institutional profile contract is an open
/// decision, so there is no authorized edit RPC to call. Guessing a name would
/// either 404 or reach an unreviewed surface, and returning a receipt would tell
/// the surface a text was saved when nothing was.
final class SupabasePrincipalProfileRepository implements PrincipalProfileRepository {
  const SupabasePrincipalProfileRepository(this._client);

  // ignore: unused_field
  final SupabaseClient _client;

  @override
  Future<PrincipalProfileEditResult> editProfile(PrincipalProfileEditCommand command) async {
    // The courtesy pre-check runs first so an obviously invalid text is named as
    // such instead of being reported as a missing service.
    final issue = PrincipalProfileBioPolicy.validate(command.bio);
    if (issue != null) throw PrincipalProfileBioRejected(issue);
    throw const PrincipalProfileEditUnavailable();
  }
}
