import 'package:flutter/material.dart';

import '../domain/health_care.dart';
import '../domain/health_care_repository.dart';
import '../domain/medication_plan_edit_snapshot.dart';
import '../domain/medication_plan_repository.dart';
import '../presentation/health_medication_plan_form_page.dart';
import 'supabase_health_care_repository.dart';

/// Adapta o repositório de planos de medicação de produção à interface que o
/// diretório de Medicação consome. Somente leitura: a escrita de plano passa
/// por [MedicationPlanRepository.save], com versão esperada e recibo no
/// servidor. O [HealthCareActor] recebido aqui só orienta o desenho; toda
/// autorização é refeita nas RPCs.
final class SupabaseMedicationPlanHealthCareRepository implements HealthCareRepository {
  SupabaseMedicationPlanHealthCareRepository(this.medicationPlans);

  final MedicationPlanRepository medicationPlans;
  final _childrenById = <String, HealthCareChild>{};
  final _childLabelByPlanId = <String, String>{};

  @override
  HealthCareActor? get defaultActor => null;

  /// Nome da criança do plano, conhecido depois de o diretório ter sido lido.
  String? childLabelFor(String planId) => _childLabelByPlanId[planId];

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) async {
    final page = await medicationPlans.fetchPage(
      MedicationPlanQuery(page: query.page, pageSize: query.pageSize),
    );
    final details = await Future.wait([
      for (final summary in page.items) medicationPlans.fetchDetail(summary.id),
    ]);
    _childrenById.clear();
    final medicationsByChild = <String, List<HealthMedication>>{};
    final labels = <String, String>{};
    for (final (index, summary) in page.items.indexed) {
      final childId = summary.childContextId ?? summary.childPersonId;
      labels[childId] = summary.childDisplayName;
      _childLabelByPlanId[summary.id] = summary.childDisplayName;
      medicationsByChild.putIfAbsent(childId, () => []).add(_medication(childId, details[index]));
    }
    for (final entry in medicationsByChild.entries) {
      _childrenById[entry.key] = HealthCareChild(
        id: entry.key,
        personId: entry.key,
        displayName: labels[entry.key] ?? '',
        operationalStatus: HealthCareOperationalStatus.active,
        medications: entry.value,
      );
    }
    return HealthCareDirectoryPage(
      items: [
        for (final child in _childrenById.values)
          HealthCareChildSummary.fromChild(child, profile: actor.profile),
      ],
      totalCount: page.total,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<HealthCareChild?> findChild(String childId, {required HealthCareActor actor}) async =>
      _childrenById[childId];

  HealthMedication _medication(String childId, MedicationPlanDetail detail) => HealthMedication(
    id: detail.id,
    childId: childId,
    versions: [
      HealthMedicationVersion(
        id: '${detail.id}-version-${detail.currentVersion}',
        medicationId: detail.id,
        version: detail.currentVersion,
        name: detail.medicationName,
        dose: detail.doseAmount.toString(),
        doseUnit: detail.doseUnit,
        route: detail.administrationRoute,
        startsAt: detail.validFrom,
        endsAt: detail.validUntil ?? DateTime.utc(9999, 12, 31),
        status: switch (detail.status) {
          MedicationPlanStatus.draft => HealthMedicationReviewStatus.requested,
          MedicationPlanStatus.active => HealthMedicationReviewStatus.active,
          MedicationPlanStatus.suspended => HealthMedicationReviewStatus.invalidated,
          MedicationPlanStatus.ended => HealthMedicationReviewStatus.ended,
        },
        schedules: [
          for (final (index, schedule) in detail.schedules.indexed)
            HealthMedicationSchedule(
              id: '${detail.id}-schedule-$index',
              time: _time(schedule.timeOfDay),
              atHome: detail.scopeKind != 'institution',
              institutionId: detail.scopeKind == 'institution' ? detail.institutionId : null,
            ),
        ],
      ),
    ],
  );

  HealthCareTimeOfDay _time(String value) {
    final parts = value.split(':');
    return HealthCareTimeOfDay(int.parse(parts.first), int.parse(parts.last));
  }

  Never _readOnly() => throw UnsupportedError(
    'Plano de medicação é escrito por MedicationPlanRepository.save, não por este adaptador.',
  );

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
  }) async => _readOnly();

  @override
  Future<HealthMedicationChangeResult> changeMedicationRelevant({
    required String childId,
    required String medicationId,
    required String name,
    required String justification,
    required HealthCareActor actor,
  }) async => _readOnly();

  @override
  Future<HealthCareAllergy> createAllergy({
    required String childId,
    required String label,
    required HealthCareAllergyType type,
    required HealthCareActor actor,
  }) async => _readOnly();

  @override
  Future<HealthCareAcknowledgement> deactivateAllergy({
    required String childId,
    required String allergyId,
    required String justification,
    required HealthCareActor actor,
  }) async => _readOnly();

  @override
  Future<HealthCareAcknowledgement> updateCareProfile({
    required String childId,
    required List<HealthCareProfileItem> items,
    required String justification,
    required HealthCareActor actor,
  }) async => _readOnly();
}

