import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../data/fake_notice_repository.dart';
import '../domain/platform_notice.dart';

enum NoticeFormStep { identity, content, audience, schedule, review }

extension NoticeFormStepLabel on NoticeFormStep {
  String get label => switch (this) {
    NoticeFormStep.identity => 'Identidade',
    NoticeFormStep.content => 'Conteúdo e aparência',
    NoticeFormStep.audience => 'Público e dispositivos',
    NoticeFormStep.schedule => 'Exibição e recorrência',
    NoticeFormStep.review => 'Revisão e publicação',
  };
}

final class NoticeFormController extends ChangeNotifier {
  NoticeFormController({required this.repository, String? noticeId}) {
    final notice = noticeId == null ? null : repository.find(noticeId);
    savedNotice = notice;
    titleController = TextEditingController(text: notice?.title ?? '');
    messageController = TextEditingController(text: notice?.message ?? '');
    audienceLabelController = TextEditingController(text: notice?.audienceLabel ?? 'Todos');
    audienceRoleLabelController = TextEditingController(text: notice?.audienceRoleLabel ?? '');
    buttonLabelController = TextEditingController(text: notice?.buttonLabel ?? 'Confirmar');
    intervalDaysController = TextEditingController(text: notice?.intervalDays?.toString() ?? '');
    dayOfMonthController = TextEditingController(text: notice?.dayOfMonth?.toString() ?? '');
    priority = notice?.priority ?? NoticePriority.important;
    contentFormat = notice?.contentFormat ?? NoticeContentFormat.textBackground;
    audience = _allowedAudiences.contains(notice?.audience)
        ? notice!.audience
        : NoticeAudience.everyone;
    targetDevice = notice?.targetDevice ?? NoticeTargetDevice.all;
    behavior = notice?.behavior ?? NoticeBehavior.confirmation;
    recurrence = notice?.recurrence ?? NoticeRecurrence.oneTime;
    imageOrientation = notice?.imageOrientation ?? NoticeImageOrientation.vertical;
    showImagePlaceholder = notice?.showImagePlaceholder ?? false;
    startsAt = notice?.startsAt ?? DateTime.now();
    endsAt = notice?.endsAt;
    recurrenceUntil = notice?.recurrenceUntil;
    selectedWeekdays.addAll(notice?.weeklyDays ?? const <int>[]);
    backgroundColor = notice?.backgroundColorValue == null
        ? const Color(0xFFD63C00)
        : Color(notice!.backgroundColorValue!);
    textColor = notice?.textColorValue == null
        ? const Color(0xFFFFFFFF)
        : Color(notice!.textColorValue!);
    for (final controller in _textControllers) {
      controller.addListener(_onTextChanged);
    }
  }

  static const allowedAudiences = <NoticeAudience>[
    NoticeAudience.everyone,
    NoticeAudience.institution,
    NoticeAudience.unit,
    NoticeAudience.group,
  ];
  static const _allowedAudiences = allowedAudiences;

  final FakeNoticeRepository repository;
  late final TextEditingController titleController;
  late final TextEditingController messageController;
  late final TextEditingController audienceLabelController;
  late final TextEditingController audienceRoleLabelController;
  late final TextEditingController buttonLabelController;
  late final TextEditingController intervalDaysController;
  late final TextEditingController dayOfMonthController;

  NoticeFormStep currentStep = NoticeFormStep.identity;
  int furthestStep = 0;
  final Set<NoticeFormStep> stepsWithErrors = {};
  PlatformNotice? savedNotice;
  late NoticePriority priority;
  late NoticeContentFormat contentFormat;
  late NoticeAudience audience;
  late NoticeTargetDevice targetDevice;
  late NoticeBehavior behavior;
  late NoticeRecurrence recurrence;
  late NoticeImageOrientation imageOrientation;
  late bool showImagePlaceholder;
  late DateTime startsAt;
  DateTime? endsAt;
  DateTime? recurrenceUntil;
  final Set<int> selectedWeekdays = {};
  late Color backgroundColor;
  late Color textColor;

  List<TextEditingController> get _textControllers => [
    titleController,
    messageController,
    audienceLabelController,
    audienceRoleLabelController,
    buttonLabelController,
    intervalDaysController,
    dayOfMonthController,
  ];

