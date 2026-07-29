import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakePlatformUserRepository', () {
    test('filters by masked identity, role, and membership status', () async {
      final repository = FakePlatformUserRepository();
      final source = repository.records.first;

      final page = await repository.fetchPage(
        PlatformUserQuery(
          search: source.maskedEmail,
          roles: {source.role},
          statuses: {source.status},
          pageSize: 8,
        ),
      );

      expect(page.items, isNotEmpty);
      expect(page.items.every((item) => item.role == source.role), isTrue);
      expect(page.items.every((item) => item.status == source.status), isTrue);
      expect(page.pageSize, 8);
    });

    test('uses eleven cards and eight table rows per page', () {
      expect(PlatformUserQuery.cardsPageSize, 11);
      expect(PlatformUserQuery.tablePageSize, 8);
      expect(const PlatformUserQuery(view: PlatformUserDirectoryView.cards).pageSize, 11);
      expect(const PlatformUserQuery(view: PlatformUserDirectoryView.table).pageSize, 8);
    });

    test('creates only a preview invitation and never reports a real send', () async {
      final repository = FakePlatformUserRepository();

      final result = await repository.create(
        PlatformUserDraft(
          firstName: 'Lia',
          lastName: 'Coelo',
          email: 'lia@coelo.me',
          role: PlatformUserRole.support,
          scope: PlatformUserScope.platform,
        ),
      );

      expect(result.record.status, PlatformMembershipStatus.invited);
      expect(result.record.invitationStatus, PlatformInvitationStatus.pending);
      expect(result.invitationSent, isFalse);
      expect(result.message, contains('nenhum convite real'));
      expect(result.record.maskedEmail, 'l**@coelo.me');
    });

    test('requires an institution when scope is institutional', () {
      expect(
        () => PlatformUserDraft(
          firstName: 'Lia',
          lastName: 'Coelo',
          email: 'lia@coelo.me',
          role: PlatformUserRole.auditor,
          scope: PlatformUserScope.institution,
        ),
        throwsArgumentError,
      );
    });

    test('derives permissions from the confirmed role catalog', () {
      expect(PlatformUserRole.owner.permissions, contains('platform.member.invite'));
      expect(PlatformUserRole.auditor.permissions, isNot(contains('platform.member.invite')));
    });
  });
}
