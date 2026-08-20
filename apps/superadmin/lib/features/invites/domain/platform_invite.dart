enum InviteAudience {
  coeloTeam('Equipe Coelo'),
  institutionAdmin('Owners e administradores'),
  professional('Profissionais'),
  guardian('Responsáveis'),
  linkedPerson('Pessoas vinculadas');

  const InviteAudience(this.label);
  final String label;
}

enum InviteChannel {
  email('E-mail'),
  mobile('Celular'),
  link('Link copiável');

  const InviteChannel(this.label);
  final String label;
}

enum InviteStatus {
  draft('Rascunho'),
  pending('Pendente'),
  accepted('Aceito'),
  expired('Expirado'),
  revoked('Revogado'),
  failed('Falhou');

  const InviteStatus(this.label);
  final String label;
}

final class InviteTimelineEntry {
  const InviteTimelineEntry(this.label, this.occurredAt);
  final String label;
  final DateTime occurredAt;
}

final class InviteDraft {
  const InviteDraft({
    required this.audience,
    required this.scope,
    required this.role,
    required this.recipient,
    required this.channel,
    this.expiresAt,
  });
  final InviteAudience audience;
  final String scope;
  final String role;
  final String recipient;
  final InviteChannel channel;
  final DateTime? expiresAt;
}

final class PlatformInvite {
  const PlatformInvite({
    required this.id,
    required this.audience,
    required this.scope,
    required this.role,
    required this.recipient,
    required this.channel,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.link,
    this.invalidatedLinks = const [],
    this.timeline = const [],
  });
  final String id;
  final InviteAudience audience;
  final String scope;
  final String role;
  final String recipient;
  final InviteChannel channel;
  final InviteStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? link;
  final List<String> invalidatedLinks;
  final List<InviteTimelineEntry> timeline;
  String get recipientMasked => maskInviteRecipient(recipient, channel);
  bool get canResend => status == InviteStatus.pending || status == InviteStatus.expired;
  bool get canRevoke => status == InviteStatus.pending;
  PlatformInvite copyWith({
    InviteStatus? status,
    DateTime? expiresAt,
    String? link,
    List<String>? invalidatedLinks,
    List<InviteTimelineEntry>? timeline,
  }) => PlatformInvite(
    id: id,
    audience: audience,
    scope: scope,
    role: role,
    recipient: recipient,
    channel: channel,
    status: status ?? this.status,
    createdAt: createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    link: link ?? this.link,
    invalidatedLinks: invalidatedLinks ?? this.invalidatedLinks,
    timeline: timeline ?? this.timeline,
  );
}

final class InviteQuery {
  const InviteQuery({
    this.search = '',
    this.audiences = const {},
    this.channels = const {},
    this.statuses = const {},
    this.scope = '',
    this.role = '',
    this.periodStart,
    this.periodEnd,
  });
  final String search;
  final Set<InviteAudience> audiences;
  final Set<InviteChannel> channels;
  final Set<InviteStatus> statuses;
  final String scope;
  final String role;
  final DateTime? periodStart;
  final DateTime? periodEnd;
}

String maskInviteRecipient(String recipient, InviteChannel channel) {
  if (channel == InviteChannel.email && recipient.contains('@')) {
    final p = recipient.split('@');
    return '${p.first.substring(0, 1)}***@${p.last}';
  }
  if (channel == InviteChannel.mobile) {
    final d = recipient.replaceAll(RegExp(r'\D'), '');
    return '${d.length > 10 ? '+${d.substring(0, 2)}' : ''}•••••${d.substring(d.length - 4)}';
  }
  return 'Link copiável';
}
