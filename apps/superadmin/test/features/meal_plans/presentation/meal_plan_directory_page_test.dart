import 'dart:async';

import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/presentation/meal_plan_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens with Models first and exposes honest file actions', (tester) async {
    await tester.pumpWidget(
      _app(
        repository: _DirectoryRepository(
          item: _plan(id: 'template-a', name: 'Modelo sazonal'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar modelo de cardápio'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Modelos')).dx,
      lessThan(tester.getTopLeft(find.text('Cardápios')).dx),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Importar arquivo'), findsOneWidget);
    expect(find.text('Exportar CSV'), findsOneWidget);
    expect(find.text('Exportar XLSX'), findsOneWidget);

    await tester.tap(find.text('Importar arquivo'));
    await tester.pumpAndSettle();
    expect(find.text('Importação de cardápios estará disponível em breve.'), findsOneWidget);
  });

  testWidgets('repository swap clears A filters and rejects its late response', (tester) async {
    final lateA = Completer<MealPlanPage>();
    final repositoryA = _DirectoryRepository(
      item: _plan(id: 'plan-a', name: 'Cardápio exclusivo A'),
      onFetch: (filter, item) {
        if (filter.search != null) return lateA.future;
        return Future.value(_page(item, filter, total: 24));
      },
    );
    final repositoryB = _DirectoryRepository(
      item: _plan(id: 'plan-b', name: 'Cardápio exclusivo B'),
    );
    final pageKey = GlobalKey();

    await tester.pumpWidget(_app(pageKey: pageKey, repository: repositoryA));
    await tester.pumpAndSettle();

    final statusField = tester.widget<CoeloAdminSingleSelectField<MealPlanStatus?>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CoeloAdminSingleSelectField<MealPlanStatus?> && widget.label == 'Status',
      ),
    );
    statusField.onChanged(MealPlanStatus.inReview);
    await tester.pumpAndSettle();
    tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)).onPageSelected!(2);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CoeloSearchField), 'contexto A');
    await tester.pump();
    expect(lateA.isCompleted, isFalse);

    await tester.pumpWidget(_app(pageKey: pageKey, repository: repositoryB));
    await tester.pumpAndSettle();

    expect(repositoryB.filters, hasLength(1));
    final queryB = repositoryB.filters.single;
    expect(queryB.search, isNull);
    expect(queryB.statuses, isEmpty);
    expect(queryB.page, 0);
    expect(queryB.pageSize, 11);
    expect(find.text('Cardápio exclusivo B'), findsOneWidget);
    expect(find.text('Cardápio exclusivo A'), findsNothing);
    expect(tester.widget<CoeloSearchField>(find.byType(CoeloSearchField)).controller.text, isEmpty);

    lateA.complete(_page(repositoryA.item, repositoryA.filters.last, total: 24));
    await tester.pump();
    expect(find.text('Cardápio exclusivo B'), findsOneWidget);
    expect(find.text('Cardápio exclusivo A'), findsNothing);
  });

  testWidgets('publish intent never crosses repositories after a context swap', (tester) async {
    final conflictsA = Completer<List<MealPlanConflict>>();
    final repositoryA = _DirectoryRepository(
      item: _plan(id: 'plan-a', name: 'Cardápio A'),
      conflictCheck: () => conflictsA.future,
    );
    final repositoryB = _DirectoryRepository(
      item: _plan(id: 'plan-b', name: 'Cardápio B'),
    );
    final pageKey = GlobalKey();

    await tester.pumpWidget(_app(pageKey: pageKey, repository: repositoryA));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar'));
    await tester.pump();
    expect(repositoryA.conflictChecks, 1);

    await tester.pumpWidget(_app(pageKey: pageKey, repository: repositoryB));
    await tester.pumpAndSettle();
    conflictsA.complete(const []);
    await tester.pump();

    expect(repositoryA.publishCalls, 0);
    expect(repositoryB.publishCalls, 0);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Cardápio B'), findsOneWidget);

    await tester.tap(find.byTooltip('Ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publicar'));
    await tester.pumpAndSettle();
    expect(repositoryB.publishCalls, 1);
  });

  testWidgets('matches the Cards and Table directory contract at every breakpoint', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [
      Size(375, 1100),
      Size(768, 1100),
      Size(1024, 1100),
      Size(1440, 1100),
    ]) {
      for (final scale in const [1.0, 2.0]) {
        await tester.binding.setSurfaceSize(size);
        final item = _plan(id: 'plan-${size.width}-$scale', name: 'Cardápio responsivo');
        await tester.pumpWidget(
          _app(
            key: ValueKey('${size.width}-$scale'),
            repository: _DirectoryRepository(item: item),
            onEdit: (_) {},
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('meal-plan-directory-card-grid')), findsOneWidget);
        final card = tester.widget<CoeloAdminInteractiveCard>(
          find.byKey(Key('meal-plan-card-${item.id}')),
        );
        expect(card.minHeight, 216);
        expect(
          find.descendant(
            of: find.byKey(Key('meal-plan-card-${item.id}')),
            matching: find.bySemanticsLabel('Status: Em revisão'),
          ),
          findsOneWidget,
        );
        expect(find.byType(CoeloStatusChip), findsNothing);
        var pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
        expect(pagination.pageSize, 11);
        expect(pagination.pageSizeOptions, const [11, 20, 50, 100]);
        expect(
          tester.takeException(),
          isNull,
          reason: 'cards at ${size.width}px and ${scale * 100}% text',
        );

        await tester.tap(find.byKey(const Key('meal-plan-directory-view-table')));
        await tester.pumpAndSettle();
        expect(find.byType(CoeloAdminResizableTable<MealPlan>), findsOneWidget);
        expect(find.byType(CoeloStatusChip), findsOneWidget);
        expect(find.byType(CoeloAdminExpandableStatusIndicator), findsNothing);
        pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
        expect(pagination.pageSize, 8);
        expect(pagination.pageSizeOptions, const [8, 20, 50, 100]);
        expect(find.byTooltip('Ações'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'table at ${size.width}px and ${scale * 100}% text',
        );

        await tester.tap(find.byKey(const Key('meal-plan-directory-view-cards')));
        await tester.pumpAndSettle();
        pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
        expect(pagination.pageSize, 11);
        expect(pagination.pageSizeOptions, const [11, 20, 50, 100]);
        expect(
          tester.takeException(),
          isNull,
          reason: 'cards restored at ${size.width}px and ${scale * 100}% text',
        );
      }
    }
  });
}

