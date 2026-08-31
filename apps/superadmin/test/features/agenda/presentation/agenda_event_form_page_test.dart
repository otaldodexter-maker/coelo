import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_event_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AgendaPrototypeStore store() =>
      AgendaPrototypeStore.seeded(clock: () => DateTime(2026, 8, 3, 12));

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

    final allDay = tester.widget<SwitchListTile>(find.byKey(const Key('agenda-event-all-day')));
    allDay.onChanged!(true);
    await tester.pump();
    expect(find.byType(CoeloDateTimeField), findsNothing);
    expect(find.byType(CoeloDateRangeField), findsOneWidget);

    final recurrence = tester.widget<CoeloAdminSingleSelectField<String>>(
      find.byKey(const Key('agenda-event-recurrence')),
    );
    expect(recurrence.options, const ['Não se repete', 'Diária', 'Semanal', 'Mensal']);
    recurrence.onChanged('Semanal');
    await tester.pump();
    expect(find.byKey(const Key('agenda-event-recurrence-end')), findsOneWidget);
    expect(find.text('Editar uma ocorrência, esta e próximas ou toda a série'), findsOneWidget);
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
    expect(find.textContaining('sininho e push'), findsOneWidget);
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
  });

  testWidgets('produção sem integração mantém composição e ações fail-closed', (tester) async {
    final prototype = store();
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
}

Widget _app({
  required AgendaPrototypeStore store,
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
