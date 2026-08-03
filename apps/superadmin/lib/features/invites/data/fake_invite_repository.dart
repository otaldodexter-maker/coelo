import '../../../app/activity/superadmin_activity.dart';
import '../../../app/prototype/superadmin_prototype_store.dart';
import '../domain/platform_invite.dart';

/// Local fixture repository; it never sends a message or creates a real token.
final class FakeInviteRepository {
  FakeInviteRepository({DateTime Function()? now, this.prototypeStore})
    : _now = now ?? DateTime.now,
      _items = _fixtures(now ?? DateTime.now);
  final DateTime Function() _now;
  final SuperadminPrototypeStore? prototypeStore;
  final List<PlatformInvite> _items;
  var _next = 6;
  List<PlatformInvite> list(InviteQuery query) {
    final q = query.search.toLowerCase();
    return _items
        .where(
          (i) =>
              (q.isEmpty ||
                  '${i.recipientMasked} ${i.scope} ${i.role}'.toLowerCase().contains(q)) &&
              (query.audiences.isEmpty || query.audiences.contains(i.audience)) &&
              (query.channels.isEmpty || query.channels.contains(i.channel)) &&
              (query.statuses.isEmpty || query.statuses.contains(i.status)) &&
              (query.scope.isEmpty || i.scope.toLowerCase().contains(query.scope.toLowerCase())) &&
              (query.role.isEmpty || i.role.toLowerCase().contains(query.role.toLowerCase())) &&
              (query.periodStart == null || !i.createdAt.isBefore(query.periodStart!)) &&
              (query.periodEnd == null || !i.createdAt.isAfter(query.periodEnd!)),
        )
        .toList(growable: false);
  }

  PlatformInvite? find(String id) =>
      _items.cast<PlatformInvite?>().firstWhere((i) => i!.id == id, orElse: () => null);
  PlatformInvite send(InviteDraft draft) {
    final now = _now();
    final i = PlatformInvite(
      id: 'invite-${_next++}',
      audience: draft.audience,
      scope: draft.scope,
      role: draft.role,
      recipient: draft.recipient,
      channel: draft.channel,
      status: InviteStatus.pending,
      createdAt: now,
      expiresAt: draft.expiresAt ?? now.add(const Duration(hours: 48)),
      link: _link('invite-${_next - 1}', 1),
      timeline: [InviteTimelineEntry('Convite enviado', now)],
    );
    _items.insert(0, i);
    _record(i, 'enviado');
    return i;
  }

  PlatformInvite resend(String id) {
    final old = _required(id);
    if (!old.canResend) throw StateError('Este convite não pode ser reenviado.');
    final now = _now();
    final i = old.copyWith(
      status: InviteStatus.pending,
      expiresAt: now.add(const Duration(hours: 48)),
      link: _link(id, old.invalidatedLinks.length + 2),
      invalidatedLinks: [...old.invalidatedLinks, ?old.link],
      timeline: [...old.timeline, InviteTimelineEntry('Convite reenviado', now)],
    );
    _replace(i);
    _record(i, 'reenviado');
    return i;
  }

  PlatformInvite revoke(String id) {
    final old = _required(id);
    if (!old.canRevoke) throw StateError('Este convite não pode ser revogado.');
    final i = old.copyWith(
      status: InviteStatus.revoked,
      timeline: [...old.timeline, InviteTimelineEntry('Convite revogado', _now())],
    );
    _replace(i);
    _record(i, 'revogado');
    return i;
  }

  PlatformInvite _required(String id) => find(id) ?? (throw StateError('Convite não encontrado.'));
  void _replace(PlatformInvite i) => _items[_items.indexWhere((x) => x.id == i.id)] = i;
  String _link(String id, int v) => 'https://preview.coelo.test/invites/$id-$v';
  void _record(PlatformInvite i, String action) {
    final s = prototypeStore;
    if (s == null) return;
    s.recordActivity(
      kind: SuperadminActivityKind.announcement,
      subject: 'Convites',
      summary: 'Convite $action para ${i.audience.label.toLowerCase()}.',
    );
    s.recordAuditEvent(
      module: 'Convites',
      action: action,
      objectType: 'convite',
      objectId: i.id,
      risk: PrototypeAuditRisk.medium,
      after: {'status': i.status.name, 'expiresAt': i.expiresAt.toIso8601String()},
    );
  }
}

List<PlatformInvite> _fixtures(DateTime Function() now) {
  final t = now();
  PlatformInvite f(
    String id,
    InviteAudience a,
    InviteChannel c,
    InviteStatus s,
    String r,
    String scope,
    String role,
  ) => PlatformInvite(
    id: id,
    audience: a,
    scope: scope,
    role: role,
    recipient: r,
    channel: c,
    status: s,
    createdAt: t.subtract(const Duration(hours: 4)),
    expiresAt: s == InviteStatus.expired
        ? t.subtract(const Duration(hours: 2))
        : t.add(const Duration(hours: 44)),
    link: 'https://preview.coelo.test/invites/$id-1',
    timeline: [InviteTimelineEntry('Convite criado', t.subtract(const Duration(hours: 4)))],
  );
  return [
    f(
      'invite-1',
      InviteAudience.institutionAdmin,
      InviteChannel.email,
      InviteStatus.pending,
      'owner@aurora.test',
      'Instituição Aurora',
      'Owner',
    ),
    f(
      'invite-2',
      InviteAudience.guardian,
      InviteChannel.mobile,
      InviteStatus.accepted,
      '+5511999990000',
      'Turma Girassol',
      'Responsável',
    ),
    f(
      'invite-3',
      InviteAudience.professional,
      InviteChannel.link,
      InviteStatus.expired,
      'link',
      'Unidade Centro',
      'Profissional',
    ),
    f(
      'invite-4',
      InviteAudience.coeloTeam,
      InviteChannel.email,
      InviteStatus.revoked,
      'time@coelo.test',
      'Coelo',
      'Operadora',
    ),
    f(
      'invite-5',
      InviteAudience.linkedPerson,
      InviteChannel.mobile,
      InviteStatus.failed,
      '+5511988880000',
      'Grupo Azul',
      'Pessoa vinculada',
    ),
  ];
}
