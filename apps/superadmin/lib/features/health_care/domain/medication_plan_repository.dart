enum MedicationPlanStatus { draft, active, suspended, ended }

final class MedicationPlanQuery {
  const MedicationPlanQuery({this.statuses = const {}, this.page = 0, this.pageSize = 25})
    : assert(page >= 0),
      assert(pageSize > 0 && pageSize <= 100);
  final Set<MedicationPlanStatus> statuses;
  final int page;
  final int pageSize;
  int get offset => page * pageSize;
}

final class MedicationPlanSummary {
  const MedicationPlanSummary({
    required this.id,
    required this.childPersonId,
    required this.status,
    required this.version,
    required this.medicationName,
    required this.doseAmount,
    required this.doseUnit,
    required this.route,
    required this.validFrom,
    this.validUntil,
  });
  final String id, childPersonId, medicationName, doseUnit, route;
  final MedicationPlanStatus status;
  final int version;
  final num doseAmount;
  final DateTime validFrom;
  final DateTime? validUntil;
}

final class MedicationPlanPage {
  MedicationPlanPage({
    required List<MedicationPlanSummary> items,
    required this.total,
    required this.limit,
    required this.offset,
  }) : items = List.unmodifiable(items);
  final List<MedicationPlanSummary> items;
  final int total, limit, offset;
}

final class MedicationScheduleDraft {
  MedicationScheduleDraft({
    required this.timeOfDay,
    required Set<int> weekdays,
    required this.timezone,
    this.frequencyKind = 'weekly',
    this.startDate,
    this.endDate,
    this.maxOccurrencesPerDay,
  }) : weekdays = Set.unmodifiable(weekdays) {
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(timeOfDay) ||
        weekdays.isEmpty ||
        weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError('Invalid medication schedule.');
    }
  }
  final String timeOfDay, timezone, frequencyKind;
  final Set<int> weekdays;
  final DateTime? startDate, endDate;
  final int? maxOccurrencesPerDay;
}

final class MedicationPlanSaveCommand {
  MedicationPlanSaveCommand({
    required this.requestId,
    required this.childPersonId,
    required this.expectedVersion,
    required this.medicationName,
    required this.doseAmount,
    required this.doseUnit,
    required this.administrationRoute,
    required this.validFrom,
    required this.reason,
    required this.scopeKind,
    required this.timezone,
    required List<MedicationScheduleDraft> schedules,
    this.planId,
    this.validUntil,
    this.routeDetails,
    this.instructions,
    this.institutionId,
    this.unitId,
    this.groupId,
    this.childContextId,
  }) : schedules = List.unmodifiable(schedules) {
    if (medicationName.trim().isEmpty ||
        doseAmount <= 0 ||
        doseUnit.trim().isEmpty ||
        administrationRoute.trim().isEmpty ||
        reason.trim().isEmpty ||
        timezone.trim().isEmpty ||
        schedules.isEmpty ||
        (validUntil != null && validUntil!.isBefore(validFrom))) {
      throw ArgumentError('Invalid medication plan.');
    }
  }
  final String requestId,
      childPersonId,
      medicationName,
      doseUnit,
      administrationRoute,
      reason,
      scopeKind,
      timezone;
  final String? planId, routeDetails, instructions, institutionId, unitId, groupId, childContextId;
  final int expectedVersion;
  final num doseAmount;
  final DateTime validFrom;
  final DateTime? validUntil;
  final List<MedicationScheduleDraft> schedules;
}

final class MedicationPlanDetail {
  MedicationPlanDetail({
    required this.id,
    required this.childPersonId,
    required this.status,
    required this.currentVersion,
    required this.medicationName,
    required this.doseAmount,
    required this.doseUnit,
    required this.administrationRoute,
    required this.validFrom,
    required this.timezone,
    required List<MedicationScheduleDraft> schedules,
    this.validUntil,
    this.routeDetails,
    this.instructions,
  }) : schedules = List.unmodifiable(schedules);
  final String id, childPersonId, medicationName, doseUnit, administrationRoute, timezone;
  final String? routeDetails, instructions;
  final MedicationPlanStatus status;
  final int currentVersion;
  final num doseAmount;
  final DateTime validFrom;
  final DateTime? validUntil;
  final List<MedicationScheduleDraft> schedules;
}

sealed class MedicationPlanException implements Exception {
  const MedicationPlanException(this.message);
  final String message;
}

final class MedicationPlanUnauthorizedException extends MedicationPlanException {
  const MedicationPlanUnauthorizedException() : super('Acesso não autorizado.');
}

final class MedicationPlanNotFoundException extends MedicationPlanException {
  const MedicationPlanNotFoundException() : super('Plano não encontrado.');
}

final class MedicationPlanConflictException extends MedicationPlanException {
  const MedicationPlanConflictException()
    : super('O plano foi alterado. Atualize e tente novamente.');
}

final class MedicationPlanInvalidInputException extends MedicationPlanException {
  const MedicationPlanInvalidInputException() : super('Revise os dados do plano.');
}

final class MedicationPlanUnavailableException extends MedicationPlanException {
  const MedicationPlanUnavailableException() : super('Planos de medicação estão indisponíveis.');
}

abstract interface class MedicationPlanRepository {
  Future<MedicationPlanPage> fetchPage(MedicationPlanQuery query);
  Future<MedicationPlanDetail> fetchDetail(String planId);
  Future<MedicationPlanDetail> save(MedicationPlanSaveCommand command);
}

final class UnavailableMedicationPlanRepository implements MedicationPlanRepository {
  const UnavailableMedicationPlanRepository();
  Never _fail() => throw const MedicationPlanUnavailableException();
  @override
  Future<MedicationPlanPage> fetchPage(MedicationPlanQuery query) async => _fail();
  @override
  Future<MedicationPlanDetail> fetchDetail(String planId) async => _fail();
  @override
  Future<MedicationPlanDetail> save(MedicationPlanSaveCommand command) async => _fail();
}