Widget _app({
  Key? key,
  GlobalKey? pageKey,
  required MealPlanRepository repository,
  ValueChanged<String>? onEdit,
  double textScale = 1,
}) => MaterialApp(
  key: key,
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: MealPlanDirectoryPage(
      key: pageKey,
      repository: repository,
      onCreate: (_) {},
      onEdit: onEdit,
    ),
  ),
);

final class _DirectoryRepository implements MealPlanRepository {
  _DirectoryRepository({required this.item, this.onFetch, this.conflictCheck});

  final MealPlan item;
  final Future<MealPlanPage> Function(MealPlanListFilter, MealPlan)? onFetch;
  final Future<List<MealPlanConflict>> Function()? conflictCheck;
  final List<MealPlanListFilter> filters = [];
  int conflictChecks = 0;
  int publishCalls = 0;

  @override
  Future<MealPlanPage> fetchPage(MealPlanListFilter filter) {
    filters.add(filter);
    return onFetch?.call(filter, item) ?? Future.value(_page(item, filter));
  }

  @override
  Future<MealPlanPage> fetchTemplatePage(MealPlanListFilter filter) => fetchPage(filter);

  @override
  Future<List<MealPlanConflict>> checkConflicts({
    required String scopeLevel,
    required String scopeId,
    required DateTime startDate,
    required DateTime endDate,
    required MealPlanRecurrence recurrence,
    required List<MealPlanMenuEntry> menu,
  }) {
    conflictChecks += 1;
    return conflictCheck?.call() ?? Future.value(const []);
  }

  @override
  Future<MealPlan> publish(String mealPlanId, String requestId, int expectedRevision) async {
    publishCalls += 1;
    return item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MealPlanPage _page(MealPlan item, MealPlanListFilter filter, {int total = 1}) =>
    MealPlanPage(items: [item], total: total, limit: filter.pageSize, offset: filter.offset);

MealPlan _plan({required String id, required String name}) => MealPlan(
  id: id,
  tenantId: 'tenant',
  institutionId: 'institution',
  name: name,
  status: MealPlanStatus.inReview,
  sourceType: MealPlanSourceType.institution,
  scopeLevel: MealPlanScopeLevel.institution,
  scopeId: 'institution',
  startDate: DateTime(2026, 8, 24),
  endDate: DateTime(2026, 8, 28),
  recurrence: MealPlanRecurrence(
    kind: MealPlanRecurrenceKind.weekly,
    weekdays: const {1, 2, 3, 4, 5},
  ),
  menu: [
    MealPlanMenuEntry(
      mealType: 'lunch',
      dishName: 'Arroz e feijão',
      weekdays: const {1, 2, 3, 4, 5},
    ),
  ],
  allergens: const [],
  alerts: const [],
  attachments: const [],
  priority: 10,
  conflictState: false,
  revision: 1,
  isDraft: false,
  requiresReview: true,
  createdBy: 'admin',
  updatedBy: 'admin',
  planVariant: MealPlanPlanVariant.complete,
  audienceSegment: MealPlanAudienceSegment.students,
);
