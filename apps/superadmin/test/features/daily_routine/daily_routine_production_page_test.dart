import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_routine_repository.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    RoutineRepository repository, {
    double width = 1440,
    double textScale = 1,
    ValueChanged<RoutineDirectoryItem>? onEdit,
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
        pageLoader: (_) async =>
            throw const PostgrestException(message: 'private object exists', code: '42501'),
      ),
    );

    expect(find.byKey(const Key('daily-routine-unauthorized')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-cards')), findsNothing);
    expect(find.textContaining('private object exists'), findsNothing);
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
