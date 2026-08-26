import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/data/fake_group_directory_repository.dart';
import 'package:coelo_superadmin/features/groups/domain/group_directory.dart' as domain;
import 'package:coelo_superadmin/features/groups/presentation/group_directory_page.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_form_page.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the group directory cards and table at supported widths and themes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_directoryApp(brightness));
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const Key('group-directory-golden-frame')),
          matchesGoldenFile(
            '../../../goldens/groups/'
            'group_directory_cards_${brightness.name}_${width.toInt()}.png',
          ),
        );

        await tester.ensureVisible(find.byKey(const Key('group-view-table')));
        await tester.tap(find.byKey(const Key('group-view-table')));
        await tester.pumpAndSettle();
        await _scrollDirectoryToTop(tester);
        await expectLater(
          find.byKey(const Key('group-directory-golden-frame')),
          matchesGoldenFile(
            '../../../goldens/groups/'
            'group_directory_table_${brightness.name}_${width.toInt()}.png',
          ),
        );
      }
    }
  });

  testWidgets('matches critical create mobile and edit desktop forms', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final institutions = FakeInstitutionDirectoryRepository();
    final groups = FakeGroupDirectoryRepository(institutions);

    tester.view.physicalSize = const Size(375, 900);
    await tester.pumpWidget(
      _formApp(
        GroupFormPage(repository: groups, logout: _logout, onCancel: () {}, onSaved: (_) {}),
        Brightness.light,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('group-form-golden-frame')),
      matchesGoldenFile('../../../goldens/groups/group_form_create_light_375.png'),
    );

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(
      _formApp(
        GroupFormPage(
          repository: groups,
          groupId: groups.records.first.id,
          logout: _logout,
          onCancel: () {},
          onSaved: (_) {},
        ),
        Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('group-form-golden-frame')),
      matchesGoldenFile('../../../goldens/groups/group_form_edit_dark_1440.png'),
    );
  });

  testWidgets('matches critical empty and error directory states', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (name: 'empty', repository: const _ScenarioRepository.empty()),
      (name: 'failure', repository: const _ScenarioRepository.failure()),
      (name: 'unauthorized', repository: const _ScenarioRepository.unauthorized()),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        _directoryApp(Brightness.light, repository: configuration.repository),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('group-directory-golden-frame')),
        matchesGoldenFile(
          '../../../goldens/groups/'
          'group_directory_${configuration.name}_light_1440.png',
        ),
      );
    }
  });

  testWidgets('matches the critical no-results directory state', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_directoryApp(Brightness.light));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sem correspondencia');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('group-directory-golden-frame')),
      matchesGoldenFile('../../../goldens/groups/group_directory_no_results_light_1440.png'),
    );
  });

  testWidgets('matches card hover and selected filter references', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeGroupDirectoryRepository(institutions);

    await tester.pumpWidget(_directoryApp(Brightness.light, repository: repository));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(Key('group-card-surface-${repository.records.first.id}'))),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('group-directory-golden-frame')),
      matchesGoldenFile('../../../goldens/groups/group_directory_card_hover_light_1440.png'),
    );
    await mouse.removePointer();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_directoryApp(Brightness.light));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em Implantação'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('group-directory-golden-frame')),
      matchesGoldenFile('../../../goldens/groups/group_directory_filter_selected_light_1440.png'),
    );
  });

  testWidgets('matches the open page-size selector reference', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_directoryApp(Brightness.light));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('group-directory-golden-frame')),
      matchesGoldenFile(
        '../../../goldens/groups/'
        'group_directory_pagination_page_size_open_light_1440.png',
      ),
    );
  });

  testWidgets('matches shell overlays integrated with the group directory', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (name: 'bug_open', triggerKey: const Key('superadmin-report-bug')),
      (name: 'profile_open', triggerKey: const Key('superadmin-profile-menu')),
      (name: 'tour_open', triggerKey: const Key('superadmin-onboarding-tour')),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_directoryApp(Brightness.light));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(configuration.triggerKey));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('group-directory-golden-frame')),
        matchesGoldenFile(
          '../../../goldens/groups/'
          'group_directory_${configuration.name}_light_1440.png',
        ),
      );
    }
  });

  testWidgets('matches the searchable institution filter flyout', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_directoryApp(Brightness.light));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-institution-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Buscar instituição'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('group-directory-golden-frame')),
      matchesGoldenFile(
        '../../../goldens/groups/'
        'group_directory_institution_filter_open_light_1440.png',
      ),
    );
  });

  testWidgets('matches a hovered table row', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeGroupDirectoryRepository(institutions);

    await tester.pumpWidget(_directoryApp(Brightness.light, repository: repository));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('group-view-table')));
    await tester.tap(find.byKey(const Key('group-view-table')));
    await tester.pumpAndSettle();
    await _scrollDirectoryToTop(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(Key('group-table-row-${repository.records.first.id}'))),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('group-directory-golden-frame')),
      matchesGoldenFile('../../../goldens/groups/group_directory_table_row_hover_light_1440.png'),
    );
    await mouse.removePointer();
  });

  testWidgets('matches hover and focus for create actions', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_directoryApp(Brightness.light));
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(CoeloAdminCreateAction).first));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('group-directory-golden-frame')),
      matchesGoldenFile('../../../goldens/groups/group_directory_create_card_hover_light_1440.png'),
    );
    await mouse.removePointer();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_directoryApp(Brightness.light));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('group-view-table')));
    await tester.tap(find.byKey(const Key('group-view-table')));
    await tester.pumpAndSettle();
    await _scrollDirectoryToTop(tester);
    await tester.tap(find.byKey(const Key('group-create-banner-surface')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('group-directory-golden-frame')),
      matchesGoldenFile(
        '../../../goldens/groups/group_directory_create_banner_focus_light_1440.png',
      ),
    );
  });
}

