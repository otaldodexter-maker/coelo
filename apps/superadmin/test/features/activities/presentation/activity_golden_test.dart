import 'dart:io';

import '../../../support/activities/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_detail_page.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_page.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches cards and table at supported widths and themes', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_directoryApp(brightness: brightness));
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('activity-golden-frame')),
          matchesGoldenFile(
            '../../../goldens/activities/'
            'activity_directory_cards_${brightness.name}_${width.toInt()}.png',
          ),
        );

        await tester.tap(find.byKey(const Key('activity-view-table')));
        await tester.pumpAndSettle();
        await _repaintGoldenFrame(tester);
        await expectLater(
          find.byKey(const Key('activity-golden-frame')),
          matchesGoldenFile(
            '../../../goldens/activities/'
            'activity_directory_table_${brightness.name}_${width.toInt()}.png',
          ),
        );
      }
    }
  });

  testWidgets('matches the approved models directory on desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _app(
        brightness: Brightness.light,
        child: ActivityDirectoryPage(
          repository: FakeActivityDirectoryRepository(),
          logout: _logout,
          onCreate: () {},
          onView: (_) {},
          onCreateFromTemplate: (_) {},
          onDuplicateTemplate: (_, _) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-type-tabs')), findsOneWidget);
    expect(find.byKey(const Key('create-activity-template-tile')), findsOneWidget);
    await expectLater(
      find.byKey(const Key('activity-golden-frame')),
      matchesGoldenFile('../../../goldens/activities/activity_directory_models_light_1440.png'),
    );
  });

  testWidgets('matches hover, filter and pagination references', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_directoryApp());
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('activity-card-surface-activity-10'))),
    );
    await tester.pumpAndSettle();
    await _repaintGoldenFrame(tester);
    await expectLater(
      find.byKey(const Key('activity-golden-frame')),
      matchesGoldenFile('../../../goldens/activities/activity_directory_card_hover_light_1440.png'),
    );
    await mouse.removePointer();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_directoryApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-institution-filter')));
    await tester.pumpAndSettle();
    await _repaintGoldenFrame(tester);
    await expectLater(
      find.byKey(const Key('activity-golden-frame')),
      matchesGoldenFile(
        '../../../goldens/activities/activity_directory_filter_open_light_1440.png',
      ),
    );

    await tester.tapAt(const Offset(1200, 400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();
    await _repaintGoldenFrame(tester);
    await expectLater(
      find.byKey(const Key('activity-golden-frame')),
      matchesGoldenFile(
        '../../../goldens/activities/'
        'activity_directory_pagination_open_light_1440.png',
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_directoryApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-view-table')));
    await tester.pumpAndSettle();
    final tableMouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await tableMouse.addPointer();
    await tableMouse.moveTo(
      tester.getCenter(find.byKey(const Key('activity-table-row-activity-10'))),
    );
    await tester.pumpAndSettle();
    await _repaintGoldenFrame(tester);
    await expectLater(
      find.byKey(const Key('activity-golden-frame')),
      matchesGoldenFile(
        '../../../goldens/activities/'
        'activity_directory_table_row_hover_light_1440.png',
      ),
    );
    await tableMouse.removePointer();
  });

  testWidgets('matches approved shell overlays over Activities', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      ('bug', const Key('superadmin-report-bug')),
      ('profile', const Key('superadmin-profile-menu')),
      ('tour', const Key('superadmin-onboarding-tour')),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_directoryApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(configuration.$2));
      await tester.pumpAndSettle();
      await _repaintGoldenFrame(tester);
      await expectLater(
        find.byKey(const Key('activity-golden-frame')),
        matchesGoldenFile(
          '../../../goldens/activities/'
          'activity_directory_${configuration.$1}_open_light_1440.png',
        ),
      );
    }
  });

  testWidgets('matches mobile light and desktop dark read-only details', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (width: 375.0, brightness: Brightness.light),
      (width: 1440.0, brightness: Brightness.dark),
    ]) {
      tester.view.physicalSize = Size(configuration.width, 900);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_detailApp(brightness: configuration.brightness));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('activity-golden-frame')),
        matchesGoldenFile(
          '../../../goldens/activities/'
          'activity_detail_${configuration.brightness.name}_${configuration.width.toInt()}.png',
        ),
      );
    }
  });

  testWidgets('matches create mobile light and edit desktop dark forms', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (width: 375.0, height: 900.0, brightness: Brightness.light, activityId: null),
      (width: 1440.0, height: 1000.0, brightness: Brightness.dark, activityId: 'activity-3'),
    ]) {
      tester.view.physicalSize = Size(configuration.width, configuration.height);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _formApp(brightness: configuration.brightness, activityId: configuration.activityId),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('activity-golden-frame')),
        matchesGoldenFile(
          '../../../goldens/activities/'
          'activity_form_${configuration.activityId == null ? 'create' : 'edit'}_'
          '${configuration.brightness.name}_${configuration.width.toInt()}.png',
        ),
      );
    }
  });

  testWidgets('matches internal location dialog on mobile', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_formApp(brightness: Brightness.light));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Robótica');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('activity-form-institution')),
        )
        .onChanged('institution-1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-unit-institution-1-unit-1')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('activity-create-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-create-location')));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('activity-golden-frame')),
      matchesGoldenFile('../../../goldens/activities/activity_form_location_dialog_light_375.png'),
    );
  });

  testWidgets('matches professional permissions by class on desktop', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_formApp(brightness: Brightness.dark));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Robótica');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('activity-form-institution')),
        )
        .onChanged('institution-1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-unit-institution-1-unit-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-group-institution-1-group-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-invite-institution-1-group-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-professional-search')), 'Marina');
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-professional-professional-1')));
    await tester.pump();
    await tester.tap(find.text('Concluir convite'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('activity-golden-frame')),
      matchesGoldenFile('../../../goldens/activities/activity_form_professionals_dark_1440.png'),
    );
  });

  testWidgets('matches text at 200 percent without sticky overlap', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_directoryApp(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('activity-golden-frame')),
      matchesGoldenFile('../../../goldens/activities/activity_directory_text_200_light_375.png'),
    );
  });
}

