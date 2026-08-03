import 'package:coelo_superadmin/features/access_profiles/data/fake_access_profile_repository.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_detail_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_directory_page.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_underline_tabs.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
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
    expect(find.byKey(const Key('access-profile-demo-notice')), findsOneWidget);
    expect(find.text('Perfil define teto; atribuição define contexto efetivo'), findsOneWidget);
    expect(find.text('Predefinido'), findsWidgets);
    expect(find.byType(SuperadminUnderlineTabs<AccessProfileDomain>), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('access-profile-toolbar'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('access-profile-domain-selector'))).dy),
    );
    expect(
      tester.getSize(find.byKey(const Key('create-access-profile-card'))).height,
      tester.getSize(find.byKey(const Key('access-profile-card-demo-owner'))).height,
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
    expect(find.text('Grupo'), findsOneWidget);
    expect(find.text('Atividade'), findsOneWidget);
  });

  testWidgets('Principal is read-only and does not expose profile creation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_directoryApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Principal'));
    await tester.pumpAndSettle();

    expect(find.text('Catálogo somente leitura'), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    expect(find.textContaining('contextos'), findsWidgets);
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
          repository: FakeAccessProfileRepository(),
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
    await tester.enterText(find.bySemanticsLabel('Buscar capacidade do Principal'), 'conversar');
    await tester.pump();

    expect(find.text('Conversar'), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
  });

  testWidgets('shows empty, error and unauthorized states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileDirectoryPage(
          repository: FakeAccessProfileRepository(profiles: const []),
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

  testWidgets('editor disables ungrantable permission and opens review dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: AccessProfileFormPage(
          repository: FakeAccessProfileRepository(),
          logout: _logout,
          domain: AccessProfileDomain.platform,
          profileId: 'demo-owner',
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('access-profile-form-footer-surface')), findsOneWidget);
    final scroll = find
        .descendant(
          of: find.byKey(const Key('access-profile-form-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(find.text('Catálogo predefinido'), 300, scrollable: scroll);
    expect(find.text('Catálogo predefinido'), findsOneWidget);
    expect(find.textContaining('controle total da plataforma'), findsOneWidget);
    expect(find.text('Perfil define teto; atribuição define contexto efetivo.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Atividade · Robótica'), 300, scrollable: scroll);
    expect(find.text('Instituição · Colégio Horizonte'), findsOneWidget);
    expect(find.text('Unidade · Unidade Centro'), findsOneWidget);
    expect(find.text('Grupo (Turma) · Girassol'), findsOneWidget);
    expect(find.text('Atividade · Robótica'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('permission-support.manage')),
      300,
      scrollable: scroll,
    );
    final unavailable = tester.widget<CheckboxListTile>(
      find.byKey(const Key('permission-support.manage')),
    );
    expect(unavailable.enabled, isFalse);

    await tester.tap(find.byKey(const Key('review-access-profile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('access-profile-review-dialog')), findsOneWidget);
    expect(find.text('Permissões adicionadas'), findsOneWidget);
    expect(find.text('Permissões removidas'), findsOneWidget);
  });

  testWidgets('detail shows effective links, audit and guarded deletion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeAccessProfileRepository(profiles: [_detailProfile]);
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

    expect(find.text('Pessoa de demonstração'), findsOneWidget);
    expect(find.text('Escopo efetivo: Plataforma'), findsOneWidget);
    expect(find.text('Permissões Superadmin alteradas'), findsOneWidget);

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
  home: AccessProfileDirectoryPage(repository: FakeAccessProfileRepository(), logout: _logout),
);

Future<LogoutResult> _logout() async => const LogoutResult.success();

final _detailProfile = AccessProfile(
  id: 'detail-profile',
  domain: AccessProfileDomain.platform,
  code: 'detail.profile',
  name: 'Perfil detalhado',
  description: 'Perfil de demonstração.',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 1,
  links: const [
    AccessProfileLink(id: 'link', personName: 'Pessoa de demonstração', scope: 'Plataforma'),
  ],
  auditAvailable: true,
  auditEvents: [
    AccessAuditEvent(
      action: 'platform_permission_changed',
      occurredAt: DateTime.utc(2026, 7, 29, 12),
      reason: 'Revisão de acesso.',
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
  bool get isDemo => false;

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
