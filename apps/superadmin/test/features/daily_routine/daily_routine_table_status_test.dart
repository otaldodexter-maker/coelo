import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_routine_repository.dart';

void main() {
  testWidgets('table status remains textual without hover expansion', (tester) async {
    final repository = FakeRoutineRepository(
      pageLoader: (query) async => RoutineDirectoryPage(
        items: const [
          RoutineDirectoryItem(
            id: 'model-active',
            kind: RoutineEntryKind.model,
            name: 'Modelo ativo',
            status: 'active',
            version: 1,
          ),
        ],
        page: query.page,
        pageSize: query.pageSize,
        totalCount: 1,
        canManage: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineDirectoryPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          onEdit: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-view-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-table')), findsOneWidget);
    expect(find.text('Ativo'), findsOneWidget);
  });
}
