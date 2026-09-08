import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  group('response projections', () {
    const legacySummary = FormResponseSummary(
      id: 'response-1',
      occurrenceId: 'occurrence-1',
      formVersionId: 'version-1',
    );

    test('keeps identified and absent historical graph defaults', () {
      final answers = {'answer-1': FormAnswer.integer(itemId: 'answer-1', value: 42)};
      final detail = FormResponseDetail(summary: legacySummary, answers: answers);
      answers.clear();

      expect(legacySummary.identityMode, FormIdentityMode.identified);
      expect(detail.originalVersion, isNull);
      expect((detail.answers['answer-1']!.value as FormIntegerValue).value, 42);
      expect(() => detail.answers.clear(), throwsUnsupportedError);
    });

    test('carries anonymous identity explicitly without identifying metadata', () {
      const summary = FormResponseSummary(
        id: 'anonymous-response',
        occurrenceId: 'occurrence-1',
        formVersionId: 'version-1',
        identityMode: FormIdentityMode.anonymous,
      );

      expect(summary.identityMode, FormIdentityMode.anonymous);
      expect(summary.respondentLabel, isNull);
      expect(summary.submittedAt, isNull);
    });

    test('preserves the historical graph and freezes nested condition choices', () {
      final optionIds = {'option-old'};
      final definition = FormDefinition(
        id: 'form-1',
        institutionId: 'institution-1',
        kind: FormKind.form,
        identityMode: FormIdentityMode.identified,
        responseUnit: FormResponseUnit.person,
        title: 'Historical form',
        sections: [
          FormSection(
            id: 'section-old',
            title: 'Original section',
            description: 'Original description',
            position: 2,
            items: [
              FormItem(
                id: 'question-old',
                kind: FormItemKind.singleChoice,
                label: 'Original question',
                helpText: 'Original help',
                position: 3,
                isRequired: true,
                config: const FormItemConfig(minSelections: 1, maxSelections: 1),
                options: const [
                  FormOption(id: 'option-old', label: 'Original option', position: 4),
                ],
                conditions: [
                  FormCondition.choice(sourceItemId: 'source-old', optionIds: optionIds),
                  const FormCondition.yesNo(sourceItemId: 'yes-no-old', expected: false),
                ],
              ),
            ],
          ),
        ],
      );
      final decoded = FormDefinitionDto.fromJson(
        FormDefinitionDto.fromDomain(definition).toJson(),
      ).toDomain();
      final original = FormVersion(
        id: 'version-1',
        formId: decoded.id,
        number: 1,
        sections: decoded.sections,
        isPublished: true,
      );
      final detail = FormResponseDetail(
        summary: legacySummary,
        answers: const {},
        originalVersion: original,
      );
      original.sections.single.items.single.conditions.first.optionIds.clear();
      final historical = detail.originalVersion!;
      final section = historical.sections.single;
      final item = section.items.single;

      expect(
        (historical.id, historical.formId, historical.number, historical.isPublished),
        ('version-1', 'form-1', 1, true),
      );
      expect((section.title, section.position), ('Original section', 2));
      expect(section.description, 'Original description');
      expect(
        (item.label, item.position, item.kind),
        ('Original question', 3, FormItemKind.singleChoice),
      );
      expect(item.helpText, 'Original help');
      expect(item.isRequired, isTrue);
      expect((item.config.minSelections, item.config.maxSelections), (1, 1));
      expect(item.options.single.label, 'Original option');
      expect(item.options.single.position, 4);
      expect(item.conditions.first.sourceItemId, 'source-old');
      expect(item.conditions.first.optionIds, {'option-old'});
      expect(item.conditions.last.kind, FormConditionKind.yesNo);
      expect(item.conditions.last.expectedYesNo, isFalse);
      expect(() => historical.sections.clear(), throwsUnsupportedError);
      expect(() => section.items.clear(), throwsUnsupportedError);
      expect(() => item.options.clear(), throwsUnsupportedError);
      expect(() => item.conditions.clear(), throwsUnsupportedError);
      expect(() => item.conditions.first.optionIds.add('forged'), throwsUnsupportedError);
    });

    test('rejects a historical version belonging to a different response version', () {
      expect(
        () => FormResponseDetail(
          summary: legacySummary,
          answers: const {},
          originalVersion: FormVersion(
            id: 'other-version',
            formId: 'form-1',
            number: 2,
            sections: const [],
            isPublished: true,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

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
