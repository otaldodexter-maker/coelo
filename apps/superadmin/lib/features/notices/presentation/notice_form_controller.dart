import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../domain/notice_repository.dart';
import '../domain/platform_notice.dart';

final class _PendingNoticeSave {
  const _PendingNoticeSave({
    required this.requestId,
    required this.draft,
    required this.fingerprint,
    required this.noticeId,
    required this.expectedVersion,
  });

  final String requestId;
  final NoticeDraft draft;
  final String fingerprint;
  final String? noticeId;
  final int? expectedVersion;
}

final class _PendingNoticePublish {
  const _PendingNoticePublish({
    required this.requestId,
    required this.notice,
    required this.draftFingerprint,
  });

  final String requestId;
  final PlatformNotice notice;
  final String draftFingerprint;
}

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
    _noticeId = noticeId;
    titleController = TextEditingController();
    messageController = TextEditingController();
    audienceLabelController = TextEditingController(text: 'Todos');
    buttonLabelController = TextEditingController(text: 'Confirmar');
    intervalDaysController = TextEditingController();
    dayOfMonthController = TextEditingController();
    priority = NoticePriority.important;
    type = CommunicationType.notice;
    contentFormat = NoticeContentFormat.textBackground;
    audience = NoticeAudience.everyone;
    targetDevice = NoticeTargetDevice.all;
    behavior = NoticeBehavior.confirmation;
    recurrence = NoticeRecurrence.oneTime;
    imageOrientation = NoticeImageOrientation.vertical;
    startsAt = DateTime.now();
    backgroundColor = const Color(0xFFD63C00);
    textColor = const Color(0xFFFFFFFF);
    buttonColor = const Color(0xFFD63C00);
    popupSize = NoticePopupSize.standard;
    hasOuterInset = true;
    for (final controller in _textControllers) {
      controller.addListener(_onTextChanged);
    }
    ready = noticeId == null ? Future.value() : _load(noticeId);
  }

  static const allowedAudiences = <NoticeAudience>[
    NoticeAudience.everyone,
    NoticeAudience.institution,
    NoticeAudience.unit,
    NoticeAudience.group,
  ];
  static const _allowedAudiences = allowedAudiences;

  final NoticeRepository repository;
  late final Future<void> ready;
  String? _noticeId;
  late final TextEditingController titleController;
  late final TextEditingController messageController;
  late final TextEditingController audienceLabelController;
  late final TextEditingController buttonLabelController;
  late final TextEditingController intervalDaysController;
  late final TextEditingController dayOfMonthController;

  NoticeFormStep currentStep = NoticeFormStep.identity;
  int furthestStep = 0;
  final Set<NoticeFormStep> stepsWithErrors = {};
  PlatformNotice? savedNotice;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  NoticeRepositoryException? loadFailure;
  late NoticePriority priority;
  late CommunicationType type;
  late NoticeContentFormat contentFormat;
  late NoticeAudience audience;
  late NoticeTargetDevice targetDevice;
  late NoticeBehavior behavior;
  late NoticeRecurrence recurrence;
  late NoticeImageOrientation imageOrientation;
  late DateTime startsAt;
  DateTime? endsAt;
  DateTime? recurrenceUntil;
  final Set<int> selectedWeekdays = {};
  late Color backgroundColor;
  late Color textColor;
  late Color buttonColor;
  late NoticePopupSize popupSize;
  late bool hasOuterInset;
  NoticeAudienceSelection audienceSelection = const NoticeAudienceSelection(
    rules: [NoticeAudienceRule(dimension: NoticeAudienceDimension.platform, selectAll: true)],
  );
  List<NoticeAudienceOption> audienceOptions = const [];
  bool isLoadingAudience = false;
  String? audienceErrorMessage;
  String? _saveRequestId;
  _PendingNoticeSave? _pendingSave;
  _PendingNoticePublish? _pendingPublish;
  int _audienceLoadGeneration = 0;
  int _loadGeneration = 0;
  int _commandGeneration = 0;
  bool _isDisposed = false;
  bool _isApplyingNotice = false;
  String _audienceSearch = '';
  String? _audienceNextCursorLabel;
  String? _audienceNextCursorId;

  List<TextEditingController> get _textControllers => [
    titleController,
    messageController,
    audienceLabelController,
    buttonLabelController,
    intervalDaysController,
    dayOfMonthController,
  ];

  bool get isEditing => _noticeId != null;
  bool get isReviewStep => currentStep == NoticeFormStep.review;
  double get contrastRatio {
    final high = math.max(backgroundColor.computeLuminance(), textColor.computeLuminance());
    final low = math.min(backgroundColor.computeLuminance(), textColor.computeLuminance());
    return (high + 0.05) / (low + 0.05);
  }

  bool get hasAccessibleContrast => contrastRatio >= 4.5;
  bool get hasMoreAudienceOptions =>
      _audienceNextCursorLabel != null && _audienceNextCursorId != null;

  Future<void> _load(String noticeId) async {
    final generation = ++_loadGeneration;
    final requestedRepository = repository;
    isLoading = true;
    errorMessage = null;
    loadFailure = null;
    notifyListeners();
    try {
      final notice = await requestedRepository.getById(noticeId);
      if (!_isCurrentLoad(generation, requestedRepository, noticeId)) return;
      if (notice.id != noticeId) {
        throw const NoticeUnexpectedException();
      }
      _applyNotice(notice);
      await loadAudienceOptions();
    } on NoticeRepositoryException catch (error) {
      if (!_isCurrentLoad(generation, requestedRepository, noticeId)) return;
      loadFailure = error;
    } on Object {
      if (!_isCurrentLoad(generation, requestedRepository, noticeId)) return;
      loadFailure = const NoticeUnexpectedException();
    } finally {
      if (_isCurrentLoad(generation, requestedRepository, noticeId)) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  bool get canRetryLoad =>
      _noticeId != null &&
      loadFailure != null &&
      loadFailure is! NoticeUnauthorizedException &&
      loadFailure is! NoticeNotFoundException;

  Future<void> retryLoad() {
    final noticeId = _noticeId;
    if (noticeId == null || !canRetryLoad) return Future.value();
    return _load(noticeId);
  }

  bool _isCurrentLoad(int generation, NoticeRepository requestedRepository, String noticeId) =>
      !_isDisposed &&
      generation == _loadGeneration &&
      identical(requestedRepository, repository) &&
      noticeId == _noticeId;

  void _applyNotice(PlatformNotice notice) {
    _isApplyingNotice = true;
    try {
      savedNotice = notice;
      _noticeId = notice.id;
      titleController.text = notice.title;
      messageController.text = notice.message;
      audienceLabelController.text = notice.audienceLabel;
      buttonLabelController.text = notice.buttonLabel;
      intervalDaysController.text = notice.intervalDays?.toString() ?? '';
      dayOfMonthController.text = notice.dayOfMonth?.toString() ?? '';
      priority = notice.priority;
      type = notice.type;
      contentFormat = notice.contentFormat;
      audience = _allowedAudiences.contains(notice.audience)
          ? notice.audience
          : NoticeAudience.everyone;
      targetDevice = notice.targetDevice;
      behavior = notice.behavior;
      recurrence = notice.recurrence;
      imageOrientation = notice.imageOrientation;
      startsAt = notice.startsAt;
      endsAt = notice.endsAt;
      recurrenceUntil = notice.recurrenceUntil;
      selectedWeekdays
        ..clear()
        ..addAll(notice.weeklyDays);
      backgroundColor = notice.backgroundColorValue == null
          ? const Color(0xFFD63C00)
          : Color(notice.backgroundColorValue!);
      textColor = notice.textColorValue == null
          ? const Color(0xFFFFFFFF)
          : Color(notice.textColorValue!);
      buttonColor = notice.buttonColorValue == null
          ? const Color(0xFFD63C00)
          : Color(notice.buttonColorValue!);
      popupSize = notice.popupSize;
      hasOuterInset = notice.hasOuterInset;
      audienceSelection = notice.audienceSelection;
    } finally {
      _isApplyingNotice = false;
    }
  }

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
    NoticeFormStep.content =>
      messageController.text.trim().isNotEmpty &&
          contentFormat == NoticeContentFormat.textBackground,
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
  });
  void setAudience(NoticeAudience value) {
    _set(() {
      audience = value;
      audienceSelection = value == NoticeAudience.everyone
          ? const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(dimension: NoticeAudienceDimension.platform, selectAll: true),
              ],
            )
          : const NoticeAudienceSelection();
      audienceLabelController.text = value == NoticeAudience.everyone ? 'Todos' : '';
      audienceOptions = const [];
      _audienceSearch = '';
      _audienceNextCursorLabel = null;
      _audienceNextCursorId = null;
      _audienceLoadGeneration += 1;
    });
    if (value != NoticeAudience.everyone) loadAudienceOptions();
  }

  void setTargetDevice(NoticeTargetDevice value) => _set(() => targetDevice = value);
  void setType(CommunicationType value) => _set(() {
    type = value;
    if (value != CommunicationType.notice) {
      behavior = NoticeBehavior.dismissible;
      popupSize = NoticePopupSize.standard;
      hasOuterInset = true;
    }
  });
  void setBehavior(NoticeBehavior value) => _set(() => behavior = value);
  void setImageOrientation(NoticeImageOrientation value) => _set(() => imageOrientation = value);
  void setStartsAt(DateTime value) => _set(() => startsAt = value);
  void setEndsAt(DateTime? value) => _set(() => endsAt = value);
  void setRecurrenceUntil(DateTime? value) => _set(() => recurrenceUntil = value);
  void setBackgroundColor(Color value) => _set(() => backgroundColor = value);
  void setTextColor(Color value) => _set(() => textColor = value);
  void setButtonColor(Color value) => _set(() => buttonColor = value);
  void setPopupSize(NoticePopupSize value) => _set(() {
    popupSize = value;
    if (value == NoticePopupSize.fullscreen) hasOuterInset = false;
  });
  void setHasOuterInset(bool value) => _set(() {
    if (popupSize != NoticePopupSize.fullscreen) hasOuterInset = value;
  });
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

  Future<void> loadAudienceOptions({String? search}) async {
    final dimension = _dimensionFor(audience);
    if (dimension == NoticeAudienceDimension.platform) return;
    final normalizedSearch = search?.trim() ?? _audienceSearch;
    final searchChanged = normalizedSearch != _audienceSearch;
    if (searchChanged) _resetSelectAllSelection();
    _audienceSearch = normalizedSearch;
    _audienceNextCursorLabel = null;
    _audienceNextCursorId = null;
    final generation = ++_audienceLoadGeneration;
    isLoadingAudience = true;
    audienceErrorMessage = null;
    notifyListeners();
    try {
      final page = await repository.fetchAudienceOptions(
        dimension: dimension,
        search: normalizedSearch.isEmpty ? null : normalizedSearch,
      );
      if (generation != _audienceLoadGeneration) return;
      audienceOptions = page.items;
      _audienceNextCursorLabel = page.nextCursorLabel;
      _audienceNextCursorId = page.nextCursorId;
    } on NoticeRepositoryException catch (error) {
      if (generation != _audienceLoadGeneration) return;
      audienceErrorMessage = error.safeMessage;
    } on Object {
      if (generation != _audienceLoadGeneration) return;
      audienceErrorMessage = const NoticeUnexpectedException().safeMessage;
    } finally {
      if (generation == _audienceLoadGeneration) {
        isLoadingAudience = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreAudienceOptions() async {
    final dimension = _dimensionFor(audience);
    final cursorLabel = _audienceNextCursorLabel;
    final cursorId = _audienceNextCursorId;
    if (dimension == NoticeAudienceDimension.platform ||
        cursorLabel == null ||
        cursorId == null ||
        isLoadingAudience) {
      return;
    }
    final generation = ++_audienceLoadGeneration;
    isLoadingAudience = true;
    audienceErrorMessage = null;
    notifyListeners();
    try {
      final page = await repository.fetchAudienceOptions(
        dimension: dimension,
        search: _audienceSearch.isEmpty ? null : _audienceSearch,
        cursorLabel: cursorLabel,
        cursorId: cursorId,
      );
      if (generation != _audienceLoadGeneration) return;
      final knownIds = audienceOptions.map((option) => option.id).toSet();
      audienceOptions = [
        ...audienceOptions,
        ...page.items.where((option) => knownIds.add(option.id)),
      ];
      _audienceNextCursorLabel = page.nextCursorLabel;
      _audienceNextCursorId = page.nextCursorId;
    } on NoticeRepositoryException catch (error) {
      if (generation != _audienceLoadGeneration) return;
      audienceErrorMessage = error.safeMessage;
    } on Object {
      if (generation != _audienceLoadGeneration) return;
      audienceErrorMessage = const NoticeUnexpectedException().safeMessage;
    } finally {
      if (generation == _audienceLoadGeneration) {
        isLoadingAudience = false;
        notifyListeners();
      }
    }
  }

  void setAudienceTargets({
    required bool selectAll,
    required Set<String> selectedIds,
    required Set<String> excludedIds,
  }) => _set(() {
    final dimension = _dimensionFor(audience);
    audienceSelection = NoticeAudienceSelection(
      rules: [
        NoticeAudienceRule(
          dimension: dimension,
          selectAll: selectAll,
          targetIds: selectedIds.toList(growable: false),
          excludedIds: excludedIds.toList(growable: false),
          filters: selectAll && _audienceSearch.isNotEmpty
              ? {
                  'search': [_audienceSearch],
                }
              : const {},
        ),
      ],
    );
    if (selectAll) {
      audienceLabelController.text = 'Todos os resultados';
    } else {
      final selectedLabels = audienceOptions
          .where((option) => selectedIds.contains(option.id))
          .map((option) => option.label)
          .toList(growable: false);
      audienceLabelController.text = selectedLabels.join(', ');
    }
  });

  void _resetSelectAllSelection() {
    if (audienceSelection.rules case [final rule] when rule.selectAll) {
      audienceSelection = NoticeAudienceSelection(
        rules: [NoticeAudienceRule(dimension: rule.dimension, selectAll: false)],
        roleCodes: audienceSelection.roleCodes,
        planIds: audienceSelection.planIds,
      );
      audienceLabelController.clear();
      _invalidatePendingCommands();
    }
  }

  NoticeDraft get draft {
    return NoticeDraft(
      type: type,
      title: titleController.text.trim(),
      message: messageController.text.trim(),
      priority: priority,
      audience: audience,
      audienceLabel: audienceLabelController.text.trim(),
      audienceRoleLabel: savedNotice?.audienceRoleLabel,
      behavior: behavior,
      mandatory: behavior != NoticeBehavior.dismissible,
      targetDevice: targetDevice,
      contentFormat: contentFormat,
      backgroundColorValue: backgroundColor.toARGB32(),
      textColorValue: textColor.toARGB32(),
      buttonColorValue: buttonColor.toARGB32(),
      popupSize: popupSize,
      hasOuterInset: hasOuterInset,
      audienceSelection: audienceSelection,
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
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  PlatformNotice get previewNotice {
    final saved = savedNotice;
    final value = draft;
    return PlatformNotice(
      type: value.type,
      id: saved?.id ?? 'notice-preview',
      title: value.title,
      message: value.message,
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
      buttonColorValue: value.buttonColorValue,
      popupSize: value.popupSize,
      hasOuterInset: value.hasOuterInset,
      audienceSelection: value.audienceSelection,
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
      buttonLabel: value.buttonLabel,
    );
  }

  Future<PlatformNotice?> saveDraft() async {
    if (isSaving) return null;
    final generation = ++_commandGeneration;
    final requestedRepository = repository;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      if (_pendingSave case final pending?) {
        final receipt = await _submitSave(requestedRepository, pending);
        if (!_canFinishCommand(requestedRepository)) return null;
        _validateSaveReceipt(pending, receipt);
        final unchanged = pending.fingerprint == _draftFingerprint(draft);
        _pendingSave = null;
        _saveRequestId = null;
        _reconcileSaveReceipt(receipt);
        if (!_isCurrentCommand(generation, requestedRepository)) return null;
        if (unchanged) {
          _applyNotice(receipt);
          return receipt;
        }
      }

      final current = savedNotice;
      final requestedNoticeId = current?.id ?? _noticeId;
      final requestedDraft = draft;
      final intent = _PendingNoticeSave(
        requestId: _saveRequestId ??= _newRequestId(),
        draft: requestedDraft,
        fingerprint: _draftFingerprint(requestedDraft),
        noticeId: requestedNoticeId,
        expectedVersion: current?.managementVersion,
      );
      _pendingSave = intent;
      _saveRequestId = intent.requestId;
      final notice = await _submitSave(requestedRepository, intent);
      if (!_canFinishCommand(requestedRepository)) return null;
      _validateSaveReceipt(intent, notice);
      _pendingSave = null;
      _saveRequestId = null;
      _reconcileSaveReceipt(notice);
      if (!_isCurrentCommand(generation, requestedRepository)) return null;
      _applyNotice(notice);
      return notice;
    } on NoticeRepositoryException catch (error) {
      if (_isDeterministicCommandFailure(error)) {
        _pendingSave = null;
        _saveRequestId = null;
      }
      if (!_isCurrentCommand(generation, requestedRepository)) return null;
      errorMessage = error.safeMessage;
      return null;
    } on Object {
      if (!_isCurrentCommand(generation, requestedRepository)) return null;
      errorMessage = const NoticeUnexpectedException().safeMessage;
      return null;
    } finally {
      if (_canFinishCommand(requestedRepository)) {
        isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<PlatformNotice> _submitSave(
    NoticeRepository requestedRepository,
    _PendingNoticeSave intent,
  ) => requestedRepository.saveDraft(
    intent.draft,
    requestId: intent.requestId,
    noticeId: intent.noticeId,
    expectedVersion: intent.expectedVersion,
  );

  void _validateSaveReceipt(_PendingNoticeSave intent, PlatformNotice notice) {
    final expectedReceiptVersion = (intent.expectedVersion ?? -1) + 1;
    if ((intent.noticeId != null && notice.id != intent.noticeId) ||
        notice.managementVersion != expectedReceiptVersion) {
      _pendingSave = null;
      _saveRequestId = null;
      throw const NoticeUnexpectedException();
    }
  }

  void _reconcileSaveReceipt(PlatformNotice notice) {
    savedNotice = notice;
    _noticeId = notice.id;
  }

  bool _isDeterministicCommandFailure(NoticeRepositoryException error) =>
      error is NoticeUnauthorizedException ||
      error is NoticeNotFoundException ||
      error is NoticeConflictException ||
      error is NoticeValidationException ||
      error is NoticeMediaDecisionRequiredException;

  String _draftFingerprint(NoticeDraft value) => jsonEncode({
    'type': value.type.name,
    'title': value.title,
    'message': value.message,
    'priority': value.priority.name,
    'audience': value.audience.name,
    'audienceLabel': value.audienceLabel,
    'behavior': value.behavior.name,
    'mandatory': value.mandatory,
    'targetDevice': value.targetDevice.name,
    'contentFormat': value.contentFormat.name,
    'audienceRoleLabel': value.audienceRoleLabel,
    'backgroundColorValue': value.backgroundColorValue,
    'textColorValue': value.textColorValue,
    'buttonColorValue': value.buttonColorValue,
    'popupSize': value.popupSize.name,
    'hasOuterInset': value.hasOuterInset,
    'audienceSelection': value.audienceSelection.toJson(),
    'buttonLabel': value.buttonLabel,
    'linkLabel': value.linkLabel,
    'recurrence': value.recurrence.name,
    'intervalDays': value.intervalDays,
    'weeklyDays': value.weeklyDays,
    'dayOfMonth': value.dayOfMonth,
    'recurrenceUntil': value.recurrenceUntil?.toUtc().toIso8601String(),
    'imageOrientation': value.imageOrientation.name,
    'backgroundTone': value.backgroundTone.name,
    'textTone': value.textTone.name,
    'startsAt': value.startsAt?.toUtc().toIso8601String(),
    'endsAt': value.endsAt?.toUtc().toIso8601String(),
  });

  Future<PlatformNotice?> saveAndPublish() async {
    if (isSaving || _isDisposed) return null;
    if (_pendingPublish case final pending?) {
      final published = await _runPublishIntent(pending, applyFields: false);
      if (published == null) return null;
      if (pending.draftFingerprint == _draftFingerprint(draft)) {
        _applyNotice(published);
        return published;
      }
      return saveAndPublish();
    }

    final saved = await saveDraft();
    if (saved == null || _isDisposed) return null;
    final intent = _PendingNoticePublish(
      requestId: _newRequestId(),
      notice: saved,
      draftFingerprint: _draftFingerprint(draft),
    );
    return _runPublishIntent(intent, applyFields: true);
  }

  Future<PlatformNotice?> _runPublishIntent(
    _PendingNoticePublish intent, {
    required bool applyFields,
  }) async {
    final generation = ++_commandGeneration;
    final requestedRepository = repository;
    _pendingPublish = intent;
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final published = await requestedRepository.publish(
        intent.notice,
        requestId: intent.requestId,
        expectedVersion: intent.notice.managementVersion,
      );
      if (!_canFinishCommand(requestedRepository)) return null;
      _validatePublishReceipt(intent.notice, published);
      _pendingPublish = null;
      _reconcileSaveReceipt(published);
      if (!_isCurrentCommand(generation, requestedRepository)) return null;
      if (applyFields) _applyNotice(published);
      return published;
    } on NoticeRepositoryException catch (error) {
      if (_isDeterministicCommandFailure(error)) {
        _pendingPublish = null;
      }
      if (!_isCurrentCommand(generation, requestedRepository)) return null;
      errorMessage = error.safeMessage;
      return null;
    } on Object {
      if (!_isCurrentCommand(generation, requestedRepository)) return null;
      errorMessage = const NoticeUnexpectedException().safeMessage;
      return null;
    } finally {
      if (_canFinishCommand(requestedRepository)) {
        isSaving = false;
        notifyListeners();
      }
    }
  }

  void _validatePublishReceipt(PlatformNotice requested, PlatformNotice published) {
    final validStatus =
        published.status == NoticeStatus.active || published.status == NoticeStatus.scheduled;
    if (published.id != requested.id ||
        published.managementVersion != requested.managementVersion + 1 ||
        !validStatus) {
      _pendingPublish = null;
      throw const NoticeUnexpectedException();
    }
  }

  bool _isCurrentCommand(int generation, NoticeRepository requestedRepository) =>
      !_isDisposed &&
      generation == _commandGeneration &&
      identical(requestedRepository, repository);

  bool _canFinishCommand(NoticeRepository requestedRepository) =>
      !_isDisposed && identical(requestedRepository, repository);

  void _set(VoidCallback mutation) {
    _invalidatePendingCommands();
    mutation();
    notifyListeners();
  }

  void _onTextChanged() {
    if (_isApplyingNotice) return;
    _invalidatePendingCommands();
    notifyListeners();
  }

  void _invalidatePendingCommands() {
    _commandGeneration++;
    _saveRequestId = null;
  }

  static bool _validInteger(TextEditingController controller, int min, int max) {
    final value = int.tryParse(controller.text.trim());
    return value != null && value >= min && value <= max;
  }

  static NoticeAudienceDimension _dimensionFor(NoticeAudience audience) => switch (audience) {
    NoticeAudience.everyone || NoticeAudience.coeloTeam => NoticeAudienceDimension.platform,
    NoticeAudience.institution => NoticeAudienceDimension.institution,
    NoticeAudience.unit => NoticeAudienceDimension.unit,
    NoticeAudience.group => NoticeAudienceDimension.group,
    NoticeAudience.role => NoticeAudienceDimension.platform,
    NoticeAudience.person => NoticeAudienceDimension.person,
  };

  @override
  void dispose() {
    _isDisposed = true;
    _loadGeneration++;
    _commandGeneration++;
    _audienceLoadGeneration++;
    for (final controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

String _newRequestId() {
  final bytes = List<int>.generate(16, (_) => math.Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
