enum NoticeStatus { draft, scheduled, active, ended, cancelled }

extension NoticeStatusLabel on NoticeStatus {
  String get label => switch (this) {
    NoticeStatus.draft => 'Rascunho',
    NoticeStatus.scheduled => 'Agendado',
    NoticeStatus.active => 'Ativo',
    NoticeStatus.ended => 'Encerrado',
    NoticeStatus.cancelled => 'Cancelado',
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
    NoticeAudience.group => 'Grupo',
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

final class PlatformNotice {
  const PlatformNotice({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.audience,
    required this.audienceLabel,
    required this.behavior,
    required this.mandatory,
    required this.reach,
    this.buttonLabel = 'Confirmar',
    this.linkLabel,
    this.deliveredCount = 0,
    this.viewedCount = 0,
    this.acceptedCount = 0,
  });

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
  final int reach;
  final String buttonLabel;
  final String? linkLabel;
  final int deliveredCount;
  final int viewedCount;
  final int acceptedCount;

  bool get canEdit => status == NoticeStatus.draft || status == NoticeStatus.scheduled;
  bool get requiresAcceptance => behavior != NoticeBehavior.dismissible;

  PlatformNotice copyWith({
    String? title,
    String? message,
    NoticePriority? priority,
    NoticeStatus? status,
    DateTime? startsAt,
    DateTime? endsAt,
    NoticeAudience? audience,
    String? audienceLabel,
    NoticeBehavior? behavior,
    bool? mandatory,
    int? reach,
    String? buttonLabel,
    String? linkLabel,
    int? deliveredCount,
    int? viewedCount,
    int? acceptedCount,
  }) => PlatformNotice(
    id: id,
    title: title ?? this.title,
    message: message ?? this.message,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt ?? this.endsAt,
    audience: audience ?? this.audience,
    audienceLabel: audienceLabel ?? this.audienceLabel,
    behavior: behavior ?? this.behavior,
    mandatory: mandatory ?? this.mandatory,
    reach: reach ?? this.reach,
    buttonLabel: buttonLabel ?? this.buttonLabel,
    linkLabel: linkLabel ?? this.linkLabel,
    deliveredCount: deliveredCount ?? this.deliveredCount,
    viewedCount: viewedCount ?? this.viewedCount,
    acceptedCount: acceptedCount ?? this.acceptedCount,
  );
}

final class NoticeDraft {
  const NoticeDraft({
    required this.title,
    required this.message,
    required this.priority,
    required this.audience,
    required this.audienceLabel,
    required this.behavior,
    required this.mandatory,
    this.buttonLabel = 'Confirmar',
    this.linkLabel,
  });

  final String title;
  final String message;
  final NoticePriority priority;
  final NoticeAudience audience;
  final String audienceLabel;
  final NoticeBehavior behavior;
  final bool mandatory;
  final String buttonLabel;
  final String? linkLabel;
}
