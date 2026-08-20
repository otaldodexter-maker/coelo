import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds a valid structure from an empty new form', (tester) async {
    final api = _EditorApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: FormDefinition(
            id: 'form-new',
            institutionId: 'institution-1',
            kind: FormKind.form,
            identityMode: FormIdentityMode.identified,
            responseUnit: FormResponseUnit.person,
            title: 'Novo formulário',
            sections: const [],
          ),
          autosaveDebounce: Duration.zero,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('form-add-section')));
    await tester.pumpAndSettle();
    expect(find.text('Seção 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('form-add-item')));
    await tester.pumpAndSettle();
    expect(find.text('Pergunta 1'), findsWidgets);

    await tester.enterText(find.byKey(const Key('form-item-label')), 'Como foi o dia?');
    await tester.pumpAndSettle();
    expect(api.savedTitle, 'Novo formulário');
    expect(api.savedItemLabel, 'Como foi o dia?');
  });

  testWidgets('duplicates and deletes sections and items without corrupting positions', (
    tester,
  ) async {
    final api = _EditorApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: _definition(),
          autosaveDebounce: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Duplicar item'));
    await tester.pumpAndSettle();
    expect(find.text('Pergunta (cópia)'), findsOneWidget);
    tester.widget<IconButton>(find.byKey(const Key('form-delete-item-0-1'))).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Pergunta (cópia)'), findsNothing);

    await tester.tap(find.byTooltip('Duplicar seção'));
    await tester.pumpAndSettle();
    expect(find.text('Seção 1 (cópia)'), findsOneWidget);
    tester.widget<IconButton>(find.byKey(const Key('form-delete-section-1'))).onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Seção 1 (cópia)'), findsNothing);
  });
  testWidgets('configures item kind options required state and a condition', (tester) async {
    final api = _EditorApi();
    final source = FormItem(
      id: 'source-item',
      kind: FormItemKind.yesNo,
      label: 'Autorizou?',
      position: 0,
    );
    final target = FormItem(
      id: 'target-item',
      kind: FormItemKind.shortText,
      label: 'Detalhes',
      position: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: FormDefinition(
            id: 'form-conditions',
            institutionId: 'institution-1',
            kind: FormKind.form,
            identityMode: FormIdentityMode.identified,
            responseUnit: FormResponseUnit.person,
            title: 'Condições',
            sections: [
              FormSection(
                id: 'section-1',
                title: 'Perguntas',
                position: 0,
                items: [source, target],
              ),
            ],
          ),
          autosaveDebounce: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    tester.widget<ListTile>(find.widgetWithText(ListTile, 'Detalhes')).onTap!();
    await tester.pumpAndSettle();

    final kindField = tester.widget<CoeloAdminSingleSelectField<FormItemKind>>(
      find.byKey(const Key('form-item-kind')),
    );
    kindField.onChanged(FormItemKind.singleChoice);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-option-label-0')), findsOneWidget);
    expect(find.byKey(const Key('form-option-label-1')), findsOneWidget);

    final requiredField = tester.widget<CoeloAdminToggleField>(
      find.byKey(const Key('form-item-required')),
    );
    requiredField.onChanged!(true);
    tester.widget<OutlinedButton>(find.byKey(const Key('form-add-condition'))).onPressed!();
    await tester.pumpAndSettle();

    final saved = api.lastSavedDefinition!;
    final savedTarget = saved.sections.single.items.last;
    expect(savedTarget.kind, FormItemKind.singleChoice);
    expect(savedTarget.options, hasLength(2));
    expect(savedTarget.isRequired, isTrue);
    expect(savedTarget.conditions.single.sourceItemId, 'source-item');
  });
  testWidgets('walks the six steps, autosaves and publishes the current version', (tester) async {
    final api = _EditorApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: _definition(),
          autosaveDebounce: Duration.zero,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('form-title')), 'Pesquisa atualizada');
    await tester.pumpAndSettle();
    expect(api.savedTitle, 'Pesquisa atualizada');
    expect(find.text('Salvo'), findsOneWidget);

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Revisão'), findsWidgets);
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(api.published, isTrue);
  });

  testWidgets('stays responsive at 375 pixels and exposes accessible move commands', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(api: _EditorApi(), initialDefinition: _definition()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mover item para cima'), findsOneWidget);
    expect(find.byTooltip('Mover item para baixo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('autosaves a changed item help text', (tester) async {
    final api = _EditorApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: _definition(),
          autosaveDebounce: Duration.zero,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('form-item-help-text')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('form-item-help-text')), 'Explique com detalhes');
    await tester.pumpAndSettle();

    expect(api.savedHelpText, 'Explique com detalhes');
  });

  testWidgets('quick poll exposes its short intent and blocks publish while invalid', (
    tester,
  ) async {
    final api = _EditorApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: FormDefinition(
            id: 'quick-poll-1',
            institutionId: 'institution-1',
            kind: FormKind.quickPoll,
            identityMode: FormIdentityMode.identified,
            responseUnit: FormResponseUnit.person,
            title: 'Pulso da semana',
            sections: [
              FormSection(
                id: 'section-1',
                title: 'Pergunta principal',
                position: 0,
                items: [
                  FormItem(id: 'item-1', kind: FormItemKind.yesNo, label: 'Tudo bem?', position: 0),
                  FormItem(
                    id: 'item-2',
                    kind: FormItemKind.information,
                    label: 'Obrigado',
                    position: 1,
                  ),
                ],
              ),
            ],
          ),
          autosaveDebounce: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final intent = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('quick-poll-intent')),
        matching: find.byType(TextField),
      ),
    );
    expect(intent.maxLength, 280);
    expect(find.text('Intenção curta *'), findsOneWidget);

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();

    expect(api.published, isFalse);
    expect(
      find.text('A enquete rápida precisa de uma intenção curta e uma pergunta principal.'),
      findsOneWidget,
    );
  });

  testWidgets('creates and saves an institution application from a new form', (tester) async {
    final api = _EditorApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: _definition(),
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('form-create-application')));
    await tester.pumpAndSettle();
    expect(find.text('Instituição atual · incluir'), findsOneWidget);

    await tester.tap(find.text('Salvar aplicação'));
    await tester.pumpAndSettle();
    expect(api.applicationSaved, isTrue);
    expect(api.lastApplication!.audienceRules.single.targetId, 'institution-1');
    expect(api.lastApplication!.managementVersion, 0);
  });
  testWidgets('saves normalized audience rules and a real schedule through the API', (
    tester,
  ) async {
    final api = _EditorApi();
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: _definition(),
          initialApplication: FormApplication(
            id: 'application-1',
            formId: 'form-1',
            institutionId: 'institution-1',
            name: 'Famílias da unidade',
            audienceRules: const [
              FormAudienceRule(
                id: 'rule-1',
                kind: FormAudienceRuleKind.unit,
                mode: FormAudienceRuleMode.include,
                targetId: 'unit-1',
              ),
            ],
            managementVersion: 2,
          ),
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicações/Distribuições'));
    await tester.pumpAndSettle();

    expect(find.text('Unidade · incluir · unit-1'), findsOneWidget);
    await tester.tap(find.text('Salvar aplicação'));
    await tester.pumpAndSettle();
    expect(api.applicationSaved, isTrue);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Fuso horário IANA'), findsOneWidget);
    await tester.tap(find.text('Salvar agendamento'));
    await tester.pumpAndSettle();
    expect(api.scheduleSaved, isTrue);
  });

  testWidgets('edits the selected schedule while preserving its id and version', (tester) async {
    final application = _applicationWithSchedules();
    final api = _EditorApi(scheduleState: application);
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: _definition(),
          initialApplication: application,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendamentos'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agendamento 2'));
    await tester.pumpAndSettle();
    expect(find.text('Europe/Lisbon'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('schedule-time-zone-schedule-2')),
      'Europe/Madrid',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar agendamento'));
    await tester.pumpAndSettle();

    final command = api.scheduleCommands.single;
    expect(command.payload.scheduleId, 'schedule-2');
    expect(command.expectedVersion, 9);
    expect(command.payload.schedule.timeZone, 'Europe/Madrid');
  });

  testWidgets('adds an independent schedule with an initial version of zero', (tester) async {
    final application = _applicationWithSchedules();
    final api = _EditorApi(scheduleState: application);
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: _definition(),
          initialApplication: application,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendamentos'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar agendamento'));
    await tester.pumpAndSettle();
    expect(find.text('Novo agendamento'), findsOneWidget);
    await tester.tap(find.text('Salvar agendamento'));
    await tester.pumpAndSettle();

    final command = api.scheduleCommands.single;
    expect(command.payload.scheduleId, isNotEmpty);
    expect(command.expectedVersion, 0);
  });

  testWidgets('removes only the confirmed selected schedule with its version', (tester) async {
    final application = _applicationWithSchedules();
    final api = _EditorApi(scheduleState: application);
    await tester.pumpWidget(
      MaterialApp(
        home: FormsEditorPage(
          api: api,
          initialDefinition: _definition(),
          initialApplication: application,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendamentos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendamento 2'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remover agendamento'));
    await tester.pumpAndSettle();
    expect(find.text('Remover agendamento?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(api.removeScheduleCommands, isEmpty);

    await tester.tap(find.text('Remover agendamento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();

    final command = api.removeScheduleCommands.single;
    expect(command.payload.scheduleId, 'schedule-2');
    expect(command.expectedVersion, 9);
    expect(find.text('Agendamento 2'), findsNothing);
  });
}

FormDefinition _definition() => FormDefinition(
  id: 'form-1',
  institutionId: 'institution-1',
  kind: FormKind.form,
  identityMode: FormIdentityMode.identified,
  responseUnit: FormResponseUnit.person,
  title: 'Pesquisa',
  managementVersion: 1,
  sections: [
    FormSection(
      id: 'section-1',
      title: 'Seção 1',
      position: 0,
      items: [FormItem(id: 'item-1', kind: FormItemKind.shortText, label: 'Pergunta', position: 0)],
    ),
  ],
);

FormApplication _applicationWithSchedules() => FormApplication(
  id: 'application-1',
  formId: 'form-1',
  institutionId: 'institution-1',
  name: 'Famílias da unidade',
  audienceRules: const [],
  schedules: [
    FormApplicationSchedule(
      id: 'schedule-1',
      schedule: FormSchedule(
        startsAtLocal: DateTime(2026, 8, 20, 9),
        timeZone: 'America/Sao_Paulo',
        recurrence: const FormRecurrence.once(),
        end: const FormScheduleEnd.never(),
      ),
      managementVersion: 4,
    ),
    FormApplicationSchedule(
      id: 'schedule-2',
      schedule: FormSchedule(
        startsAtLocal: DateTime(2026, 8, 21, 9),
        timeZone: 'Europe/Lisbon',
        recurrence: const FormRecurrence.once(),
        end: const FormScheduleEnd.never(),
      ),
      managementVersion: 9,
    ),
  ],
  managementVersion: 2,
);

final class _EditorApi implements FormsApi {
  _EditorApi({this.scheduleState});

  String? savedTitle;
  String? savedHelpText;
  String? savedItemLabel;
  FormDefinition? lastSavedDefinition;
  bool published = false;
  bool applicationSaved = false;
  FormApplication? lastApplication;
  bool scheduleSaved = false;
  FormApplication? scheduleState;
  final scheduleCommands = <FormCommand<FormSaveSchedulePayload>>[];
  final removeScheduleCommands = <FormCommand<FormRemoveSchedulePayload>>[];

  @override
  Future<FormDefinition> saveDraft(FormCommand<FormDefinition> command) async {
    savedTitle = command.payload.title;
    savedHelpText = command.payload.sections.firstOrNull?.items.firstOrNull?.helpText;
    savedItemLabel = command.payload.sections.firstOrNull?.items.firstOrNull?.label;
    lastSavedDefinition = command.payload;
    return command.payload;
  }

  @override
  Future<FormDefinition> publish(FormCommand<FormIdPayload> command) async {
    published = true;
    return _definition();
  }

  @override
  Future<FormApplication> saveApplication(FormCommand<FormSaveApplicationPayload> command) async {
    applicationSaved = true;
    lastApplication = command.payload.application;
    return command.payload.application;
  }

  @override
  Future<FormApplication> saveSchedule(FormCommand<FormSaveSchedulePayload> command) async {
    scheduleSaved = true;
    scheduleCommands.add(command);
    final application = scheduleState ?? _applicationWithSchedules();
    final scheduleId = command.payload.scheduleId ?? 'schedule-new';
    final existing = application.schedules
        .where((schedule) => schedule.id == scheduleId)
        .firstOrNull;
    scheduleState = FormApplication(
      id: application.id,
      formId: application.formId,
      institutionId: application.institutionId,
      name: application.name,
      status: application.status,
      opensForDays: application.opensForDays,
      audienceRules: application.audienceRules,
      schedules: [
        for (final schedule in application.schedules)
          if (schedule.id == scheduleId)
            FormApplicationSchedule(
              id: schedule.id,
              status: schedule.status,
              schedule: command.payload.schedule,
              reminders: command.payload.reminders,
              managementVersion: schedule.managementVersion + 1,
            )
          else
            schedule,
        if (existing == null)
          FormApplicationSchedule(
            id: scheduleId,
            schedule: command.payload.schedule,
            reminders: command.payload.reminders,
            managementVersion: 1,
          ),
      ],
      managementVersion: application.managementVersion,
    );
    return scheduleState!;
  }

  @override
  Future<FormApplication> removeSchedule(FormCommand<FormRemoveSchedulePayload> command) async {
    removeScheduleCommands.add(command);
    final application = scheduleState ?? _applicationWithSchedules();
    scheduleState = FormApplication(
      id: application.id,
      formId: application.formId,
      institutionId: application.institutionId,
      name: application.name,
      status: application.status,
      opensForDays: application.opensForDays,
      audienceRules: application.audienceRules,
      schedules: application.schedules
          .where((schedule) => schedule.id != command.payload.scheduleId)
          .toList(),
      managementVersion: application.managementVersion,
    );
    return scheduleState!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
