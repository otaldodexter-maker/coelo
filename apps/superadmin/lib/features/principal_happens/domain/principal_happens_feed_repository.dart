import 'principal_happens_preview_data.dart';

final class PrincipalHappensFeedScope {
  const PrincipalHappensFeedScope({required this.institutionId, this.unitId, this.groupId});

  final String institutionId;
  final String? unitId;
  final String? groupId;
}

abstract interface class PrincipalHappensFeedRepository {
  Future<List<PrincipalPostPreviewItem>> listVisiblePosts(PrincipalHappensFeedScope scope);
}

final class PrincipalHappensFeedUnauthorized implements Exception {
  const PrincipalHappensFeedUnauthorized();
}

final class PrincipalHappensFeedUnavailable implements Exception {
  const PrincipalHappensFeedUnavailable();
}
