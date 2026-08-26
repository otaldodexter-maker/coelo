import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/dev_menu/development_invite_repository.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/plans/data/fake_plan_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan and invite actions reach activity center and sanitized audit once', () async {
    final now = DateTime.utc(2026, 8, 3, 12);
    final activities = SuperadminActivityController(now: () => now);
    final store = SuperadminPrototypeStore(activityController: activities, now: () => now);

    final plans = FakePlanCatalogRepository(store: store);
    plans.update(plans.plans.first.copyWith(), reason: 'Revisão operacional local.');

    final invites = DevelopmentInviteRepository(now: () => now);
    final page = await invites.fetchPage(InviteDirectoryQuery());
    final invite = page.items.first;
    final result = await invites.resend(
      InviteResendCommand(
        inviteId: invite.id,
        requestId: 'operational-resend',
        expectedVersion: invite.managementVersion,
      ),
    );
    store.recordActivity(
      kind: SuperadminActivityKind.announcement,
      subject: 'Convites',
      summary: 'Convite reenviado no ambiente local.',
    );
    store.recordAuditEvent(
      module: 'Convites',
      action: 'reenviado',
      objectType: 'convite',
      objectId: result.invite.id,
      risk: PrototypeAuditRisk.medium,
      after: {
        'status': result.invite.status.name,
        'expiresAt': result.invite.expiresAt.toIso8601String(),
      },
    );

    for (final module in ['Planos', 'Convites']) {
      expect(store.auditEvents.where((event) => event.module == module), hasLength(1));
    }
    for (final subject in ['Planos', 'Convites']) {
      expect(activities.activities.where((activity) => activity.subject == subject), isNotEmpty);
    }
    const sensitive = ['Mensagem integral', '@', 'token', 'http://', 'https://', '.csv', '.xlsx'];
    final serialized = store.auditEvents
        .map((event) => '${event.actor} ${event.objectId} ${event.before} ${event.after}')
        .join(' ')
        .toLowerCase();
    for (final value in sensitive) {
      expect(serialized, isNot(contains(value.toLowerCase())));
    }
  });
}
