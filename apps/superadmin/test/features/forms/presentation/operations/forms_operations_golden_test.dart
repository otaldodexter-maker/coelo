import 'dart:io';

import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches monitor, responses and files at approved widths and themes', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final surface in [
      FormsOperationsSurface.monitor,
      FormsOperationsSurface.responses,
      FormsOperationsSurface.files,
    ]) {
      for (final width in [375.0, 768.0, 1440.0]) {
        for (final brightness in [Brightness.light, Brightness.dark]) {
          tester.view.physicalSize = Size(width, 1000);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(_goldenApp(surface, brightness));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('forms-operations-golden-root')),
            matchesGoldenFile(
              'goldens/forms_operations_${surface.name}_${brightness.name}_${width.toInt()}.png',
            ),
          );
        }
      }
    }
  });
}

Widget _goldenApp(FormsOperationsSurface surface, Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('forms-operations-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  ),
  home: SuperadminShell(
    logout: _logout,
    title: _title(surface),
    subtitle: 'Formulários · operação visual local',
    currentDestination: 'forms',
    canAccessCapability: (_) => true,
    child: switch (surface) {
      FormsOperationsSurface.monitor => const FormsOperationsPage.monitor(development: true),
      FormsOperationsSurface.responses => const FormsOperationsPage.responses(development: true),
      FormsOperationsSurface.files => const FormsOperationsPage.files(development: true),
      FormsOperationsSurface.responseDetail => const FormsOperationsPage.responseDetail(
        development: true,
      ),
    },
  ),
);

String _title(FormsOperationsSurface surface) => switch (surface) {
  FormsOperationsSurface.monitor => 'Monitoramento',
  FormsOperationsSurface.responses => 'Respostas',
  FormsOperationsSurface.files => 'Arquivos e exportações',
  FormsOperationsSurface.responseDetail => 'Detalhe da resposta',
};

Future<LogoutResult> _logout() async => const LogoutResult.success();

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();
  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
