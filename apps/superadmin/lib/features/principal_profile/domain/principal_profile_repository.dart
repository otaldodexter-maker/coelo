import 'package:flutter/foundation.dart';

/// Backend-authorized context used to address one institutional profile.
///
/// The identifier routes; it never authorizes. The server re-derives actor,
/// tenant, hierarchy and RLS on every call.
@immutable
final class PrincipalProfileScope {
  const PrincipalProfileScope({required this.institutionId}) : assert(institutionId != '');

  final String institutionId;

  @override
  bool operator ==(Object other) =>
      other is PrincipalProfileScope && other.institutionId == institutionId;

  @override
  int get hashCode => institutionId.hashCode;
}

/// `principal.profile-edit`, deliberately narrowed to the editorial text.
///
/// Only `bio` is carried. That is not the whole screen and is not meant to be:
/// the institutional profile contract is still an open decision, and the fields
/// it has to settle are the ones this command leaves out.
///
/// * `name` and `typeLabel` are institution registry data. Editing them here
///   too would create a second source of truth alongside Instituicoes.
/// * `metrics` are derived counts. Anything the client could send would be a
///   number it declared about itself, so they must stay server-computed.
/// * `nextEvent` mirrors the Agenda.
/// * `highlights` are editorial, so they belong in this action eventually, but
///   their order and their limit are not defined yet.
/// * `links` are ambiguous in the current model — people/unit bonds or external
///   links — and the answer changes privacy and LGPD handling.
///
/// Sending any of those before the decision would be inventing the contract.
@immutable
final class PrincipalProfileEditCommand {
  const PrincipalProfileEditCommand({
    required this.institutionId,
    required this.bio,
    required this.requestId,
    required this.expectedVersion,
  }) : assert(institutionId != ''),
       assert(requestId != '');

  final String institutionId;
  final String bio;

  /// Preserved by the caller so a retry replays instead of writing twice.
  final String requestId;

  /// The version the operator was looking at. The server refuses a write over a
  /// profile that changed underneath, instead of silently overwriting it.
  final int expectedVersion;
}

enum PrincipalProfileBioIssue { empty, tooLong }

/// Client-side pre-check for the editorial text.
///
/// A courtesy that explains a refusal before a pointless round trip. It
/// authorizes nothing: the server revalidates the same text.
abstract final class PrincipalProfileBioPolicy {
  static const maximumCharacters = 600;

  static PrincipalProfileBioIssue? validate(String bio) {
    final normalized = bio.trim();
    if (normalized.isEmpty) return PrincipalProfileBioIssue.empty;
    // Counted in characters, the way a Postgres `length()` check would.
    if (normalized.runes.length > maximumCharacters) return PrincipalProfileBioIssue.tooLong;
    return null;
  }
}

abstract interface class PrincipalProfileRepository {
  /// Applies an authorized edit and returns the server's re-projection.
  ///
  /// Nothing is rewritten locally: the surface renders what comes back, so an
  /// edit can never be shown as applied when the server did not apply it.
  Future<PrincipalProfileEditResult> editProfile(PrincipalProfileEditCommand command);
}

@immutable
final class PrincipalProfileEditResult {
  const PrincipalProfileEditResult({required this.bio, required this.version});

  final String bio;
  final int version;
}

sealed class PrincipalProfileFailure implements Exception {
  const PrincipalProfileFailure();
}

final class PrincipalProfileUnauthorized extends PrincipalProfileFailure {
  const PrincipalProfileUnauthorized();
}

/// The profile changed under the operator. The edit is refused so the older
/// text never overwrites the newer one.
final class PrincipalProfileConflict extends PrincipalProfileFailure {
  const PrincipalProfileConflict();
}

/// The text was refused by the client pre-check, before any round trip.
final class PrincipalProfileBioRejected extends PrincipalProfileFailure {
  const PrincipalProfileBioRejected(this.issue);

  final PrincipalProfileBioIssue issue;
}

/// No authorized edit command exists yet. Raised instead of inventing an RPC
/// name or letting the surface believe the profile changed.
final class PrincipalProfileEditUnavailable extends PrincipalProfileFailure {
  const PrincipalProfileEditUnavailable();
}
