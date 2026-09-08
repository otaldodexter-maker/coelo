import 'package:flutter/foundation.dart';

@immutable
final class PrincipalNowFeedScope {
  const PrincipalNowFeedScope({
    required this.institutionId,
    this.unitId,
    this.groupId,
    this.limit = 20,
  }) : assert(limit > 0 && limit <= 50);

  final String institutionId;
  final String? unitId;
  final String? groupId;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is PrincipalNowFeedScope &&
      other.institutionId == institutionId &&
      other.unitId == unitId &&
      other.groupId == groupId &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(institutionId, unitId, groupId, limit);
}

@immutable
final class PrincipalNowFeedItem {
  const PrincipalNowFeedItem({
    required this.publicationId,
    required this.author,
    required this.authorInitials,
    required this.contextLabel,
    required this.timeLabel,
    required this.caption,
    required this.publishedAt,
    required this.expiresAt,
    required this.media,
    this.audio,
    this.canExpire = false,
    this.cropScale = 1,
    this.cropX = 0,
    this.cropY = 0,
    this.coverPosition = 0,
  });

  final String publicationId;
  final String author;
  final String authorInitials;
  final String contextLabel;
  final String timeLabel;
  final String caption;
  final DateTime publishedAt;
  final DateTime expiresAt;
  final PrincipalNowMediaDescriptor media;
  final PrincipalNowMediaDescriptor? audio;

  /// Whether the authorised projection says this actor may expire this Agora.
  /// Decided by profile, hierarchy and RLS on the server; the client only
  /// renders what was already granted and never derives it.
  final bool canExpire;
  final double cropScale;
  final double cropX;
  final double cropY;
  final double coverPosition;
}

enum PrincipalNowMediaKind { media, audio }

@immutable
final class PrincipalNowMediaDescriptor {
  const PrincipalNowMediaDescriptor({
    required this.readTicket,
    required this.mimeType,
    required this.kind,
  });

  final String readTicket;
  final String mimeType;
  final PrincipalNowMediaKind kind;
}

@immutable
final class PrincipalNowMediaRead {
  const PrincipalNowMediaRead({
    required this.signedUrl,
    required this.mimeType,
    required this.kind,
    required this.expiresIn,
  });

  final String signedUrl;
  final String mimeType;
  final PrincipalNowMediaKind kind;
  final Duration expiresIn;
}

/// Manual expiration of one published Agora.
///
/// The command only addresses the publication and records intent. Authorization
/// stays on the server, which re-derives actor, tenant, hierarchy and RLS.
@immutable
final class PrincipalNowExpireCommand {
  const PrincipalNowExpireCommand({
    required this.publicationId,
    required this.requestId,
    required this.reason,
  }) : assert(publicationId != ''),
       assert(requestId != '');

  final String publicationId;

  /// Preserved by the caller so a retry replays instead of expiring twice.
  final String requestId;

  /// Recorded with the expiration. Kept required so the audit trail never
  /// depends on the operator remembering to send it.
  final String reason;
}

abstract interface class PrincipalNowFeedRepository {
  /// Returns only publications authorized by the backend for [scope].
  Future<List<PrincipalNowFeedItem>> listVisibleStories(PrincipalNowFeedScope scope);

  /// Redeems a single-use public viewer ticket. Author draft tickets are not accepted here.
  Future<PrincipalNowMediaRead> resolveMedia({
    required PrincipalNowFeedScope scope,
    required String publicationId,
    required PrincipalNowMediaDescriptor media,
  });

  /// Expires a published Agora logically. The server decides by profile,
  /// hierarchy and RLS, keeps the tombstone and writes the audit entry; media
  /// assets are marked, never purged here.
  Future<void> expireNow(PrincipalNowExpireCommand command);
}

final class PrincipalNowFeedRefreshSignal extends ChangeNotifier {
  String? get lastPublishedNowId => _lastPublishedNowId;
  String? _lastPublishedNowId;

  void markPublished(String publicationId) {
    assert(publicationId.isNotEmpty, 'publicationId must not be empty.');
    _lastPublishedNowId = publicationId;
    notifyListeners();
  }
}

sealed class PrincipalNowFeedFailure implements Exception {
  const PrincipalNowFeedFailure();
}

final class PrincipalNowFeedUnauthorized extends PrincipalNowFeedFailure {
  const PrincipalNowFeedUnauthorized();
}

final class PrincipalNowFeedUnavailable extends PrincipalNowFeedFailure {
  const PrincipalNowFeedUnavailable();
}

/// The authorised expiration command does not exist yet. Raised instead of
/// pretending an Agora was taken off the air.
final class PrincipalNowExpireUnavailable extends PrincipalNowFeedFailure {
  const PrincipalNowExpireUnavailable();
}
