import 'dart:io';
import 'dart:ui';
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_detail_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_directory_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'location_read_fixtures.dart';

void main() {
  setUpAll(_fonts);
  testWidgets('shared status text200 accessible candidate', (tester) async {
    await _size(tester, 375);
    final reader = ControlledLocationReader();
    await tester.pumpWidget(
      _app(
        LocationDirectoryPanel(
          scope: scopeA,
          reader: reader,
          sessionAvailable: true,
          onOpen: (_) {},
        ),
        textScale: 2,
      ),
    );
    reader.directories.single.result.complete(
      LocationDirectoryResult(
        items: [locationFixture(status: LocationCatalogStatus.suspended)],
        totalCount: 1,
      ),
    );
    await tester.pumpAndSettle();
    final status = find.byKey(const Key('location-status-$locationA'));
    await tester.ensureVisible(status);
    await tester.tap(status);
    await tester.pumpAndSettle();
    expect(tester.getSize(status).height, greaterThanOrEqualTo(CoeloSize.touchMin));
    await _golden(tester, 'directory_status_text200_light_375');
  });
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      if (dark && width != 375 && width != 1440) continue;
      testWidgets('directory base $width dark=$dark', (tester) async {
        await _size(tester, width);
        final reader = ControlledLocationReader();
        await tester.pumpWidget(
          _app(
            LocationDirectoryPanel(
              scope: scopeA,
              reader: reader,
              sessionAvailable: true,
              onOpen: (_) {},
            ),
            dark: dark,
          ),
        );
        reader.directories.single.result.complete(_page());
        await tester.pumpAndSettle();
        await _golden(tester, 'directory_cards_${dark ? 'dark' : 'light'}_${width.toInt()}');
        if (width == 375 || width == 1440) {
          await tester.tap(find.byKey(const Key('location-view-table')));
          reader.directories.last.result.complete(_page());
          await tester.pumpAndSettle();
          await _golden(tester, 'directory_table_${dark ? 'dark' : 'light'}_${width.toInt()}');
        }
      });
    }
  }
  for (final state in ['loading', 'empty', 'no_results', 'denied', 'unavailable']) {
    testWidgets('directory $state candidate', (tester) async {
      await _size(tester, 375);
      final reader = ControlledLocationReader();
      await tester.pumpWidget(
        _app(
          LocationDirectoryPanel(
            scope: scopeA,
            reader: reader,
            sessionAvailable: state != 'denied',
            onOpen: (_) {},
          ),
        ),
      );
      if (state == 'empty') {
        reader.directories.last.result.complete(LocationDirectoryResult(items: [], totalCount: 0));
      }
      if (state == 'unavailable') {
        reader.directories.last.result.completeError(StateError('private'));
      }
      if (state == 'no_results') {
        reader.directories.last.result.complete(_page());
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'inexistente');
        reader.directories.last.result.complete(LocationDirectoryResult(items: [], totalCount: 0));
      }
      if (state == 'loading') {
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        await tester.pumpAndSettle();
      }
      await _golden(tester, 'directory_${state}_light_375');
    });
  }
  for (final state in ['light', 'dark', 'loading', 'denied', 'unavailable', 'focus']) {
    testWidgets('detail $state candidate', (tester) async {
      await _size(tester, state == 'dark' ? 1440 : 375);
      final reader = ControlledLocationReader();
      await tester.pumpWidget(
        _app(
          LocationDetailPanel(
            scope: scopeA,
            id: locationA,
            reader: reader,
            sessionAvailable: state != 'denied',
            onBack: () {},
          ),
          dark: state == 'dark',
        ),
      );
      if (state == 'unavailable') reader.details.last.result.completeError(StateError('private'));
      if (['light', 'dark', 'focus'].contains(state)) {
        reader.details.last.result.complete(locationFixture());
      }
      if (state == 'loading') {
        await tester.pump(const Duration(milliseconds: 100));
      } else {
        await tester.pumpAndSettle();
      }
      if (state == 'focus') {
        await _focusByTab(tester, find.byKey(const Key('location-detail-back')));
        await tester.pumpAndSettle();
      }
      await _golden(
        tester,
        state == 'light'
            ? 'detail_light_375'
            : state == 'dark'
            ? 'detail_dark_1440'
            : 'detail_${state}_light_375',
      );
    });
  }
  testWidgets('directory interactive candidates', (tester) async {
    await _size(tester, 1440);
    final reader = ControlledLocationReader();
    await tester.pumpWidget(
      _app(
        LocationDirectoryPanel(
          scope: scopeA,
          reader: reader,
          sessionAvailable: true,
          onOpen: (_) {},
        ),
      ),
    );
    reader.directories.last.result.complete(_page());
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('location-card-$locationA'))));
    await tester.pumpAndSettle();
    await _golden(tester, 'directory_card_hover_light_1440');
    await mouse.moveTo(Offset.zero);
    await _focusByTab(tester, find.byKey(const Key('location-card-$locationA')));
    await _golden(tester, 'directory_card_focus_light_1440');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.byKey(const Key('location-status-$locationA')));
    await tester.pumpAndSettle();
    await _golden(tester, 'directory_status_light_1440');
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await _golden(tester, 'directory_search_focus_light_1440');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await _golden(tester, 'directory_files_light_1440');
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.text('Disponível depois do MVP'), findsOneWidget);
    expect(reader.directories, hasLength(1));
    await mouse.removePointer();
  });
  testWidgets('table row and pagination interaction candidates', (tester) async {
    await _size(tester, 1440);
    final reader = ControlledLocationReader();
    var opened = 0;
    await tester.pumpWidget(
      _app(
        LocationDirectoryPanel(
          scope: scopeA,
          reader: reader,
          sessionAvailable: true,
          onOpen: (_) => opened++,
        ),
      ),
    );
    reader.directories.last.result.complete(_page());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('location-view-table')));
    reader.directories.last.result.complete(_page());
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('Sala de leitura').hitTestable().first));
    await tester.pumpAndSettle();
    await _golden(tester, 'directory_row_hover_light_1440');
    await mouse.moveTo(Offset.zero);
    await _focusByTab(tester, find.byKey(const Key(locationA)));
    await _golden(tester, 'directory_row_focus_light_1440');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, 1);
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();
    await _golden(tester, 'directory_pagination_light_1440');
    await mouse.removePointer();
  });
}

Future<void> _focusByTab(WidgetTester tester, Finder target) async {
  bool containsFocus() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    final element = tester.element(target);
    var found = focused == element;
    void visit(Element child) {
      if (child == focused) found = true;
      child.visitChildren(visit);
    }

    element.visitChildren(visit);
    return found;
  }

  for (var i = 0; i < 35 && !containsFocus(); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  expect(containsFocus(), isTrue, reason: 'Target must receive actual keyboard focus');
}

LocationDirectoryResult _page() => LocationDirectoryResult(
  items: [
    locationFixture(),
    locationFixture(
      id: locationB,
      name: 'Jardim externo',
      kind: LocationKind.external,
      status: LocationCatalogStatus.inactive,
    ),
  ],
  totalCount: 24,
);

Future<void> _size(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
}

Future<void> _golden(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  await expectLater(
    find.byKey(const Key('location-frame')),
    matchesGoldenFile('goldens/status_a11y/location_$name.png'),
  );
}

Widget _app(Widget panel, {bool dark = false, double textScale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: dark ? CoeloTheme.dark : CoeloTheme.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('location-frame'),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
  ),
  home: Scaffold(body: panel),
);
Future<void> _fonts() async {
  final nunito = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunito.load();
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final bytes = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}
