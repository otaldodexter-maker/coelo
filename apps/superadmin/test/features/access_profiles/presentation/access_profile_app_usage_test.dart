import 'package:coelo_superadmin/features/access_profiles/data/fake_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/staff_access/data/fake_staff_access_repository.dart';
import 'package:coelo_superadmin/features/staff_access/domain/staff_access.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Passo "Utilização do app" do perfil de funcionário (domínio institution):
/// o horário definido no perfil é herdado pelos vínculos (lote 86).
void main() {
  Widget app(Widget child) => MaterialApp(theme: CoeloTheme.light, home: child);

  testWidgets('perfil institution ganha o passo e salva o horário do perfil depois do perfil', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final staffAccess = FakeStaffAccessRepository();
    AccessProfile? saved;
    await tester.pumpWidget(
      app(
        AccessProfileFormPage(
          repository: FakeAccessProfileRepository(),
          staffAccessRepository: staffAccess,
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.institution,
          profileId: 'demo-coordinator',
          onCancel: () {},
          onSaved: (profile) => saved = profile,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Utilização do app'), findsOneWidget);

    // Perfil e escopo -> Permissões -> Utilização do app
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('access-profile-app-usage-toggle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('access-profile-app-usage-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('access-profile-app-usage-windows-weekdays')));
    await tester.tap(find.byKey(const Key('access-profile-app-usage-windows-weekdays')));
    await tester.pumpAndSettle();

    // -> Pessoas vinculadas -> Revisão
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('access-profile-review-reason')), 'Horário padrão');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    final draft = staffAccess.savedProfileRules.single;
    expect(draft.clear, isFalse);
    expect(draft.windows.length, 5);
    expect(draft.windows.first.start, '08:00');
    expect(staffAccess.profileRules['demo-coordinator']?.version, 1);
  });

  testWidgets('perfil platform e sem repositório de acesso não mostram o passo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        AccessProfileFormPage(
          repository: FakeAccessProfileRepository(),
          staffAccessRepository: FakeStaffAccessRepository(),
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.platform,
          profileId: 'demo-owner',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Utilização do app'), findsNothing);
  });

  testWidgets('perfil com horário existente carrega ligado e desligar limpa (clear)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final staffAccess = FakeStaffAccessRepository();
    staffAccess.profileRules['demo-coordinator'] = staffAccess.profileRules['role-educador']!;
    await tester.pumpWidget(
      app(
        AccessProfileFormPage(
          repository: FakeAccessProfileRepository(),
          staffAccessRepository: staffAccess,
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.institution,
          profileId: 'demo-coordinator',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('access-profile-app-usage-window-start-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('access-profile-app-usage-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('access-profile-review-reason')), 'Sem horário');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-save')));
    await tester.pumpAndSettle();

    expect(staffAccess.savedProfileRules.single.clear, isTrue);
    expect(staffAccess.profileRules.containsKey('demo-coordinator'), isFalse);
    expect(staffAccess.profileRules['role-educador'], isNotNull);
  });
}
