import 'dart:async';

import '../../../support/activities/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
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
          onImportRequested: () async {},
          onExportRequested: (_) async =>
              const ActivityDirectoryExportResult(fileName: 'atividades.xlsx'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Atividades'), findsWidgets);
    expect(find.byKey(const Key('activity-card-activity-10')), findsOneWidget);
    final activityCard = find.byKey(const Key('activity-card-activity-10'));
    expect(
      find.descendant(of: activityCard, matching: find.byType(CoeloAdminInteractiveCard)),
      findsOneWidget,
    );
    final statusIndicator = tester.widget<CoeloAdminExpandableStatusIndicator>(
      find.descendant(of: activityCard, matching: find.byType(CoeloAdminExpandableStatusIndicator)),
    );
    expect(statusIndicator.label, ActivityStatus.archived.label);
    expect(statusIndicator.semanticLabel, 'Status da atividade: Arquivada');
    final activeIndicator = tester.widget<CoeloAdminExpandableStatusIndicator>(
      find.descendant(
        of: find.byKey(const Key('activity-card-activity-2')),
        matching: find.byType(CoeloAdminExpandableStatusIndicator),
      ),
    );
    expect(activeIndicator.label, ActivityStatus.active.label);
    expect(activeIndicator.semanticLabel, 'Status da atividade: Ativa');
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);
    expect(find.text('Criar atividade'), findsOneWidget);
    expect(find.textContaining('Editar atividade'), findsNothing);
    expect(
      find.byWidgetPredicate((widget) => widget is SuperadminDirectoryViewToggle),
      findsOneWidget,
    );
    expect(find.text('Instituição'), findsWidgets);
    expect(find.text('Tipo'), findsWidgets);
    expect(find.text('Unidades'), findsWidgets);
    expect(find.text('Turmas'), findsWidgets);
    expect(find.text('Equipe institucional'), findsNothing);
    expect(find.text('Crianças'), findsNothing);

    expect(
      tester.getSize(find.byType(CoeloAdminCreateAction)).height,
      closeTo(tester.getSize(find.byKey(const Key('activity-card-activity-10'))).height, 0.5),
    );

    await tester.tap(find.text('Criar atividade'));
    expect(createCount, 1);
    await tester.tap(find.byKey(const Key('activity-card-activity-10')));
    expect(viewedId, 'activity-10');
    expect(editedId, isNull);
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
    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsNothing);
    expect(find.byKey(const Key('coelo-admin-pagination-page-1')), findsNothing);
    expect(find.textContaining(RegExp(r'Página 1 de \d+')), findsOneWidget);
    expect(find.bySemanticsLabel('Página anterior'), findsOneWidget);
    expect(find.bySemanticsLabel('Próxima página'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
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

  testWidgets('export identifies the selected table view', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ActivityDirectoryExportRequest? exported;
    var importCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: FakeActivityDirectoryRepository(),
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
          onImportRequested: () async => importCount++,
          onExportRequested: (request) async {
            exported = request;
            return const ActivityDirectoryExportResult(fileName: 'atividades-turmas.xlsx');
          },
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
    await tester.tap(find.text('Exportar XLSX'));
    await tester.pumpAndSettle();

    expect(exported?.format, ActivityDirectoryExportFormat.xlsx);
    expect(exported?.tableView, ActivityDirectoryTableView.groups);
    expect(find.textContaining('atividades-turmas.xlsx'), findsOneWidget);
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(importCount, 1);
    expect(
      find.textContaining(RegExp(r'fake|demo|dev|catálogo|teste', caseSensitive: false)),
      findsNothing,
    );
  });

  testWidgets('stacks filters by internal width at 200 percent text', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
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

      final controls = tester.getRect(find.byKey(const Key('activity-filter-controls')));
      final filters = [
        tester.getRect(find.byKey(const Key('activity-institution-filter'))),
        tester.getRect(find.byKey(const Key('activity-unit-filter'))),
        tester.getRect(find.byKey(const Key('activity-group-filter'))),
        tester.getRect(find.byKey(const Key('activity-status-filter'))),
        tester.getRect(find.byKey(const Key('activity-origin-filter'))),
      ];
      for (final filter in filters) {
        expect(filter.width, closeTo(controls.width, 1), reason: '$width filter width');
      }
      for (var index = 1; index < filters.length; index++) {
        expect(filters[index].top, greaterThan(filters[index - 1].bottom));
      }
      expect(tester.takeException(), isNull, reason: '$width overflow');
    }
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
    expect(find.byKey(const Key('activity-status-filter')), findsOneWidget);
    expect(find.byKey(const Key('activity-status-tabs')), findsNothing);
    final statusFilter = tester.widget<CoeloAdminMultiSelectFilter<ActivityStatus>>(
      find.descendant(
        of: find.byKey(const Key('activity-status-filter')),
        matching: find.byType(CoeloAdminMultiSelectFilter<ActivityStatus>),
      ),
    );
    expect(statusFilter.options, ActivityStatus.values);
    expect(find.byKey(const Key('activity-origin-filter')), findsOneWidget);
    expect(find.byKey(const Key('activity-type-filter')), findsNothing);
    expect(find.text('Recorrência'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('status filter applies the real activity status query', (tester) async {
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

    expect(find.byKey(const Key('activity-card-activity-10')), findsOneWidget);

    final statusFilter = tester.widget<CoeloAdminMultiSelectFilter<ActivityStatus>>(
      find.descendant(
        of: find.byKey(const Key('activity-status-filter')),
        matching: find.byType(CoeloAdminMultiSelectFilter<ActivityStatus>),
      ),
    );
    statusFilter.onChanged({ActivityStatus.active});
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-card-activity-2')), findsOneWidget);
    expect(find.byKey(const Key('activity-card-activity-10')), findsNothing);
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

    expect(
      find.descendant(of: card, matching: find.byType(CoeloAdminInteractiveCard)),
      findsOneWidget,
    );
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
      expect(
        find.byType(CoeloAdminCreateAction),
        scenario.$1 == _DirectoryScenario.unauthorized ? findsNothing : findsOneWidget,
      );
      if (scenario.$1 != _DirectoryScenario.unauthorized) {
        await tester.tap(find.byKey(const Key('activity-view-table')));
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const Key('create-activity-banner')),
        scenario.$1 == _DirectoryScenario.unauthorized ? findsNothing : findsOneWidget,
      );
    });
  }

  testWidgets('keeps create visible with no results and still clears filters', (tester) async {
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

    await tester.enterText(find.byType(CoeloSearchField), 'atividade inexistente');
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma atividade encontrada'), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.text('Limpar filtros'), findsAtLeastNWidgets(1));
    await tester.tap(find.byKey(const Key('activity-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-activity-banner')), findsOneWidget);
  });

  testWidgets('starts from and duplicates a real predefined template', (tester) async {
    ActivityTemplateOption? started;
    ActivityTemplateOption? duplicated;
    String? duplicateInstitutionId;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: _TemplateOptionsRepository(),
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
          onCreateFromTemplate: (template) => started = template,
          onDuplicateTemplate: (template, institutionId) async {
            duplicated = template;
            duplicateInstitutionId = institutionId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-type-tabs')), findsOneWidget);
    expect(find.byKey(const Key('activity-card-activity-10')), findsNothing);
    expect(find.text('Modelos de atividades'), findsNothing);
    expect(find.byKey(const Key('create-activity-template-tile')), findsOneWidget);
    expect(find.text('Modelo Coelo'), findsNWidgets(2));
    expect(find.byKey(const Key('activity-template-template-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-template-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-template-table')), findsOneWidget);
    expect(find.byKey(const Key('activity-template-row-template-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-template-view-cards')));
    await tester.pumpAndSettle();
    final categoryFilter = tester.widget<CoeloAdminMultiSelectFilter<ActivityTaxonomyOption>>(
      find.byKey(const Key('activity-template-taxonomy-filter')),
    );
    categoryFilter.onChanged({const ActivityTaxonomyOption(id: 'sports', label: 'Esportes')});
    await tester.pump();
    expect(find.byKey(const Key('activity-template-template-1')), findsNothing);
    expect(find.byKey(const Key('activity-template-template-2')), findsOneWidget);
    categoryFilter.onChanged({});
    await tester.pump();
    expect(find.byKey(const Key('activity-template-template-1')), findsOneWidget);
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('activity-template-origin-filter')),
        )
        .onChanged('Institucional');
    await tester.enterText(find.byKey(const Key('activity-template-search')), 'sem resultado');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('activity-template-clear-filters')));
    await tester.pump();
    tester
        .widget<TextButton>(find.byKey(const Key('activity-template-clear-filters')))
        .onPressed!();
    await tester.pump();
    expect(find.byKey(const Key('activity-template-template-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-template-start-template-1')));
    expect(started?.id, 'template-1');

    await tester.tap(find.byKey(const Key('activity-template-duplicate-template-1')));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<String?>>(
          find.byKey(const Key('activity-template-copy-institution')),
        )
        .onChanged('institution-1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-template-copy-submit')));
    await tester.pumpAndSettle();

    expect(duplicated?.id, 'template-1');
    expect(duplicateInstitutionId, 'institution-1');
    expect(find.text('Modelo duplicado com sucesso.'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('activity-directory-scroll')),
      const Offset(0, 2000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atividades').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-card-activity-10')), findsOneWidget);
    expect(find.byKey(const Key('activity-template-section')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps model loading and failure local to the activity directory', (tester) async {
    final delayed = _DelayedTemplateRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: delayed,
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
          onCreateFromTemplate: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('activity-templates-loading')), findsOneWidget);
    expect(find.byKey(const Key('create-activity-template-tile')), findsOneWidget);
    expect(find.byKey(const Key('activity-card-activity-10')), findsNothing);
    delayed.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-template-section')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: _FailingTemplateRepository(),
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
          onCreateFromTemplate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-templates-failure')), findsOneWidget);
    expect(find.byKey(const Key('create-activity-template-tile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-template-view-table')));
    await tester.pump();
    expect(find.byKey(const Key('create-activity-template-banner')), findsOneWidget);
    expect(find.byKey(const Key('activity-card-activity-10')), findsNothing);
  });

  testWidgets('does not fetch or render models when activity access is unauthorized', (
    tester,
  ) async {
    final repository = _ScenarioRepository(_DirectoryScenario.unauthorized);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
          onCreateFromTemplate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byKey(const Key('activity-type-tabs')), findsNothing);
    expect(find.byKey(const Key('activity-template-toolbar')), findsNothing);
    expect(find.byKey(const Key('activity-template-section')), findsNothing);
    expect(find.byKey(const Key('activity-templates-loading')), findsNothing);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
    expect(repository.formOptionsCalls, 0);
  });

  testWidgets('shows an honest initial loading state with Models selected', (tester) async {
    final repository = _InitialLoadingRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ActivityDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onCreate: () {},
          onView: (_) {},
          onCreateFromTemplate: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('activity-directory-loading')), findsOneWidget);
    expect(find.byKey(const Key('activity-template-section')), findsNothing);
    repository.complete();
    await tester.pumpAndSettle();
  });
}

