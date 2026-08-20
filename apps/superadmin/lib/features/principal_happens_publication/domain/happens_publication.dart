import 'package:flutter/foundation.dart';

enum HappensPostStatus { draft, scheduled, published }

enum HappensAudienceKind { families, students, schoolStaff, guardiansOnly }

enum HappensPublicationPhase {
  initial,
  loading,
  editing,
  autosaving,
  saved,
  uploading,
  publishing,
  scheduled,
  success,
  conflict,
  failure,
  unauthorized,
}

@immutable
final class HappensPublicationContext {
  const HappensPublicationContext({
    required this.institutionId,
    required this.institutionName,
    required this.unitId,
    required this.unitName,
    required this.groupId,
    required this.groupName,
  });

  final String institutionId;
  final String institutionName;
  final String unitId;
  final String unitName;
  final String groupId;
  final String groupName;

  static const demo = HappensPublicationContext(
    institutionId: '00000000-0000-0000-0000-000000000101',
    institutionName: 'Colégio Coelo',
    unitId: '00000000-0000-0000-0000-000000000102',
    unitName: 'Unidade Higienópolis',
    groupId: '00000000-0000-0000-0000-000000000103',
    groupName: '3º ano A',
  );
}

@immutable
final class HappensMediaDraft {
  HappensMediaDraft({
    required this.localId,
    required this.name,
    required this.mimeType,
    required Uint8List bytes,
    this.assetId,
    this.objectKey,
  }) : bytes = Uint8List.fromList(bytes);

  final String localId;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final String? assetId;
  final String? objectKey;

  bool get isVideo => mimeType.startsWith('video/');
}

@immutable
final class HappensPostDraft {
  HappensPostDraft({
    this.id,
    this.caption = '',
    Iterable<HappensAudienceKind> audiences = const [],
    Iterable<HappensMediaDraft> media = const [],
    this.publishAt,
    this.version = 0,
  }) : audiences = Set.unmodifiable(audiences),
       media = List.unmodifiable(media);

  final String? id;
  final String caption;
  final Set<HappensAudienceKind> audiences;
  final List<HappensMediaDraft> media;
  final DateTime? publishAt;
  final int version;

  HappensPostDraft copyWith({
    String? id,
    String? caption,
    Iterable<HappensAudienceKind>? audiences,
    Iterable<HappensMediaDraft>? media,
    DateTime? publishAt,
    bool clearPublishAt = false,
    int? version,
  }) => HappensPostDraft(
    id: id ?? this.id,
    caption: caption ?? this.caption,
    audiences: audiences ?? this.audiences,
    media: media ?? this.media,
    publishAt: clearPublishAt ? null : (publishAt ?? this.publishAt),
    version: version ?? this.version,
  );
}

@immutable
final class HappensPublication {
  const HappensPublication({required this.id, required this.status, required this.publishAt});
  final String id;
  final HappensPostStatus status;
  final DateTime publishAt;
}

@immutable
final class HappensUploadIntent {
  const HappensUploadIntent({
    required this.assetId,
    required this.institutionId,
    required this.postId,
    required this.requestId,
    required this.objectKey,
    required this.token,
    required this.displayOrder,
  });
  final String assetId;
  final String institutionId;
  final String postId;
  final String requestId;
  final String objectKey;
  final String token;
  final int displayOrder;
}

abstract interface class HappensPublicationRepository {
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context);
  Future<HappensPostDraft> saveDraft(HappensPublicationContext context, HappensPostDraft draft);
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  );
  Future<HappensMediaDraft> finalizeMedia(HappensUploadIntent intent, HappensMediaDraft media);
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media);
  Future<HappensPublication> publish(HappensPublicationContext context, HappensPostDraft draft);
}

final class InMemoryHappensPublicationRepository implements HappensPublicationRepository {
  HappensPostDraft? savedDraft;
  HappensPublication? lastPublication;

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) async => savedDraft;

  @override
  Future<HappensPostDraft> saveDraft(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    savedDraft = draft.copyWith(id: draft.id ?? 'draft-1', version: draft.version + 1);
    return savedDraft!;
  }

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) async => HappensUploadIntent(
    assetId: 'asset-${media.localId}',
    institutionId: context.institutionId,
    postId: postId,
    requestId: media.localId,
    objectKey: '${context.institutionId}/${media.localId}/${media.name}',
    token: 'local',
    displayOrder: displayOrder,
  );

  @override
  Future<HappensMediaDraft> finalizeMedia(
    HappensUploadIntent intent,
    HappensMediaDraft media,
  ) async => HappensMediaDraft(
    localId: media.localId,
    name: media.name,
    mimeType: media.mimeType,
    bytes: media.bytes,
    assetId: intent.assetId,
    objectKey: intent.objectKey,
  );

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) async {}

  @override
  Future<HappensPublication> publish(
    HappensPublicationContext context,
    HappensPostDraft draft,
  ) async {
    final now = DateTime.now().toUtc();
    final at = draft.publishAt?.toUtc() ?? now;
    lastPublication = HappensPublication(
      id: draft.id ?? 'post-1',
      status: at.isAfter(now) ? HappensPostStatus.scheduled : HappensPostStatus.published,
      publishAt: at,
    );
    return lastPublication!;
  }
}
