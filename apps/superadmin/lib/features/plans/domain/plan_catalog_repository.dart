import 'plan_catalog.dart';
import 'dart:math';

abstract interface class PlanCatalogRepository {
  Future<PlanPage> list(PlanQuery query);
  Future<PlanDetails> get(String planId);
  Future<PlanDetails> save(PlanSaveCommand command);
}

final class PlanDetails {
  const PlanDetails({required this.plan, this.linkedInstitutions = const []});
  final PlanCatalog plan;
  final List<PlanLinkedInstitution> linkedInstitutions;
}

final class PlanSaveCommand {
  const PlanSaveCommand({
    required this.requestId,
    required this.expectedRevision,
    required this.draft,
    required this.reason,
  });

  final String requestId;
  final int? expectedRevision;
  final PlanDraft draft;
  final String reason;
}

final class PlanRepositoryException implements Exception {
  const PlanRepositoryException(this.kind, this.message);
  final PlanRepositoryFailureKind kind;
  final String message;
}

enum PlanRepositoryFailureKind { unauthorized, conflict, validation, unavailable, unknown }

String newPlanRequestId() {
  final random = Random.secure();
  final values = List<int>.generate(16, (_) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40;
  values[8] = (values[8] & 0x3f) | 0x80;
  final hex = values.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
