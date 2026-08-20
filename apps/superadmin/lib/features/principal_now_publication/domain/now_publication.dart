import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

enum NowPublicationPhase {
  initial,
  loading,
  editing,
  uploading,
  saving,
  saved,
  publishing,
  success,
  conflict,
  failure,
  unauthorized,
}

enum NowPublicationIssue {
  mediaRequired,
  mediaTypeUnsupported,
  videoMetadataUnavailable,
  videoTooLong,
  mediaTooLarge,
  captionTooLong,
  audienceRequired,
  scheduleMustBeFuture,
  audioRightsRequired,
}

const nowMvpMaxUploadBytes = 25 * 1024 * 1024;

enum NowAudience { families, students, schoolStaff, guardiansOnly }

@immutable
final class NowPlanCapabilities {
  const NowPlanCapabilities({this.maxVideoDuration = const Duration(seconds: 30)});

  final Duration maxVideoDuration;

  bool accepts(Duration duration) => duration <= maxVideoDuration;
}

@immutable
final class NowPublicationContext {
  const NowPublicationContext({
    required this.tenantId,
    required this.institutionId,
    required this.unitId,
    required this.groupId,
    required this.institutionName,
    required this.unitName,
    required this.groupName,
    required this.allowedAudiences,
    this.capabilities = const NowPlanCapabilities(),
  });

  final String tenantId;
  final String institutionId;
  final String unitId;
  final String groupId;
  final String institutionName;
  final String unitName;
  final String groupName;
  final Set<NowAudience> allowedAudiences;
  final NowPlanCapabilities capabilities;

  static const demo = NowPublicationContext(
    tenantId: '00000000-0000-4000-8000-000000000001',
    institutionId: '00000000-0000-4000-8000-000000000002',
    unitId: '00000000-0000-4000-8000-000000000003',
    groupId: '00000000-0000-4000-8000-000000000004',
    institutionName: 'Colégio Coelo',
    unitName: 'Unidade Centro',
    groupName: 'Turma 3º ano A',
    allowedAudiences: {NowAudience.families},
  );
}

@immutable
final class NowMediaDraft {
  const NowMediaDraft({
    required this.localId,
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.duration,
    this.remoteAssetId,
    this.remoteUrl,
    this.cropScale = 1,
    this.cropX = 0,
    this.cropY = 0,
    this.coverPosition = 0,
  });

  factory NowMediaDraft.image({
    required String localId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) => NowMediaDraft(localId: localId, name: name, mimeType: mimeType, bytes: bytes);

  factory NowMediaDraft.video({
    required String localId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    required Duration duration,
  }) => NowMediaDraft(
    localId: localId,
    name: name,
    mimeType: mimeType,
    bytes: bytes,
    duration: duration,
  );

  final String localId;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final Duration? duration;
  final String? remoteAssetId;
  final String? remoteUrl;
  final double cropScale;
  final double cropX;
  final double cropY;
  final double coverPosition;

  bool get isVideo => mimeType.startsWith('video/');
  bool get isImage => mimeType.startsWith('image/');

  NowMediaDraft copyWith({
    String? remoteAssetId,
    String? remoteUrl,
    double? cropScale,
    double? cropX,
    double? cropY,
    double? coverPosition,
  }) => NowMediaDraft(
    localId: localId,
    name: name,
    mimeType: mimeType,
    bytes: bytes,
    duration: duration,
    remoteAssetId: remoteAssetId ?? this.remoteAssetId,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    cropScale: cropScale ?? this.cropScale,
    cropX: cropX ?? this.cropX,
    cropY: cropY ?? this.cropY,
    coverPosition: coverPosition ?? this.coverPosition,
  );
}

@immutable
final class NowAudioDraft {
  const NowAudioDraft({
    required this.localId,
    required this.name,
    required this.mimeType,
    required this.bytes,
    this.rightsConfirmed = false,
    this.remoteAssetId,
  });

  final String localId;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  final bool rightsConfirmed;
  final String? remoteAssetId;

  NowAudioDraft copyWith({bool? rightsConfirmed, String? remoteAssetId}) => NowAudioDraft(
    localId: localId,
    name: name,
    mimeType: mimeType,
    bytes: bytes,
    rightsConfirmed: rightsConfirmed ?? this.rightsConfirmed,
    remoteAssetId: remoteAssetId ?? this.remoteAssetId,
  );
}

@immutable
final class NowPublicationDraft {
  const NowPublicationDraft({
    this.id,
    this.version = 0,
    this.media,
    this.audio,
    this.caption = '',
    this.overlayText = '',
    this.audiences = const {},
    this.publishAt,
  });

