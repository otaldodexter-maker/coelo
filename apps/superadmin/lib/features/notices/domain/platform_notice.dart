enum CommunicationType { notice, content, highlight, forYou }

extension CommunicationTypeLabel on CommunicationType {
  String get label => switch (this) {
    CommunicationType.notice => 'Aviso',
    CommunicationType.content => 'Conteúdo',
    CommunicationType.highlight => 'Destaque',
    CommunicationType.forYou => 'Para você',
  };

  String get storageValue => switch (this) {
    CommunicationType.notice => 'popup',
    CommunicationType.content => 'content_card',
    CommunicationType.highlight => 'highlight',
    CommunicationType.forYou => 'for_you',
  };
}

CommunicationType communicationTypeFromStorage(Object? value) => switch (value?.toString()) {
  'content_card' || 'content' => CommunicationType.content,
  'highlight' => CommunicationType.highlight,
  'for_you' => CommunicationType.forYou,
  _ => CommunicationType.notice,
};

enum NoticeStatus { draft, scheduled, active, paused, ended, cancelled }

extension NoticeStatusLabel on NoticeStatus {
  String get label => switch (this) {
    NoticeStatus.draft => 'Rascunho',
    NoticeStatus.scheduled => 'Agendado',
    NoticeStatus.active => 'Ativo',
    NoticeStatus.paused => 'Pausado',
    NoticeStatus.ended => 'Expirado',
    NoticeStatus.cancelled => 'Inativo',
  };
}

enum NoticePriority { routine, important, urgent }

extension NoticePriorityLabel on NoticePriority {
  String get label => switch (this) {
    NoticePriority.routine => 'Rotina',
    NoticePriority.important => 'Importante',
    NoticePriority.urgent => 'Urgente',
  };
}

enum NoticeAudience { everyone, coeloTeam, institution, unit, group, role, person }

extension NoticeAudienceLabel on NoticeAudience {
  String get label => switch (this) {
    NoticeAudience.everyone => 'Todos',
    NoticeAudience.coeloTeam => 'Equipe Coelo',
    NoticeAudience.institution => 'Instituição',
    NoticeAudience.unit => 'Unidade',
    NoticeAudience.group => 'Turma',
    NoticeAudience.role => 'Papel',
    NoticeAudience.person => 'Pessoa',
  };
}

enum NoticeBehavior { dismissible, confirmation, checkboxConfirmation }

extension NoticeBehaviorLabel on NoticeBehavior {
  String get label => switch (this) {
    NoticeBehavior.dismissible => 'Apenas fechar',
    NoticeBehavior.confirmation => 'Confirmação obrigatória',
    NoticeBehavior.checkboxConfirmation => 'Checkbox de aceite + confirmar',
  };
}

enum NoticeContentFormat { textBackground, image }

extension NoticeContentFormatLabel on NoticeContentFormat {
  String get label => switch (this) {
    NoticeContentFormat.textBackground => 'Texto sobre fundo',
    NoticeContentFormat.image => 'Imagem',
  };
}

enum NoticeTargetDevice { all, web, mobile, tablet }

extension NoticeTargetDeviceLabel on NoticeTargetDevice {
  String get label => switch (this) {
    NoticeTargetDevice.all => 'Todos',
    NoticeTargetDevice.web => 'Web',
    NoticeTargetDevice.mobile => 'Mobile',
    NoticeTargetDevice.tablet => 'Tablet',
  };
}

enum NoticeRecurrence { oneTime, daily, weekly, monthly, interval }

extension NoticeRecurrenceLabel on NoticeRecurrence {
  String get label => switch (this) {
    NoticeRecurrence.oneTime => 'Única',
    NoticeRecurrence.daily => 'Diária',
    NoticeRecurrence.weekly => 'Semanal',
    NoticeRecurrence.monthly => 'Mensal',
    NoticeRecurrence.interval => 'Intervalo de dias',
  };
}

enum NoticeImageOrientation { vertical, horizontal }

extension NoticeImageOrientationLabel on NoticeImageOrientation {
  String get label => switch (this) {
    NoticeImageOrientation.vertical => 'Vertical',
    NoticeImageOrientation.horizontal => 'Horizontal',
  };
}

enum NoticeVisualTone { brand, dark, light, neutral, success, warning, danger }

enum NoticePopupSize { compact, standard, large, fullscreen }

enum NoticeAudienceDimension { platform, institution, unit, group, person, role, plan }

final class NoticeAudienceRule {
  const NoticeAudienceRule({
    required this.dimension,
    this.selectAll = false,
    this.targetIds = const [],
    this.excludedIds = const [],
    this.filters = const {},
  });

