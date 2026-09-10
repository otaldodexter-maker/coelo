import 'package:coelo_domain/locations.dart';

enum GroupLocationCreateFailure { invalidInput, denied, conflict, unavailable }

final class GroupLocationCreateException implements Exception {
  const GroupLocationCreateException(this.failure);
  final GroupLocationCreateFailure failure;
  @override
  String toString() => 'GroupLocationCreateException(${failure.name})';
}

/// Only the approved minimal CREATE DRAFT slice. No legacy composition fields.
final class GroupLocationCreateCommand {
  const GroupLocationCreateCommand({
    required this.requestId,
    required this.institutionId,
    required this.unitId,
    required this.name,
    required this.groupType,
    required this.groupTypeOtherText,
    required this.locationSelection,
    this.reservation,
  });
  final String requestId;
  final String institutionId;
  final String unitId;
  final String name;
  final String groupType;
  final String? groupTypeOtherText;
  final CataloguedLocationSelection locationSelection;
  final GroupLocationReservationIntent? reservation;
}

/// The server supplies the newly created Group consumer; no placeholder ID.
final class GroupLocationReservationIntent {
  const GroupLocationReservationIntent({
    required this.firstOccurrence,
    required this.recurrence,
    this.conflictJustification,
  });
  final LocationReservationOccurrence firstOccurrence;
  final LocationReservationRecurrence recurrence;
  final String? conflictJustification;

  Map<String, Object?> toJson() {
    final justification = conflictJustification?.trim();
    if (!validLocationReservationJustification(justification)) {
      throw const GroupLocationCreateException(GroupLocationCreateFailure.invalidInput);
    }
    return {
      'first_occurrence': {
        'starts_at': firstOccurrence.startsAt.toIso8601String(),
        'ends_at': firstOccurrence.endsAt.toIso8601String(),
      },
      'recurrence': switch (recurrence) {
        LocationReservationOnce() => {'kind': 'once'},
        LocationReservationWeekly(:final weekdays, :final until, :final timeZone) => {
          'kind': 'weekly',
          'weekdays': weekdays.toList()..sort(),
          'until':
              '${until.year.toString().padLeft(4, '0')}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}',
          'time_zone': timeZone,
        },
      },
      'conflict_justification': justification,
    };
  }
}

final class GroupLocationCreateResult {
  const GroupLocationCreateResult({
    required this.groupId,
    required this.managementVersion,
    required this.status,
    required this.locationId,
    this.reservation,
  });
  final String groupId;
  final int managementVersion;
  final String status;
  final String locationId;
  final LocationReservation? reservation;
}

abstract interface class GroupLocationCreateRepository {
  /// Composition availability, never authorization of an actor.
  bool get available;
  Future<GroupLocationCreateResult> create(GroupLocationCreateCommand command);
}

final class UnavailableGroupLocationCreateRepository implements GroupLocationCreateRepository {
  const UnavailableGroupLocationCreateRepository();
  @override
  bool get available => false;
  @override
  Future<GroupLocationCreateResult> create(GroupLocationCreateCommand command) async {
    throw const GroupLocationCreateException(GroupLocationCreateFailure.unavailable);
  }
}
