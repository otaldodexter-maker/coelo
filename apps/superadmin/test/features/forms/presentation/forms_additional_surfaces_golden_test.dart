import 'dart:io';

import 'package:coelo_superadmin/features/forms/presentation/operations/forms_media_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/overview/forms_overview_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/forms_test_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

enum _Surface { overview, test, media }

void main() {
  setUpAll(_loadGoldenFonts);

  for (final surface in _Surface.values) {
    for (final brightness in Brightness.values) {
      for (final width in const [375.0, 768.0, 1440.0]) {
        testWidgets('${surface.name} ${brightness.name} ${width.toInt()}', (tester) async {
          tester.view
            ..devicePixelRatio = 1
            ..physicalSize = Size(width, 1200);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(_app(surface, brightness));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('forms-additional-golden-root')),
            matchesGoldenFile(
              'goldens/forms_${surface.name}_${brightness.name}_${width.toInt()}.png',
            ),
          );
        });
      }
    }
  }
}

Widget _app(_Surface surface, Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: RepaintBoundary(key: const Key('forms-additional-golden-root'), child: child),
  ),
  home: Scaffold(
    body: switch (surface) {
      _Surface.overview => FormsOverviewPage.development(
        formId: 'form-family-annual-survey',
        onEdit: () {},
        onTest: () {},
        onMonitor: () {},
        onResponses: () {},
        onFiles: () {},
      ),
      _Surface.test => const FormsTestPage.development(formId: 'form-dev-02'),
      _Surface.media => const FormsMediaPage.development(
        assetId: FormsMediaPage.developmentPreviewAssetId,
      ),
    },
  ),
);

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();
  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await loader.load();
}
