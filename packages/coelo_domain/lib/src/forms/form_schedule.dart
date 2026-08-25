enum FormRecurrenceKind { once, daily, weekly, monthly }

sealed class FormRecurrence {
  const FormRecurrence({required this.kind, required this.interval}) : assert(interval > 0);

  const factory FormRecurrence.once() = FormOnceRecurrence;
  const factory FormRecurrence.daily({required int interval}) = FormDailyRecurrence;
  const factory FormRecurrence.weekly({required int interval, required Set<int> weekdays}) =
      FormWeeklyRecurrence;
  const factory FormRecurrence.monthly({required int interval, bool useLastDay, int? day}) =
      FormMonthlyRecurrence;

  final FormRecurrenceKind kind;
  final int interval;
}

final class FormOnceRecurrence extends FormRecurrence {
  const FormOnceRecurrence() : super(kind: FormRecurrenceKind.once, interval: 1);
}

final class FormDailyRecurrence extends FormRecurrence {
  const FormDailyRecurrence({required super.interval}) : super(kind: FormRecurrenceKind.daily);
}

final class FormWeeklyRecurrence extends FormRecurrence {
  const FormWeeklyRecurrence({required super.interval, required this.weekdays})
    : super(kind: FormRecurrenceKind.weekly);

  final Set<int> weekdays;
}

final class FormMonthlyRecurrence extends FormRecurrence {
  const FormMonthlyRecurrence({required super.interval, this.useLastDay = false, this.day})
    : assert(useLastDay || (day != null && day >= 1 && day <= 31)),
      super(kind: FormRecurrenceKind.monthly);

  final bool useLastDay;
  final int? day;
}

sealed class FormScheduleEnd {
  const FormScheduleEnd();
  const factory FormScheduleEnd.never() = FormScheduleNeverEnds;
  const factory FormScheduleEnd.onDate(DateTime date) = FormScheduleEndsOnDate;
  const factory FormScheduleEnd.afterOccurrences(int count) = FormScheduleEndsAfterOccurrences;
}

final class FormScheduleNeverEnds extends FormScheduleEnd {
  const FormScheduleNeverEnds();
}

final class FormScheduleEndsOnDate extends FormScheduleEnd {
  const FormScheduleEndsOnDate(this.date);
  final DateTime date;
}

final class FormScheduleEndsAfterOccurrences extends FormScheduleEnd {
  const FormScheduleEndsAfterOccurrences(this.count) : assert(count > 0);
  final int count;
}

final class FormSchedule {
  const FormSchedule({
    required this.startsAtLocal,
    required this.timeZone,
    required this.recurrence,
    required this.end,
  }) : assert(timeZone != '');

  final DateTime startsAtLocal;
  final String timeZone;
  final FormRecurrence recurrence;
  final FormScheduleEnd end;
}

final class FormLocalOccurrence {
  const FormLocalOccurrence({required this.localDateTime, required this.timeZone});
  final DateTime localDateTime;
  final String timeZone;
}

final class FormScheduleCalculator {
  const FormScheduleCalculator();

  List<FormLocalOccurrence> next(FormSchedule schedule, {required int limit}) {
    if (limit <= 0) return const [];
    final maximum = switch (schedule.end) {
      FormScheduleEndsAfterOccurrences value => value.count < limit ? value.count : limit,
      _ => limit,
    };
    final values = <FormLocalOccurrence>[];
    var candidate = schedule.startsAtLocal;
    var attempts = 0;
    while (values.length < maximum && attempts < 36600) {
      attempts++;
      if (_pastEnd(candidate, schedule.end)) break;
      if (_matches(candidate, schedule)) {
        values.add(FormLocalOccurrence(localDateTime: candidate, timeZone: schedule.timeZone));
      }
      if (schedule.recurrence is FormMonthlyRecurrence) {
        candidate = _nextMonthly(schedule, values.length);
      } else {
        candidate = candidate.add(const Duration(days: 1));
      }
      if (schedule.recurrence is FormOnceRecurrence && values.isNotEmpty) break;
    }
    return List.unmodifiable(values);
  }

  bool _pastEnd(DateTime candidate, FormScheduleEnd end) => switch (end) {
    FormScheduleEndsOnDate value => candidate.isAfter(_endOfDay(value.date)),
    _ => false,
  };

  bool _matches(DateTime candidate, FormSchedule schedule) {
    final days = _date(candidate).difference(_date(schedule.startsAtLocal)).inDays;
    return switch (schedule.recurrence) {
      FormOnceRecurrence() => days == 0,
      FormDailyRecurrence value => days % value.interval == 0,
      FormWeeklyRecurrence value =>
        (days ~/ 7) % value.interval == 0 && value.weekdays.contains(candidate.weekday),
      FormMonthlyRecurrence() => true,
    };
  }

  DateTime _nextMonthly(FormSchedule schedule, int emittedCount) {
    final recurrence = schedule.recurrence as FormMonthlyRecurrence;
    final monthOffset = emittedCount * recurrence.interval;
    final month = DateTime(schedule.startsAtLocal.year, schedule.startsAtLocal.month + monthOffset);
    final requestedDay = recurrence.useLastDay
        ? DateTime(month.year, month.month + 1, 0).day
        : recurrence.day!;
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = requestedDay > lastDay ? lastDay : requestedDay;
    return DateTime(
      month.year,
      month.month,
      day,
      schedule.startsAtLocal.hour,
      schedule.startsAtLocal.minute,
      schedule.startsAtLocal.second,
    );
  }
}

DateTime _date(DateTime value) => DateTime(value.year, value.month, value.day);
DateTime _endOfDay(DateTime value) => DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
