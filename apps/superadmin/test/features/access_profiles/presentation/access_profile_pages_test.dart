import '../../../support/access_profiles/test_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_detail_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_directory_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_underline_tabs.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the Institutions card, table, create and pagination patterns', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_directoryApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('access-profile-card-grid')), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.byKey(const Key('access-profile-pagination-footer')), findsOneWidget);
    expect(find.text('Perfil define teto; atribuição define contexto efetivo'), findsOneWidget);
    expect(find.text('Predefinido'), findsWidgets);
    expect(find.byType(SuperadminUnderlineTabs<AccessProfileDomain>), findsOneWidget);
    expect(find.byKey(const Key('access-profile-status-tabs')), findsNothing);
    expect(find.text('Todos'), findsNothing);
    expect(find.text('Ativos'), findsNothing);
    expect(find.text('Inativos'), findsNothing);
    expect(find.byType(CoeloAdminMultiSelectFilter<AccessProfileStatus>), findsNothing);
    expect(find.byType(CoeloAdminInteractiveCard), findsWidgets);
    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsWidgets);
    expect(
      tester.getTopLeft(find.byKey(const Key('access-profile-toolbar'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('access-profile-domain-selector'))).dy),
    );
    expect(
      tester.getSize(find.byKey(const Key('create-access-profile-card'))).height,
      tester
          .getSize(
            find.byKey(const Key('access-profile-card-10000000-0000-4000-8000-000000000001')),
          )
          .height,
    );

    await tester.tap(find.byKey(const Key('access-profile-view-table')));
    await tester.pumpAndSettle();

    final toggle = tester.widget<SuperadminDirectoryViewToggle<AccessProfileTableView>>(
      find.byType(SuperadminDirectoryViewToggle<AccessProfileTableView>),
    );
    expect(toggle.tableViews.map((option) => option.label), [
      'Agrupado',
      'Detalhado por atribuições',
    ]);
    expect(find.byKey(const Key('access-profile-table')), findsOneWidget);
    expect(find.byKey(const Key('create-access-profile-banner')), findsOneWidget);

    toggle.onTableViewSelected(AccessProfileTableView.assignments);
    await tester.pumpAndSettle();
    expect(find.text('Instituição'), findsOneWidget);
    expect(find.text('Unidade'), findsOneWidget);
    expect(find.text('Turma'), findsOneWidget);
    expect(find.text('Atividade'), findsOneWidget);
  });

  testWidgets('Principal is read-only and does not expose profile creation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_directoryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Principal'));
    await tester.pumpAndSettle();

    expect(find.text('Catálogo somente leitura'), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    expect(find.byKey(const Key('access-profile-status-tabs')), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('compact layout and text at 200 percent do not overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AccessProfileDirectoryPage(
          repository: TestAccessProfileRepository(),
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final directoryScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('access-profiles-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    directoryScroll.position.jumpTo(400);
    await tester.pump();
    expect(find.byKey(const Key('access-profile-card-grid')), findsOneWidget);
    directoryScroll.position.jumpTo(0);
    await tester.pump();
    final compactToggle = tester.widget<SuperadminDirectoryViewToggle<AccessProfileTableView>>(
      find.byType(SuperadminDirectoryViewToggle<AccessProfileTableView>),
    );
    compactToggle.onTableViewSelected(AccessProfileTableView.grouped);
    await tester.pumpAndSettle();
    directoryScroll.position.jumpTo(400);
    await tester.pump();
    expect(find.byKey(const Key('access-profile-table')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports Principal search without exposing write actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_directoryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Principal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.bySemanticsLabel('Buscar capacidade do Principal'), 'Comunicação');
    await tester.pump();

    expect(find.text('Comunicação'), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
  });

  testWidgets('shows empty, error and unauthorized states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDirectoryPage(
          repository: TestAccessProfileRepository(profiles: const []),
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum perfil cadastrado'), findsOneWidget);
    expect(find.text('Criar perfil'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDirectoryPage(
          repository: const _ThrowingRepository(unauthorized: false),
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar os perfis'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDirectoryPage(
          repository: const _ThrowingRepository(unauthorized: true),
          logout: _logout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
  });

  testWidgets('editor uses the approved stepped flow and a responsive permission matrix', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: TestAccessProfileRepository(),
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: '10000000-0000-4000-8000-000000000001',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byKey(const Key('access-profile-form-footer-surface')), findsOneWidget);
    expect(find.text('Perfil e escopo'), findsWidgets);
    expect(find.text('Catálogo predefinido'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(ExpansionTile), findsNothing);

    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('access-profile-permission-matrix')), findsOneWidget);
    expect(find.text('Pessoas'), findsWidgets);
    expect(find.text('Ver'), findsWidgets);
    expect(find.byKey(const Key('capability-people.manage')), findsOneWidget);

    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Pessoas vinculadas'), findsWidgets);
    expect(find.text('Nenhuma pessoa vinculada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Permissões adicionadas'), findsOneWidget);
    expect(find.text('Permissões removidas'), findsOneWidget);
    expect(find.byType(CoeloAdminDialogShell), findsNothing);
    expect(find.byKey(const Key('access-profile-save')), findsOneWidget);
  });

  testWidgets('editor revalidates identity before returning to an unlocked review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: TestAccessProfileRepository(),
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: '10000000-0000-4000-8000-000000000001',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const Key('access-profile-continue')));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const Key('step-perfil-e-escopo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.tap(find.byKey(const Key('step-revis-o')));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome do perfil.'), findsOneWidget);
    expect(find.text('Permissões adicionadas'), findsNothing);
  });

  testWidgets('editor blocks an invalid save after review was opened', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: TestAccessProfileRepository(),
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: '10000000-0000-4000-8000-000000000001',
          onCancel: () {},
          onSaved: (_) => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nameController = tester
        .widget<TextFormField>(find.byType(TextFormField).first)
        .controller!;
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(const Key('access-profile-continue')));
      await tester.pumpAndSettle();
    }
    nameController.clear();
    await tester.enterText(find.byType(TextFormField).first, 'Revisão de acesso');
    await tester.pump();
    await tester.tap(find.byKey(const Key('access-profile-save')));
    await tester.pumpAndSettle();

    expect(saved, isFalse);
    expect(find.text('Informe o nome do perfil.'), findsOneWidget);
    expect(find.text('Perfil e escopo'), findsWidgets);
  });

  testWidgets('permission search remains applied after returning to the matrix', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: TestAccessProfileRepository(),
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: '10000000-0000-4000-8000-000000000001',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.bySemanticsLabel('Buscar permissão por módulo, tela ou ação'),
      'gerenciar',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('capability-people.manage')), findsOneWidget);
    expect(find.byKey(const Key('capability-people.read')), findsNothing);

    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-previous')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('capability-people.manage')), findsOneWidget);
    expect(find.byKey(const Key('capability-people.read')), findsNothing);
  });

  testWidgets('create uses three steps and only exposes save on review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: TestAccessProfileRepository(),
          logout: _logout,
          domain: AccessProfileDomain.institution,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigation = tester.widget<SuperadminFormStepNavigation>(
      find.byType(SuperadminFormStepNavigation),
    );
    expect(navigation.steps.map((step) => step.label), [
      'Perfil e escopo',
      'Permissões',
      'Revisão',
    ]);
    expect(find.byKey(const Key('access-profile-save')), findsNothing);
    expect(find.text('Pessoas vinculadas'), findsNothing);
    expect(tester.widget(find.byKey(const Key('access-profile-continue'))), isA<FilledButton>());
  });

  testWidgets('permission cells toggle with Space and Enter', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: TestAccessProfileRepository(),
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: '10000000-0000-4000-8000-000000000001',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();

    final focusTarget = find.byKey(const Key('capability-focus-people.read'));
    final permissionSemantics = find.byKey(const Key('capability-people.read'));
    bool selected() => tester.widget<Semantics>(permissionSemantics).properties.checked ?? false;
    final initialValue = selected();
    final focusDetector = find.descendant(
      of: focusTarget,
      matching: find.byType(FocusableActionDetector),
    );
    final focusNode = tester.widget<FocusableActionDetector>(focusDetector).focusNode!;
    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(selected(), isNot(initialValue));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected(), initialValue);
  });
  testWidgets('permission matrix only renders catalog capabilities and explains restrictions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: TestAccessProfileRepository(profiles: const [_restrictedProfile]),
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: _restrictedProfile.id,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('capability-people.read')), findsOneWidget);
    expect(find.byKey(const Key('capability-attendance.manage')), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);

    final inheritedSemantics = tester.getSemantics(find.byKey(const Key('capability-people.read')));
    expect(inheritedSemantics.label, contains('Origem: herdada'));
    expect(inheritedSemantics.label, contains('Efetiva: permitida'));
    final unavailableSemantics = tester.getSemantics(
      find.byKey(const Key('capability-attendance.manage')),
    );
    expect(unavailableSemantics.label, contains('Autoridade insuficiente'));
  });

  testWidgets('form remains usable at the 768px tablet breakpoint', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: TestAccessProfileRepository(),
          logout: _logout,
          domain: AccessProfileDomain.institution,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byKey(const Key('access-profile-form-footer-surface')), findsOneWidget);
    expect(find.byKey(const Key('access-profile-continue')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission matrix stacks at 375px with text at 200 percent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AccessProfileFormPage(
          repository: TestAccessProfileRepository(),
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: '10000000-0000-4000-8000-000000000001',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('access-profile-permission-matrix')), findsOneWidget);
    expect(find.text('Pessoas'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail shows effective links, audit and guarded deletion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = TestAccessProfileRepository(profiles: [_detailProfile]);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDetailPage(
          repository: repository,
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: _detailProfile.id,
          onBack: () {},
          onEdit: () {},
          onDeleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pessoa vinculada'), findsOneWidget);
    expect(find.text('Escopo efetivo: Plataforma'), findsOneWidget);
    expect(find.text('Permissões Superadmin alteradas'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byType(ListTile), findsNothing);

    final deleteButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Excluir'),
    );
    final colors = CoeloTheme.light.colorScheme;
    expect(deleteButton.style?.foregroundColor?.resolve({}), colors.error);
    expect(
      deleteButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.errorContainer,
    );
    expect(deleteButton.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir perfil'), findsOneWidget);
    final destructiveAction = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Excluir e realocar'),
    );
    expect(destructiveAction.onPressed, isNull);
  });
}

Widget _directoryApp() => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  home: AccessProfileDirectoryPage(repository: TestAccessProfileRepository(), logout: _logout),
);

