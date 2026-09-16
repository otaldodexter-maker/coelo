// R14 S5 (owner.r12-21/25/27): o catálogo real devolve códigos técnicos e
// rótulos do servidor; a matriz e a revisão precisam traduzir módulo › tela →
// ação e não podem esconder permissões que compartilham a mesma ação numa
// tela (Modelos de perfil × Admin/Superadmin/Principal).
import 'package:coelo_superadmin/features/access_profiles/data/fake_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_permission_labels.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_detail_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AccessPermission _catalog(
  String code,
  String name, {
  required String actionCode,
  String module = 'access',
  String screenCode = 'access_profile_models',
  String? moduleLabel = 'Acessos',
  String? screenLabel = 'Modelos de perfil',
  String? actionLabel,
  bool selected = false,
  String risk = 'high',
}) => AccessPermission.fromJson({
  'code': code,
  'name': name,
  'description': name,
  'module': module,
  'screen_code': screenCode,
  'action_code': actionCode,
  'module_label': moduleLabel,
  'screen_label': screenLabel,
  'action_label': actionLabel,
  'risk': risk,
  'requires_mfa': false,
  'selected': selected,
  'grantable': true,
  'inherited': false,
});

final _realCatalog = [
  _catalog(
    'institution.role_models.create',
    'Criar modelos Admin.',
    actionCode: 'create',
    actionLabel: 'Criar',
  ),
  _catalog(
    'platform.role_models.create',
    'Criar modelos Superadmin.',
    actionCode: 'create',
    actionLabel: 'Criar',
  ),
  _catalog(
    'principal.role_models.create',
    'Criar modelos Principal.',
    actionCode: 'create',
    actionLabel: 'Criar',
    risk: 'critical',
  ),
  _catalog(
    'institution.role_models.read',
    'Consultar modelos Admin.',
    actionCode: 'read',
    actionLabel: 'Visualizar',
    selected: true,
    risk: 'normal',
  ),
  _catalog(
    'platform.role_models.read',
    'Consultar modelos Superadmin.',
    actionCode: 'read',
    actionLabel: 'Visualizar',
    risk: 'normal',
  ),
  _catalog(
    'principal.role_models.read',
    'Consultar modelos Principal.',
    actionCode: 'read',
    actionLabel: 'Visualizar',
    risk: 'normal',
  ),
  _catalog(
    'meal_plans.directory.read',
    'Consultar cardápios.',
    actionCode: 'read',
    module: 'meal_plans',
    screenCode: 'directory',
    moduleLabel: 'CardÃ¡pios',
    screenLabel: 'Directory',
    actionLabel: 'Visualizar',
    risk: 'normal',
  ),
];

AccessProfile _profile() => AccessProfile(
  id: 'r14-s5-profile',
  domain: AccessProfileDomain.platform,
  code: 'r14-s5-perfil-qa-1a2b3c4d',
  name: 'R14 S5 Perfil QA',
  description: 'Perfil sintético.',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 0,
  permissions: _realCatalog,
);

Widget _formApp(double width) => MaterialApp(
  theme: CoeloTheme.light,
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 1200)),
    child: AccessProfileFormPage(
      repository: FakeAccessProfileRepository(profiles: [_profile()]),
      logout: unavailableSuperadminLogout,
      domain: AccessProfileDomain.platform,
      profileId: 'r14-s5-profile',
      onCancel: () {},
      onSaved: (_) {},
    ),
  ),
);

