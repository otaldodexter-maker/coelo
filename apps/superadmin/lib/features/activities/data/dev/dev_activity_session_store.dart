import '../../domain/activity_command.dart';
import '../../domain/activity_directory.dart';

enum DevActivitySessionMode { content, empty, failure, unauthorized }

final class DevActivitySessionStore {
  DevActivitySessionStore.content() : mode = DevActivitySessionMode.content;
  DevActivitySessionStore.empty() : mode = DevActivitySessionMode.empty;
  DevActivitySessionStore.failure() : mode = DevActivitySessionMode.failure;
  DevActivitySessionStore.unauthorized() : mode = DevActivitySessionMode.unauthorized;

  final DevActivitySessionMode mode;
  final Map<String, ActivityDetail> _details = {};

  Iterable<ActivityDetail> get details => _details.values;
  ActivityDetail? detail(String id) => _details[id];
  void remember(ActivityDetail detail) => _details.putIfAbsent(detail.item.id, () => detail);

  void guardDirectory() {
    if (mode == DevActivitySessionMode.failure) {
      throw const ActivityDirectoryUnavailableException();
    }
    if (mode == DevActivitySessionMode.unauthorized) {
      throw const ActivityDirectoryUnauthorizedException();
    }
  }

  void guardCommand() {
    if (mode == DevActivitySessionMode.failure) {
      throw const ActivityCommandUnavailableException();
    }
    if (mode == DevActivitySessionMode.unauthorized) {
      throw const ActivityCommandUnauthorizedException();
    }
  }

  void upsert(ActivitySaveCommand command, ActivitySaveResult result) {
    final now = DateTime.utc(2026, 8, 24, 15);
    final previous = _details[result.activityId];
    final item = ActivityDirectoryItem(
      id: result.activityId,
      institutionId: command.institutionId,
      institutionName: 'Instituição local',
      name: command.name,
      description: command.description,
      status: result.status,
      origin: command.unitIds.isEmpty ? ActivityOrigin.institution : ActivityOrigin.unit,
      distribution: command.unitIds.isEmpty
          ? ActivityDistribution.institutionStandard
          : ActivityDistribution.unitLocal,
      governance: command.governance,
      handleStem: command.handleStem,
      activeUnitCount: command.unitIds.length,
      activeGroupCount: command.groupIds.length,
      managementVersion: result.managementVersion,
      updatedAt: now,
    );
    _details[result.activityId] = ActivityDetail(
      item: item,
      createdAt: previous?.createdAt ?? now,
      units: [
        for (final id in command.unitIds)
          ActivityUnitLink(id: id, name: id, status: ActivityStatus.active, startsAt: now),
      ],
      groups: [
        for (final id in command.groupIds)
          ActivityGroupLink(
            id: id,
            name: id,
            unitName: command.unitIds.firstOrNull ?? '',
            status: ActivityStatus.active,
            participation: ActivityParticipation.all,
            assigneeCount: command.assignments.length,
            participantCount: command.participants.length,
          ),
      ],
      taxonomyId: command.taxonomyId,
      templateId: command.templateId,
      taxonomyOtherDescription: command.taxonomyOtherDescription,
      pedagogicalConfiguration: {
        ...command.pedagogicalConfiguration,
        'expected_version': (command.expectedAssessmentVersion ?? 0) + 1,
        'change_justification': command.assessmentChangeJustification,
      },
    );
  }

  void reset() => _details.clear();
}