Future<LogoutResult> _logout() async => const LogoutResult.success();

final _detailProfile = AccessProfile(
  id: 'detail-profile',
  domain: AccessProfileDomain.platform,
  code: 'detail.profile',
  name: 'Perfil detalhado',
  description: 'Perfil de teste isolado.',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 1,
  links: const [AccessProfileLink(id: 'link', personName: 'Pessoa vinculada', scope: 'Plataforma')],
  auditAvailable: true,
  auditEvents: [
    AccessAuditEvent(
      action: 'platform_permission_changed',
      occurredAt: DateTime.utc(2026, 7, 29, 12),
      reason: 'Revisão de acesso.',
    ),
  ],
);

const _restrictedProfile = AccessProfile(
  id: 'restricted-profile',
  domain: AccessProfileDomain.platform,
  code: 'restricted.profile',
  name: 'Perfil restrito',
  description: 'Catálogo com restrições.',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 0,
  permissions: [
    AccessPermission(
      code: 'people.read',
      module: 'Pessoas',
      screenCode: 'people',
      actionCode: 'read',
      name: 'Visualizar pessoas',
      selected: true,
      inherited: true,
    ),
    AccessPermission(
      code: 'attendance.manage',
      module: 'Pessoas',
      screenCode: 'attendance',
      actionCode: 'manage',
      name: 'Gerenciar frequência',
      grantable: false,
      unavailableReason: 'Autoridade insuficiente para attendance.manage.',
    ),
  ],
);

final class _ThrowingRepository implements AccessProfileRepository {
  const _ThrowingRepository({required this.unauthorized});

  final bool unauthorized;

  Never _throw() => unauthorized
      ? throw const AccessProfileUnauthorizedException()
      : throw const AccessProfileUnavailableException();

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) async => _throw();

  @override
  Future<List<PrincipalCapability>> fetchPrincipalCapabilities() async => _throw();

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) async => _throw();

  @override
  Future<AccessProfile> fetchTemplate(AccessProfileDomain domain) async => _throw();

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) async => _throw();

  @override
  Future<void> deleteAndReassign({
    required String requestId,
    required AccessProfileDomain domain,
    required String profileId,
    required int expectedVersion,
    required String? replacementProfileId,
    required String reason,
  }) async => _throw();
}
