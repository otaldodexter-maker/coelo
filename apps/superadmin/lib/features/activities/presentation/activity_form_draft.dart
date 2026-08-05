import 'dart:typed_data';

import '../domain/activity_directory.dart';

final class ActivityProfessionalPermissions {
  const ActivityProfessionalPermissions({
    this.happens = true,
    this.now = true,
    this.moments = true,
    this.chat = true,
  });

  final bool happens;
  final bool now;
  final bool moments;
  final bool chat;

  ActivityProfessionalPermissions copyWith({bool? happens, bool? now, bool? moments, bool? chat}) =>
      ActivityProfessionalPermissions(
        happens: happens ?? this.happens,
        now: now ?? this.now,
        moments: moments ?? this.moments,
        chat: chat ?? this.chat,
      );
}

final class ActivityProfessionalAssignment {
  const ActivityProfessionalAssignment({
    required this.groupId,
    required this.professionalId,
    this.permissions = const ActivityProfessionalPermissions(),
  });

  final String groupId;
  final String professionalId;
  final ActivityProfessionalPermissions permissions;

  ActivityProfessionalAssignment copyWith({ActivityProfessionalPermissions? permissions}) =>
      ActivityProfessionalAssignment(
        groupId: groupId,
        professionalId: professionalId,
        permissions: permissions ?? this.permissions,
      );
}

final class ActivityFormDraft {
  const ActivityFormDraft({
    required this.name,
    required this.description,
    required this.category,
    required this.activityLabel,
    required this.governance,
    required this.institutionId,
    required this.unitIds,
    required this.groupIds,
    required this.assignments,
    this.locationId,
    this.imageName,
    this.imageBytes,
  });

  final String name;
  final String description;
  final ActivityCategory? category;
  final String activityLabel;
  final ActivityGovernance governance;
  final String institutionId;
  final Set<String> unitIds;
  final String? locationId;
  final Set<String> groupIds;
  final List<ActivityProfessionalAssignment> assignments;
  final String? imageName;
  final Uint8List? imageBytes;
}
