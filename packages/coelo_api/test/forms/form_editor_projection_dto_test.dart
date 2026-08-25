import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  test('editor projection DTO restores definition and normalized application', () {
    final definition = _definition();
    final application = _application();
    final json = FormEditorProjectionDto.fromDomain(
      FormEditorProjection(definition: definition, application: application),
    ).toJson();
    final decoded = FormEditorProjectionDto.fromJson(json).toDomain();

    expect(decoded.definition.title, 'Pesquisa');
    expect(decoded.application?.audienceRules.single.targetId, 'group-1');
    expect(decoded.application?.schedules.single.reminders.single.kind, FormReminderKind.onOpen);
  });

  test('editor projection DTO accepts no application and rejects unknown keys', () {
    final json = FormEditorProjectionDto.fromDomain(
      FormEditorProjection(definition: _definition()),
    ).toJson();

    expect(FormEditorProjectionDto.fromJson(json).toDomain().application, isNull);
    expect(
      () => FormEditorProjectionDto.fromJson({...json, 'person_id': 'forged'}),
      throwsA(isA<WireFormatException>()),
    );
  });
}

FormDefinition _definition() => FormDefinition(
  id: 'form-1',
  institutionId: 'institution-1',
  kind: FormKind.form,
  identityMode: FormIdentityMode.identified,
  responseUnit: FormResponseUnit.person,
  title: 'Pesquisa',
  sections: const [],
);

FormApplication _application() => FormApplication(
  id: 'application-1',
  formId: 'form-1',
  institutionId: 'institution-1',
  name: 'Famílias',
  audienceRules: const [
    FormAudienceRule(
      id: 'rule-1',
      kind: FormAudienceRuleKind.group,
      mode: FormAudienceRuleMode.include,
      targetId: 'group-1',
    ),
  ],
  schedules: [
    FormApplicationSchedule(
      id: 'schedule-1',
      schedule: FormSchedule(
        startsAtLocal: DateTime(2026, 10, 30, 9),
        timeZone: 'America/Sao_Paulo',
        recurrence: const FormRecurrence.once(),
        end: const FormScheduleEnd.never(),
      ),
      reminders: const [FormReminder(kind: FormReminderKind.onOpen)],
      managementVersion: 2,
    ),
  ],
  managementVersion: 3,
);
