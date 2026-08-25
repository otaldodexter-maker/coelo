import 'form_schedule.dart';

enum FormAudienceRuleKind {
  institution,
  unit,
  group,
  activity,
  guardian,
  teacher,
  employee,
  profile,
  person,
}

enum FormAudienceRuleMode { include, exclude }

enum FormApplicationStatus { active, paused, archived }

enum FormScheduleStatus { active, archived }

final class FormAudienceRule {
  const FormAudienceRule({
    required this.id,
    required this.kind,
    required this.mode,
    required this.targetId,
  });

  final String id;
  final FormAudienceRuleKind kind;
  final FormAudienceRuleMode mode;
  final String targetId;
}

final class FormApplication {
  FormApplication({
    required this.id,
    required this.formId,
    required this.institutionId,
    required this.name,
    this.status = FormApplicationStatus.active,
    this.opensForDays = 7,
    required List<FormAudienceRule> audienceRules,
    List<FormApplicationSchedule> schedules = const [],
    required this.managementVersion,
  }) : audienceRules = List.unmodifiable(audienceRules),
       schedules = List.unmodifiable(schedules);

  final String id;
  final String formId;
  final String institutionId;
  final String name;
  final FormApplicationStatus status;
  final int opensForDays;
  final List<FormAudienceRule> audienceRules;
  final List<FormApplicationSchedule> schedules;
  final int managementVersion;
}

final class FormApplicationSchedule {
  FormApplicationSchedule({
    required this.id,
    this.status = FormScheduleStatus.active,
    required this.schedule,
    List<FormReminder> reminders = const [],
    required this.managementVersion,
  }) : reminders = List.unmodifiable(reminders);

  final String id;
  final FormScheduleStatus status;
  final FormSchedule schedule;
  final List<FormReminder> reminders;
  final int managementVersion;
}

enum FormReminderKind { onOpen, beforeClose, everyDays }

final class FormReminder {
  const FormReminder({required this.kind, this.amount});
  final FormReminderKind kind;
  final int? amount;
}

enum FormOccurrenceStatus { scheduled, open, closed, cancelled }

final class FormOccurrence {
  const FormOccurrence({
    required this.id,
    required this.applicationId,
    required this.formVersionId,
    required this.opensAt,
    required this.closesAt,
    required this.status,
    required this.managementVersion,
  });

  final String id;
  final String applicationId;
  final String formVersionId;
  final DateTime opensAt;
  final DateTime closesAt;
  final FormOccurrenceStatus status;
  final int managementVersion;
}
