import 'dart:io';

import '../../support/import_repository_stub.dart';
import 'package:coelo_superadmin/features/imports/domain/import_repository.dart';
import 'package:coelo_superadmin/features/imports/presentation/import_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_fonts);
  testWidgets('captures imports directory responsive light and dark evidence', (tester) async {
    tester.view.devicePixelRatio = 1; addTearDown(tester.view.resetDevicePixelRatio); addTearDown(tester.view.resetPhysicalSize);
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) for (final brightness in [Brightness.light, Brightness.dark]) {
      tester.view.physicalSize = Size(width, 900); await tester.pumpWidget(_app(brightness, InMemoryImportRepository())); await tester.pumpAndSettle(); await expectLater(find.byKey(const Key('import-hub-golden-root')), matchesGoldenFile('goldens/import_hub_directory_${brightness.name}_${width.toInt()}.png')); await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets('captures unavailable and creation-dialog states', (tester) async {
    tester.view.devicePixelRatio = 1; tester.view.physicalSize = const Size(1440, 900); addTearDown(tester.view.resetDevicePixelRatio); addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(Brightness.dark, const UnavailableImportRepository())); await tester.pumpAndSettle(); expect(find.text('Importações indisponíveis'), findsOneWidget); await expectLater(find.byKey(const Key('import-hub-golden-root')), matchesGoldenFile('goldens/import_hub_unavailable_dark_1440.png'));
    await tester.pumpWidget(const SizedBox.shrink()); await tester.pump(); await tester.pumpWidget(_app(Brightness.light, InMemoryImportRepository())); await tester.pumpAndSettle(); await tester.tap(find.byType(CoeloAdminCreateAction)); await tester.pumpAndSettle(); await expectLater(find.byKey(const Key('import-hub-golden-root')), matchesGoldenFile('goldens/import_hub_new_dialog_light_1440.png'));
  });
}
Widget _app(Brightness brightness, ImportRepository repository) => MaterialApp(theme: CoeloTheme.light, darkTheme: CoeloTheme.dark, themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light, builder: (context, child) => RepaintBoundary(key: const Key('import-hub-golden-root'), child: child!), home: Scaffold(body: ImportDirectoryPage(key: ValueKey(repository), repository: repository, onNewImport: (_) {})));
Future<void> _fonts() async { final nunito = FontLoader('Nunito Sans')..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf')); await nunito.load(); final root = File(Platform.resolvedExecutable).parent.parent.parent; final bytes = File('${root.path}/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync(); final icons = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes))); await icons.load(); }