Widget _directoryApp(Brightness brightness, {domain.GroupDirectoryRepository? repository}) {
  final institutions = FakeInstitutionDirectoryRepository();
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('group-directory-golden-frame'),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
        child: child!,
      ),
    ),
    home: GroupDirectoryPage(
      repository: repository ?? FakeGroupDirectoryRepository(institutions),
      logout: _logout,
      onBugReportSubmitted: (_) {},
    ),
  );
}

Widget _formApp(Widget child, Brightness brightness) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('group-form-golden-frame'),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
        child: child!,
      ),
    ),
    home: child,
  );
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

Future<void> _scrollDirectoryToTop(WidgetTester tester) async {
  await tester.drag(find.byKey(const Key('group-directory-scroll')), const Offset(0, 1000));
  await tester.pumpAndSettle();
}

enum _Scenario { empty, failure, unauthorized }

final class _ScenarioRepository implements domain.GroupDirectoryRepository {
  const _ScenarioRepository.empty() : scenario = _Scenario.empty;
  const _ScenarioRepository.failure() : scenario = _Scenario.failure;
  const _ScenarioRepository.unauthorized() : scenario = _Scenario.unauthorized;

  final _Scenario scenario;

  @override
  String createId(String institutionId, String unitId, String name) =>
      throw UnsupportedError('Read-only golden scenario.');

  @override
  Future<domain.GroupDirectoryFilterOptions> fetchFilterOptions({
    Set<String> institutionIds = const {},
  }) async => const domain.GroupDirectoryFilterOptions();

  @override
  Future<domain.GroupDirectoryPage> fetchPage(domain.GroupDirectoryQuery query) async =>
      switch (scenario) {
        _Scenario.empty => domain.GroupDirectoryPage(
          items: const [],
          totalCount: 0,
          page: 0,
          pageSize: query.pageSize,
        ),
        _Scenario.failure => throw Exception('Golden failure scenario.'),
        _Scenario.unauthorized => throw const domain.GroupDirectoryUnauthorizedException(),
      };

  @override
  Future<domain.GroupRecord?> findById(String id) async => null;

  @override
  Future<domain.GroupDirectoryFormContext> fetchFormContext({String? institutionId}) async =>
      const domain.GroupDirectoryFormContext(institutions: [], units: []);

  @override
  Future<domain.GroupDirectoryExportResult> requestExport(domain.GroupDirectoryQuery query) async =>
      throw UnsupportedError('Read-only golden scenario.');

  @override
  Future<domain.GroupDirectorySaveResult> saveComposition(
    domain.GroupDirectorySaveRequest request,
  ) async => throw UnsupportedError('Read-only golden scenario.');

  @override
  Future<void> upsert(domain.GroupRecord record) =>
      throw UnsupportedError('Read-only golden scenario.');
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
