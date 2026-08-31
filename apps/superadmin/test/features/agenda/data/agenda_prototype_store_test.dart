import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 3, 9);
  test('taxonomia e alcance são independentes da prioridade', () {
    expect(AgendaItemType.values, hasLength(9));
    expect(AgendaItemType.values.map((e) => e.label), [
      'Evento',
      'Rotina recorrente',
      'Aniversário',
      'Feriado ou recesso',
      'Compromisso/agendamento',
      'Prazo/pendência',
      'Alteração operacional',
      'Reserva de espaço/recurso',
      'Outros',
    ]);
    const audience = AgendaAudience(institutionId: 'inst-horizonte', groupIds: {'group-girassol'});
    final item = AgendaItem.fixture(
      id: 'a',
      title: 'A',
      audience: audience,
      startsAt: now,
      endsAt: now.add(const Duration(hours: 1)),
    );
    expect(item.prominence, AgendaVisualProminence.group);
    expect(item.copyWith(priority: AgendaPriority.urgent).prominence, item.prominence);
  });
  test('isola instituições, audiência e ordena recorrência com exceção', () {
    final store = AgendaPrototypeStore.seeded(clock: () => now);
    expect(
      store.itemsForInstitution('inst-horizonte'),
      everyElement(predicate<AgendaItem>((e) => e.audience.institutionId == 'inst-horizonte')),
    );
    expect(
      store.itemsForContext('group-girassol'),
      everyElement(predicate<AgendaItem>((e) => e.audience.institutionId == 'inst-horizonte')),
    );
    final occurrences = store.occurrencesBetween(DateTime(2026, 8, 3), DateTime(2026, 8, 19));
    final ballet = occurrences.where((e) => e.item.id == 'routine-ballet').toList();
    expect(ballet.map((e) => e.startsAt), [DateTime(2026, 8, 4, 17), DateTime(2026, 8, 18, 17)]);
    expect(ballet.first.duration, const Duration(hours: 1));
    expect(
      occurrences,
      orderedEquals(
        List<AgendaOccurrence>.of(occurrences)..sort(AgendaOccurrence.compareChronologically),
      ),
    );
  });
  test('descendente restringe mas não amplia bloqueio ancestral', () {
    final store = AgendaPrototypeStore.seeded(clock: () => now);
    const cap = AgendaCapability.approveGuardianBirthdayRequest;
    expect(store.resolveCapability('unit-cambui', cap).state, PermissionState.inherited);
    expect(store.setCapabilityRestricted('unit-cambui', cap, true), isTrue);
    expect(store.resolveCapability('group-girassol', cap).state, PermissionState.blockedByAncestor);
    expect(store.setCapabilityRestricted('group-girassol', cap, false), isFalse);
  });
  test('primeira decisão vence, aprovação cria rascunho e reprovação exige motivo', () {
    final store = AgendaPrototypeStore.seeded(clock: () => now);
    final count = store.items.length;
    expect(
      store.decideRequest(
        requestId: 'request-pending',
        actorContextId: 'inst-horizonte',
        actorName: 'Helena',
        approve: false,
      ),
      RequestDecisionResult.reasonRequired,
    );
    expect(
      store.decideRequest(
        requestId: 'request-pending',
        actorContextId: 'inst-horizonte',
        actorName: 'Helena',
        approve: true,
      ),
      RequestDecisionResult.approvedAndConvertedToDraft,
    );
    expect(store.items, hasLength(count + 1));
    expect(store.items.last.status, AgendaItemStatus.draft);
    expect(store.items.last.origin, AgendaItemOrigin.guardianRequest);
    expect(
      store.decideRequest(
        requestId: 'request-pending',
        actorContextId: 'unit-cambui',
        actorName: 'Outra',
        approve: false,
        reason: 'Não',
      ),
      RequestDecisionResult.alreadyDecided,
    );
  });

  test('lifecycle cancela, restaura e só exclui rascunho com histórico', () {
    final store = AgendaPrototypeStore.seeded(clock: () => now);

    expect(store.cancelItem('event-parents', actorName: 'Helena'), AgendaMutationResult.success);
    expect(store.itemById('event-parents')!.status, AgendaItemStatus.canceled);
    expect(store.itemById('event-parents')!.history.last.action, AgendaHistoryAction.canceled);

    expect(store.restoreItem('event-parents', actorName: 'Helena'), AgendaMutationResult.success);
    expect(store.itemById('event-parents')!.status, AgendaItemStatus.published);
    expect(store.itemById('event-parents')!.history.last.action, AgendaHistoryAction.restored);

    final scheduled = AgendaItem.fixture(
      id: 'scheduled-restore',
      title: 'Agendado',
      audience: const AgendaAudience(institutionId: 'inst-horizonte'),
      startsAt: now,
      endsAt: now.add(const Duration(hours: 1)),
      status: AgendaItemStatus.scheduled,
    );
    store.upsertItem(scheduled);
    store.cancelItem(scheduled.id, actorName: 'Helena');
    store.restoreItem(scheduled.id, actorName: 'Helena');
    expect(store.itemById(scheduled.id)!.status, AgendaItemStatus.scheduled);

    expect(store.deleteDraft('event-parents'), AgendaMutationResult.invalidLifecycle);
    expect(store.deleteDraft('request-draft-missing'), AgendaMutationResult.notFound);

    final draft = AgendaItem.fixture(
      id: 'draft-delete',
      title: 'Rascunho',
      audience: const AgendaAudience(institutionId: 'inst-horizonte'),
      startsAt: now,
      endsAt: now.add(const Duration(hours: 1)),
      status: AgendaItemStatus.draft,
    );
    store.upsertItem(draft);
    expect(store.deleteDraft(draft.id), AgendaMutationResult.success);
    expect(store.itemById(draft.id), isNull);
  });

  test('recorrência suporta diária, semanal e mensal com fim por data ou quantidade', () {
    final daily = AgendaRecurrence.daily(occurrenceCount: 3);
    final weekly = AgendaRecurrence.weekly(until: DateTime(2026, 9, 1), interval: 2);
    final monthly = AgendaRecurrence.monthly(occurrenceCount: 2);

    expect(daily.frequency, AgendaRecurrenceFrequency.daily);
    expect(daily.occurrenceCount, 3);
    expect(weekly.frequency, AgendaRecurrenceFrequency.weekly);
    expect(weekly.until, DateTime(2026, 9, 1));
    expect(monthly.frequency, AgendaRecurrenceFrequency.monthly);

    final store = AgendaPrototypeStore.seeded(clock: () => now);
    for (final entry in <(String, AgendaRecurrence)>[
      ('daily', daily),
      ('weekly-count', AgendaRecurrence.weekly(occurrenceCount: 2)),
      ('monthly', monthly),
    ]) {
      store.upsertItem(
        AgendaItem.fixture(
          id: entry.$1,
          title: entry.$1,
          audience: const AgendaAudience(institutionId: 'inst-horizonte'),
          startsAt: DateTime(2026, 8, 1, 9),
          endsAt: DateTime(2026, 8, 1, 10),
          recurrence: entry.$2,
        ),
      );
    }
    final occurrences = store.occurrencesBetween(DateTime(2026, 8, 1), DateTime(2026, 11, 2));
    expect(occurrences.where((e) => e.item.id == 'daily'), hasLength(3));
    expect(occurrences.where((e) => e.item.id == 'weekly-count'), hasLength(2));
    expect(occurrences.where((e) => e.item.id == 'monthly').map((e) => e.startsAt), [
      DateTime(2026, 8, 1, 9),
      DateTime(2026, 9, 1, 9),
    ]);
  });

  test('edição recorrente registra escopo ocorrência, futuras ou série', () {
    final store = AgendaPrototypeStore.seeded(clock: () => now);
    for (final scope in AgendaOccurrenceEditScope.values) {
      expect(
        store.recordOccurrenceEdit(
          itemId: 'routine-ballet',
          occurrenceStartsAt: DateTime(2026, 8, 18, 17),
          scope: scope,
          actorName: 'Helena',
        ),
        AgendaMutationResult.success,
      );
    }
    expect(
      store.itemById('routine-ballet')!.history.map((e) => e.occurrenceEditScope),
      AgendaOccurrenceEditScope.values,
    );
  });

  test('item preserva fuso IANA explícito e rejeita identificador não IANA', () {
    expect(isValidIanaTimeZoneId('America/Sao_Paulo'), isTrue);
    expect(isValidIanaTimeZoneId('UTC'), isTrue);
    expect(isValidIanaTimeZoneId('GMT-3'), isFalse);
    final item = AgendaItem.fixture(
      id: 'timezone',
      title: 'Com fuso',
      audience: const AgendaAudience(institutionId: 'inst-horizonte'),
      startsAt: now,
      endsAt: now.add(const Duration(hours: 1)),
      timeZoneId: 'America/Manaus',
    );
    expect(item.timeZoneId, 'America/Manaus');
  });

  test('modo de resposta e política de responsáveis são independentes', () {
    final item = AgendaItem.fixture(
      id: 'authorization',
      title: 'Autorização',
      audience: const AgendaAudience(institutionId: 'inst-horizonte'),
      startsAt: now,
      endsAt: now.add(const Duration(hours: 1)),
      responseMode: AgendaResponseMode.authorization,
    );
    expect(item.responseMode, AgendaResponseMode.authorization);
    expect(item.guardianResponsePolicy, GuardianResponsePolicy.oneIsEnough);
    expect(
      item
          .copyWith(guardianResponsePolicy: GuardianResponsePolicy.allMustRespond)
          .guardianResponsePolicy,
      GuardianResponsePolicy.allMustRespond,
    );
  });

  test('conflito de reserva exige capability, motivo e deixa histórico', () {
    final store = AgendaPrototypeStore.seeded(clock: () => now);
    final conflicting = AgendaItem.fixture(
      id: 'reserve-conflict',
      title: 'Outra reserva',
      type: AgendaItemType.resourceReservation,
      audience: const AgendaAudience(institutionId: 'inst-horizonte'),
      startsAt: DateTime(2026, 8, 5, 11),
      endsAt: DateTime(2026, 8, 5, 12),
      location: 'Auditório',
    );

    expect(
      store.saveItem(conflicting, actorContextId: 'unit-cambui'),
      AgendaMutationResult.reservationConflict,
    );
    expect(
      store.saveItem(conflicting, actorContextId: 'unknown-context', overrideConflict: true),
      AgendaMutationResult.notAuthorized,
    );
    expect(
      store.saveItem(conflicting, actorContextId: 'inst-horizonte', overrideConflict: true),
      AgendaMutationResult.reasonRequired,
    );
    expect(
      store.saveItem(
        conflicting,
        actorContextId: 'inst-horizonte',
        actorName: 'Helena',
        overrideConflict: true,
        reason: 'Prioridade institucional',
      ),
      AgendaMutationResult.success,
    );
    final saved = store.itemById(conflicting.id)!;
    expect(saved.history.last.action, AgendaHistoryAction.reservationConflictOverridden);
    expect(saved.history.last.reason, 'Prioridade institucional');
  });

  test('fixture de aniversário expõe somente primeiro nome e contexto autorizado', () {
    final store = AgendaPrototypeStore.seeded(clock: () => now);
    final birthdays = store.birthdaysForContext('unit-cambui');
    expect(birthdays, isNotEmpty);
    expect(birthdays.first.firstName, 'Lia');
    expect(birthdays.first.contextId, 'group-girassol');
    expect(birthdays.first.month, 8);
    expect(birthdays.first.day, 5);
    expect(birthdays.first.authorizedPhotoUrl, isNull);
    expect(birthdays.first.toString(), isNot(contains('2020')));
    expect(store.birthdaysForContext('inst-aurora'), isEmpty);
  });
}
