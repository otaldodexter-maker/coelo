import 'dart:io';
import 'dart:ui' as ui;

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_form_page.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_logo_picker.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches critical create and edit form references', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = FakeInstitutionDirectoryRepository();

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(
      _goldenApp(
        InstitutionFormPage(
          key: const ValueKey('create-form'),
          repository: repository,
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-form-golden-root')),
      matchesGoldenFile('goldens/institution_form_create_light_375.png'),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(
      _goldenApp(
        InstitutionFormPage(
          key: const ValueKey('edit-form'),
          repository: repository,
          institutionId: 'demo-institution-aurora',
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-form-golden-root')),
      matchesGoldenFile('goldens/institution_form_edit_dark_1440.png'),
    );
  });

  testWidgets('matches the approved institution avatar adjustment', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final bytes = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 320, 320),
        Paint()..color = CoeloTheme.light.colorScheme.primary,
      );
      final image = await recorder.endRecording().toImage(320, 320);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });

    await tester.pumpWidget(
      _goldenApp(
        InstitutionFormPage(
          repository: FakeInstitutionDirectoryRepository(),
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
          imagePicker: () async => InstitutionLogoFile(name: 'instituicao.png', bytes: bytes!),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-logo-picker')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('institution-form-golden-root')),
      matchesGoldenFile('goldens/institution_form_avatar_crop_open_light_1440.png'),
    );
  });
}

Widget _goldenApp(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('institution-form-golden-root'),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    ),
    home: child,
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
