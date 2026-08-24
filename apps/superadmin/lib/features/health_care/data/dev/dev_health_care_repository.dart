import '../../domain/health_care.dart';
import '../../domain/health_care_repository.dart';

final class DevHealthCareRepository implements HealthCareRepository {
  DevHealthCareRepository({required HealthCareActor actor, List<HealthCareChild> children = const []})
      : _actor = actor,
        _seed = List.unmodifiable(children),
        _children = List.of(children);

  final HealthCareActor _actor;
  final List<HealthCareChild> _seed;
  List<HealthCareChild> _children;

  @override
  HealthCareActor get defaultActor => _actor;
  void resetSession() => _children = List.of(_seed);

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(HealthCareDirectoryQuery query, {required HealthCareActor actor}) async {
    final visible = _children.where(actor.canReadDetail).where(query.matches).toList();
    final start = query.offset;
    final page = start >= visible.length ? const <HealthCareChild>[] : visible.skip(start).take(query.pageSize).toList();
    return HealthCareDirectoryPage(items: page.map((child) => HealthCareChildSummary.fromChild(child, profile: actor.profile)).toList(), totalCount: visible.length, page: query.page, pageSize: query.pageSize);
  }

  @override
  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor}) async {
    final child = _children.where((item) => item.id == childId).firstOrNull;
    return child != null && actor.canReadDetail(child) ? child : null;
  }

  @override
  Future<HealthMedication> createMedication({required String childId, required String name, required String dose, required String doseUnit, required String route, required DateTime startsAt, required DateTime endsAt, required List<HealthMedicationSchedule> schedules, String? documentName, String? documentType, required HealthCareActor actor}) async {
    _requireEdit(actor, childId);
    final medicationId = 'medication-${DateTime.now().microsecondsSinceEpoch}';
    final medication = HealthMedication(id: medicationId, childId: childId, versions: [HealthMedicationVersion(id: 'version-1', medicationId: medicationId, version: 1, name: name, dose: dose, doseUnit: doseUnit, route: route, startsAt: startsAt, endsAt: endsAt, status: HealthMedicationReviewStatus.active, schedules: schedules, documentName: documentName, documentType: documentType)]);
    final child = (await findChild(childId, actor: actor))!;
    _replace(child.copyWith(medications: [...child.medications, medication]));
    return medication;
  }

  @override
  Future<HealthMedicationChangeResult> changeMedicationRelevant({required String childId, required String medicationId, required String name, required String justification, required HealthCareActor actor}) async => throw UnsupportedError('Use the medication plan dev repository.');
  @override
  Future<HealthCareAllergy> createAllergy({required String childId, required String label, required HealthCareAllergyType type, required HealthCareActor actor}) async => throw UnsupportedError('Allergy preview is not part of this fixture.');
  @override
  Future<HealthCareAcknowledgement> deactivateAllergy({required String childId, required String allergyId, required String justification, required HealthCareActor actor}) async => throw UnsupportedError('Allergy preview is not part of this fixture.');

  @override
  Future<HealthCareAcknowledgement> updateCareProfile({required String childId, required List<HealthCareProfileItem> items, required String justification, required HealthCareActor actor}) async {
    _requireEdit(actor, childId);
    final child = (await findChild(childId, actor: actor))!;
    _replace(child.copyWith(careProfile: items));
    return HealthCareAcknowledgement(id: 'ack-${DateTime.now().microsecondsSinceEpoch}', childId: childId, subject: HealthCareAcknowledgementSubject.careProfile, createdAt: DateTime.now());
  }

  void _requireEdit(HealthCareActor actor, String childId) {
    final child = _children.where((item) => item.id == childId).firstOrNull;
    if (child == null) throw StateError('Criança não encontrada.');
    if (!actor.can(HealthCareCapability.recordCreateEdit) || !actor.canReadDetail(child)) throw StateError('Acesso não autorizado.');
  }
  void _replace(HealthCareChild value) {
    _children = [for (final child in _children) child.id == value.id ? value : child];
  }
}

extension on Iterable<HealthCareChild> {
  HealthCareChild? get firstOrNull => isEmpty ? null : first;
}
