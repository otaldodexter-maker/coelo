import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/invites/data/fake_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3, 12);
  test('uses exact 48 hours by default and masks recipient', () {
    final i = FakeInviteRepository(now: () => now).send(
      const InviteDraft(
        audience: InviteAudience.institutionAdmin,
        scope: 'Aurora',
        role: 'Owner',
        recipient: 'owner@aurora.test',
        channel: InviteChannel.email,
      ),
    );
    expect(i.expiresAt, now.add(const Duration(hours: 48)));
    expect(i.recipientMasked, 'o***@aurora.test');
  });
  test('manual expiry, filters, resend and revoke rules work', () {
    final c = SuperadminActivityController(now: () => now);
    final s = SuperadminPrototypeStore(activityController: c, now: () => now);
    final r = FakeInviteRepository(now: () => now, prototypeStore: s);
    final old = r
        .list(const InviteQuery(statuses: {InviteStatus.pending}, channels: {InviteChannel.email}))
        .single;
    final resent = r.resend(old.id);
    expect(resent.invalidatedLinks, contains(old.link));
    expect(resent.link, isNot(old.link));
    expect(c.activities, hasLength(1));
    expect(s.auditEvents, hasLength(1));
    expect(s.auditEvents.single.after.values.join(), isNot(contains('@')));
    expect(r.revoke(resent.id).status, InviteStatus.revoked);
    expect(() => r.resend(resent.id), throwsStateError);
  });
}
