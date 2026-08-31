import 'dart:io';

import '../../support/import_repository_stub.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/domain/import_job.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_wizard_controller.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_wizard_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_fonts);
  testWidgets('captures imports directory responsive light and dark evidence', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = await _seededRepository();
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(_app(brightness, repository));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('import-hub-golden-root')),
          matchesGoldenFile('goldens/import_hub_directory_${brightness.name}_${width.toInt()}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
  testWidgets('captures imports wizard responsive light and dark evidence', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(_wizardApp(brightness));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const Key('import-hub-golden-root')),
          matchesGoldenFile('goldens/import_hub_wizard_${brightness.name}_${width.toInt()}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
  testWidgets('captures unavailable entity and text at 200 percent', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(_wizardApp(Brightness.light, entity: ImportEntity.forms, textScale: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('import-entity-unavailable')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_wizard_unavailable_light_1440_200.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(_wizardApp(Brightness.dark, textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_wizard_dark_375_200.png'),
    );
  });
  testWidgets('captures unavailable and creation-dialog states', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(Brightness.dark, const UnavailableImportRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Importações indisponíveis'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_unavailable_dark_1440.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(_app(Brightness.light, InMemoryImportRepository()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CoeloAdminCreateAction));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_new_dialog_light_1440.png'),
    );
  });
  testWidgets('captures empty, no-results and unauthorized directory states', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(_app(Brightness.light, InMemoryImportRepository()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_empty_light_375_v4_21.png'),
    );

    await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_no_results_light_375_v4_21.png'),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(_app(Brightness.dark, const _UnauthorizedImportRepository()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_unauthorized_dark_1440_v4_21.png'),
    );
  });
  testWidgets('captures the mapped-file step with real local fixture data', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ImportWizardController(repository: InMemoryImportRepository());
    await controller.next();
    controller.sourceFile = ImportSourceFile(
      name: 'unidades_agosto.xlsx',
      bytes: Uint8List.fromList(const [1, 2, 3]),
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    controller.selectFile(ImportFileFixture.xlsx);
    await controller.next();

    await tester.pumpWidget(_wizardApp(Brightness.light, controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Chave de correspondência: Código da unidade'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_wizard_mapping_light_1440_v4_21.png'),
    );
  });
  testWidgets('captures preview, confirmation and completed status states', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = ImportWizardController(
      repository: InMemoryImportRepository(),
      stepInterval: Duration.zero,
    );
    await controller.next();
    controller.sourceFile = ImportSourceFile(
      name: 'unidades_agosto.xlsx',
      bytes: Uint8List.fromList(const [1, 2, 3]),
      mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    controller.selectFile(ImportFileFixture.xlsx);
    await controller.next();
    await controller.next();
    await controller.next();

    await tester.pumpWidget(_wizardApp(Brightness.light, controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Prévia de 8 linhas'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_wizard_preview_light_1440_v4_21.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final confirmationController = await _confirmationController();
    await tester.pumpWidget(_wizardApp(Brightness.light, controller: confirmationController));
    await tester.pumpAndSettle();
    expect(find.text('Revise e confirme a importação.'), findsOneWidget);
    expect(find.text('Entidade e contexto'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_wizard_confirmation_light_1440_v4_21_v3.png'),
    );

    confirmationController.confirm();
    await tester.pumpAndSettle();
    expect(find.textContaining('Resultado: 7 criados'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('import-hub-golden-root')),
      matchesGoldenFile('goldens/import_hub_wizard_completed_light_1440_v4_21_v3.png'),
    );
  });
}

Widget _app(Brightness brightness, ImportRepository repository) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  builder: (context, child) =>
      RepaintBoundary(key: const Key('import-hub-golden-root'), child: child!),
  home: Scaffold(
    body: ImportDirectoryPage(
      key: ValueKey(repository),
      repository: repository,
      onNewImport: (_) {},
    ),
  ),
);

Widget _wizardApp(
  Brightness brightness, {
  ImportEntity? entity,
  double textScale = 1,
  ImportWizardController? controller,
}) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
    child: RepaintBoundary(key: const Key('import-hub-golden-root'), child: child!),
  ),
  home: Scaffold(
    body: ImportWizardPage(
      controller:
          controller ??
          ImportWizardController(repository: InMemoryImportRepository(), initialEntity: entity),
      onFinished: () {},
    ),
  ),
);

Future<InMemoryImportRepository> _seededRepository() async {
  final repository = InMemoryImportRepository();
  final entities = const [
    ImportEntity.units,
    ImportEntity.people,
    ImportEntity.groups,
    ImportEntity.activities,
    ImportEntity.institutions,
    ImportEntity.mealPlans,
  ];
  for (var index = 0; index < entities.length; index++) {
    final entity = entities[index];
    await repository.save(
      ImportJob(
        id: 'golden-$index',
        entity: entity,
        context: entity.label,
        file: index.isEven ? ImportFileFixture.xlsx : ImportFileFixture.csv,
        strategy: ImportStrategy.createOnly,
        mapping: const {},
        previewRows: List.generate(
          12 + index * 7,
          (row) => ImportPreviewRow(row: row + 1, values: const {'nome': 'Registro'}),
        ),
        conflicts: const [],
        result: const ImportResult(),
        status: entity == ImportEntity.people
            ? ImportJobStatus.inProgress
            : entity == ImportEntity.institutions
            ? ImportJobStatus.error
            : ImportJobStatus.completed,
        progress: entity == ImportEntity.people ? 48 : 100,
        actor: const ['Fernanda Silva', 'João Martins', 'Carla Mendes'][index % 3],
        createdAt: DateTime.utc(2026, 8, 28, 9, 42).subtract(Duration(hours: index * 3)),
      ),
    );
  }
  return repository;
}

final class _UnauthorizedImportRepository implements ImportRepository {
  const _UnauthorizedImportRepository();

  @override
  Future<ImportJobPage> fetchPage(ImportJobQuery query) async =>
      throw const ImportRepositoryUnauthorizedException();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ImportWizardController> _confirmationController() async {
  final controller = ImportWizardController(
    repository: InMemoryImportRepository(),
    stepInterval: Duration.zero,
  );
  await controller.next();
  controller.sourceFile = ImportSourceFile(
    name: 'unidades_agosto.xlsx',
    bytes: Uint8List.fromList(const [1, 2, 3]),
    mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  controller.selectFile(ImportFileFixture.xlsx);
  await controller.next();
  await controller.next();
  await controller.next();
  await controller.next();
  return controller;
}

Future<void> _fonts() async {
  final nunito = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunito.load();
  final root = File(Platform.resolvedExecutable).parent.parent.parent;
  final bytes = File('${root.path}/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync();
  final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)));
  await icons.load();
}
