import 'package:coelo_superadmin/app/activity/superadmin_activity.dart' show SuperadminExportFormat;
import 'package:coelo_superadmin/features/people/presentation/person_file_actions.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides file actions when no real callbacks are available', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.byKey(const Key('coelo-admin-files-action')), findsNothing);
    expect(find.text('Importar'), findsNothing);
    expect(find.text('Exportar CSV'), findsNothing);
  });

  testWidgets('shows ordered actions and delegates export with the selected view', (tester) async {
    SuperadminExportFormat? exportedFormat;
    PersonDirectoryTableView? exportedView;
    var imports = 0;
    await tester.pumpWidget(
      _app(
        onImport: () => imports++,
        onExport: (format, view) {
          exportedFormat = format;
          exportedView = view;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();

    final import = find.text('Importar');
    final csv = find.text('Exportar CSV');
    final xlsx = find.text('Exportar XLSX');
    expect(import, findsOneWidget);
    expect(csv, findsOneWidget);
    expect(xlsx, findsOneWidget);
    expect(tester.getTopLeft(import).dy, lessThan(tester.getTopLeft(csv).dy));
    expect(tester.getTopLeft(csv).dy, lessThan(tester.getTopLeft(xlsx).dy));

    await tester.tap(xlsx);
    await tester.pumpAndSettle();
    expect(exportedFormat, SuperadminExportFormat.xlsx);
    expect(exportedView, PersonDirectoryTableView.grouped);

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(imports, 1);
  });

  testWidgets('uses the compact trigger', (tester) async {
    await tester.pumpWidget(_app(compact: true, onImport: () {}));

    expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);
    expect(find.text('Arquivos'), findsNothing);
    expect(
      tester.widget<Widget>(find.byKey(const Key('coelo-admin-files-action'))),
      isA<IconButton>(),
    );
  });

  testWidgets('identifies the selected table view in export callback', (tester) async {
    PersonDirectoryTableView? exportedView;
    await tester.pumpWidget(
      _app(
        tableView: PersonDirectoryTableView.activities,
        onExport: (_, view) => exportedView = view,
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();
    expect(exportedView, PersonDirectoryTableView.activities);
  });
}

Widget _app({
  bool compact = false,
  PersonDirectoryTableView tableView = PersonDirectoryTableView.grouped,
  VoidCallback? onImport,
  PersonExportAction? onExport,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Align(
        alignment: Alignment.topRight,
        child: PersonFileActions(
          onImport: onImport,
          onExport: onExport,
          compact: compact,
          tableView: tableView,
        ),
      ),
    ),
  ),
);
