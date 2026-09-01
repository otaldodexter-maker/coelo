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
  testWidgets('renders canonical cards, files and opens edit directly', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakePlatformUserRepository();
    String? editedId;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PlatformUserDirectoryPage(
          repository: repository,
          capability: PlatformUserCapability.owner,
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (id) => editedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Usuários internos'), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    final createAction = tester.widget<CoeloAdminCreateAction>(find.byType(CoeloAdminCreateAction));
    expect(createAction.variant, CoeloAdminCreateActionVariant.tile);
    expect(
      tester.getSize(find.byKey(const Key('create-platform-user-card'))).height,
      closeTo(
        tester.getSize(find.byKey(Key('platform-user-card-${repository.records.first.id}'))).height,
        0.5,
      ),
    );
    expect(find.byKey(const Key('platform-user-role-filter')), findsOneWidget);
    expect(find.byKey(const Key('platform-user-status-filter')), findsOneWidget);
    expect(find.text('Arquivos'), findsOneWidget);
    expect(find.textContaining('MFA'), findsNothing);

    final first = repository.records.first;
    await tester.tap(find.byKey(Key('platform-user-card-${first.id}')));
    expect(editedId, first.id);
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
    expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);
    expect(find.byKey(const Key('platform-user-card-grid')), findsOneWidget);
  });

  testWidgets('repository and capability swap clear every context A query', (tester) async {
    final pageKey = GlobalKey();
    final repositoryA = _LifecycleRepository.immediate('Contexto A');
    final repositoryB = _LifecycleRepository.immediate('Contexto B');

    await tester.pumpWidget(
      _directoryApp(
        key: pageKey,
        repository: repositoryA,
        capability: PlatformUserCapability.owner,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Contexto A Exclusivo'), findsWidgets);

    await tester.enterText(find.byKey(const Key('platform-user-search')), 'busca de A');
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('platform-user-view-table')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _directoryApp(
        key: pageKey,
        repository: repositoryB,
        capability: PlatformUserCapability.unauthorized,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Contexto A Exclusivo'), findsNothing);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(repositoryB.queries, isEmpty);

    await tester.pumpWidget(
      _directoryApp(
        key: pageKey,
        repository: repositoryB,
        capability: PlatformUserCapability.owner,
      ),
    );
    await tester.pumpAndSettle();

    expect(repositoryB.queries, hasLength(1));
    final query = repositoryB.queries.single;
    expect(query.search, isEmpty);
    expect(query.profileIds, isEmpty);
    expect(query.statuses, isEmpty);
    expect(query.scopes, isEmpty);
    expect(query.page, 1);
    expect(query.view, PlatformUserDirectoryView.cards);
    expect(query.pageSize, PlatformUserQuery.cardsPageSize);
    expect(find.text('Contexto B Exclusivo'), findsWidgets);
    expect(find.text('Contexto A Exclusivo'), findsNothing);
  });

  testWidgets('late repository A response cannot repaint repository B', (tester) async {
    final pageKey = GlobalKey();
    final repositoryA = _LifecycleRepository.pending('Contexto A');
    final repositoryB = _LifecycleRepository.pending('Contexto B');

    await tester.pumpWidget(
      _directoryApp(
        key: pageKey,
        repository: repositoryA,
        capability: PlatformUserCapability.owner,
      ),
    );
    await tester.pump();
    expect(repositoryA.queries, hasLength(1));

    await tester.pumpWidget(
      _directoryApp(
        key: pageKey,
        repository: repositoryB,
        capability: PlatformUserCapability.owner,
      ),
    );
    await tester.pump();
    expect(repositoryB.queries, hasLength(1));

    repositoryB.complete();
    await tester.pumpAndSettle();
    expect(find.text('Contexto B Exclusivo'), findsWidgets);

    repositoryA.complete();
    await tester.pump();
    expect(find.text('Contexto B Exclusivo'), findsWidgets);
    expect(find.text('Contexto A Exclusivo'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
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
    await tester.enterText(find.byKey(const Key('platform-user-search')), 'sem correspondência');
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

  testWidgets('keeps cards and table stable across the responsive matrix', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
      for (final scale in const [1.0, 2.0]) {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: PlatformUserDirectoryPage(
              repository: FakePlatformUserRepository(),
              capability: PlatformUserCapability.owner,
              logout: unavailableSuperadminLogout,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('platform-user-card-grid')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: width.toString());

        await tester.tap(find.byKey(const Key('platform-user-view-table')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('platform-user-directory-table')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: width.toString());

        await tester.tap(find.byKey(const Key('platform-user-view-cards')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('platform-user-card-grid')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: width.toString());
      }
    }
  });
}

Widget _directoryApp({
  required Key key,
  required PlatformUserRepository repository,
  required PlatformUserCapability capability,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: PlatformUserDirectoryPage(
    key: key,
    repository: repository,
    capability: capability,
    logout: unavailableSuperadminLogout,
  ),
);

final class _LifecycleRepository implements PlatformUserRepository {
  _LifecycleRepository._(this._record, this._pending);

  factory _LifecycleRepository.immediate(String name) =>
      _LifecycleRepository._(_recordNamed(name), false);

  factory _LifecycleRepository.pending(String name) =>
      _LifecycleRepository._(_recordNamed(name), true);

  final PlatformUserRecord _record;
  final bool _pending;
  final queries = <PlatformUserQuery>[];
  final _completion = Completer<PlatformUserPage>();

  void complete() {
    if (!_completion.isCompleted) _completion.complete(_page());
  }

  PlatformUserPage _page() => PlatformUserPage(
    items: [_record],
    totalCount: 1,
    page: queries.last.page,
    pageSize: queries.last.pageSize,
  );

  @override
  Future<PlatformUserPage> fetchPage(PlatformUserQuery query) {
    queries.add(query);
    return _pending ? _completion.future : Future.value(_page());
  }

  @override
  List<PlatformAccessProfile> get profiles => PlatformAccessProfiles.values;

  @override
  List<PlatformUserRecord> get records => [_record];

  @override
  PlatformUserRecord? findById(String id) => id == _record.id ? _record : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlatformUserRecord _recordNamed(String name) {
  final source = FakePlatformUserRepository().records.first;
  return source.copyWith(
    identity: source.identity.copyWith(firstName: name, lastName: 'Exclusivo', displayName: ''),
  );
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
