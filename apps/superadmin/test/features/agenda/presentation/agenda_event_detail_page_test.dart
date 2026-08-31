import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_events_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AgendaPrototypeStore store() =>
      AgendaPrototypeStore.seeded(clock: () => DateTime(2026, 8, 31, 14, 30));

  Widget app(Widget child) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(body: child),
  );

  testWidgets('detalhe torna contrato operacional e histórico auditável', (tester) async {
    final prototype = store();
    prototype.upsertItem(
      AgendaItem.fixture(
        id: 'event-contract',
        title: 'Autorização para passeio',
        type: AgendaItemType.event,
        audience: const AgendaAudience(
          institutionId: 'inst-horizonte',
          unitIds: {'unit-cambui'},
          groupIds: {'group-girassol'},
        ),
        startsAt: DateTime(2026, 9, 7, 8),
        endsAt: DateTime(2026, 9, 7, 12),
        location: 'Museu Municipal',
        description: 'Saída pedagógica com autorização dos responsáveis.',
        recurrence: AgendaRecurrence.weekly(
          occurrenceCount: 4,
          exceptions: {DateTime(2026, 9, 21)},
        ),
        timeZoneId: 'America/Sao_Paulo',
        responseMode: AgendaResponseMode.authorization,
        guardianResponsePolicy: GuardianResponsePolicy.allMustRespond,
        history: [
          AgendaHistoryEntry(
            action: AgendaHistoryAction.occurrenceEdited,
            actorName: 'Helena Owner',
            occurredAt: DateTime(2026, 8, 30, 10),
            occurrenceStartsAt: DateTime(2026, 9, 14, 8),
            occurrenceEditScope: AgendaOccurrenceEditScope.occurrence,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      app(
        AgendaEventDetailPage(
          store: prototype,
          eventId: 'event-contract',
          onBack: () {},
          onEdit: () {},
        ),
      ),
    );

    expect(find.text('Contexto e audiência'), findsOneWidget);
    expect(find.textContaining('Unidade Cambuí'), findsWidgets);
    expect(find.textContaining('Turma Girassol'), findsWidgets);
    expect(find.text('America/Sao_Paulo'), findsOneWidget);
    expect(find.textContaining('Semanal'), findsOneWidget);
    expect(find.textContaining('4 ocorrências'), findsOneWidget);
    expect(find.text('Autorização'), findsOneWidget);
    expect(find.text('Todos os responsáveis devem responder'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Histórico'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.textContaining('Helena Owner'), findsOneWidget);
    expect(find.textContaining('Somente esta ocorrência'), findsOneWidget);
  });

  testWidgets('cancelar e restaurar exigem confirmação e registram histórico', (tester) async {
    final prototype = store();
    await tester.pumpWidget(
      app(
        AgendaEventDetailPage(
          store: prototype,
          eventId: 'event-parents',
          onBack: () {},
          onEdit: () {},
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('agenda-event-cancel')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('agenda-event-cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar evento?'), findsOneWidget);
    expect(prototype.itemById('event-parents')!.status, AgendaItemStatus.published);

    await tester.tap(find.byKey(const Key('agenda-event-confirm-lifecycle')));
    await tester.pumpAndSettle();
    expect(prototype.itemById('event-parents')!.status, AgendaItemStatus.canceled);
    expect(prototype.itemById('event-parents')!.history.last.actorName, 'Owner Coelo');
    await tester.scrollUntilVisible(
      find.textContaining('Cancelado por Owner Coelo'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Cancelado por Owner Coelo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('agenda-event-restore')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('agenda-event-restore')));
    await tester.pumpAndSettle();
    expect(find.text('Restaurar evento?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('agenda-event-confirm-lifecycle')));
    await tester.pumpAndSettle();
    expect(prototype.itemById('event-parents')!.status, AgendaItemStatus.published);
    await tester.scrollUntilVisible(
      find.textContaining('Restaurado por Owner Coelo'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Restaurado por Owner Coelo'), findsOneWidget);
  });

  testWidgets('somente rascunho pode ser excluído e ausência fica explícita', (tester) async {
    final prototype = store();
    prototype.upsertItem(
      AgendaItem.fixture(
        id: 'draft-event',
        title: 'Rascunho de reunião',
        audience: const AgendaAudience(institutionId: 'inst-horizonte'),
        startsAt: DateTime(2026, 9, 2, 18),
        endsAt: DateTime(2026, 9, 2, 19),
        status: AgendaItemStatus.draft,
      ),
    );
    await tester.pumpWidget(
      app(
        AgendaEventDetailPage(
          store: prototype,
          eventId: 'draft-event',
          onBack: () {},
          onEdit: () {},
        ),
      ),
    );

    expect(find.byKey(const Key('agenda-event-cancel')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('agenda-event-delete-draft')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('agenda-event-delete-draft')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir rascunho?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('agenda-event-confirm-lifecycle')));
    await tester.pumpAndSettle();

    expect(prototype.itemById('draft-event'), isNull);
    expect(find.text('Item não encontrado'), findsOneWidget);
  });

  testWidgets('not-found e indisponível são estados distintos e fail-closed', (tester) async {
    final prototype = store();
    await tester.pumpWidget(
      app(
        AgendaEventDetailPage(store: prototype, eventId: 'missing', onBack: () {}, onEdit: () {}),
      ),
    );
    expect(find.text('Item não encontrado'), findsOneWidget);

    await tester.pumpWidget(
      app(
        AgendaEventDetailPage(
          store: prototype,
          eventId: 'event-parents',
          unavailable: true,
          onBack: () {},
          onEdit: () {},
        ),
      ),
    );
    expect(find.text('Agenda indisponível'), findsOneWidget);
    expect(find.byKey(const Key('agenda-event-detail')), findsOneWidget);
    expect(find.text('Descrição'), findsOneWidget);
    expect(find.text('Contexto e audiência'), findsOneWidget);
    expect(find.text('Agenda e respostas'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('agenda-event-edit-unavailable')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('agenda-event-detail')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('agenda-event-edit-unavailable')))
          .onPressed,
      isNull,
    );
    expect(find.text('Reunião de responsáveis'), findsNothing);
  });

  testWidgets('diretório oferece lifecycle contextual com confirmação', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final prototype = store();
    prototype.upsertItem(
      AgendaItem.fixture(
        id: 'directory-lifecycle',
        title: 'Evento operacional',
        audience: const AgendaAudience(institutionId: 'inst-horizonte'),
        startsAt: DateTime(2026, 8, 1, 8),
        endsAt: DateTime(2026, 8, 1, 9),
      ),
    );
    await tester.pumpWidget(
      app(AgendaEventsPage(store: prototype, onCreate: () {}, onOpen: (_) {}, onEdit: (_) {})),
    );

    await tester.tap(find.byKey(const Key('agenda-event-actions-directory-lifecycle')));
    await tester.pumpAndSettle();
    tester
        .widget<MenuItemButton>(
          find.ancestor(of: find.text('Cancelar evento'), matching: find.byType(MenuItemButton)),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Cancelar evento?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('agenda-event-confirm-lifecycle')));
    await tester.pumpAndSettle();

    expect(prototype.itemById('directory-lifecycle')!.status, AgendaItemStatus.canceled);
  });
}
