import 'health_care.dart';

abstract interface class HealthCareRepository {
  HealthCareActor? get defaultActor;

  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  });

  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor});

  Future<HealthMedication> createMedication({
    required String childId,
    required String name,
    required String dose,
    required String doseUnit,
    required String route,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<HealthMedicationSchedule> schedules,
    String? documentName,
    String? documentType,
    required HealthCareActor actor,
  });

  Future<HealthMedicationChangeResult> changeMedicationRelevant({
    required String childId,
    required String medicationId,
    required String name,
    required String justification,
    required HealthCareActor actor,
  });

  Future<HealthCareAllergy> createAllergy({
    required String childId,
    required String label,
    required HealthCareAllergyType type,
    required HealthCareActor actor,
  });

  Future<HealthCareAcknowledgement> deactivateAllergy({
    required String childId,
    required String allergyId,
    required String justification,
    required HealthCareActor actor,
  });

  Future<HealthCareAcknowledgement> updateCareProfile({
    required String childId,
    required List<HealthCareProfileItem> items,
    required String justification,
    required HealthCareActor actor,
  });
}

final class UnavailableHealthCareRepository implements HealthCareRepository {
  const UnavailableHealthCareRepository();

  Never _unavailable() => throw StateError('Saúde e cuidado estão indisponíveis.');

  @override
  HealthCareActor? get defaultActor => null;

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) async => _unavailable();
  @override
  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor}) async =>
      _unavailable();
  @override
  Future<HealthMedication> createMedication({
    required String childId,
    required String name,
    required String dose,
    required String doseUnit,
    required String route,
    required DateTime startsAt,
    required DateTime endsAt,
    required List<HealthMedicationSchedule> schedules,
    String? documentName,
    String? documentType,
    required HealthCareActor actor,
  }) async => _unavailable();
  @override
  Future<HealthMedicationChangeResult> changeMedicationRelevant({
    required String childId,
    required String medicationId,
    required String name,
    required String justification,
    required HealthCareActor actor,
  }) async => _unavailable();
  @override
  Future<HealthCareAllergy> createAllergy({
    required String childId,
    required String label,
    required HealthCareAllergyType type,
    required HealthCareActor actor,
  }) async => _unavailable();
  @override
  Future<HealthCareAcknowledgement> deactivateAllergy({
    required String childId,
    required String allergyId,
    required String justification,
    required HealthCareActor actor,
  }) async => _unavailable();
  @override
  Future<HealthCareAcknowledgement> updateCareProfile({
    required String childId,
    required List<HealthCareProfileItem> items,
    required String justification,
    required HealthCareActor actor,
  }) async => _unavailable();
}
