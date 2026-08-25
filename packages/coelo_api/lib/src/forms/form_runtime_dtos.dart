import 'package:coelo_domain/coelo_domain.dart';

import 'form_wire_contracts.dart';

final class FormAnswerDto {
  const FormAnswerDto(this.value);

  factory FormAnswerDto.fromDomain(FormAnswer value) => FormAnswerDto(value);

  factory FormAnswerDto.fromJson(Map<String, Object?> json) {
    const context = 'form_answer';
    requireOnlyKeys(json, const {
      'item_id',
      'kind',
      'text_value',
      'integer_value',
      'decimal_value',
      'money_minor_units',
      'date_value',
      'yes_no_value',
      'option_ids',
      'scale_value',
      'asset_ids',
    }, context: context);
    final itemId = requireString(json, 'item_id', context: context);
    final kind = requireString(json, 'kind', context: context);
    return FormAnswerDto(switch (kind) {
      'short_text' => FormAnswer.shortText(
        itemId: itemId,
        value: _required<String>(json, 'text_value', context),
      ),
      'integer' => FormAnswer.integer(
        itemId: itemId,
        value: _required<int>(json, 'integer_value', context),
      ),
      'decimal' => FormAnswer.decimal(
        itemId: itemId,
        value: _number(json, 'decimal_value', context),
      ),
      'money' => FormAnswer.money(
        itemId: itemId,
        minorUnits: _required<int>(json, 'money_minor_units', context),
      ),
      'date' => FormAnswer.date(
        itemId: itemId,
        value: _parseDate(_required<String>(json, 'date_value', context), context),
      ),
      'yes_no' => FormAnswer.yesNo(
        itemId: itemId,
        value: _required<bool>(json, 'yes_no_value', context),
      ),
      'single_choice' => FormAnswer.singleChoice(
        itemId: itemId,
        optionId: _stringList(json, 'option_ids', context).single,
      ),
      'multiple_choice' => FormAnswer.multipleChoice(
        itemId: itemId,
        optionIds: _stringList(json, 'option_ids', context).toSet(),
      ),
      'scale' => FormAnswer.scale(
        itemId: itemId,
        value: _required<int>(json, 'scale_value', context),
      ),
      'photo' => FormAnswer.photo(
        itemId: itemId,
        assetIds: _stringList(json, 'asset_ids', context),
      ),
      'gallery' => FormAnswer.gallery(
        itemId: itemId,
        assetIds: _stringList(json, 'asset_ids', context),
      ),
      _ => throw WireFormatException('$context.kind contains unknown value: $kind.'),
    });
  }

  final FormAnswer value;

  FormAnswer toDomain() => value;

  Map<String, Object?> toJson() {
    final answerValue = value.value;
    return {
      'item_id': value.itemId,
      'kind': _answerKinds[value.kind],
      'text_value': answerValue is FormShortTextValue ? answerValue.value : null,
      'integer_value': answerValue is FormIntegerValue ? answerValue.value : null,
      'decimal_value': answerValue is FormDecimalValue ? answerValue.value : null,
      'money_minor_units': answerValue is FormMoneyValue ? answerValue.minorUnits : null,
      'date_value': answerValue is FormDateValue ? _dateOnly(answerValue.value) : null,
      'yes_no_value': answerValue is FormYesNoValue ? answerValue.value : null,
      'option_ids': answerValue is FormChoiceValue
          ? answerValue.optionIds.toList(growable: false)
          : const <String>[],
      'scale_value': answerValue is FormScaleValue ? answerValue.value : null,
      'asset_ids': answerValue is FormAssetValue ? answerValue.assetIds : const <String>[],
    };
  }
}

final class FormApplicationDto {
  const FormApplicationDto(this.value);

  factory FormApplicationDto.fromDomain(FormApplication value) => FormApplicationDto(value);

  factory FormApplicationDto.fromJson(Map<String, Object?> json) {
    const context = 'form_application';
    requireOnlyKeys(json, const {
      'id',
      'form_id',
      'institution_id',
      'name',
      'status',
      'opens_for_days',
      'audience_rules',
      'schedules',
      'management_version',
    }, context: context);
    return FormApplicationDto(
      FormApplication(
        id: requireString(json, 'id', context: context),
        formId: requireString(json, 'form_id', context: context),
        institutionId: requireString(json, 'institution_id', context: context),
        name: requireString(json, 'name', context: context),
        status: switch (requireString(json, 'status', context: context)) {
          'active' => FormApplicationStatus.active,
          'paused' => FormApplicationStatus.paused,
          'archived' => FormApplicationStatus.archived,
          final value => throw WireFormatException('Unknown application status: $value.'),
        },
        opensForDays: requireInt(json, 'opens_for_days', context: context),
        audienceRules: requireList(json, 'audience_rules', context: context)
            .map((value) => _decodeRule(_object(value, 'form_application.audience_rules')))
            .toList(growable: false),
        schedules: requireList(json, 'schedules', context: context)
            .map(
              (value) => _decodeApplicationSchedule(_object(value, 'form_application.schedules')),
            )
            .toList(growable: false),
        managementVersion: requireInt(json, 'management_version', context: context),
      ),
    );
  }

