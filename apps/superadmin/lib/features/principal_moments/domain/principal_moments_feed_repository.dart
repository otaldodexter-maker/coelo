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

  /// Redeems one descriptor through the authorised gateway. The ticket is
  /// single use and short lived, and the client never signs anything itself.
  Future<PrincipalMomentsMediaRead> resolveMedia(PrincipalMomentsMediaDescriptor media);
}

final class PrincipalMomentsMediaRead {
  const PrincipalMomentsMediaRead({
    required this.signedUrl,
    required this.mimeType,
    required this.expiresIn,
  });

  final String signedUrl;
  final String mimeType;
  final Duration expiresIn;
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