  final NoticeAudienceDimension dimension;
  final bool selectAll;
  final List<String> targetIds;
  final List<String> excludedIds;
  final Map<String, List<String>> filters;

  Map<String, Object?> toJson() => {
    'dimension': dimension.name,
    'select_all': selectAll,
    'target_ids': targetIds,
    'excluded_ids': excludedIds,
    'filters': filters,
  };

  factory NoticeAudienceRule.fromJson(Map<String, dynamic> json) => NoticeAudienceRule(
    dimension: NoticeAudienceDimension.values.firstWhere(
      (value) => value.name == json['dimension'],
      orElse: () => NoticeAudienceDimension.platform,
    ),
    selectAll: json['select_all'] as bool? ?? false,
    targetIds: _noticeStringList(json['target_ids']),
    excludedIds: _noticeStringList(json['excluded_ids']),
    filters: _noticeStringListMap(json['filters']),
  );
}

final class NoticeAudienceSelection {
  const NoticeAudienceSelection({
    this.rules = const [],
    this.roleCodes = const [],
    this.planIds = const [],
  });

  final List<NoticeAudienceRule> rules;
  final List<String> roleCodes;
  final List<String> planIds;

  Map<String, Object?> toJson() => {
    'rules': rules.map((rule) => rule.toJson()).toList(growable: false),
    'role_codes': roleCodes,
    'plan_ids': planIds,
  };

  factory NoticeAudienceSelection.fromJson(Map<String, dynamic> json) => NoticeAudienceSelection(
    rules: (json['rules'] as List<dynamic>? ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map((rule) => NoticeAudienceRule.fromJson(Map<String, dynamic>.from(rule)))
        .toList(growable: false),
    roleCodes: _noticeStringList(json['role_codes']),
    planIds: _noticeStringList(json['plan_ids']),
  );
}

final class NoticeAppearance {
  const NoticeAppearance({
    this.backgroundColorValue,
    this.textColorValue,
    this.buttonColorValue,
    this.popupSize = NoticePopupSize.standard,
    this.hasOuterInset = true,
  });

  final int? backgroundColorValue;
  final int? textColorValue;
  final int? buttonColorValue;
  final NoticePopupSize popupSize;
  final bool hasOuterInset;

  bool get effectiveHasOuterInset => popupSize != NoticePopupSize.fullscreen && hasOuterInset;
}

extension NoticeVisualToneLabel on NoticeVisualTone {
  String get label => switch (this) {
    NoticeVisualTone.brand => 'Marca',
    NoticeVisualTone.dark => 'Escuro',
    NoticeVisualTone.light => 'Claro',
    NoticeVisualTone.neutral => 'Neutro',
    NoticeVisualTone.success => 'Sucesso',
    NoticeVisualTone.warning => 'Alerta',
    NoticeVisualTone.danger => 'Erro',
  };
}

String recurrenceSummaryLabel({
  required NoticeRecurrence recurrence,
  int? intervalDays,
  List<int> weeklyDays = const [],
  int? dayOfMonth,
  DateTime? until,
}) {
  final untilText = until == null
      ? ''
      : ' até ${until.day.toString().padLeft(2, '0')}/${until.month.toString().padLeft(2, '0')}/${until.year}';
  return switch (recurrence) {
    NoticeRecurrence.oneTime => 'única',
    NoticeRecurrence.daily => 'diária$untilText',
    NoticeRecurrence.weekly => 'semanal (${_weekdayNames(weeklyDays)})$untilText',
    NoticeRecurrence.monthly => 'mensal (dia ${dayOfMonth ?? 1})$untilText',
    NoticeRecurrence.interval => '${intervalDays ?? 1} em ${intervalDays ?? 1} dia(s)$untilText',
  };
}

String _weekdayNames(List<int> days) {
  const labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sab', 'Dom'];
  if (days.isEmpty) return 'nenhum';
  final sorted = List<int>.from(days)..sort();
  return sorted.where((day) => day >= 1 && day <= 7).map((day) => labels[day - 1]).join(', ');
}

final class PlatformNotice {
  const PlatformNotice({
    this.type = CommunicationType.notice,
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.audience,
    required this.audienceLabel,
    required NoticeBehavior behavior,
    bool mandatory = false,
    required this.targetDevice,
    required this.reach,
    this.contentFormat = NoticeContentFormat.textBackground,
    this.audienceRoleLabel,
    this.backgroundColorValue,
    this.textColorValue,
    this.buttonColorValue,
    NoticePopupSize popupSize = NoticePopupSize.standard,
    bool hasOuterInset = true,
    this.audienceSelection = const NoticeAudienceSelection(),
    this.recurrence = NoticeRecurrence.oneTime,
    this.intervalDays,
    this.weeklyDays = const [],
    this.dayOfMonth,
    this.recurrenceUntil,
    this.imageOrientation = NoticeImageOrientation.vertical,
    this.backgroundTone = NoticeVisualTone.dark,
    this.textTone = NoticeVisualTone.light,
    this.buttonLabel = 'Confirmar',
    this.linkLabel,
    this.deliveredCount = 0,
    this.viewedCount = 0,
    this.acceptedCount = 0,
    this.managementVersion = 0,
  }) : behavior = type == CommunicationType.notice ? behavior : NoticeBehavior.dismissible,
       mandatory = type == CommunicationType.notice && behavior != NoticeBehavior.dismissible,
       popupSize = type == CommunicationType.notice ? popupSize : NoticePopupSize.standard,
       hasOuterInset = type == CommunicationType.notice
           ? (popupSize == NoticePopupSize.fullscreen ? false : hasOuterInset)
           : true;