  final FormApplication value;

  FormApplication toDomain() => value;

  Map<String, Object?> toJson() => {
    'id': value.id,
    'form_id': value.formId,
    'institution_id': value.institutionId,
    'name': value.name,
    'status': value.status.name,
    'opens_for_days': value.opensForDays,
    'audience_rules': value.audienceRules.map(_encodeRule).toList(growable: false),
    'schedules': value.schedules.map(_encodeApplicationSchedule).toList(growable: false),
    'management_version': value.managementVersion,
  };
}

FormApplicationSchedule _decodeApplicationSchedule(Map<String, Object?> json) {
  const context = 'form_application_schedule';
  requireOnlyKeys(json, const {
    'id',
    'status',
    'management_version',
    'starts_at_local',
    'time_zone',
    'recurrence',
    'end',
    'reminders',
  }, context: context);
  return FormApplicationSchedule(
    id: requireString(json, 'id', context: context),
    status: switch (requireString(json, 'status', context: context)) {
      'active' => FormScheduleStatus.active,
      'archived' => FormScheduleStatus.archived,
      final value => throw WireFormatException('Unknown schedule status: $value.'),
    },
    schedule: _decodeSchedule({
      'starts_at_local': json['starts_at_local'],
      'time_zone': json['time_zone'],
      'recurrence': json['recurrence'],
      'end': json['end'],
    }),
    reminders: requireList(
      json,
      'reminders',
      context: context,
    ).map((value) => _decodeReminder(_object(value, '$context.reminders'))).toList(growable: false),
    managementVersion: requireInt(json, 'management_version', context: context),
  );
}

Map<String, Object?> _encodeApplicationSchedule(FormApplicationSchedule value) => {
  'id': value.id,
  'status': value.status.name,
  'management_version': value.managementVersion,
  ..._encodeSchedule(value.schedule),
  'reminders': value.reminders.map(_encodeReminder).toList(growable: false),
};

FormAudienceRule _decodeRule(Map<String, Object?> json) {
  const context = 'form_audience_rule';
  requireOnlyKeys(json, const {'id', 'kind', 'mode', 'target_id'}, context: context);
  final kind = requireString(json, 'kind', context: context);
  final mode = requireString(json, 'mode', context: context);
  return FormAudienceRule(
    id: requireString(json, 'id', context: context),
    kind: _audienceKinds.entries
        .firstWhere(
          (entry) => entry.value == kind,
          orElse: () => throw WireFormatException('Unknown audience kind: $kind.'),
        )
        .key,
    mode: switch (mode) {
      'include' => FormAudienceRuleMode.include,
      'exclude' => FormAudienceRuleMode.exclude,
      _ => throw WireFormatException('Unknown audience mode: $mode.'),
    },
    targetId: requireString(json, 'target_id', context: context),
  );
}

Map<String, Object?> _encodeRule(FormAudienceRule value) => {
  'id': value.id,
  'kind': _audienceKinds[value.kind],
  'mode': value.mode.name,
  'target_id': value.targetId,
};

FormSchedule _decodeSchedule(Map<String, Object?> json) {
  const context = 'form_schedule';
  requireOnlyKeys(json, const {
    'starts_at_local',
    'time_zone',
    'recurrence',
    'end',
  }, context: context);
  return FormSchedule(
    startsAtLocal: _parseDateTime(
      requireString(json, 'starts_at_local', context: context),
      '$context.starts_at_local',
    ),
    timeZone: requireString(json, 'time_zone', context: context),
    recurrence: _decodeRecurrence(requireMap(json, 'recurrence', context: context)),
    end: _decodeEnd(requireMap(json, 'end', context: context)),
  );
}

Map<String, Object?> _encodeSchedule(FormSchedule value) => {
  'starts_at_local': value.startsAtLocal.toIso8601String(),
  'time_zone': value.timeZone,
  'recurrence': _encodeRecurrence(value.recurrence),
  'end': _encodeEnd(value.end),
};

FormRecurrence _decodeRecurrence(Map<String, Object?> json) {
  const context = 'form_recurrence';
  requireOnlyKeys(json, const {
    'kind',
    'interval',
    'weekdays',
    'day',
    'use_last_day',
  }, context: context);
  final kind = requireString(json, 'kind', context: context);
  final interval = requireInt(json, 'interval', context: context);
  return switch (kind) {
    'once' => const FormRecurrence.once(),
    'daily' => FormRecurrence.daily(interval: interval),
    'weekly' => FormRecurrence.weekly(
      interval: interval,
      weekdays: requireList(json, 'weekdays', context: context).map((value) {
        if (value is! int) throw const WireFormatException('weekdays must contain integers.');
        return value;
      }).toSet(),
    ),
    'monthly' => FormRecurrence.monthly(
      interval: interval,
      useLastDay: requireBool(json, 'use_last_day', context: context),
      day: json['day'] as int?,
    ),
    _ => throw WireFormatException('Unknown recurrence kind: $kind.'),
  };
}

