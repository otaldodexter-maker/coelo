import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_routine_repository.dart';

/// ADR 0041 C3 (`owner.r12-01`): cards de Modelos de rotina com altura
/// uniforme na grade, linha "Efetivo: —" quando não houver valor e
/// Arquivar em todos os cards (Restaurar no arquivado, B1).
void main() {
  const items = [
    RoutineDirectoryItem(
      id: 'with-effective',
      kind: RoutineEntryKind.model,
      name: 'Modelo Berçário',
      status: 'active',
      version: 3,
      originLabel: 'Instituto Horizonte',
      effectiveLabel: 'Instituição',
    ),
    RoutineDirectoryItem(
      id: 'without-effective',
      kind: RoutineEntryKind.model,
      name: 'Modelo Médio',
      status: 'draft',
      version: 1,
      originLabel: 'Colégio Aurora',
    ),
    RoutineDirectoryItem(
      id: 'archived-model',
      kind: RoutineEntryKind.model,
      name: 'Modelo Maternal',
      status: 'archived',
      version: 5,
    ),
  ];

  FakeRoutineRepository repository() => FakeRoutineRepository(
    pageLoader: (query) async => RoutineDirectoryPage(
      items: items,
      page: query.page,
      pageSize: query.pageSize,
      totalCount: items.length,
      canManage: true,
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    required FakeRoutineRepository repository,
    Future<bool> Function(RoutineDirectoryItem item)? onArchive,
    Future<bool> Function(RoutineDirectoryItem item)? onRestore,
    double width = 1440,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineDirectoryPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          onEdit: (_) {},
          onCreateEntry: (_) {},
          onDuplicateModel: (_) {},
          onCreateFromModel: (_) {},
          onArchive: onArchive,
          onRestore: onRestore,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cards and the create tile share the row height', (tester) async {
    await pump(tester, repository: repository(), onArchive: (_) async => true);

    final create = tester.getSize(find.byKey(const Key('daily-routine-create-tile')));
    final withEffective = tester.getSize(
      find.byKey(const Key('daily-routine-card-with-effective')),
    );
    final withoutEffective = tester.getSize(
      find.byKey(const Key('daily-routine-card-without-effective')),
    );
    expect(withEffective.height, withoutEffective.height);
    expect(create.height, withEffective.height);
    expect(withEffective.height, greaterThanOrEqualTo(216));
    expect(withEffective.width, withoutEffective.width);
  });

  testWidgets('every card renders the Efetivo line, with an em dash when empty', (tester) async {
    await pump(tester, repository: repository());

    expect(find.text('Efetivo: Instituição'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('daily-routine-effective-without-effective'))).data,
      'Efetivo: —',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('daily-routine-effective-archived-model'))).data,
      'Efetivo: —',
    );
  });

  testWidgets('Arquivar appears on every active card and Restaurar on the archived one', (
    tester,
  ) async {
    final archived = <String>[];
    final restored = <String>[];
    final repo = repository();
    await pump(
      tester,
      repository: repo,
      onArchive: (item) async {
        archived.add(item.id);
        return true;
      },
      onRestore: (item) async {
        restored.add(item.id);
        return true;
      },
    );

    expect(find.byKey(const Key('daily-routine-archive-with-effective')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-archive-without-effective')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-archive-archived-model')), findsNothing);
    expect(find.byKey(const Key('daily-routine-restore-archived-model')), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Arquivar'), findsNWidgets(2));
    expect(find.widgetWithText(TextButton, 'Restaurar'), findsOneWidget);

    final loadsBefore = repo.pageQueries.length;
    await tester.tap(find.byKey(const Key('daily-routine-archive-without-effective')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-archive-dialog')), findsOneWidget);
    expect(find.text('Arquivar Modelo Médio?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('daily-routine-archive-confirm')));
    await tester.pumpAndSettle();
    expect(archived, ['without-effective']);
    expect(repo.pageQueries.length, loadsBefore + 1, reason: 'reload após arquivar');

    await tester.tap(find.byKey(const Key('daily-routine-restore-archived-model')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily-routine-restore-dialog')), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(restored, isEmpty, reason: 'cancelar não chama o callback');

    await tester.tap(find.byKey(const Key('daily-routine-restore-archived-model')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily-routine-restore-confirm')));
    await tester.pumpAndSettle();
    expect(restored, ['archived-model']);
  });

  testWidgets('without archive callbacks the lifecycle actions stay hidden', (tester) async {
    await pump(tester, repository: repository());
    expect(find.widgetWithText(TextButton, 'Arquivar'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Restaurar'), findsNothing);
  });
}
