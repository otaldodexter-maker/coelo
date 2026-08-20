import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

enum MomentsStatus { draft, published }

enum MomentsAudienceKind { families, students, schoolStaff, guardiansOnly }

enum MomentsPublicationPhase {
  initial,
  loading,
  editing,
  saving,
  saved,
  publishing,
  success,
  conflict,
  failure,
  unauthorized,
}

@immutable
final class MomentsPublicationContext {
  const MomentsPublicationContext({
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

  static const demo = MomentsPublicationContext(
    institutionId: 'institution-preview',
    institutionName: 'Colégio Coelo',
    unitId: 'unit-preview',
    unitName: 'Unidade Higienópolis',
    groupId: 'group-preview',
    groupName: '3º ano A',
  );
}

@immutable
final class MomentsMediaDraft {
  const MomentsMediaDraft({
    required this.localId,
    required this.assetPath,
    required this.durationLabel,
    required this.cropIndex,
  });

  factory MomentsMediaDraft.demo(int index) => MomentsMediaDraft(
    localId: 'moment-media-$index',
    assetPath: 'assets/principal_moments/moments-strip.png',
    durationLabel: const ['0:15', '0:08', '0:12', '0:10', '0:18'][index % 5],
    cropIndex: index % 5,
  );

  final String localId;
  final String assetPath;
  final String durationLabel;
  final int cropIndex;
}

@immutable
final class MomentsDraft {
  MomentsDraft({
    this.id,
    this.caption = '',
    Iterable<MomentsAudienceKind> audiences = const {},
    Iterable<MomentsMediaDraft> media = const [],
    this.saveAsDraft = false,
    this.version = 0,
  }) : audiences = Set.unmodifiable(audiences),
       media = List.unmodifiable(media);

  final String? id;
  final String caption;
  final Set<MomentsAudienceKind> audiences;
  final List<MomentsMediaDraft> media;
  final bool saveAsDraft;
  final int version;

  int get captionCharacters => caption.characters.length;

  MomentsDraft copyWith({
    String? id,
    String? caption,
    Iterable<MomentsAudienceKind>? audiences,
    Iterable<MomentsMediaDraft>? media,
    bool? saveAsDraft,
    int? version,
  }) => MomentsDraft(
    id: id ?? this.id,
    caption: caption ?? this.caption,
    audiences: Set.unmodifiable(audiences ?? this.audiences),
    media: List.unmodifiable(media ?? this.media),
    saveAsDraft: saveAsDraft ?? this.saveAsDraft,
    version: version ?? this.version,
  );
}

@immutable
final class MomentsPublication {
  const MomentsPublication({required this.id, required this.status});

  final String id;
  final MomentsStatus status;
}

abstract interface class MomentsPublicationRepository {
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context);

  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft);

  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft);
}

final class InMemoryMomentsPublicationRepository implements MomentsPublicationRepository {
  InMemoryMomentsPublicationRepository({MomentsDraft? draft}) : savedDraft = draft;

  MomentsDraft? savedDraft;
  MomentsPublication? lastPublication;

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async => savedDraft;

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) async {
    savedDraft = draft.copyWith(id: draft.id ?? 'moment-draft-1', version: draft.version + 1);
    return savedDraft!;
  }

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) async {
    lastPublication = const MomentsPublication(
      id: 'moment-publication-1',
      status: MomentsStatus.published,
    );
    return lastPublication!;
  }
}

final class MomentsPublicationConflict implements Exception {}

final class MomentsPublicationUnauthorized implements Exception {}