  final String? id;
  final int version;
  final NowMediaDraft? media;
  final NowAudioDraft? audio;
  final String caption;
  final String overlayText;
  final Set<NowAudience> audiences;
  final DateTime? publishAt;

  List<NowPublicationIssue> validate(NowPublicationContext context, {DateTime? now}) {
    final issues = <NowPublicationIssue>[];
    if (media == null) {
      issues.add(NowPublicationIssue.mediaRequired);
    } else {
      if (!media!.isImage && !media!.isVideo) {
        issues.add(NowPublicationIssue.mediaTypeUnsupported);
      }
      if (media!.bytes.length > nowMvpMaxUploadBytes) {
        issues.add(NowPublicationIssue.mediaTooLarge);
      }
      final duration = media!.duration;
      if (media!.isVideo) {
        if (duration == null || duration <= Duration.zero) {
          issues.add(NowPublicationIssue.videoMetadataUnavailable);
        } else if (!context.capabilities.accepts(duration)) {
          issues.add(NowPublicationIssue.videoTooLong);
        }
      }
    }
    if (caption.characters.length > 60) issues.add(NowPublicationIssue.captionTooLong);
    if (audiences.isEmpty || !context.allowedAudiences.containsAll(audiences)) {
      issues.add(NowPublicationIssue.audienceRequired);
    }
    if (publishAt != null && !publishAt!.isAfter(now ?? DateTime.now())) {
      issues.add(NowPublicationIssue.scheduleMustBeFuture);
    }
    if (audio != null && !audio!.rightsConfirmed) {
      issues.add(NowPublicationIssue.audioRightsRequired);
    }
    if (audio != null && audio!.bytes.length > nowMvpMaxUploadBytes) {
      issues.add(NowPublicationIssue.mediaTooLarge);
    }
    return issues;
  }

  NowPublicationDraft copyWith({
    String? id,
    int? version,
    NowMediaDraft? media,
    bool clearMedia = false,
    NowAudioDraft? audio,
    bool clearAudio = false,
    String? caption,
    String? overlayText,
    Set<NowAudience>? audiences,
    DateTime? publishAt,
    bool clearPublishAt = false,
  }) => NowPublicationDraft(
    id: id ?? this.id,
    version: version ?? this.version,
    media: clearMedia ? null : (media ?? this.media),
    audio: clearAudio ? null : (audio ?? this.audio),
    caption: caption ?? this.caption,
    overlayText: overlayText ?? this.overlayText,
    audiences: Set.unmodifiable(audiences ?? this.audiences),
    publishAt: clearPublishAt ? null : (publishAt ?? this.publishAt),
  );
}

@immutable
final class NowPublication {
  const NowPublication({required this.id, required this.publishAt});
  final String id;
  final DateTime? publishAt;
}

abstract interface class NowPublicationRepository {
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context);
  Future<NowPublicationDraft> saveDraft(NowPublicationContext context, NowPublicationDraft draft);
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  );
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  );
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft);
}

final class InMemoryNowPublicationRepository implements NowPublicationRepository {
  NowPublicationDraft? savedDraft;
  NowPublication? lastPublication;

  @override
  Future<NowPublicationDraft?> loadDraft(NowPublicationContext context) async => savedDraft;

  @override
  Future<NowPublicationDraft> saveDraft(
    NowPublicationContext context,
    NowPublicationDraft draft,
  ) async {
    savedDraft = draft.copyWith(
      id: draft.id ?? '00000000-0000-4000-8000-000000000010',
      version: draft.version + 1,
    );
    return savedDraft!;
  }

  @override
  Future<NowMediaDraft> uploadMedia(
    NowPublicationContext context,
    String publicationId,
    NowMediaDraft media,
  ) async => media.copyWith(remoteAssetId: 'media-${media.localId}');

  @override
  Future<NowAudioDraft> uploadAudio(
    NowPublicationContext context,
    String publicationId,
    NowAudioDraft audio,
  ) async => audio.copyWith(remoteAssetId: 'audio-${audio.localId}');

  @override
  Future<NowPublication> publish(NowPublicationContext context, NowPublicationDraft draft) async {
    lastPublication = NowPublication(
      id: draft.id ?? '00000000-0000-4000-8000-000000000011',
      publishAt: draft.publishAt,
    );
    return lastPublication!;
  }
}

final class NowPublicationConflict implements Exception {}

final class NowPublicationUnauthorized implements Exception {}
