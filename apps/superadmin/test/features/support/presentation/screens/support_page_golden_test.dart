import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/support/presentation/screens/support_page.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches support kanban, table, and detail references', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        final controller = SupportPrototypeController(clock: () => DateTime(2026, 7, 27, 12));
        await tester.pumpWidget(_goldenApp(controller, brightness));
        await tester.pumpAndSettle();
        final suffix = '${brightness.name}_${width.toInt()}';

        await expectLater(
          find.byKey(const Key('support-golden-root')),
          matchesGoldenFile('goldens/support_kanban_$suffix.png'),
        );

        await tester.tap(find.text('Tabela').first);
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('support-golden-root')),
          matchesGoldenFile('goldens/support_table_$suffix.png'),
        );

        await tester.tap(find.text('Kanban').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('support-ticket-SUP-001')).first);
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('support-golden-root')),
          matchesGoldenFile('goldens/support_detail_$suffix.png'),
        );

        controller.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
}

Widget _goldenApp(SupportPrototypeController controller, Brightness brightness) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('support-golden-root'),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
        child: child!,
      ),
    ),
    home: SupportPage(
      controller: controller,
      logout: _logout,
      onInstitutionsOpen: () {},
      onCatalogOpen: () {},
    ),
  );
}

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
