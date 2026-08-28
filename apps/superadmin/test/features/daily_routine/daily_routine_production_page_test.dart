import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_routine_repository.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    RoutineRepository repository, {
    double width = 1440,
    double textScale = 1,
    ValueChanged<RoutineDirectoryItem>? onEdit,
    ValueChanged<RoutineEntryKind>? onCreateEntry,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: DailyRoutineDirectoryPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          onEdit: onEdit,
          onCreateEntry: onCreateEntry,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('launch tab has a real empty state distinct from models and applications', (
    tester,
  ) async {
    final requestedKinds = <RoutineEntryKind>[];
    await pumpPage(
      tester,
      FakeRoutineRepository(
        pageLoader: (query) async {
          requestedKinds.add(query.kind);
          return RoutineDirectoryPage(
            items: const [],
            page: query.page,
            pageSize: query.pageSize,
            totalCount: 0,
            canManage: true,
          );
        },
      ),
    );

    expect(find.byKey(const Key('daily-routine-type-tabs')), findsOneWidget);
    expect(find.text('Modelos'), findsOneWidget);
    expect(find.text('Rotinas'), findsOneWidget);
    expect(find.text('Lancamentos'), findsOneWidget);
    await tester.tap(find.text('Lancamentos'));
    await tester.pumpAndSettle();

    expect(requestedKinds.last, RoutineEntryKind.launch);
    expect(find.byKey(const Key('daily-routine-launches-empty')), findsOneWidget);
  });

  testWidgets('opening a directory entry preserves its entry kind for typed deep links', (
    tester,
  ) async {
    Object? opened;
    await pumpPage(
      tester,
      FakeRoutineRepository(
        pageLoader: (query) async => RoutineDirectoryPage(
          items: const [
            RoutineDirectoryItem(
              id: 'application-1',
              kind: RoutineEntryKind.application,
              name: 'Rotina da unidade',
              status: 'active',
              version: 2,
            ),
          ],
          page: query.page,
          pageSize: query.pageSize,
          totalCount: 1,
          canManage: true,
        ),
      ),
      onEdit: (value) => opened = value,
    );

    await tester.tap(find.byKey(const Key('daily-routine-card-application-1')));

    expect(opened, isA<RoutineDirectoryItem>());
    expect((opened! as RoutineDirectoryItem).kind, RoutineEntryKind.application);
  });
  testWidgets('unauthorized page is fail closed and never exposes stale entries', (tester) async {
    await pumpPage(
      tester,
      FakeRoutineRepository(
        pageLoader: (_) async => throw const RoutineRepositoryException(
          RoutineRepositoryFailureKind.unauthorized,
          'private object exists',
        ),
      ),
    );

    expect(find.byKey(const Key('daily-routine-unauthorized')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-cards')), findsNothing);
    expect(find.byKey(const Key('daily-routine-search')), findsNothing);
    expect(find.byKey(const Key('daily-routine-type-tabs')), findsNothing);
    expect(find.textContaining('private object exists'), findsNothing);
  });

  testWidgets('repository swap clears the previous tenant before a late response', (tester) async {
    final staleResponse = Completer<RoutineDirectoryPage>();
    var loadsA = 0;
    final repositoryA = FakeRoutineRepository(
      pageLoader: (query) async {
        if (loadsA++ > 0) return staleResponse.future;
        return RoutineDirectoryPage(
          items: const [
            RoutineDirectoryItem(
              id: 'routine-a',
              kind: RoutineEntryKind.model,
              name: 'Rotina privada A',
              status: 'active',
              version: 1,
            ),
          ],
          page: query.page,
          pageSize: query.pageSize,
          totalCount: 1,
          canManage: true,
        );
      },
    );
    final repositoryB = FakeRoutineRepository(
      pageLoader: (_) async => throw const RoutineRepositoryException(
        RoutineRepositoryFailureKind.unauthorized,
        'tenant B denied',
      ),
    );

    Widget app(RoutineRepository repository) => MaterialApp(
      theme: CoeloTheme.light,
      home: DailyRoutineDirectoryPage(
        repository: repository,
        logout: unavailableSuperadminLogout,
        onCreateEntry: (_) {},
        onEdit: (_) {},
      ),
    );

    await tester.pumpWidget(app(repositoryA));
    await tester.pumpAndSettle();
    expect(find.text('Rotina privada A'), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-create-tile')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('daily-routine-search')), 'privada');
    await tester.pump();
    await tester.pumpWidget(app(repositoryB));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-unauthorized')), findsOneWidget);
    expect(find.text('Rotina privada A'), findsNothing);
    expect(find.byKey(const Key('daily-routine-search')), findsNothing);
    expect(find.byKey(const Key('daily-routine-create-tile')), findsNothing);

    staleResponse.complete(
      const RoutineDirectoryPage(
        items: [
          RoutineDirectoryItem(
            id: 'routine-a-late',
            kind: RoutineEntryKind.model,
            name: 'Resposta tardia A',
            status: 'active',
            version: 2,
          ),
        ],
        page: 1,
        pageSize: 11,
        totalCount: 1,
        canManage: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resposta tardia A'), findsNothing);
    expect(find.byKey(const Key('daily-routine-unauthorized')), findsOneWidget);
  });

  testWidgets('directory follows toolbar then tabs ordering from the approved baseline', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeRoutineRepository(
        pageLoader: (query) async => RoutineDirectoryPage(
          items: const [],
          page: query.page,
          pageSize: query.pageSize,
          totalCount: 0,
          canManage: true,
        ),
      ),
    );

    final searchTop = tester.getTopLeft(find.byKey(const Key('daily-routine-search'))).dy;
    final tabsTop = tester.getTopLeft(find.byKey(const Key('daily-routine-type-tabs'))).dy;
    expect(searchTop, lessThan(tabsTop));
  });

  testWidgets('read-only notice follows toolbar and tabs without changing directory order', (
    tester,
  ) async {
    await pumpPage(
      tester,
      FakeRoutineRepository(
        pageLoader: (query) async => RoutineDirectoryPage(
          items: const [],
          page: query.page,
          pageSize: query.pageSize,
          totalCount: 0,
          canManage: false,
        ),
      ),
    );

    final searchTop = tester.getTopLeft(find.byKey(const Key('daily-routine-search'))).dy;
    final tabsTop = tester.getTopLeft(find.byKey(const Key('daily-routine-type-tabs'))).dy;
    final noticeTop = tester.getTopLeft(find.text('Modo somente leitura')).dy;
    final stateTop = tester.getTopLeft(find.byKey(const Key('daily-routine-empty'))).dy;
    expect(searchTop, lessThan(tabsTop));
    expect(tabsTop, lessThan(noticeTop));
    expect(noticeTop, lessThan(stateTop));
  });

  testWidgets('authorized create action remains available across empty and error states', (
    tester,
  ) async {
    var calls = 0;
    await pumpPage(
      tester,
      FakeRoutineRepository(
        pageLoader: (query) async {
          if (calls++ > 0) {
            throw const RoutineRepositoryException(
              RoutineRepositoryFailureKind.unavailable,
              'temporarily unavailable',
            );
          }
          return RoutineDirectoryPage(
            items: const [],
            page: query.page,
            pageSize: query.pageSize,
            totalCount: 0,
            canManage: true,
          );
        },
      ),
      onCreateEntry: (_) {},
    );

    expect(find.byKey(const Key('daily-routine-create-state')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('daily-routine-search')), 'falha');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-error')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-create-state')), findsOneWidget);
  });

  testWidgets('repository pagination is rendered in the sticky footer surface', (tester) async {
    await pumpPage(
      tester,
      FakeRoutineRepository(
        pageLoader: (query) async => RoutineDirectoryPage(
          items: const [
            RoutineDirectoryItem(
              id: 'routine-page-item',
              kind: RoutineEntryKind.model,
              name: 'Rotina paginada',
              status: 'active',
              version: 1,
            ),
          ],
          page: query.page,
          pageSize: query.pageSize,
          totalCount: 30,
          canManage: true,
        ),
      ),
    );

    expect(find.byKey(const Key('daily-routine-pagination-footer')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-pagination')), findsOneWidget);
  });

  testWidgets('directory tabs and async state survive responsive 200 percent matrix', (
    tester,
  ) async {
    for (final width in const [375.0, 768.0, 1024.0, 1440.0]) {
      await pumpPage(
        tester,
        FakeRoutineRepository(
          pageLoader: (query) async => RoutineDirectoryPage(
            items: const [],
            page: query.page,
            pageSize: query.pageSize,
            totalCount: 0,
            canManage: true,
          ),
        ),
        width: width,
        textScale: 2,
      );

      expect(tester.takeException(), isNull, reason: 'width=$width textScale=2');
      expect(find.byKey(const Key('daily-routine-type-tabs')), findsOneWidget);
      expect(find.byKey(const Key('daily-routine-empty')), findsOneWidget);
    }
  });
}
