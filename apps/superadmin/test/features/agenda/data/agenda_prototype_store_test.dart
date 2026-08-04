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
}
