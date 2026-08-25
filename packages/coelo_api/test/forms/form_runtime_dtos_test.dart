import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  test('application DTO round-trips independent schedules and their versions', () {
    final application = FormApplication(
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
          id: 'schedule-weekly',
          schedule: FormSchedule(
            startsAtLocal: DateTime(2026, 10, 30, 9),
            timeZone: 'America/Sao_Paulo',
            recurrence: const FormRecurrence.weekly(
              interval: 2,
              weekdays: {DateTime.monday, DateTime.friday},
            ),
            end: const FormScheduleEnd.afterOccurrences(8),
          ),
          reminders: const [FormReminder(kind: FormReminderKind.beforeClose, amount: 2)],
          managementVersion: 4,
        ),
        FormApplicationSchedule(
          id: 'schedule-once',
          schedule: FormSchedule(
            startsAtLocal: DateTime(2026, 11, 2, 14),
            timeZone: 'America/Sao_Paulo',
            recurrence: const FormRecurrence.once(),
            end: const FormScheduleEnd.never(),
          ),
          managementVersion: 1,
        ),
      ],
      managementVersion: 3,
    );

    final json = FormApplicationDto.fromDomain(application).toJson();
    final decoded = FormApplicationDto.fromJson(json).toDomain();

    expect(decoded.schedules, hasLength(2));
    expect(decoded.schedules.first.id, 'schedule-weekly');
    expect(decoded.schedules.first.schedule.timeZone, 'America/Sao_Paulo');
    expect((decoded.schedules.first.schedule.recurrence as FormWeeklyRecurrence).weekdays, {1, 5});
    expect((decoded.schedules.first.schedule.end as FormScheduleEndsAfterOccurrences).count, 8);
    expect(decoded.schedules.first.reminders.single.kind, FormReminderKind.beforeClose);
    expect(decoded.schedules.first.managementVersion, 4);
    expect(decoded.schedules.last.id, 'schedule-once');
    expect(decoded.schedules.last.managementVersion, 1);
  });

  test('application DTO rejects superseded single-schedule keys', () {
    final json = FormApplicationDto.fromDomain(
      FormApplication(
        id: 'application-1',
        formId: 'form-1',
        institutionId: 'institution-1',
        name: 'Famílias',
        audienceRules: const [],
        schedules: const [],
        managementVersion: 3,
      ),
    ).toJson();

    expect(
      () => FormApplicationDto.fromJson({...json, 'schedule': null}),
      throwsA(isA<WireFormatException>()),
    );
  });

  test('answer DTO round-trips every typed storage shape', () {
    final answers = [
      FormAnswer.shortText(itemId: 'text', value: 'Ana'),
      FormAnswer.integer(itemId: 'integer', value: 2),
      FormAnswer.decimal(itemId: 'decimal', value: 2.5),
      FormAnswer.money(itemId: 'money', minorUnits: 1299),
      FormAnswer.date(itemId: 'date', value: DateTime(2026, 8, 13)),
      FormAnswer.yesNo(itemId: 'yes-no', value: true),
      FormAnswer.singleChoice(itemId: 'single', optionId: 'a'),
      FormAnswer.multipleChoice(itemId: 'multiple', optionIds: {'a', 'b'}),
      FormAnswer.scale(itemId: 'scale', value: 4),
      FormAnswer.photo(itemId: 'photo', assetIds: ['asset-1']),
      FormAnswer.gallery(itemId: 'gallery', assetIds: ['asset-2']),
    ];

    final decoded = answers
        .map(FormAnswerDto.fromDomain)
        .map((dto) => FormAnswerDto.fromJson(dto.toJson()).toDomain())
        .toList();

    expect(decoded.map((answer) => answer.value.runtimeType), [
      FormShortTextValue,
      FormIntegerValue,
      FormDecimalValue,
      FormMoneyValue,
      FormDateValue,
      FormYesNoValue,
      FormChoiceValue,
      FormChoiceValue,
      FormScaleValue,
      FormAssetValue,
      FormAssetValue,
    ]);
  });

  test('runtime DTOs reject unknown keys', () {
    final json = FormAnswerDto.fromDomain(FormAnswer.yesNo(itemId: 'yes-no', value: true)).toJson();
    expect(
      () => FormAnswerDto.fromJson({...json, 'person_id': 'forged'}),
      throwsA(isA<WireFormatException>()),
    );
  });
}
