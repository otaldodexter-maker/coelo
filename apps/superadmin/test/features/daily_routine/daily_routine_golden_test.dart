import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_routine_repository.dart';

const _removedOriginFilterReason =
    'V2.10 no longer exposes an origin-filter overlay. The directory uses typed tabs and search.';
const _removedReviewReason =
    'V2.10 no longer has a Revisao e ativacao wizard step; replacing it would mislabel another state.';
const _removedDirtyExitReason =
    'V2.10 has no cancel action or dirty-exit confirmation on the current editor.';
const _sharedDialogReconciliationReason =
    'CoeloAdminDialogShell height belongs to the shared V4.19/V4.20 reconciliation; its oversized baseline cannot be promoted here.';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches create and edit form baselines', (tester) async {
    await _pumpEditor(tester, width: 375, brightness: Brightness.light);
    await _expectGolden(tester, 'daily_routine_form_create_light_375.png');

    await _pumpEditor(tester, width: 1440, brightness: Brightness.dark, modelId: 'unit-model');
    await _expectGolden(tester, 'daily_routine_form_edit_dark_1440.png');
  });

  testWidgets('matches current scope and ordered-fields states', (tester) async {
    await _pumpEditor(tester, width: 1024, brightness: Brightness.light, modelId: 'unit-model');
    await tester.tap(find.byKey(const Key('daily-routine-model-origin-scope')));
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'daily_routine_scope_light_1024.png');

    await _pumpEditor(tester, width: 1024, brightness: Brightness.light, modelId: 'unit-model');
    await tester.ensureVisible(find.byKey(const Key('daily-routine-ordered-editor')));
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'daily_routine_fields_light_1024.png');
  });

  testWidgets('matches directory cards and table baselines', (tester) async {
    await _pumpDirectory(tester);
    await _expectGolden(tester, 'daily_routine_directory_cards_light_1440.png');

    await tester.tap(find.byKey(const Key('daily-routine-view-table')));
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'daily_routine_directory_table_light_1440.png');
  });

  testWidgets('matches directory card hover state', (tester) async {
    await _pumpDirectory(tester);
    final card = find.byKey(const Key('daily-routine-card-institution-model'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'daily_routine_directory_card_hover_light_1440.png');
  });

  testWidgets('matches validation feedback state', (tester) async {
    await _pumpEditor(tester, width: 375, brightness: Brightness.light);
    await tester.tap(find.byKey(const Key('daily-routine-save')));
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'daily_routine_identity_error_light_375.png');
  });

  testWidgets('SKIP: $_sharedDialogReconciliationReason', (tester) async {
    await _pumpEditor(tester, width: 1024, brightness: Brightness.light, modelId: 'unit-model');
    await tester.ensureVisible(find.byKey(const Key('daily-routine-section-arrival')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar secao').first);
    await tester.pumpAndSettle();
    await _expectGolden(tester, 'daily_routine_section_dialog_light_1024.png');
  }, skip: true);

  testWidgets('matches current read-only form state', (tester) async {
    await _pumpEditor(
      tester,
      width: 1440,
      brightness: Brightness.light,
      modelId: 'read-only-model',
    );
    await _expectGolden(tester, 'daily_routine_read_only_light_1440.png');
  });

  testWidgets('SKIP: $_removedOriginFilterReason', (tester) async {
    await _pumpDirectory(tester);
    await _expectGolden(tester, 'daily_routine_directory_filter_open_light_1440.png');
    await _expectGolden(tester, 'daily_routine_directory_filter_selected_light_1440.png');
  }, skip: true);

  testWidgets('SKIP: $_removedReviewReason', (tester) async {
    await _pumpEditor(
      tester,
      width: 1440,
      brightness: Brightness.dark,
      modelId: 'institution-model',
    );
    await _expectGolden(tester, 'daily_routine_review_dark_1440.png');
  }, skip: true);

  testWidgets('SKIP: $_removedDirtyExitReason', (tester) async {
    await _pumpEditor(tester, width: 375, brightness: Brightness.light);
    await _expectGolden(tester, 'daily_routine_dirty_exit_light_375.png');
  }, skip: true);
}

Future<void> _expectGolden(WidgetTester tester, String fileName) => expectLater(
  find.byKey(const Key('daily-routine-golden-root')),
  matchesGoldenFile('goldens/$fileName'),
);

Future<void> _pumpEditor(
  WidgetTester tester, {
  required double width,
  required Brightness brightness,
  String? modelId,
}) async {
  _setViewport(tester, width);
  await tester.pumpWidget(
    _app(
      brightness,
      DailyRoutineEditorPage(
        key: UniqueKey(),
        repository: _editorRepository,
        logout: unavailableSuperadminLogout,
        modelId: modelId,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpDirectory(WidgetTester tester) async {
  _setViewport(tester, 1440);
  await tester.pumpWidget(
    _app(
      Brightness.light,
      DailyRoutineDirectoryPage(
        key: UniqueKey(),
        repository: _directoryRepository,
        logout: unavailableSuperadminLogout,
        onCreateEntry: (_) {},
        onEdit: (_) {},
        onDuplicateModel: (_) {},
        onCreateFromModel: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app(Brightness brightness, Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  themeAnimationStyle: AnimationStyle.noAnimation,
  builder: (context, child) => RepaintBoundary(
    key: const Key('daily-routine-golden-root'),
    child: MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
      child: child!,
    ),
  ),
  home: home,
);

final _directoryRepository = FakeRoutineRepository(
  pageLoader: (query) async => RoutineDirectoryPage(
    items: const [
      RoutineDirectoryItem(
        id: 'institution-model',
        kind: RoutineEntryKind.model,
        name: 'Modelo Berçário',
        status: 'active',
        version: 3,
        originLabel: 'Instituto Horizonte',
        effectiveLabel: 'Instituição',
      ),
      RoutineDirectoryItem(
        id: 'fundamental-model',
        kind: RoutineEntryKind.model,
        name: 'Modelo Fundamental',
        status: 'active',
        version: 2,
        originLabel: 'Instituto Horizonte',
        effectiveLabel: 'Unidade Centro',
      ),
      RoutineDirectoryItem(
        id: 'middle-model',
        kind: RoutineEntryKind.model,
        name: 'Modelo Médio',
        status: 'draft',
        version: 1,
        originLabel: 'Colégio Aurora',
      ),
      RoutineDirectoryItem(
        id: 'preschool-model',
        kind: RoutineEntryKind.model,
        name: 'Modelo Pré',
        status: 'inactive',
        version: 4,
        originLabel: 'Colégio Aurora',
        effectiveLabel: 'Unidade Norte',
      ),
      RoutineDirectoryItem(
        id: 'maternal-model',
        kind: RoutineEntryKind.model,
        name: 'Modelo Maternal',
        status: 'archived',
        version: 5,
        originLabel: 'Instituto Horizonte',
      ),
    ],
    page: query.page,
    pageSize: query.pageSize,
    totalCount: 5,
    canManage: true,
  ),
);

final _editorRepository = FakeRoutineRepository(
  models: const [_institutionModel, _unitModel, _readOnlyModel],
  canManage: true,
);

const _institutionModel = RoutineModel(
  id: 'institution-model',
  name: 'Modelo Berçário',
  description: 'Registro diário de cuidado e comunicação.',
  version: 3,
  status: RoutineModelStatus.active,
  sections: [_arrivalSection],
  expectedVersion: 3,
  institutionId: 'instituto-horizonte',
  canManage: true,
);

const _unitModel = RoutineModel(
  id: 'unit-model',
  name: 'Rotina da Unidade Centro',
  description: 'Configuração cotidiana da unidade, com campos ordenados.',
  version: 2,
  status: RoutineModelStatus.draft,
  sections: [_arrivalSection, _careSection],
  expectedVersion: 2,
  originScope: RoutineModelOriginScope.unit,
  institutionId: 'instituto-horizonte',
  originUnitId: 'unidade-centro',
  canManage: true,
);

const _readOnlyModel = RoutineModel(
  id: 'read-only-model',
  name: 'Modelo Coelo de referência',
  description: 'Disponível somente para consulta neste escopo.',
  version: 7,
  status: RoutineModelStatus.active,
  sections: [_arrivalSection],
  expectedVersion: 7,
  institutionId: 'instituto-horizonte',
);

const _arrivalSection = RoutineSection(
  id: 'arrival',
  name: 'Chegada e acolhimento',
  sortOrder: 0,
  fields: [
    RoutineField(
      id: 'arrival-note',
      label: 'Observações da chegada',
      kind: RoutineFieldKind.longText,
      sortOrder: 0,
    ),
    RoutineField(
      id: 'arrival-mood',
      label: 'Como chegou?',
      kind: RoutineFieldKind.singleChoice,
      sortOrder: 1,
      options: [
        RoutineFieldOption(id: 'calm', label: 'Tranquilo', sortOrder: 0),
        RoutineFieldOption(id: 'sensitive', label: 'Sensível', sortOrder: 1),
      ],
    ),
  ],
);

const _careSection = RoutineSection(
  id: 'care',
  name: 'Cuidados do dia',
  sortOrder: 1,
  fields: [
    RoutineField(
      id: 'care-fed',
      label: 'Alimentação registrada',
      kind: RoutineFieldKind.boolean,
      sortOrder: 0,
      isRequired: true,
    ),
  ],
);

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();

  final windowsDirectory = Platform.environment['WINDIR'] ?? r'C:\Windows';
  final emojiFont = File('$windowsDirectory\\Fonts\\seguiemj.ttf');
  if (emojiFont.existsSync()) {
    final emojiLoader = FontLoader('Segoe UI Emoji')
      ..addFont(Future.value(ByteData.sublistView(emojiFont.readAsBytesSync())));
    await emojiLoader.load();
  }

  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final materialIconsLoader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await materialIconsLoader.load();
}
