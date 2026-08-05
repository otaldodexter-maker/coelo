import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/imports/data/fake_import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_wizard_controller.dart';
import 'package:coelo_superadmin/features/invites/data/fake_invite_repository.dart';
import 'package:coelo_superadmin/features/invites/domain/platform_invite.dart';
import 'package:coelo_superadmin/features/notices/data/fake_notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/plans/data/fake_plan_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('four operational actions reach activity center and sanitized audit exactly once', () async {
    final now = DateTime.utc(2026, 8, 3, 12);
    final activities = SuperadminActivityController(now: () => now);
    final store = SuperadminPrototypeStore(activityController: activities, now: () => now);

    final plans = FakePlanCatalogRepository(store: store);
    plans.update(plans.plans.first.copyWith(), reason: 'Revisão operacional local.');

    final importController = ImportWizardController(
      repository: FakeImportRepository(now: () => now),
      store: store,
      stepInterval: Duration.zero,
    )..confirm();
    for (var index = 0; index < 8; index += 1) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(importController.job?.progress, 100);

    final invites = FakeInviteRepository(now: () => now, prototypeStore: store);
    invites.resend(invites.list(const InviteQuery()).first.id);

    final notices = FakeNoticeRepository(store: store, now: () => now);
    final notice = notices.create(
      const NoticeDraft(
        title: 'Manutenção local',
        message: 'Mensagem integral que não pode entrar na auditoria.',
        priority: NoticePriority.important,
        audience: NoticeAudience.coeloTeam,
        audienceLabel: 'Equipe Coelo',
        behavior: NoticeBehavior.dismissible,
        mandatory: false,
      ),
    );
    notices.publish(notice.id);

    for (final module in ['Planos', 'Importações', 'Convites', 'Avisos']) {
      expect(store.auditEvents.where((event) => event.module == module), hasLength(1));
    }
    for (final subject in ['Planos', 'Convites', 'Avisos']) {
      expect(activities.activities.where((activity) => activity.subject == subject), isNotEmpty);
    }
    expect(
      activities.activities.where(
        (activity) => activity.kind == SuperadminActivityKind.import && activity.progress == 100,
      ),
      hasLength(1),
    );

    const sensitive = ['Mensagem integral', '@', 'token', 'http://', 'https://', '.csv', '.xlsx'];
    final serialized = store.auditEvents
        .map((event) => '${event.actor} ${event.objectId} ${event.before} ${event.after}')
        .join(' ')
        .toLowerCase();
    for (final value in sensitive) {
      expect(serialized, isNot(contains(value.toLowerCase())));
    }

    importController.dispose();
  });
}