  final CommunicationType type;
  final String id;
  final String title;
  final String message;
  final NoticePriority priority;
  final NoticeStatus status;
  final DateTime startsAt;
  final DateTime? endsAt;
  final NoticeAudience audience;
  final String audienceLabel;
  final NoticeBehavior behavior;
  final bool mandatory;
  final NoticeTargetDevice targetDevice;
  final int reach;
  final NoticeContentFormat contentFormat;
  final String? audienceRoleLabel;
  final int? backgroundColorValue;
  final int? textColorValue;
  final int? buttonColorValue;
  final NoticePopupSize popupSize;
  final bool hasOuterInset;
  final NoticeAudienceSelection audienceSelection;
  final NoticeRecurrence recurrence;
  final int? intervalDays;
  final List<int> weeklyDays;
  final int? dayOfMonth;
  final DateTime? recurrenceUntil;
  final NoticeImageOrientation imageOrientation;
  final NoticeVisualTone backgroundTone;
  final NoticeVisualTone textTone;
  final String buttonLabel;
  final String? linkLabel;
  final int deliveredCount;
  final int viewedCount;
  final int acceptedCount;
  final int managementVersion;

  NoticeAppearance get appearance => NoticeAppearance(
    backgroundColorValue: backgroundColorValue,
    textColorValue: textColorValue,
    buttonColorValue: buttonColorValue,
    popupSize: popupSize,
    hasOuterInset: hasOuterInset,
  );

  bool get canEdit =>
      status == NoticeStatus.draft ||
      status == NoticeStatus.scheduled ||
      status == NoticeStatus.paused;
  bool get requiresAcceptance => behavior != NoticeBehavior.dismissible;
  bool get isPopup => type == CommunicationType.notice;
  bool get isRecurring => recurrence != NoticeRecurrence.oneTime;
  String get recurrenceLabel => recurrenceSummaryLabel(
    recurrence: recurrence,
    intervalDays: intervalDays,
    weeklyDays: weeklyDays,
    dayOfMonth: dayOfMonth,
    until: recurrenceUntil,
  );

