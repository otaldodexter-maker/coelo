import 'package:flutter/foundation.dart';

import 'principal_moments_preview_data.dart';

/// Backend-authorized context used to request the Momentos feed.
///
/// Repository implementations must validate the actor, tenant and audience on
/// the server. These identifiers are routing hints and are never authorization.
@immutable
final class PrincipalMomentsFeedScope {
  const PrincipalMomentsFeedScope({required this.institutionId, this.unitId, this.groupId});

  final String institutionId;
  final String? unitId;
  final String? groupId;

  @override
  bool operator ==(Object other) =>
      other is PrincipalMomentsFeedScope &&
      other.institutionId == institutionId &&
      other.unitId == unitId &&
      other.groupId == groupId;

  @override
  int get hashCode => Object.hash(institutionId, unitId, groupId);
}

abstract interface class PrincipalMomentsFeedRepository {
  /// Returns only moments the authenticated actor may currently consume.
  ///
  /// Implementations must fail closed. Client-side filtering is not an
  /// authorization boundary.
  Future<List<PrincipalMomentPreviewItem>> listVisibleMoments(PrincipalMomentsFeedScope scope);
}

/// Feature-local invalidation seam shared with the publication route.
///
/// A successful publisher passes its confirmed receipt/id to [markPublished].
/// The consumer then reloads through [PrincipalMomentsFeedRepository], without
/// treating the receipt itself as authorized feed data.
final class PrincipalMomentsFeedRefreshSignal extends ChangeNotifier {
  String? get lastPublishedMomentId => _lastPublishedMomentId;
  String? _lastPublishedMomentId;

  void markPublished(String publicationId) {
    assert(publicationId.isNotEmpty, 'publicationId must not be empty.');
    _lastPublishedMomentId = publicationId;
    notifyListeners();
  }
}

sealed class PrincipalMomentsFeedFailure implements Exception {
  const PrincipalMomentsFeedFailure();
}

final class PrincipalMomentsFeedUnauthorized extends PrincipalMomentsFeedFailure {
  const PrincipalMomentsFeedUnauthorized();
}

final class PrincipalMomentsFeedUnavailable extends PrincipalMomentsFeedFailure {
  const PrincipalMomentsFeedUnavailable();
}

/// Author-only withdrawal seam for a published moment.
///
/// The client never decides who may withdraw. `can_withdraw` from the feed is a
/// rendering hint; the backend re-authorizes actor, tenant, scope, permission
/// and authorship on every call.
abstract interface class PrincipalMomentsWithdrawalRepository {
  Future<void> withdrawMoment(String publicationId, {String? reason});
}

sealed class PrincipalMomentsWithdrawalFailure implements Exception {
  const PrincipalMomentsWithdrawalFailure();
}

/// The backend refused the withdrawal (permission, tenant, scope or authorship).
final class PrincipalMomentsWithdrawalDenied extends PrincipalMomentsWithdrawalFailure {
  const PrincipalMomentsWithdrawalDenied();
}

/// The withdrawal could not be completed and the moment state is unchanged.
final class PrincipalMomentsWithdrawalUnavailable extends PrincipalMomentsWithdrawalFailure {
  const PrincipalMomentsWithdrawalUnavailable();
}