/// Rascunho do formulário a partir do detalhe de produção. A criança é
/// identificada pelo contexto infantil, o mesmo id que as opções de criança do
/// formulário usam na criação.
HealthMedicationPlanFormDraft medicationPlanFormDraft(MedicationPlanDetail detail) {
  final schedule = detail.schedules.firstOrNull;
  final timeParts = schedule?.timeOfDay.split(':');
  return HealthMedicationPlanFormDraft(
    planId: detail.id,
    expectedVersion: detail.currentVersion,
    childId: detail.childContextId ?? detail.childPersonId,
    medicationName: detail.medicationName,
    doseAmount: detail.doseAmount,
    doseUnit: detail.doseUnit,
    administrationRoute: detail.administrationRoute,
    validFrom: detail.validFrom,
    validUntil: detail.validUntil,
    time: timeParts == null
        ? null
        : TimeOfDay(hour: int.parse(timeParts.first), minute: int.parse(timeParts.last)),
    weekdays: schedule?.weekdays ?? const {},
    responsibleIds: const {},
    editSnapshot: MedicationPlanEditSnapshot(
      planId: detail.id,
      childPersonId: detail.childPersonId,
      timezone: detail.timezone,
      schedules: detail.schedules,
      instructions: detail.instructions,
      routeDetails: detail.routeDetails,
      scopeKind: detail.scopeKind,
      institutionId: detail.institutionId,
      unitId: detail.unitId,
      groupId: detail.groupId,
      childContextId: detail.childContextId,
    ),
  );
}

/// Salva o rascunho do formulário em produção. O `requestId` que o formulário
/// gera não é um UUID; cada um recebe um UUID próprio e estável, para uma
/// repetição da mesma tentativa reaproveitar o recibo do servidor em vez de
/// criar outro plano.
final class SupabaseMedicationPlanDraftSaver {
  SupabaseMedicationPlanDraftSaver(this.medicationPlans);

  final MedicationPlanRepository medicationPlans;
  final _requestIds = <String, String>{};

  Future<HealthMedicationPlanSaveReceipt> call(HealthMedicationPlanFormDraft draft) async {
    final formRequestId = draft.requestId;
    final validFrom = draft.validFrom;
    if (formRequestId == null || formRequestId.isEmpty || validFrom == null) {
      throw const MedicationPlanInvalidInputException();
    }
    final snapshot = draft.editSnapshot;
    final editing = draft.planId != null;
    if (editing && (snapshot == null || snapshot.planId != draft.planId)) {
      throw const MedicationPlanInvalidInputException();
    }
    final time = draft.time;
    final timezone = snapshot?.timezone.isNotEmpty == true
        ? snapshot!.timezone
        : 'America/Sao_Paulo';
    final original = snapshot?.schedules.firstOrNull;
    final saved = await medicationPlans.save(
      MedicationPlanSaveCommand(
        requestId: _requestIds.putIfAbsent(formRequestId, newHealthCareRequestId),
        planId: draft.planId,
        // Na criação a criança vai pelo contexto infantil e a instituição é
        // derivada dele no servidor; o cliente nunca a escolhe.
        childPersonId: editing ? snapshot!.childPersonId : '',
        childContextId: editing ? snapshot!.childContextId : draft.childId,
        expectedVersion: draft.expectedVersion,
        medicationName: draft.medicationName,
        doseAmount: draft.doseAmount,
        doseUnit: draft.doseUnit,
        administrationRoute: draft.administrationRoute,
        validFrom: validFrom,
        validUntil: draft.validUntil,
        reason: editing ? 'Alteração do plano pelo Superadmin' : 'Plano registrado pelo Superadmin',
        scopeKind: snapshot?.scopeKind ?? 'institution',
        institutionId: snapshot?.institutionId,
        unitId: snapshot?.unitId,
        groupId: snapshot?.groupId,
        timezone: timezone,
        instructions: snapshot?.instructions,
        routeDetails: snapshot?.routeDetails,
        schedules: [
          MedicationScheduleDraft(
            timeOfDay: time == null
                ? '08:00'
                : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            weekdays: draft.weekdays.isEmpty ? const {1, 2, 3, 4, 5} : draft.weekdays,
            timezone: original?.timezone ?? timezone,
            frequencyKind: original?.frequencyKind ?? 'weekly',
            startDate: original?.startDate,
            endDate: original?.endDate,
            maxOccurrencesPerDay: original?.maxOccurrencesPerDay,
          ),
          if (snapshot != null) ...snapshot.schedules.skip(1),
        ],
      ),
    );
    return HealthMedicationPlanSaveReceipt(
      planId: saved.id,
      version: saved.currentVersion,
      editSnapshot: medicationPlanFormDraft(saved).editSnapshot,
    );
  }
}
