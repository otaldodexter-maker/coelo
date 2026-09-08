import 'dart:async';

import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_repository.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_event_form_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_reservation_conflict_dialog.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AgendaPrototypeStore store() =>
      AgendaPrototypeStore.seeded(clock: () => DateTime(2026, 8, 3, 12));

  testWidgets('reservation dialog preserves the local dark theme above root navigator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Theme(
          data: CoeloTheme.dark,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showAgendaReservationConflictOverrideDialog(context),
                child: const Text('Abrir conflito'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir conflito'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(
        tester.element(find.byKey(const Key('agenda-reservation-override-dialog'))),
      ).brightness,
      Brightness.dark,
    );
  });

  for (final stage in ['save', 'occurrence', 'publication']) {
    testWidgets('pending $stage stops after form context changes', (tester) async {
      final a = _PendingFormRepository(stage);
      final b = store();
      final saved = <String>[];
      await tester.pumpWidget(
        _app(store: a, eventId: 'routine-ballet', canPublish: false, onSaved: saved.add),
      );
      await _goToReview(tester);
      final publish = tester
          .widget<FilledButton>(find.byKey(const Key('agenda-wizard-publish')))
          .onPressed!;
      publish();
      publish();
      await tester.pump();
      await tester.pump();
      expect(a.saves, 1);
      expect(a.occurrences, stage == 'save' ? 0 : 1);
      expect(a.publications, stage == 'publication' ? 1 : 0);
      final occurrenceCalls = a.occurrences;
      final publicationCalls = a.publications;
      await tester.pumpWidget(_app(store: b, eventId: 'event-parents', onSaved: saved.add));
      a.pending.complete(AgendaMutationResult.success);
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(a.occurrences, occurrenceCalls);
      expect(a.publications, publicationCalls);
      expect(b.publicationRequests, isEmpty);
      expect(find.text(b.itemById('event-parents')!.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('conflict dialog closes on context change without completing old save', (
    tester,
  ) async {
    final a = _PendingFormRepository('save');
    final b = store();
    final saved = <String>[];
    await tester.pumpWidget(_app(store: a, eventId: 'event-parents', onSaved: saved.add));
    await _goToReview(tester);
    await tester.tap(find.byKey(const Key('agenda-wizard-save-draft')));
    a.pending.complete(AgendaMutationResult.reservationConflict);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-reservation-override-dialog')), findsOneWidget);
    final navigator = Navigator.of(
      tester.element(find.byKey(const Key('agenda-reservation-override-dialog'))),
      rootNavigator: true,
    );
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Rota sentinela'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(store: b, eventId: 'routine-ballet', onSaved: saved.add));
    await tester.pumpAndSettle();
    expect(find.text('Rota sentinela'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-reservation-override-dialog')), findsNothing);
    expect(a.saves, 1);
    expect(saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same form reloads fields when event ID changes', (tester) async {
    final prototype = store();
    await tester.pumpWidget(_app(store: prototype, eventId: 'event-parents'));
    final a = prototype.itemById('event-parents')!;
    final b = prototype.itemById('routine-ballet')!;
    expect(find.text(a.title), findsOneWidget);
    await tester.pumpWidget(_app(store: prototype, eventId: b.id));
    await tester.pump();
    expect(find.text(b.title), findsOneWidget);
    expect(find.text(a.title), findsNothing);
  });

  testWidgets('repository swap resets draft edits and wizard step', (tester) async {
    final a = store();
    final b = store();
    b.upsertItem(b.itemById('event-parents')!.copyWith(title: 'Evento B'));
    await tester.pumpWidget(_app(store: a, eventId: 'event-parents'));
    await tester.enterText(find.byType(CoeloFormTextField).first, 'Edição sensível A');
    await _continue(tester);
    await tester.pumpWidget(_app(store: b, eventId: 'event-parents'));
    await tester.pump();
    expect(find.text('Evento B'), findsOneWidget);
    expect(find.text('Edição sensível A'), findsNothing);
    expect(find.byKey(const Key('agenda-event-type')), findsOneWidget);
  });

  testWidgets('dados básicos expõem nove tipos, contexto principal e audiência refinada', (
    tester,
  ) async {
    await tester.pumpWidget(_app(store: store()));

    final type = tester.widget<CoeloAdminSingleSelectField<AgendaItemType>>(
      find.byKey(const Key('agenda-event-type')),
    );
    expect(type.options, AgendaItemType.values);
    expect(type.options, hasLength(9));

    final context = tester.widget<CoeloAdminSingleSelectField<String>>(
      find.byKey(const Key('agenda-event-context')),
    );
    expect(context.options, const ['Instituição', 'Unidade', 'Turma', 'Atividade', 'Pessoa']);

    final audience = tester.widget<CoeloAdminMultiSelectField<String>>(
      find.byKey(const Key('agenda-event-audience')),
    );
    expect(
      audience.options,
      containsAll(['Responsáveis', 'Equipe', 'Perfis específicos', 'Pessoas']),
    );
    expect(find.text('Título'), findsOneWidget);
  });

  testWidgets('período alterna data e hora por dia inteiro e configura fuso e recorrência', (
    tester,
  ) async {
    await tester.pumpWidget(_app(store: store()));
    await _continue(tester);

    expect(find.byType(CoeloDateTimeField), findsNWidgets(2));
    final timeZone = tester.widget<CoeloAdminSingleSelectField<String>>(
      find.byKey(const Key('agenda-event-timezone')),
    );
    expect(timeZone.value, 'America/Sao_Paulo');
    expect(timeZone.options, containsAll(['America/Sao_Paulo', 'America/Manaus', 'UTC']));

    final allDay = tester.widget<CoeloAdminToggleField>(
      find.byKey(const Key('agenda-event-all-day')),
    );
    allDay.onChanged!(true);
    await tester.pump();
    expect(find.byType(CoeloDateTimeField), findsNothing);
    expect(find.byType(CoeloDateRangeField), findsOneWidget);
    expect(find.byKey(const Key('agenda-event-location-map')), findsOneWidget);

    final recurrence = tester.widget<CoeloAdminSingleSelectField<String>>(
      find.byKey(const Key('agenda-event-recurrence')),
    );
    expect(recurrence.options, const ['Não se repete', 'Diária', 'Semanal', 'Mensal']);
    recurrence.onChanged('Semanal');
    await tester.pump();
    expect(find.byKey(const Key('agenda-event-recurrence-end')), findsOneWidget);
    expect(find.text('Editar uma ocorrência, esta e próximas ou toda a série'), findsOneWidget);
  });

  testWidgets('dados básicos permitem adicionar pergunta contextual ao evento', (tester) async {
    final prototype = store();
    final saved = <String>[];
    await tester.pumpWidget(_app(store: prototype, onSaved: saved.add));

    expect(find.textContaining('Não solicite dados sensíveis'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('agenda-event-add-question')));
    await tester.tap(find.byKey(const Key('agenda-event-add-question')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('agenda-event-question-0')),
      'A criança participará do passeio?',
    );
    tester
        .widget<CoeloAdminSingleSelectField<AgendaQuestionType>>(
          find.byKey(const Key('agenda-event-question-type-0')),
        )
        .onChanged(AgendaQuestionType.yesNo);
    await tester.pump();
    await _goToReview(tester);
    await tester.tap(find.byKey(const Key('agenda-wizard-save-draft')));
    await tester.pump();

    expect(saved, hasLength(1));
    final question = prototype.itemById(saved.single)!.questions.single;
    expect(question.title, 'A criança participará do passeio?');
    expect(question.type, AgendaQuestionType.yesNo);
  });

  testWidgets('pergunta vazia bloqueia salvamento e remoção não reutiliza identificador', (
    tester,
  ) async {
    final prototype = store();
    final saved = <String>[];
    await tester.pumpWidget(_app(store: prototype, onSaved: saved.add));

    await tester.ensureVisible(find.byKey(const Key('agenda-event-add-question')));
    await tester.tap(find.byKey(const Key('agenda-event-add-question')));
    await tester.pump();
    await _goToReview(tester);
    await tester.tap(find.byKey(const Key('agenda-wizard-save-draft')));
    await tester.pump();

    expect(
      find.text('Preencha o título de todas as perguntas ou remova as perguntas vazias.'),
      findsOneWidget,
    );
    expect(saved, isEmpty);

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const Key('agenda-wizard-previous')));
      await tester.pump();
    }
    await tester.ensureVisible(find.byTooltip('Remover pergunta 1'));
    await tester.tap(find.byTooltip('Remover pergunta 1'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('agenda-event-add-question')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('agenda-event-question-0')),
      'A família precisa de apoio de acessibilidade?',
    );
    await _goToReview(tester);
    await tester.tap(find.byKey(const Key('agenda-wizard-save-draft')));
    await tester.pump();

    expect(saved, hasLength(1));
    expect(prototype.itemById(saved.single)!.questions.single.id, 'question-2');
  });

  testWidgets('respostas, política de responsáveis e lembretes seguem o contrato', (tester) async {
    await tester.pumpWidget(_app(store: store()));
    await _continue(tester);
    await _continue(tester);

    final response = tester.widget<CoeloAdminSingleSelectField<AgendaResponseMode>>(
      find.byKey(const Key('agenda-event-response-mode')),
    );
    expect(response.options, AgendaResponseMode.values);
    response.onChanged(AgendaResponseMode.authorization);
    await tester.pump();

    final policy = tester.widget<CoeloAdminSingleSelectField<GuardianResponsePolicy>>(
      find.byKey(const Key('agenda-event-guardian-policy')),
    );
    expect(policy.value, GuardianResponsePolicy.oneIsEnough);

    final reminders = tester.widget<CoeloAdminMultiSelectField<String>>(
      find.byKey(const Key('agenda-event-reminders')),
    );
    expect(reminders.options, const [
      'Na publicação',
      '24 horas antes',
      '1 hora antes',
      'Personalizado',
    ]);
    expect(find.textContaining('sem canais'), findsNothing);
    expect(find.textContaining('canais serão configurados pela plataforma'), findsOneWidget);
  });

  testWidgets('sem capability salva rascunho e solicita publicação', (tester) async {
    final prototype = store();
    final saved = <String>[];
    await tester.pumpWidget(_app(store: prototype, canPublish: false, onSaved: saved.add));
    await _goToReview(tester);

    expect(find.text('Solicitar publicação'), findsOneWidget);
    await tester.tap(find.byKey(const Key('agenda-wizard-publish')));
    await tester.pump();

    expect(saved, hasLength(1));
    expect(prototype.itemById(saved.single)!.status, AgendaItemStatus.draft);
    expect(prototype.publicationRequests, hasLength(1));
    expect(prototype.publicationRequests.single.itemId, saved.single);
    expect(prototype.publicationRequests.single.status, AgendaPublicationRequestStatus.pending);
  });

  testWidgets('produção sem integração mantém composição e ações fail-closed', (tester) async {
    final prototype = AgendaPrototypeStore.empty();
    final initialCount = prototype.items.length;
    final saved = <String>[];
    await tester.pumpWidget(_app(store: prototype, actionsAvailable: false, onSaved: saved.add));
    await _goToReview(tester);

    expect(find.byKey(const Key('agenda-event-actions-unavailable')), findsOneWidget);
    expect(find.text('Integração indisponível'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('agenda-wizard-save-draft'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('agenda-wizard-publish'))).onPressed,
      isNull,
    );
    expect(prototype.items, hasLength(initialCount));
    expect(saved, isEmpty);
  });

  testWidgets('validação obrigatória anuncia erro e preserva o formulário', (tester) async {
    final prototype = store();
    final saved = <String>[];
    await tester.pumpWidget(_app(store: prototype, onSaved: saved.add));
    await tester.enterText(find.byType(CoeloFormTextField).first, '');
    await _goToReview(tester);

    await tester.tap(find.byKey(const Key('agenda-wizard-save-draft')));
    await tester.pump();

    expect(find.byKey(const Key('agenda-event-form-feedback')), findsOneWidget);
    expect(find.text('Informe o título do evento antes de continuar.'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('quantidade de recorrência exige inteiro positivo antes de salvar', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final prototype = store();
    final saved = <String>[];
    await tester.pumpWidget(_app(store: prototype, onSaved: saved.add));
    await _continue(tester);
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('agenda-event-recurrence')),
        )
        .onChanged('Diária');
    await tester.pump();
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('agenda-event-recurrence-end')),
        )
        .onChanged('Após uma quantidade');
    await tester.pump();
    tester
            .widget<CoeloFormTextField>(find.byKey(const Key('agenda-event-occurrence-count')))
            .controller
            .text =
        '0';
    await _continue(tester);
    await _continue(tester);

    await tester.tap(find.byKey(const Key('agenda-wizard-save-draft')));
    await tester.pump();

    expect(find.text('Informe uma quantidade de ocorrências maior que zero.'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('override autorizado de reserva exige motivo e registra histórico', (tester) async {
    final prototype = store();
    final saved = <String>[];
    await tester.pumpWidget(_app(store: prototype, onSaved: saved.add));
    tester
        .widget<CoeloAdminSingleSelectField<AgendaItemType>>(
          find.byKey(const Key('agenda-event-type')),
        )
        .onChanged(AgendaItemType.resourceReservation);
    await tester.pump();
    await _continue(tester);
    tester
        .widget<CoeloDateTimeField>(find.byKey(const Key('agenda-event-start')))
        .onChanged(DateTime(2026, 8, 5, 11));
    tester
        .widget<CoeloDateTimeField>(find.byKey(const Key('agenda-event-end')))
        .onChanged(DateTime(2026, 8, 5, 12));
    await tester.enterText(
      find.widgetWithText(CoeloFormTextField, 'Local (opcional)'),
      'Auditório',
    );
    await _continue(tester);
    await _continue(tester);

    await tester.tap(find.byKey(const Key('agenda-wizard-publish')));
    await tester.pumpAndSettle();
    expect(find.text('Substituir conflito de reserva?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('agenda-reservation-override-reason')),
      'Prioridade institucional',
    );
    await tester.tap(find.byKey(const Key('agenda-reservation-override-confirm')));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(
      prototype.itemById(saved.single)!.history.last.action,
      AgendaHistoryAction.reservationConflictOverridden,
    );
  });

  testWidgets('edição carrega valores aprovados e preserva o id', (tester) async {
    final prototype = store();
    final original = prototype.itemById('event-parents')!;
    prototype.upsertItem(
      original.copyWith(
        timeZoneId: 'America/Manaus',
        responseMode: AgendaResponseMode.rsvp,
        guardianResponsePolicy: GuardianResponsePolicy.allMustRespond,
      ),
    );
    final saved = <String>[];
    await tester.pumpWidget(_app(store: prototype, eventId: original.id, onSaved: saved.add));

    expect(find.text('Editar evento'), findsOneWidget);
    expect(find.text(original.title), findsOneWidget);
    await _continue(tester);
    expect(
      tester
          .widget<CoeloAdminSingleSelectField<String>>(
            find.byKey(const Key('agenda-event-timezone')),
          )
          .value,
      'America/Manaus',
    );
    await _continue(tester);
    expect(
      tester
          .widget<CoeloAdminSingleSelectField<AgendaResponseMode>>(
            find.byKey(const Key('agenda-event-response-mode')),
          )
          .value,
      AgendaResponseMode.rsvp,
    );
    await _continue(tester);
    await tester.tap(find.byKey(const Key('agenda-wizard-save-draft')));
    await tester.pump();
    expect(saved, [original.id]);
  });

  testWidgets('edição recorrente aplica o escopo selecionado ao histórico', (tester) async {
    final prototype = store();
    final recurring = prototype.itemById('routine-ballet')!;
    final saved = <String>[];
    await tester.pumpWidget(_app(store: prototype, eventId: recurring.id, onSaved: saved.add));
    await _continue(tester);

    final scope = tester.widget<CoeloAdminSingleSelectField<AgendaOccurrenceEditScope>>(
      find.byKey(const Key('agenda-event-occurrence-edit-scope')),
    );
    scope.onChanged(AgendaOccurrenceEditScope.thisAndFollowing);
    await tester.pump();
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('agenda-event-recurrence')),
        )
        .onChanged('Não se repete');
    await tester.pump();
    await _continue(tester);
    await _continue(tester);
    await tester.tap(find.byKey(const Key('agenda-wizard-save-draft')));
    await tester.pump();

    expect(saved, [recurring.id]);
    expect(
      prototype.itemById(recurring.id)!.history.last.occurrenceEditScope,
      AgendaOccurrenceEditScope.thisAndFollowing,
    );
  });
}

Widget _app({
  required AgendaRepository store,
  String? eventId,
  bool canPublish = true,
  bool actionsAvailable = true,
  ValueChanged<String>? onSaved,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: AgendaEventFormPage(
      store: store,
      eventId: eventId,
      canPublish: canPublish,
      actionsAvailable: actionsAvailable,
      onCancel: () {},
      onSaved: onSaved ?? (_) {},
    ),
  ),
);

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('agenda-wizard-continue')));
  await tester.pump();
}

Future<void> _goToReview(WidgetTester tester) async {
  await _continue(tester);
  await _continue(tester);
  await _continue(tester);
}

final class _PendingFormRepository extends AgendaRepository {
  _PendingFormRepository(this.stage);
  final String stage;
  final delegate = AgendaPrototypeStore.seeded(clock: () => DateTime(2026, 8, 3, 12));
  final pending = Completer<AgendaMutationResult>();
  int saves = 0, occurrences = 0, publications = 0;
  @override
  DateTime get referenceDate => delegate.referenceDate;
  @override
  List<AgendaItem> get items => delegate.items;
  @override
  List<AgendaContext> get contexts => delegate.contexts;
  @override
  AgendaItem? itemById(String id) => delegate.itemById(id);
  @override
  bool get supportsOccurrenceScopedEdits => true;
  @override
  String? get lastSavedItemId => 'routine-ballet';
  @override
  PermissionResolution resolveCapability(String contextId, AgendaCapability capability) =>
      delegate.resolveCapability(contextId, capability);
  @override
  FutureOr<AgendaMutationResult> saveItem(
    AgendaItem item, {
    required String actorContextId,
    String actorName = 'Owner Coelo',
    bool overrideConflict = false,
    String? reason,
  }) {
    saves++;
    return stage == 'save' ? pending.future : AgendaMutationResult.success;
  }

  @override
  FutureOr<AgendaMutationResult> recordOccurrenceEdit({
    required String itemId,
    required DateTime occurrenceStartsAt,
    required AgendaOccurrenceEditScope scope,
    required String actorName,
  }) {
    occurrences++;
    return stage == 'occurrence' ? pending.future : AgendaMutationResult.success;
  }

  @override
  FutureOr<AgendaMutationResult> requestPublication(String itemId, {required String requestedBy}) {
    publications++;
    return stage == 'publication' ? pending.future : AgendaMutationResult.success;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
