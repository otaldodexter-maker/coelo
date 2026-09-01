import 'package:coelo_superadmin/features/circulars/presentation/circular_directory_page.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses cards on mobile and the canonical table from tablet upward', (tester) async {
    await _pump(tester, size: const Size(375, 900), onCreate: () {});
    expect(find.byKey(const Key('circular-directory-card-list')), findsOneWidget);
    expect(find.byKey(const Key('create-circular-card')), findsOneWidget);
    expect(find.byType(CoeloAdminResizableTable<CircularDirectoryItem>), findsNothing);
    expect(find.text('Cards'), findsNothing);
    expect(find.text('Tabela'), findsNothing);

    await _pump(tester, size: const Size(768, 900), onCreate: () {});
    expect(find.byKey(const Key('circular-directory-card-list')), findsNothing);
    expect(find.byKey(const Key('create-circular-banner')), findsOneWidget);
    final table = tester.widget<CoeloAdminResizableTable<CircularDirectoryItem>>(
      find.byType(CoeloAdminResizableTable<CircularDirectoryItem>),
    );
    expect(table.headerHeight, 56);
    expect(table.rowHeight, 64);
  });

  testWidgets('keeps import and export available from the canonical file menu', (tester) async {
    var imported = false;
    var exported = false;
    await _pump(
      tester,
      size: const Size(1440, 900),
      onImport: () => imported = true,
      onExport: () => exported = true,
    );

    expect(find.byType(CoeloAdminFileActions), findsOneWidget);
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    expect(find.text('Importar circulares'), findsOneWidget);
    expect(find.text('Exportar circulares'), findsOneWidget);

    await tester.tap(find.text('Importar circulares'));
    await tester.pumpAndSettle();
    expect(imported, isTrue);

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar circulares'));
    await tester.pumpAndSettle();
    expect(exported, isTrue);
  });

  testWidgets('filters by approved tabs and search without inventing persistence', (tester) async {
    await _pump(tester, size: const Size(1440, 900));
    for (final label in ['Todas', 'Rascunhos', 'Agendadas', 'Publicadas', 'Encerradas']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Rascunhos'));
    await tester.pump();
    expect(find.text('Circular em elaboração'), findsWidgets);
    expect(find.text('Renovação de matrícula'), findsNothing);

    await tester.tap(find.text('Todas'));
    await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
    await tester.pump();
    expect(find.text('Nenhum resultado'), findsOneWidget);
  });

  testWidgets('keeps unauthorized fail closed and exposes retry only for errors', (tester) async {
    await _pump(tester, viewState: CircularDirectoryViewState.forbidden);
    expect(find.text('Sem permissão'), findsOneWidget);
    expect(find.byType(CoeloAdminListingToolbar), findsNothing);
    expect(find.text('Nova circular'), findsNothing);

    var retried = false;
    await _pump(tester, viewState: CircularDirectoryViewState.error, onRetry: () => retried = true);
    await tester.tap(find.text('Tentar novamente'));
    expect(retried, isTrue);
  });

  testWidgets('uses the literal Institutions pagination sizes at each breakpoint', (tester) async {
    final manyItems = List<CircularDirectoryItem>.generate(
      24,
      (index) => CircularDirectoryItem(
        id: 'circular-$index',
        title: 'Circular $index',
        excerpt: 'Conteúdo $index',
        authorName: 'Autoria',
        contextLabel: 'Ensino Fundamental',
        status: CircularStatus.published,
        effectiveAt: DateTime.utc(2026, 8, 31),
        attachmentCount: 0,
        questionCount: 0,
        responseCount: 0,
      ),
    );

    await _pump(tester, size: const Size(375, 900), items: manyItems);
    final compactFooter = tester.widget<SuperadminListingPaginationFooter>(
      find.byType(SuperadminListingPaginationFooter),
    );
    var pagination = compactFooter.child as CoeloAdminPagination;
    expect(pagination.pageSize, 11);
    expect(pagination.pageSizeOptions, const [11, 20, 50, 100]);
    expect(compactFooter.compactCurrentPage, 1);
    expect(compactFooter.compactTotalPages, 3);
    expect(compactFooter.compactOnPrevious, isNull);
    expect(compactFooter.compactOnNext, isNotNull);

    await _pump(tester, size: const Size(768, 900), items: manyItems);
    pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(pagination.pageSize, 8);
    expect(pagination.pageSizeOptions, const [8, 20, 50, 100]);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  VoidCallback? onCreate,
  VoidCallback? onRetry,
  VoidCallback? onImport,
  VoidCallback? onExport,
  CircularDirectoryViewState viewState = CircularDirectoryViewState.content,
  List<CircularDirectoryItem>? items,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: CircularDirectoryPage(
          items: items ?? _items,
          viewState: viewState,
          onCreate: onCreate,
          onRetry: onRetry,
          onImport: onImport,
          onExport: onExport,
          onOpen: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

final _items = [
  CircularDirectoryItem(
    id: 'circular-published',
    title: 'Renovação de matrícula',
    excerpt: 'Confirme a renovação para o próximo ano.',
    authorName: 'Ana Souza',
    contextLabel: 'Ensino Fundamental',
    status: CircularStatus.published,
    effectiveAt: DateTime.utc(2026, 8, 21),
    attachmentCount: 2,
    questionCount: 1,
    responseCount: 84,
  ),
  CircularDirectoryItem(
    id: 'circular-draft',
    title: 'Circular em elaboração',
    excerpt: 'Conteúdo ainda não publicado.',
    authorName: 'Bruno Lima',
    contextLabel: 'Educação Infantil',
    status: CircularStatus.draft,
    effectiveAt: DateTime.utc(2026, 8, 30),
    attachmentCount: 0,
    questionCount: 2,
    responseCount: 0,
  ),
];
