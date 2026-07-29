import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/shell/superadmin_notice.dart';
import 'package:coelo_superadmin/features/people/presentation/person_file_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows ordered desktop file actions and completes a people export', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();

    final import = find.byKey(const Key('people-files-import'));
    final csv = find.byKey(const Key('people-files-export-csv'));
    final xlsx = find.byKey(const Key('people-files-export-xlsx'));
    expect(import, findsOneWidget);
    expect(csv, findsOneWidget);
    expect(xlsx, findsOneWidget);
    expect(tester.getTopLeft(import).dy, lessThan(tester.getTopLeft(csv).dy));
    expect(tester.getTopLeft(csv).dy, lessThan(tester.getTopLeft(xlsx).dy));

    await tester.tap(xlsx);
    await tester.pump(const Duration(milliseconds: 250));
    expect(controller.activities.single.fileName, 'pessoas.xlsx');
    expect(controller.activities.single.subject, 'Pessoas');
    expect(find.text('A exportação está em andamento. Acompanhe pelo sininho.'), findsOneWidget);
  });

  testWidgets('uses the compact trigger', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller, compact: true));

    expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);
    expect(find.text('Arquivos'), findsNothing);
    expect(
      tester.widget<Widget>(find.byKey(const Key('coelo-admin-files-action'))),
      isA<IconButton>(),
    );
  });

  testWidgets('runs the two-step people import demo and starts local activity', (tester) async {
    final controller = SuperadminActivityController(tickInterval: const Duration(seconds: 30));
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('people-files-import')));
    await tester.pumpAndSettle();
    expect(find.text('Importar pessoas'), findsOneWidget);
    expect(find.text('Etapa 1 de 2 · Arquivo'), findsOneWidget);
    expect(find.textContaining('nenhum arquivo real será enviado'), findsOneWidget);

    await tester.tap(find.byKey(const Key('people-import-template-export')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Modelo XLSX preparado para download demonstrativo.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('people-demo-file-picker')));
    await tester.pumpAndSettle();
    expect(find.text('pessoas-julho.xlsx'), findsOneWidget);
    await tester.tap(find.byKey(const Key('people-import-review')));
    await tester.pumpAndSettle();
    expect(find.text('Etapa 2 de 2 · Revisar'), findsOneWidget);
    expect(find.text('24 linhas válidas'), findsOneWidget);
    expect(find.text('2 linhas com erro'), findsOneWidget);

    await tester.tap(find.byKey(const Key('people-import-confirm')));
    await tester.pumpAndSettle();
    expect(controller.activities.single.subject, 'Pessoas');
    expect(controller.activities.single.fileName, 'pessoas-julho.xlsx');
    expect(controller.activities.single.summary, 'Preparando importação');
    expect(find.text('A importação está em andamento. Acompanhe pelo sininho.'), findsOneWidget);
  });
}

Widget _app(SuperadminActivityController controller, {bool compact = false}) => MaterialApp(
  theme: CoeloTheme.light,
  home: SuperadminNoticeHost(
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Align(
          alignment: Alignment.topRight,
          child: PersonFileActions(activityController: controller, compact: compact),
        ),
      ),
    ),
  ),
);
