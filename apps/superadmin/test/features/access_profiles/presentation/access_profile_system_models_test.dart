import 'package:coelo_superadmin/features/access_profiles/data/fake_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_detail_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_directory_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// P31 (ADR 0034 Decisão 15): modelos do sistema aparecem, não se editam e
// "Criar perfil" oferece do zero ou a partir do modelo.
void main() {
  testWidgets('create asks for scratch or model when the list has system profiles', (
    tester,
  ) async {
    AccessProfileDomain? createdDomain;
    String? sourceId;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDirectoryPage(
          repository: FakeAccessProfileRepository(),
          logout: unavailableSuperadminLogout,
          onCreate: (domain) => createdDomain = domain,
          onCreateFromModel: (_, id) => sourceId = id,
          onOpen: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.widget<CoeloAdminCreateAction>(find.byType(CoeloAdminCreateAction)).onPressed!();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('access-profile-create-mode-dialog')), findsOneWidget);
    expect(find.byKey(const Key('access-profile-create-from-demo-owner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('access-profile-create-from-demo-owner')));
    await tester.pumpAndSettle();
    expect(sourceId, 'demo-owner');
    expect(createdDomain, isNull);

    tester.widget<CoeloAdminCreateAction>(find.byType(CoeloAdminCreateAction)).onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-create-from-scratch')));
    await tester.pumpAndSettle();
    expect(createdDomain, AccessProfileDomain.platform);
  });

  testWidgets('system profile detail hides edit and delete and offers create from model', (
    tester,
  ) async {
    var createFromModel = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDetailPage(
          repository: FakeAccessProfileRepository(),
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.platform,
          profileId: 'demo-owner',
          onBack: () {},
          onEdit: () {},
          onDeleted: () {},
          onCreateFromModel: () => createFromModel += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('access-profile-system-notice')), findsOneWidget);
    expect(find.text('Editar perfil'), findsNothing);
    expect(find.text('Excluir'), findsNothing);
    await tester.tap(find.byKey(const Key('access-profile-create-from-model')));
    expect(createFromModel, 1);
  });

  // P45 = B (Owner, 11/09): modelo do sistema de Admin criado pelo Superadmin
  // pode ser excluido (e editado, P31) pela plataforma; o de plataforma nao.
  testWidgets('institution system model offers edit, delete and create from model', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDetailPage(
          repository: FakeAccessProfileRepository(),
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.institution,
          profileId: 'demo-admin-owner',
          onBack: () {},
          onEdit: () {},
          onDeleted: () {},
          onCreateFromModel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('access-profile-system-notice')), findsOneWidget);
    expect(find.byKey(const Key('access-profile-system-delete')), findsOneWidget);
    expect(find.byKey(const Key('access-profile-system-edit')), findsOneWidget);
    expect(find.byKey(const Key('access-profile-create-from-model')), findsOneWidget);
  });

  testWidgets('form created from a model starts with its permissions and no identity', (
    tester,
  ) async {
    final repository = FakeAccessProfileRepository();
    final source = await repository.fetchDetail(AccessProfileDomain.platform, 'demo-owner');
    final expected = source.permissions.where((p) => p.selected).map((p) => p.code).toSet();
    expect(expected, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.platform,
          sourceProfileId: 'demo-owner',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(AccessProfileFormPage)) as dynamic; // ignore: avoid_dynamic_calls
    final draft = state.debugDraft as AccessProfile;
    expect(draft.id, isEmpty);
    expect(draft.name, isEmpty);
    expect(draft.permissions.where((p) => p.selected).map((p) => p.code).toSet(), expected);
  });
}
