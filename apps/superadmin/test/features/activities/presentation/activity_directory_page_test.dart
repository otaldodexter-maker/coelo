import 'package:coelo_superadmin/features/activities/data/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders canonical cards and opens the read-only detail', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? viewedId;
    String? editedId;
    var createCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onCreate: () => createCount++,
          onEdit: (id) => editedId = id,
          onView: (id) => viewedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atividades'), findsWidgets);
    expect(find.byKey(const Key('activity-card-activity-10')), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);
    expect(find.text('Criar atividade'), findsOneWidget);
    expect(find.textContaining('Editar atividade'), findsNothing);
    expect(
      find.byWidgetPredicate((widget) => widget is SuperadminDirectoryViewToggle),
      findsOneWidget,
    );
    expect(find.textContaining('Local:'), findsWidgets);
    expect(find.text('Unidades'), findsWidgets);
    expect(find.text('Turmas'), findsWidgets);
    expect(find.text('Equipe institucional'), findsWidgets);
    expect(find.text('Crianças'), findsWidgets);

    expect(
      tester.getSize(find.byType(CoeloAdminCreateAction)).height,
      closeTo(tester.getSize(find.byKey(const Key('activity-card-activity-10'))).height, 0.5),
    );

    await tester.tap(find.text('Criar atividade'));
    expect(createCount, 1);
    await tester.tap(find.byKey(const Key('activity-card-activity-10')));
    expect(editedId, 'activity-10');
    expect(viewedId, isNull);
    expect(find.byKey(const Key('activity-card-edit-activity-10')), findsNothing);
  });

  testWidgets('switches between grouped, unit and group table views', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('activity-view-table')));
    await tester.pumpAndSettle();
    expect(find.text('Agrupado'), findsOneWidget);
    expect(find.text('Por Unidades'), findsOneWidget);
    expect(find.text('Por Turmas'), findsOneWidget);
    await tester.tap(find.text('Por Unidades'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-unit-directory-table')), findsOneWidget);

    await tester.longPress(find.byKey(const Key('activity-view-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Por Turmas'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-group-directory-table')), findsOneWidget);
    expect(find.byKey(const Key('activity-detail-status-activity-10')), findsOneWidget);
  });

  testWidgets('switches to the canonical resizable table and keeps sticky pagination', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: ActivityDirectoryPage(
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-directory-pagination-footer')), findsOneWidget);
    expect(find.byType(SuperadminListingPaginationFooter), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final toggle = tester.widget<SuperadminDirectoryViewToggle<ActivityDirectoryTableView>>(
      find.byType(SuperadminDirectoryViewToggle<ActivityDirectoryTableView>),
    );
    toggle.onTableViewSelected(ActivityDirectoryTableView.grouped);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-directory-table')), findsOneWidget);
    expect(find.byKey(const Key('create-activity-banner')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export preview identifies the selected table view', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('activity-view-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Por Turmas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-files-export-xlsx')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Por Turmas'), findsOneWidget);
    expect(find.textContaining('Nenhum arquivo real foi gerado'), findsOneWidget);
  });

  testWidgets('shows only confirmed filters and supports reduced motion focus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ActivityDirectoryPage(
            repository: FakeActivityDirectoryRepository(),
            logout: () async => const LogoutResult.success(),
            onCreate: () {},
            onView: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-institution-filter')), findsOneWidget);
    expect(find.byKey(const Key('activity-unit-filter')), findsOneWidget);
    expect(find.byKey(const Key('activity-group-filter')), findsOneWidget);
    expect(find.byKey(const Key('activity-status-filter')), findsNothing);
    expect(find.byKey(const Key('activity-status-tabs')), findsOneWidget);
    for (final label in ['Todos', 'Ativos', 'Em Implantação', 'Inativos']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('activity-origin-filter')), findsOneWidget);
    expect(find.text('Tipo'), findsNothing);
    expect(find.text('Recorrência'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('status tabs are visual and keep the same activity results', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialCards = find.byType(CoeloAdminInteractiveCard).evaluate().length;
    expect(find.byKey(const Key('activity-card-activity-10')), findsOneWidget);

    await tester.tap(find.text('Inativos'));
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminInteractiveCard), findsNWidgets(initialCards));
    expect(find.byKey(const Key('activity-card-activity-10')), findsOneWidget);
  });

  testWidgets('uses the approved hover treatment without changing card geometry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const Key('activity-card-activity-10'));
    final before = tester.getSize(card);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();

    final surface = tester.widget<Container>(
      find.byKey(const Key('activity-card-surface-activity-10')),
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.width, greaterThan(1));
    expect(tester.getSize(card), before);
  });

  for (final scenario in [
    (_DirectoryScenario.empty, 'Nenhuma atividade cadastrada'),
    (_DirectoryScenario.failure, 'Não foi possível carregar as atividades'),
    (_DirectoryScenario.unauthorized, 'Acesso não autorizado'),
  ]) {
    testWidgets('renders the ${scenario.$1.name} directory state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: ActivityDirectoryPage(
            repository: _ScenarioRepository(scenario.$1),
            logout: () async => const LogoutResult.success(),
            onCreate: () {},
            onView: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(scenario.$2), findsOneWidget);
    });
  }
}

enum _DirectoryScenario { empty, failure, unauthorized }

final class _ScenarioRepository implements ActivityDirectoryRepository {
  const _ScenarioRepository(this.scenario);

  final _DirectoryScenario scenario;

  @override
  Future<ActivityDetail?> fetchById(String activityId) async => null;

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async {
    if (scenario == _DirectoryScenario.failure) {
      throw const ActivityDirectoryUnavailableException();
    }
    if (scenario == _DirectoryScenario.unauthorized) {
      throw const ActivityDirectoryUnauthorizedException();
    }
    return const ActivityFilterOptions();
  }

  @override
  Future<ActivityFormOptions> fetchFormOptions() async => const ActivityFormOptions();

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async {
    if (scenario == _DirectoryScenario.failure) {
      throw const ActivityDirectoryUnavailableException();
    }
    if (scenario == _DirectoryScenario.unauthorized) {
      throw const ActivityDirectoryUnauthorizedException();
    }
    return ActivityDirectoryResult(
      items: const [],
      totalCount: 0,
      page: query.page,
      pageSize: query.pageSize,
    );
  }
}