void main() {
  group('rótulos do catálogo real', () {
    test('tradução local do código real tem prioridade e o servidor cobre o resto', () {
      final admin = _realCatalog.first;
      expect(permissionModuleLabel(admin), 'Acessos');
      expect(permissionScreenLabel(admin), 'Modelos de perfil');
      expect(permissionActionLabel(admin), 'Criar');
      expect(permissionPath(admin), 'Acessos › Modelos de perfil › Criar modelos Admin.');

      final meal = _realCatalog.last;
      // module_label veio com codificação errada do servidor; a tradução local vale.
      expect(permissionModuleLabel(meal), 'Cardápios');
      // screen_label "Directory" é só o código humanizado; a tradução local vale.
      expect(permissionScreenLabel(meal), 'Listagem');

      final unknown = AccessPermission.fromJson({
        'code': 'x.y.z',
        'name': 'x.y.z',
        'module': 'zeta_module',
        'screen_code': 'zeta_screen',
        'action_code': 'zeta_action',
        'module_label': 'Zeta',
        'screen_label': 'Tela Zeta',
        'action_label': 'Fazer zeta',
      });
      expect(permissionModuleLabel(unknown), 'Zeta');
      expect(permissionScreenLabel(unknown), 'Tela Zeta');
      expect(permissionActionLabel(unknown), 'Fazer zeta');
      expect(permissionPath(unknown), 'Zeta › Tela Zeta › Fazer zeta');
    });

    test('tela com ações repetidas desdobra por alvo sem perder permissão', () {
      final rows = permissionMatrixRows(_realCatalog);
      expect(rows.map((row) => row.label), [
        'Modelos de perfil · Admin',
        'Modelos de perfil · Superadmin',
        'Modelos de perfil · Principal',
        'Listagem',
      ]);
      expect(rows.expand((row) => row.permissions).length, _realCatalog.length);
      expect(rows.first.permissions.map((item) => item.actionCode), ['create', 'read']);
    });
  });

  for (final width in [1440.0, 600.0]) {
    testWidgets('matriz em $width mostra módulo→tela→ação traduzidos e todas as células', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_formApp(width));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('access-profile-continue')));
      await tester.pumpAndSettle();

      final matrix = find.byKey(const Key('access-profile-permission-matrix'));
      expect(find.descendant(of: matrix, matching: find.text('Acessos')), findsOneWidget);
      expect(find.descendant(of: matrix, matching: find.text('Cardápios')), findsOneWidget);
      expect(find.text('access'), findsNothing);
      expect(find.text('Access profile models'), findsNothing);
      expect(find.text('Modelos de perfil · Admin'), findsOneWidget);
      expect(find.text('Modelos de perfil · Superadmin'), findsOneWidget);
      expect(find.text('Modelos de perfil · Principal'), findsOneWidget);
      for (final permission in _realCatalog) {
        expect(
          find.byKey(Key('permission-${permission.code}'), skipOffstage: false),
          findsOneWidget,
          reason: permission.code,
        );
      }
      // Célula acessível: rótulo de produto na semântica e tooltip por foco.
      final cell = find.byKey(const Key('permission-principal.role_models.create'));
      await tester.ensureVisible(cell);
      final semantics = tester.getSemantics(cell);
      expect(semantics.label, startsWith('Criar em Modelos de perfil'));
      final tooltip = tester.widget<Tooltip>(
        find.descendant(of: cell, matching: find.byType(Tooltip)),
      );
      expect(tooltip.message, contains('Ação sensível'));
      // Foco por teclado mostra a mesma explicação (owner.r12-24).
      final detector = tester.widget<FocusableActionDetector>(
        find.byKey(const Key('permission-focus-principal.role_models.create')),
      );
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      detector.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text(tooltip.message!), findsOneWidget);
      // Risco elevado sem MFA explica a trilha de auditoria.
      final high = tester.widget<Tooltip>(
        find.descendant(
          of: find.byKey(const Key('permission-institution.role_models.create')),
          matching: find.byType(Tooltip),
        ),
      );
      expect(high.message, contains('trilha de auditoria'));
    });
  }

  testWidgets('revisão descreve módulo › tela › ação com o nome do catálogo', (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_formApp(1440));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    final cell = find.byKey(const Key('permission-platform.role_models.create'));
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.pumpAndSettle();
    // Permissões › Pessoas vinculadas › Revisão.
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    expect(
      find.text('Acessos › Modelos de perfil › Criar modelos Superadmin.', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('detalhe traduz módulo, tela e ação do catálogo real', (tester) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDetailPage(
          repository: FakeAccessProfileRepository(profiles: [_profile()]),
          logout: unavailableSuperadminLogout,
          domain: AccessProfileDomain.platform,
          profileId: 'r14-s5-profile',
          onBack: () {},
          onEdit: () {},
          onDeleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acessos', skipOffstage: false), findsWidgets);
    expect(find.text('Consultar modelos Admin.', skipOffstage: false), findsOneWidget);
    expect(find.text('Modelos de perfil › Ver', skipOffstage: false), findsOneWidget);
    expect(find.text('Access profile models · Ver', skipOffstage: false), findsNothing);
  });
}
