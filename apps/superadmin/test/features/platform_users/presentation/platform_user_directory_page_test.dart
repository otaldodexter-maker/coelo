import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_directory_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders canonical cards and opens view instead of edit', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakePlatformUserRepository();
    String? openedId;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserDirectoryPage(
          repository: repository,
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
          onView: (id) => openedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usuários internos'), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.byKey(const Key('platform-user-role-filter')), findsOneWidget);
    expect(find.byKey(const Key('platform-user-status-filter')), findsOneWidget);
    expect(find.text('Arquivos'), findsNothing);
    expect(find.textContaining('MFA'), findsNothing);

    final first = repository.records.first;
    await tester.tap(find.byKey(Key('platform-user-card-${first.id}')));
    expect(openedId, first.id);
  });

  testWidgets('uses one canonical grouped table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserDirectoryPage(
          repository: FakePlatformUserRepository(),
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('platform-user-view-table')));
    await tester.pumpAndSettle();

    final toggle = tester.widget<SuperadminDirectoryViewToggle<PlatformUserTableView>>(
      find.byType(SuperadminDirectoryViewToggle<PlatformUserTableView>),
    );
    expect(toggle.tableViews.map((option) => option.label), ['Agrupado']);
    expect(find.byKey(const Key('platform-user-directory-table')), findsOneWidget);
    expect(find.text('Pessoa'), findsWidgets);
    expect(find.text('Perfil'), findsWidgets);
    expect(find.text('Escopo'), findsWidgets);
    expect(find.text('Convite'), findsWidgets);
    expect(find.text('Revisado em'), findsWidgets);
    expect(find.byKey(const Key('platform-user-table-page-size-8')), findsOneWidget);

    expect(find.text('Vínculo'), findsWidgets);
  });

  testWidgets('uses the measured shared pagination footer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserDirectoryPage(
          repository: FakePlatformUserRepository(),
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminListingPaginationFooter), findsOneWidget);
    final scroll = tester.widget<ListView>(
      find.byKey(const Key('platform-user-directory-content-scroll')),
    );
    expect((scroll.padding! as EdgeInsets).bottom, greaterThan(CoeloSpacing.space4));
  });

  testWidgets('shows no permission without exposing create', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserDirectoryPage(
          repository: FakePlatformUserRepository(),
          capability: PlatformUserCapability.unauthorized,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
  });

  testWidgets('keeps Auditor read only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserDirectoryPage(
          repository: FakePlatformUserRepository(),
          capability: PlatformUserCapability.auditor,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    expect(find.byKey(const Key('coelo-admin-files-action')), findsNothing);
    expect(find.byKey(const Key('platform-user-card-grid')), findsOneWidget);
  });

  testWidgets('renders loading, empty, error, and no-results states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<PlatformUserPage>();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserDirectoryPage(
          repository: _ScenarioRepository(pending: pending),
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.complete(const PlatformUserPage(items: [], totalCount: 0, page: 1, pageSize: 11));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum usuário interno cadastrado'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserDirectoryPage(
          repository: _ScenarioRepository(error: StateError('falha')),
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar os usuários internos'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserDirectoryPage(
          repository: FakePlatformUserRepository(),
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sem correspondência');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado encontrado'), findsOneWidget);
  });

  testWidgets('supports 200 percent text at compact width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: PlatformUserDirectoryPage(
          repository: FakePlatformUserRepository(),
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('platform-user-pagination-footer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _ScenarioRepository implements PlatformUserRepository {
  _ScenarioRepository({this.pending, this.error});

  final Completer<PlatformUserPage>? pending;
  final Object? error;

  @override
  List<PlatformUserRecord> get records => const [];

  @override
  List<PlatformAccessProfile> get profiles => PlatformAccessProfiles.values;

  @override
  PlatformUserRecord? findById(String id) => null;

  @override
  Future<PlatformUserPage> fetchPage(PlatformUserQuery query) {
    if (error case final error?) return Future.error(error);
    return pending?.future ??
        Future.value(
          PlatformUserPage(
            items: const [],
            totalCount: 0,
            page: query.page,
            pageSize: query.pageSize,
          ),
        );
  }

  @override
  Future<PlatformUserCreateResult> create(PlatformUserDraft draft) => throw UnimplementedError();

  @override
  Future<PlatformUserRecord> update(String id, PlatformUserDraft draft) =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