Map<String, Object?> _encodeRecurrence(FormRecurrence value) => {
  'kind': value.kind.name,
  'interval': value.interval,
  'weekdays': value is FormWeeklyRecurrence
      ? value.weekdays.toList(growable: false)
      : const <int>[],
  'day': value is FormMonthlyRecurrence ? value.day : null,
  'use_last_day': value is FormMonthlyRecurrence && value.useLastDay,
};

FormScheduleEnd _decodeEnd(Map<String, Object?> json) {
  const context = 'form_schedule_end';
  requireOnlyKeys(json, const {'kind', 'date', 'count'}, context: context);
  return switch (requireString(json, 'kind', context: context)) {
    'never' => const FormScheduleEnd.never(),
    'date' => FormScheduleEnd.onDate(_parseDate(_required<String>(json, 'date', context), context)),
    'count' => FormScheduleEnd.afterOccurrences(_required<int>(json, 'count', context)),
    final value => throw WireFormatException('Unknown schedule end kind: $value.'),
  };
}

Map<String, Object?> _encodeEnd(FormScheduleEnd value) => switch (value) {
  FormScheduleNeverEnds() => {'kind': 'never', 'date': null, 'count': null},
  FormScheduleEndsOnDate value => {'kind': 'date', 'date': _dateOnly(value.date), 'count': null},
  FormScheduleEndsAfterOccurrences value => {'kind': 'count', 'date': null, 'count': value.count},
};

FormReminder _decodeReminder(Map<String, Object?> json) {
  const context = 'form_reminder';
  requireOnlyKeys(json, const {'kind', 'amount'}, context: context);
  final kind = requireString(json, 'kind', context: context);
  return FormReminder(
    kind: switch (kind) {
      'on_open' => FormReminderKind.onOpen,
      'before_close' => FormReminderKind.beforeClose,
      'every_days' => FormReminderKind.everyDays,
      _ => throw WireFormatException('Unknown reminder kind: $kind.'),
    },
    amount: json['amount'] as int?,
  );
}

Map<String, Object?> _encodeReminder(FormReminder value) => {
  'kind': switch (value.kind) {
    FormReminderKind.onOpen => 'on_open',
    FormReminderKind.beforeClose => 'before_close',
    FormReminderKind.everyDays => 'every_days',
  },
  'amount': value.amount,
};

T _required<T>(Map<String, Object?> json, String key, String context) {
  final value = json[key];
  if (value is! T) throw WireFormatException('$context.$key has an invalid type.');
  return value;
}

double _number(Map<String, Object?> json, String key, String context) {
  final value = json[key];
  if (value is! num) throw WireFormatException('$context.$key must be a number.');
  return value.toDouble();
}

List<String> _stringList(Map<String, Object?> json, String key, String context) =>
    requireList(json, key, context: context)
        .map((value) {
          if (value is! String) throw WireFormatException('$context.$key must contain strings.');
          return value;
        })
        .toList(growable: false);

DateTime _parseDate(String value, String context) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw WireFormatException('$context must be an ISO-8601 date.');
  return DateTime(parsed.year, parsed.month, parsed.day);
}

DateTime _parseDateTime(String value, String context) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw WireFormatException('$context must be an ISO-8601 date-time.');
  return parsed;
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

Map<String, Object?> _object(Object? value, String context) {
  if (value is! Map<String, Object?>) throw WireFormatException('$context must contain objects.');
  return value;
}

const _answerKinds = {
  FormAnswerKind.shortText: 'short_text',
  FormAnswerKind.integer: 'integer',
  FormAnswerKind.decimal: 'decimal',
  FormAnswerKind.money: 'money',
  FormAnswerKind.date: 'date',
  FormAnswerKind.yesNo: 'yes_no',
  FormAnswerKind.singleChoice: 'single_choice',
  FormAnswerKind.multipleChoice: 'multiple_choice',
  FormAnswerKind.scale: 'scale',
  FormAnswerKind.photo: 'photo',
  FormAnswerKind.gallery: 'gallery',
};

const _audienceKinds = {
  FormAudienceRuleKind.institution: 'institution',
  FormAudienceRuleKind.unit: 'unit',
  FormAudienceRuleKind.group: 'group',
  FormAudienceRuleKind.activity: 'activity',
  FormAudienceRuleKind.guardian: 'guardian',
  FormAudienceRuleKind.teacher: 'teacher',
  FormAudienceRuleKind.employee: 'employee',
  FormAudienceRuleKind.profile: 'profile',
  FormAudienceRuleKind.person: 'person',
};
