import 'principal_happens_preview_data.dart';

final class PrincipalHappensFeedScope {
  const PrincipalHappensFeedScope({required this.institutionId, this.unitId, this.groupId});

  final String institutionId;
  final String? unitId;
  final String? groupId;
}

final class PrincipalHappensRemoveCommand {
  const PrincipalHappensRemoveCommand({
    required this.postId,
    required this.requestId,
    required this.reason,
  }) : assert(postId != ''),
       assert(requestId != '');

  final String postId;

  /// Preserved by the caller so a retry replays instead of removing twice.
  final String requestId;

  /// Recorded with the removal. Kept required so the audit trail never depends
  /// on the caller remembering to send it.
  final String reason;
}

abstract interface class PrincipalHappensFeedRepository {
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope);

  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media);

  /// Removes a published post logically. The server decides by profile,
  /// hierarchy and RLS, keeps the tombstone and writes the audit entry; media
  /// assets are marked, never purged here.
  Future<void> removePost(PrincipalHappensRemoveCommand command);
}

final class PrincipalHappensMediaRead {
  const PrincipalHappensMediaRead({
    required this.signedUrl,
    required this.mimeType,
    required this.expiresIn,
  });

  final String signedUrl;
  final String mimeType;
  final Duration expiresIn;
}

final class PrincipalHappensFeedUnauthorized implements Exception {
  const PrincipalHappensFeedUnauthorized();
}

/// The authorised removal command does not exist yet. Raised instead of
/// pretending a post was taken down.
final class PrincipalHappensRemoveUnavailable implements Exception {
  const PrincipalHappensRemoveUnavailable();
}

final class PrincipalHappensFeedUnavailable implements Exception {
  const PrincipalHappensFeedUnavailable();
}
