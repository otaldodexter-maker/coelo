import 'dart:io';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'dart:ui';

import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches open selected light at 1024', (tester) async {
    await _pumpPicker(tester, width: 1024);
    await _match(tester, 'goldens/date_range/coelo_date_range_picker_open_selected_light_1024.png');
  });

  testWidgets('matches open selected dark at 1440', (tester) async {
    await _pumpPicker(tester, width: 1440, brightness: Brightness.dark);
    await _match(tester, 'goldens/date_range/coelo_date_range_picker_open_selected_dark_1440.png');
  });

  testWidgets('matches compact selected light at 375', (tester) async {
    await _pumpPicker(tester, width: 375);
    await _match(
      tester,
      'goldens/date_range/coelo_date_range_picker_compact_selected_light_375.png',
    );
  });

  testWidgets('matches short field light at 768', (tester) async {
    await _pumpField(tester, width: 768);
    await _match(tester, 'goldens/date_range/coelo_date_range_field_short_light_768.png');
  });

  testWidgets('matches day hover light at 1024', (tester) async {
    await _pumpPicker(tester, width: 1024);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byKey(const ValueKey('coelo-date-2026-08-20'))));
    await tester.pump();
    await _match(tester, 'goldens/date_range/coelo_date_range_picker_hover_light_1024.png');
  });

  testWidgets('matches focus light at 1024', (tester) async {
    await _pumpPicker(tester, width: 1024);
    await tester.tap(find.byKey(const ValueKey('coelo-date-2026-08-20')));
    await tester.pump();
    await _match(tester, 'goldens/date_range/coelo_date_range_picker_focus_light_1024.png');
  });

  testWidgets('matches today light at 1024', (tester) async {
    await _pumpPicker(tester, width: 1024, selected: false);
    await _match(tester, 'goldens/date_range/coelo_date_range_picker_today_light_1024.png');
  });

  testWidgets('matches disabled day light at 1024', (tester) async {
    await _pumpPicker(tester, width: 1024, disableDay: 20);
    await _match(tester, 'goldens/date_range/coelo_date_range_picker_disabled_light_1024.png');
  });
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required double width,
  Brightness brightness = Brightness.light,
  bool selected = true,
  int? disableDay,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 760);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    _goldenApp(
      brightness: brightness,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width < 760 ? width : 760),
          child: CoeloDateRangePicker(
            value: selected
                ? DateTimeRange(start: DateTime(2026, 8, 13), end: DateTime(2026, 8, 18))
                : null,
            onChanged: (_) {},
            firstDate: DateTime(2026, 8),
            lastDate: DateTime(2026, 10, 31),
            currentDate: DateTime(2026, 8, 13),
            selectableDayPredicate: disableDay == null ? null : (day) => day.day != disableDay,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpField(WidgetTester tester, {required double width}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 180);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    _goldenApp(
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space6),
        child: CoeloDateRangeField(
          value: DateTimeRange(start: DateTime(2026, 8, 13), end: DateTime(2026, 8, 18)),
          onChanged: (_) {},
          firstDate: DateTime(2026),
          lastDate: DateTime(2027, 12, 31),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _goldenApp({required Widget child, Brightness brightness = Brightness.light}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('coelo-date-range-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  ),
  home: Scaffold(body: child),
);

Future<void> _match(WidgetTester tester, String path) =>
    expectLater(find.byKey(const Key('coelo-date-range-golden-root')), matchesGoldenFile(path));

Future<void> _loadGoldenFonts() async {
  final nunitoBytes = File(
    '../../assets/brand/fonts/nunito-sans/NunitoSans-VariableFont_YTLC,opsz,wdth,wght.ttf',
  ).readAsBytesSync();
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(Future.value(ByteData.sublistView(nunitoBytes)));
  await nunitoSans.load();

  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
