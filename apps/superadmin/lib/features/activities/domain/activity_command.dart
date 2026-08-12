import 'dart:typed_data';

import 'activity_directory.dart';

enum ActivityCommandIntent { saveDraft, publish }

enum ActivityIdentityKind { initials, icon, image }

enum ActivityCommandExportFormat { csv, xlsx }

enum ActivityProfessionalAccessLevel {
  none('none'),
  view('view'),
  edit('edit'),
  both('both');

  const ActivityProfessionalAccessLevel(this.databaseValue);
  final String databaseValue;
}

enum ActivityCommandProfessionalRole {
  instructor('instructor'),
  activityAdmin('activity_admin');

  const ActivityCommandProfessionalRole(this.databaseValue);
  final String databaseValue;
}

final class ActivityCommandIdentity {
  const ActivityCommandIdentity({
    required this.kind,
    required this.initials,
    required this.color,
    required this.icon,
    this.preserveExisting = false,
    this.imageName,
    this.imageBytes,
  });

  final ActivityIdentityKind kind;
  final String initials;
  final String color;
  final String icon;
  final bool preserveExisting;
  final String? imageName;
  final Uint8List? imageBytes;
}

final class ActivityCommandAssignment {
  const ActivityCommandAssignment({
    required this.groupId,
    required this.membershipId,
    required this.role,
    required this.permissions,
  });

  final String? groupId;
  final String membershipId;
  final ActivityCommandProfessionalRole role;
  final Map<String, ActivityProfessionalAccessLevel> permissions;
}

final class ActivityCommandParticipant {
  const ActivityCommandParticipant({
    required this.groupId,
    required this.childGroupLinkId,
    required this.belongs,
  });

  final String groupId;
  final String childGroupLinkId;
  final bool belongs;
}

final class ActivitySaveCommand {
  const ActivitySaveCommand({
    required this.requestId,
    required this.intent,
    required this.name,
    required this.description,
    this.handleStem,
    required this.taxonomyId,
    required this.taxonomyOtherDescription,
    required this.governance,
    required this.institutionId,
    required this.unitIds,
    required this.groupIds,
    required this.assignments,
    this.participants = const [],
    required this.identity,
    this.templateId,
    this.activityId,
    this.expectedVersion = 0,
  });

  final String requestId;
  final ActivityCommandIntent intent;
  final String? activityId;
  final String? templateId;
  final int expectedVersion;
  final String name;
  final String description;
  final String? handleStem;
  final String taxonomyId;
  final String taxonomyOtherDescription;
  final ActivityGovernance governance;
  final String institutionId;
  final Set<String> unitIds;
  final Set<String> groupIds;
  final List<ActivityCommandAssignment> assignments;
  final List<ActivityCommandParticipant> participants;
  final ActivityCommandIdentity identity;
}

final class ActivitySaveResult {
  const ActivitySaveResult({
    required this.activityId,
    required this.managementVersion,
    required this.status,
  });

  final String activityId;
  final int managementVersion;
  final ActivityStatus status;
}

final class ActivityLocationCommand {
  const ActivityLocationCommand({
    required this.requestId,
    required this.institutionId,
    required this.unitIds,
    required this.name,
  });

  final String requestId;
  final String institutionId;
  final Set<String> unitIds;
  final String name;
}

final class ActivityLocationResult {
  const ActivityLocationResult({required this.id, required this.unitId, required this.name});

  final String id;
  final String unitId;
  final String name;
}

final class ActivityExportResult {
  const ActivityExportResult({required this.jobId, required this.downloadUrl});

  final String jobId;
  final String downloadUrl;
}

final class ActivityTemplateCopyCommand {
  const ActivityTemplateCopyCommand({
    required this.requestId,
    required this.templateId,
    required this.institutionId,
  });

  final String requestId;
  final String templateId;
  final String institutionId;
}

final class ActivityTemplateCopyResult {
  const ActivityTemplateCopyResult({
    required this.id,
    required this.institutionId,
    required this.name,
  });

  final String id;
  final String institutionId;
  final String name;
}

abstract interface class ActivityCommandRepository {
  Future<ActivitySaveResult> save(ActivitySaveCommand command);

  Future<ActivityTemplateCopyResult> copyTemplate(ActivityTemplateCopyCommand command);

  Future<List<ActivityLocationResult>> createLocations(ActivityLocationCommand command);

  Future<ActivityExportResult> requestExport(
    ActivityDirectoryQuery query, {
    required ActivityCommandExportFormat format,
  });
}

final class ActivityCommandUnauthorizedException implements Exception {
  const ActivityCommandUnauthorizedException();
}

final class ActivityCommandConflictException implements Exception {
  const ActivityCommandConflictException();
}

final class ActivityCommandUnavailableException implements Exception {
  const ActivityCommandUnavailableException();
}