Widget _directoryApp({
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) => _app(
  brightness: brightness,
  textScaler: textScaler,
  child: ActivityDirectoryPage(
    repository: FakeActivityDirectoryRepository(),
    logout: _logout,
    onCreate: () {},
    onView: (_) {},
    onExportRequested: (_) async =>
        const ActivityDirectoryExportResult(fileName: 'atividades.xlsx'),
    onBugReportSubmitted: (_) {},
  ),
);

Widget _detailApp({required Brightness brightness}) => _app(
  brightness: brightness,
  child: ActivityDetailPage(
    activityId: 'activity-1',
    repository: FakeActivityDirectoryRepository(),
    logout: _logout,
    onBack: () {},
    onBugReportSubmitted: (_) {},
  ),
);

Widget _formApp({required Brightness brightness, String? activityId}) => _app(
  brightness: brightness,
  child: ActivityFormPage(
    activityId: activityId,
    repository: FakeActivityDirectoryRepository(),
    logout: _logout,
    onCancel: () {},
    onSaveDraft: (_) async {},
    onSubmit: (_) async {},
    onCreateLocation: (draft) async => [
      for (final unitId in draft.unitIds)
        ActivityFormLocationOption(id: 'golden-location-$unitId', unitId: unitId, name: draft.name),
    ],
    imagePicker: () async => null,
  ),
);

Widget _app({
  required Widget child,
  required Brightness brightness,
  TextScaler textScaler = TextScaler.noScaling,
}) => RepaintBoundary(
  key: const Key('activity-golden-frame'),
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: textScaler),
      child: child!,
    ),
    home: child,
  ),
);

Future<LogoutResult> _logout() async => const LogoutResult.success();

Future<void> _repaintGoldenFrame(WidgetTester tester) async {
  tester
      .renderObject<RenderRepaintBoundary>(find.byKey(const Key('activity-golden-frame')))
      .markNeedsPaint();
  await tester.pump();
}

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