  bool get isEditing => savedNotice != null;
  bool get isReviewStep => currentStep == NoticeFormStep.review;
  double get contrastRatio {
    final high = math.max(backgroundColor.computeLuminance(), textColor.computeLuminance());
    final low = math.min(backgroundColor.computeLuminance(), textColor.computeLuminance());
    return (high + 0.05) / (low + 0.05);
  }

  bool get hasAccessibleContrast => contrastRatio >= 4.5;

  SuperadminFormStepStatus statusFor(NoticeFormStep step) {
    if (stepsWithErrors.contains(step)) return SuperadminFormStepStatus.error;
    if (step == currentStep) return SuperadminFormStepStatus.current;
    if (step.index < currentStep.index || step.index < furthestStep) {
      return SuperadminFormStepStatus.complete;
    }
    return SuperadminFormStepStatus.incomplete;
  }

  bool validate(NoticeFormStep step) => switch (step) {
    NoticeFormStep.identity => titleController.text.trim().isNotEmpty,
    NoticeFormStep.content => messageController.text.trim().isNotEmpty,
    NoticeFormStep.audience =>
      _allowedAudiences.contains(audience) && audienceLabelController.text.trim().isNotEmpty,
    NoticeFormStep.schedule =>
      (endsAt == null || !endsAt!.isBefore(startsAt)) &&
          (recurrenceUntil == null || !recurrenceUntil!.isBefore(startsAt)) &&
          switch (recurrence) {
            NoticeRecurrence.oneTime || NoticeRecurrence.daily => true,
            NoticeRecurrence.weekly =>
              selectedWeekdays.isNotEmpty && selectedWeekdays.every((day) => day >= 1 && day <= 7),
            NoticeRecurrence.monthly => _validInteger(dayOfMonthController, 1, 31),
            NoticeRecurrence.interval => _validInteger(intervalDaysController, 1, 30),
          },
    NoticeFormStep.review => NoticeFormStep.values.take(4).every(validate) && hasAccessibleContrast,
  };

  bool validateAll({bool requireContrast = false}) {
    NoticeFormStep? firstInvalid;
    for (final step in NoticeFormStep.values.take(4)) {
      if (validate(step)) {
        stepsWithErrors.remove(step);
      } else {
        stepsWithErrors.add(step);
        firstInvalid ??= step;
      }
    }
    if (requireContrast && !hasAccessibleContrast) {
      stepsWithErrors.add(NoticeFormStep.review);
      firstInvalid ??= NoticeFormStep.review;
    } else {
      stepsWithErrors.remove(NoticeFormStep.review);
    }
    if (firstInvalid != null) {
      currentStep = firstInvalid;
      furthestStep = math.max(furthestStep, firstInvalid.index);
    }
    notifyListeners();
    return firstInvalid == null;
  }

  bool continueFromCurrentStep() {
    if (!validate(currentStep)) {
      stepsWithErrors.add(currentStep);
      notifyListeners();
      return false;
    }
    stepsWithErrors.remove(currentStep);
    if (isReviewStep) {
      notifyListeners();
      return true;
    }
    final nextIndex = math.min(currentStep.index + 1, NoticeFormStep.values.length - 1);
    currentStep = NoticeFormStep.values[nextIndex];
    furthestStep = math.max(furthestStep, nextIndex);
    notifyListeners();
    return true;
  }

  void previousStep() {
    if (currentStep.index == 0) return;
    currentStep = NoticeFormStep.values[currentStep.index - 1];
    notifyListeners();
  }

  void goToStep(int index) {
    if (index < 0 || index >= NoticeFormStep.values.length || index > furthestStep) return;
    currentStep = NoticeFormStep.values[index];
    notifyListeners();
  }

