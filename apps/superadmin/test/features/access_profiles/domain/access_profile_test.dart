import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccessProfileReview', () {
    const current = AccessProfile(
      id: 'owner',
      domain: AccessProfileDomain.platform,
      code: 'owner',
      name: 'Owner',
      description: 'Autoridade total.',
      status: AccessProfileStatus.active,
      maxScope: AccessProfileScope.platform,
      version: 4,
      membershipCount: 1,
      permissions: [
        AccessPermission(
          code: 'platform.read',
          module: 'platform',
          name: 'Visualizar plataforma',
          selected: true,
        ),
        AccessPermission(
          code: 'audit.read',
          module: 'audit',
          name: 'Visualizar auditoria',
          selected: true,
        ),
      ],
    );

    test('describes additions, removals and scope changes', () {
      final review = AccessProfileReview.compare(
        current,
        current.copyWith(
          maxScope: AccessProfileScope.institution,
          permissions: const [
            AccessPermission(
              code: 'platform.read',
              module: 'platform',
              name: 'Visualizar plataforma',
              selected: true,
            ),
            AccessPermission(
              code: 'support.manage',
              module: 'support',
              name: 'Gerenciar suporte',
              selected: true,
            ),
          ],
        ),
      );

      expect(review.addedCodes, ['support.manage']);
      expect(review.removedCodes, ['audit.read']);
      expect(review.scopeChanged, isTrue);
      expect(review.isSensitive, isTrue);
    });
  });

  group('AccessProfileQuery', () {
    test('resets pagination when filters change', () {
      const query = AccessProfileQuery(page: 3, search: 'owner');

      final changed = query.copyWith(domain: AccessProfileDomain.institution, resetPage: true);

      expect(changed.page, 0);
      expect(changed.domain, AccessProfileDomain.institution);
      expect(changed.search, 'owner');
    });
  });

  test('ungrantable permissions cannot become selected', () {
    const permission = AccessPermission(
      code: 'platform.roles.manage',
      module: 'platform',
      name: 'Gerenciar perfis',
      selected: false,
      grantable: false,
      unavailableReason: 'Você não possui esta permissão.',
    );

    expect(permission.withSelection(true).selected, isFalse);
  });

  test('missing selected field fails closed', () {
    final permission = AccessPermission.fromJson({
      'code': 'platform.roles.manage',
      'module': 'platform',
      'name': 'Gerenciar perfis',
    });

    expect(permission.selected, isFalse);
  });

  test('reads explicit screen and action metadata from the detail contract', () {
    final permission = AccessPermission.fromJson({
      'code': 'institutions.update',
      'module': 'Instituições',
      'screen_code': 'institutions',
      'action_code': 'update',
      'name': 'Editar instituições',
    });

    expect(permission.screenCode, 'institutions');
    expect(permission.actionCode, 'update');
  });

  test('inherited permissions cannot be changed by the draft', () {
    const permission = AccessPermission(
      code: 'people.read',
      module: 'people',
      name: 'Visualizar pessoas',
      selected: true,
      inherited: true,
    );

    expect(permission.withSelection(false).selected, isTrue);
  });

  test('draft never turns inherited permissions into direct grants', () {
    const profile = AccessProfile(
      id: 'profile',
      domain: AccessProfileDomain.platform,
      code: 'profile',
      name: 'Perfil',
      description: '',
      status: AccessProfileStatus.active,
      maxScope: AccessProfileScope.platform,
      version: 1,
      membershipCount: 0,
      permissions: [
        AccessPermission(
          code: 'people.read',
          module: 'people',
          name: 'Visualizar pessoas',
          selected: true,
          inherited: true,
        ),
      ],
    );

    expect(profile.toDraftJson()['permission_codes'], isEmpty);
  });
}
