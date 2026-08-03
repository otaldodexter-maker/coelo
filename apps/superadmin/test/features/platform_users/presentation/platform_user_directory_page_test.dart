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
    expect(find.text('Arquivos'), findsOneWidget);
    expect(find.textContaining('MFA'), findsNothing);

    final first = repository.records.first;
    await tester.tap(find.byKey(Key('platform-user-card-${first.id}')));
    expect(openedId, first.id);
  });

  testWidgets('offers preview import and export through the approved files flyout', (tester) async {
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

    final toggle = tester.widget<SuperadminDirectoryViewToggle<PlatformUserTableView>>(
      find.byType(SuperadminDirectoryViewToggle<PlatformUserTableView>),
    );
    toggle.onTableViewSelected(PlatformUserTableView.scopes);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Importar'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);

    await tester.tap(find.byKey(const Key('platform-user-files-import')));
    await tester.pumpAndSettle();
    expect(find.text('Importar usuários internos'), findsOneWidget);
    expect(find.textContaining('nenhum arquivo real será enviado'), findsOneWidget);
    expect(find.text('Selecionar arquivo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('platform-user-demo-file-picker')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('platform-user-import-review')));
    await tester.pumpAndSettle();
    expect(find.text('12 linhas válidas'), findsOneWidget);
    expect(find.text('2 linhas com erro'), findsOneWidget);
    await tester.tap(find.byKey(const Key('platform-user-import-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.text('Importação concluída somente no preview. Nenhum usuário real foi alterado.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('platform-user-files-export-csv')));
    await tester.pumpAndSettle();
    expect(find.textContaining('visão: Detalhado por escopos'), findsOneWidget);
  });

  testWidgets('switches between grouped and detailed scope tables', (tester) async {
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
    expect(toggle.tableViews.map((option) => option.label), ['Agrupado', 'Detalhado por escopos']);
    expect(find.byKey(const Key('platform-user-directory-table')), findsOneWidget);
    expect(find.text('Pessoa'), findsWidgets);
    expect(find.text('Papel'), findsWidgets);
    expect(find.text('Escopo'), findsWidgets);
    expect(find.text('Convite'), findsWidgets);
    expect(find.text('Revisado em'), findsWidgets);
    expect(find.byKey(const Key('platform-user-table-page-size-8')), findsOneWidget);

    toggle.onTableViewSelected(PlatformUserTableView.scopes);
    await tester.pumpAndSettle();
    expect(find.text('Instituição vinculada'), findsOneWidget);
    expect(find.text('Convite'), findsNothing);
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
  Future<void> update(PlatformUserRecord record) => throw UnimplementedError();
}