  void setPriority(NoticePriority value) => _set(() => priority = value);
  void setContentFormat(NoticeContentFormat value) => _set(() {
    contentFormat = value;
    if (value != NoticeContentFormat.image) showImagePlaceholder = false;
  });
  void setAudience(NoticeAudience value) => _set(() => audience = value);
  void setTargetDevice(NoticeTargetDevice value) => _set(() => targetDevice = value);
  void setBehavior(NoticeBehavior value) => _set(() => behavior = value);
  void setImageOrientation(NoticeImageOrientation value) => _set(() => imageOrientation = value);
  void setShowImagePlaceholder(bool value) => _set(() => showImagePlaceholder = value);
  void setStartsAt(DateTime value) => _set(() => startsAt = value);
  void setEndsAt(DateTime? value) => _set(() => endsAt = value);
  void setRecurrenceUntil(DateTime? value) => _set(() => recurrenceUntil = value);
  void setBackgroundColor(Color value) => _set(() => backgroundColor = value);
  void setTextColor(Color value) => _set(() => textColor = value);
  void setSelectedWeekdays(Set<int> values) => _set(() {
    selectedWeekdays
      ..clear()
      ..addAll(values);
  });
  void setRecurrence(NoticeRecurrence value) => _set(() {
    recurrence = value;
    intervalDaysController.clear();
    dayOfMonthController.clear();
    selectedWeekdays.clear();
    if (value == NoticeRecurrence.oneTime) recurrenceUntil = null;
  });
  void recordSaved(PlatformNotice notice) => _set(() => savedNotice = notice);

  NoticeDraft get draft {
    final role = audienceRoleLabelController.text.trim();
    return NoticeDraft(
      title: titleController.text.trim(),
      message: messageController.text.trim(),
      priority: priority,
      audience: audience,
      audienceLabel: audienceLabelController.text.trim(),
      audienceRoleLabel: role.isEmpty ? null : role,
      behavior: behavior,
      mandatory: behavior != NoticeBehavior.dismissible,
      targetDevice: targetDevice,
      contentFormat: contentFormat,
      backgroundColorValue: backgroundColor.toARGB32(),
      textColorValue: textColor.toARGB32(),
      buttonLabel: buttonLabelController.text.trim().isEmpty
          ? 'Confirmar'
          : buttonLabelController.text.trim(),
      recurrence: recurrence,
      intervalDays: recurrence == NoticeRecurrence.interval
          ? int.tryParse(intervalDaysController.text.trim())
          : null,
      weeklyDays: recurrence == NoticeRecurrence.weekly
          ? (List<int>.of(selectedWeekdays)..sort())
          : const [],
      dayOfMonth: recurrence == NoticeRecurrence.monthly
          ? int.tryParse(dayOfMonthController.text.trim())
          : null,
      recurrenceUntil: recurrence == NoticeRecurrence.oneTime ? null : recurrenceUntil,
      imageOrientation: imageOrientation,
      showImagePlaceholder: contentFormat == NoticeContentFormat.image && showImagePlaceholder,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  PlatformNotice get previewNotice {
    final saved = savedNotice;
    final value = draft;
    return PlatformNotice(
      id: saved?.id ?? 'notice-preview',
      title: value.title.isEmpty ? 'Prévia do aviso' : value.title,
      message: value.message.isEmpty ? 'Mensagem do aviso.' : value.message,
      priority: value.priority,
      status: saved?.status ?? NoticeStatus.draft,
      startsAt: value.startsAt ?? DateTime.now(),
      endsAt: value.endsAt,
      audience: value.audience,
      audienceLabel: value.audienceLabel,
      audienceRoleLabel: value.audienceRoleLabel,
      behavior: value.behavior,
      mandatory: value.behavior != NoticeBehavior.dismissible,
      targetDevice: value.targetDevice,
      contentFormat: value.contentFormat,
      backgroundColorValue: value.backgroundColorValue,
      textColorValue: value.textColorValue,
      reach: saved?.reach ?? 0,
      deliveredCount: saved?.deliveredCount ?? 0,
      viewedCount: saved?.viewedCount ?? 0,
      acceptedCount: saved?.acceptedCount ?? 0,
      recurrence: value.recurrence,
      intervalDays: value.intervalDays,
      weeklyDays: value.weeklyDays,
      dayOfMonth: value.dayOfMonth,
      recurrenceUntil: value.recurrenceUntil,
      imageOrientation: value.imageOrientation,
      showImagePlaceholder: value.showImagePlaceholder,
      buttonLabel: value.buttonLabel,
    );
  }

  void _set(VoidCallback mutation) {
    mutation();
    notifyListeners();
  }

  void _onTextChanged() => notifyListeners();

  static bool _validInteger(TextEditingController controller, int min, int max) {
    final value = int.tryParse(controller.text.trim());
    return value != null && value >= min && value <= max;
  }

  @override
  void dispose() {
    for (final controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