enum _DirectoryScenario { empty, failure, unauthorized }

final class _ScenarioRepository implements ActivityDirectoryRepository {
  _ScenarioRepository(this.scenario);

  final _DirectoryScenario scenario;
  int formOptionsCalls = 0;

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
  Future<ActivityFormOptions> fetchFormOptions({required String institutionId}) async {
    formOptionsCalls++;
    return const ActivityFormOptions();
  }

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async {
    formOptionsCalls++;
    return const ActivityTemplateOptions();
  }

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) async => const [];

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

final class _DelayedTemplateRepository extends FakeActivityDirectoryRepository {
  final Completer<ActivityTemplateOptions> _completer = Completer<ActivityTemplateOptions>();

  void complete() => _completer.complete(const ActivityTemplateOptions());

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) =>
      _completer.future;
}

final class _InitialLoadingRepository extends FakeActivityDirectoryRepository {
  final Completer<ActivityDirectoryResult> _page = Completer<ActivityDirectoryResult>();

  void complete() => _page.complete(
    const ActivityDirectoryResult(items: [], totalCount: 0, page: 0, pageSize: 11),
  );

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) => _page.future;
}

final class _FailingTemplateRepository extends FakeActivityDirectoryRepository {
  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) =>
      Future.error(const ActivityDirectoryUnavailableException());
}

final class _TemplateOptionsRepository extends FakeActivityDirectoryRepository {
  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({String? institutionId}) async =>
      const ActivityTemplateOptions(
        institutions: [
          ActivityFormInstitutionOption(id: 'institution-1', name: 'Colégio Horizonte'),
        ],
        taxonomy: [
          ActivityTaxonomyOption(id: 'languages', label: 'Idiomas'),
          ActivityTaxonomyOption(id: 'sports', label: 'Esportes'),
        ],
        templates: [
          ActivityTemplateOption(id: 'template-1', name: 'Inglês', taxonomyId: 'languages'),
          ActivityTemplateOption(id: 'template-2', name: 'Futebol', taxonomyId: 'sports'),
        ],
      );
}
