import 'principal_happens_preview_data.dart';

final class PrincipalHappensFeedScope {
  const PrincipalHappensFeedScope({required this.institutionId, this.unitId, this.groupId});

  final String institutionId;
  final String? unitId;
  final String? groupId;
}

abstract interface class PrincipalHappensFeedRepository {
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope);

  Future<PrincipalHappensMediaRead> resolveMedia(PrincipalHappensMediaDescriptor media);
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

final class PrincipalHappensFeedUnavailable implements Exception {
  const PrincipalHappensFeedUnavailable();
}