  PlatformNotice copyWith({
    CommunicationType? type,
    String? id,
    String? title,
    String? message,
    NoticePriority? priority,
    NoticeStatus? status,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
    NoticeAudience? audience,
    String? audienceLabel,
    NoticeBehavior? behavior,
    bool? mandatory,
    NoticeTargetDevice? targetDevice,
    int? reach,
    NoticeContentFormat? contentFormat,
    String? audienceRoleLabel,
    int? backgroundColorValue,
    int? textColorValue,
    int? buttonColorValue,
    NoticePopupSize? popupSize,
    bool? hasOuterInset,
    NoticeAudienceSelection? audienceSelection,
    NoticeRecurrence? recurrence,
    int? intervalDays,
    List<int>? weeklyDays,
    int? dayOfMonth,
    DateTime? recurrenceUntil,
    bool clearRecurrenceUntil = false,
    NoticeImageOrientation? imageOrientation,
    NoticeVisualTone? backgroundTone,
    NoticeVisualTone? textTone,
    String? buttonLabel,
    String? linkLabel,
    int? deliveredCount,
    int? viewedCount,
    int? acceptedCount,
    int? managementVersion,
  }) => PlatformNotice(
    type: type ?? this.type,
    id: id ?? this.id,
    title: title ?? this.title,
    message: message ?? this.message,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    startsAt: startsAt ?? this.startsAt,
    endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
    audience: audience ?? this.audience,
    audienceLabel: audienceLabel ?? this.audienceLabel,
    behavior: behavior ?? this.behavior,
    mandatory: mandatory ?? this.mandatory,
    targetDevice: targetDevice ?? this.targetDevice,
    reach: reach ?? this.reach,
    contentFormat: contentFormat ?? this.contentFormat,
    audienceRoleLabel: audienceRoleLabel ?? this.audienceRoleLabel,
    backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
    textColorValue: textColorValue ?? this.textColorValue,
    buttonColorValue: buttonColorValue ?? this.buttonColorValue,
    popupSize: popupSize ?? this.popupSize,
    hasOuterInset: hasOuterInset ?? this.hasOuterInset,
    audienceSelection: audienceSelection ?? this.audienceSelection,
    recurrence: recurrence ?? this.recurrence,
    intervalDays: intervalDays ?? this.intervalDays,
    weeklyDays: weeklyDays ?? this.weeklyDays,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    recurrenceUntil: clearRecurrenceUntil ? null : recurrenceUntil ?? this.recurrenceUntil,
    imageOrientation: imageOrientation ?? this.imageOrientation,
    backgroundTone: backgroundTone ?? this.backgroundTone,
    textTone: textTone ?? this.textTone,
    buttonLabel: buttonLabel ?? this.buttonLabel,
    linkLabel: linkLabel ?? this.linkLabel,
    deliveredCount: deliveredCount ?? this.deliveredCount,
    viewedCount: viewedCount ?? this.viewedCount,
    acceptedCount: acceptedCount ?? this.acceptedCount,
    managementVersion: managementVersion ?? this.managementVersion,
  );
}

final class NoticeDraft {
  const NoticeDraft({
    this.type = CommunicationType.notice,
    required this.title,
    required this.message,
    required this.priority,
    required this.audience,
    required this.audienceLabel,
    required NoticeBehavior behavior,
    bool mandatory = false,
    this.targetDevice = NoticeTargetDevice.all,
    this.contentFormat = NoticeContentFormat.textBackground,
    this.audienceRoleLabel,
    this.backgroundColorValue,
    this.textColorValue,
    this.buttonColorValue,
    NoticePopupSize popupSize = NoticePopupSize.standard,
    bool hasOuterInset = true,
    this.audienceSelection = const NoticeAudienceSelection(),
    this.buttonLabel = 'Confirmar',
    this.linkLabel,
    this.recurrence = NoticeRecurrence.oneTime,
    this.intervalDays,
    this.weeklyDays = const [],
    this.dayOfMonth,
    this.recurrenceUntil,
    this.imageOrientation = NoticeImageOrientation.vertical,
    this.backgroundTone = NoticeVisualTone.dark,
    this.textTone = NoticeVisualTone.light,
    this.startsAt,
    this.endsAt,
  }) : behavior = type == CommunicationType.notice ? behavior : NoticeBehavior.dismissible,
       mandatory = type == CommunicationType.notice && behavior != NoticeBehavior.dismissible,
       popupSize = type == CommunicationType.notice ? popupSize : NoticePopupSize.standard,
       hasOuterInset = type == CommunicationType.notice
           ? (popupSize == NoticePopupSize.fullscreen ? false : hasOuterInset)
           : true;

  final CommunicationType type;
  final String title;
  final String message;
  final NoticePriority priority;
  final NoticeAudience audience;
  final String audienceLabel;
  final NoticeBehavior behavior;
  final bool mandatory;
  final NoticeTargetDevice targetDevice;
  final NoticeContentFormat contentFormat;
  final String? audienceRoleLabel;
  final int? backgroundColorValue;
  final int? textColorValue;
  final int? buttonColorValue;
  final NoticePopupSize popupSize;
  final bool hasOuterInset;
  final NoticeAudienceSelection audienceSelection;
  final String buttonLabel;
  final String? linkLabel;
  final NoticeRecurrence recurrence;
  final int? intervalDays;
  final List<int> weeklyDays;
  final int? dayOfMonth;
  final DateTime? recurrenceUntil;
  final NoticeImageOrientation imageOrientation;
  final NoticeVisualTone backgroundTone;
  final NoticeVisualTone textTone;
  final DateTime? startsAt;
  final DateTime? endsAt;

  NoticeAppearance get appearance => NoticeAppearance(
    backgroundColorValue: backgroundColorValue,
    textColorValue: textColorValue,
    buttonColorValue: buttonColorValue,
    popupSize: popupSize,
    hasOuterInset: hasOuterInset,
  );

  bool get isPopup => type == CommunicationType.notice;
}

List<String> _noticeStringList(Object? value) =>
    (value as List<dynamic>? ?? const []).map((item) => item.toString()).toList(growable: false);

Map<String, List<String>> _noticeStringListMap(Object? value) {
  if (value is! Map) return const {};
  return {for (final entry in value.entries) entry.key.toString(): _noticeStringList(entry.value)};
}
