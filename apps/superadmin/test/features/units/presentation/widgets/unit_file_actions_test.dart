import 'dart:typed_data';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/units/data/unavailable_unit_composition.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:coelo_superadmin/features/units/presentation/widgets/unit_file_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('names the current unit view in the export preview', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
            viewLabel: 'Agrupado',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar CSV'));
    await tester.pump();

    expect(controller.activities.single.subject, 'Unidades · Agrupado');
    expect(controller.activities.single.fileName, 'unidades-agrupado.csv');
  });

  testWidgets('does not expose fixture or demonstration labels in import', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
            viewLabel: 'Cards',
          ),
        ),
      ),
    );

    final forbidden = RegExp(r'fake|demo|dev|catálogo|teste', caseSensitive: false);
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.textContaining(forbidden), findsNothing);

    await tester.tap(find.byKey(const Key('unit-import-template-export')));
    await tester.pump();
    expect(find.textContaining(forbidden), findsNothing);
  });

  testWidgets('unavailable gateway rejects export without a demo activity', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            backendCommands: const UnavailableUnitBackendCommandsGateway(),
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();

    expect(controller.activities, isEmpty);
    expect(find.text('Não foi possível gerar a exportação autorizada. Tente novamente.'), findsOne);
    expect(find.text('A exportação está em andamento. Acompanhe pelo sininho.'), findsNothing);
  });

  testWidgets('unavailable gateway rejects import preview without a demo job', (tester) async {
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult([
        PlatformFile(
          name: 'unidades.csv',
          size: 8,
          bytes: Uint8List.fromList('name\nA\n'.codeUnits),
        ),
      ]),
    );
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            backendCommands: const UnavailableUnitBackendCommandsGateway(),
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-demo-file-picker')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('unit-import-review')));
    await tester.pumpAndSettle();

    expect(controller.activities, isEmpty);
    expect(find.byKey(const Key('unit-import-confirm')), findsNothing);
    expect(
      find.text('O arquivo foi rejeitado. Revise formato, cabeçalhos e permissões.'),
      findsOne,
    );
    expect(find.text('24 linhas válidas'), findsNothing);
  });

  testWidgets('unavailable gateway rejects template without demo success', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            backendCommands: const UnavailableUnitBackendCommandsGateway(),
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-import-template-export')));
    await tester.pumpAndSettle();

    expect(controller.activities, isEmpty);
    expect(find.text('Não foi possível gerar o modelo autorizado.'), findsOne);
    expect(find.text('Modelo XLSX preparado para download.'), findsNothing);
  });
}

final class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}
