import 'dart:async';
import 'dart:io';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_page.dart'
    as domain;
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the institution directory cards and table references', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_goldenApp(brightness: brightness));
        await tester.pumpAndSettle();

        final themeName = brightness.name;
        final widthName = width.toInt();
        await expectLater(
          find.byKey(const Key('institution-directory-golden-root')),
          matchesGoldenFile('goldens/institution_directory_cards_${themeName}_$widthName.png'),
        );

        await tester.ensureVisible(find.byKey(const Key('institution-view-table')));
        await tester.tap(find.byKey(const Key('institution-view-table')));
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(const Key('institution-directory-golden-root')),
          matchesGoldenFile('goldens/institution_directory_table_${themeName}_$widthName.png'),
        );
      }
    }
  });

  testWidgets('matches loading, empty, failure, and unauthorized references', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final pendingRepository = _PendingRepository();
    addTearDown(pendingRepository.complete);
    await tester.pumpWidget(_goldenApp(repository: pendingRepository));
    await tester.pump();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_loading_light_1440.png'),
    );

    for (final configuration in [
      (name: 'empty', repository: FakeInstitutionDirectoryRepository(items: [])),
      (name: 'failure', repository: const _FailureRepository()),
      (name: 'unauthorized', repository: const _UnauthorizedRepository()),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_goldenApp(repository: configuration.repository));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('institution-directory-golden-root')),
        matchesGoldenFile('goldens/institution_directory_${configuration.name}_light_1440.png'),
      );
    }
  });

  testWidgets('matches the no-results reference', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sem correspondencia');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_no_results_light_1440.png'),
    );
  });

  testWidgets('matches disabled pagination references', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _goldenApp(
        repository: FakeInstitutionDirectoryRepository(items: _paginationItems()),
        onConversationsOpen: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Página 1 de 2'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_pagination_disabled_light_1440.png'),
    );
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_pagination_page_size_open_light_1440.png'),
    );
  });

  testWidgets('matches hover, focus, and selected filter references', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.byKey(const Key('institution-card-surface-demo-institution-aurora'))),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_card_hover_light_1440.png'),
    );
    await mouse.removePointer();

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_search_focus_light_1440.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Escola'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_filter_selected_light_1440.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em Implantação'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_status_tabs_light_1440.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();
    final flyoutMouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(flyoutMouse.removePointer);
    await flyoutMouse.addPointer(
      location: tester.getCenter(find.widgetWithText(MenuItemButton, 'Unidades')),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_table_flyout_open_light_1440.png'),
    );
  });

  testWidgets('matches the collapsed navigation flyout reference', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-sidebar-collapse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-navigation-section-access')));
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(
        find.ancestor(of: find.text('Pessoas'), matching: find.byType(MenuItemButton)),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_collapsed_flyout_hover_light_1024.png'),
    );
    await mouse.removePointer();
  });

  testWidgets('matches approved interactive directory state references', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-type-filter')));
    await tester.pumpAndSettle();
    final filterMouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await filterMouse.addPointer();
    await filterMouse.moveTo(tester.getCenter(find.widgetWithText(MenuItemButton, 'Escola')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_filter_option_hover_light_1440.png'),
    );
    await filterMouse.removePointer();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    final filesMouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await filesMouse.addPointer();
    await filesMouse.moveTo(tester.getCenter(find.widgetWithText(MenuItemButton, 'Exportar CSV')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_files_hover_light_1440.png'),
    );
    await filesMouse.removePointer();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-status-demo-institution-aurora')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_status_expanded_light_1440.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('institution-view-table')));
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-directory-table')), findsOneWidget);
    final tableMouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await tableMouse.addPointer();
    await tableMouse.moveTo(
      tester.getCenter(find.byKey(const Key('institution-table-row-demo-institution-horizonte'))),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_table_row_hover_light_1440.png'),
    );
    await tableMouse.removePointer();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_goldenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-profile-menu')));
    await tester.pumpAndSettle();
    final profileMouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await profileMouse.addPointer();
    await profileMouse.moveTo(tester.getCenter(find.widgetWithText(MenuItemButton, 'Sair')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_logout_hover_light_1440.png'),
    );
    await profileMouse.removePointer();
  });
}

Widget _goldenApp({
  Brightness brightness = Brightness.light,
  InstitutionDirectoryRepository? repository,
  VoidCallback? onConversationsOpen,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) => RepaintBoundary(
      key: const Key('institution-directory-golden-root'),
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: true, textScaler: TextScaler.noScaling),
        child: child!,
      ),
    ),
    home: InstitutionDirectoryPage(
      repository: repository ?? FakeInstitutionDirectoryRepository(),
      logout: _logout,
      onConversationsOpen: onConversationsOpen,
    ),
  );
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

List<InstitutionDirectoryItem> _paginationItems() {
  final source = demoInstitutionDirectoryItems.first;
  return List.generate(
    21,
    (index) => InstitutionDirectoryItem(
      id: 'golden-institution-$index',
      publicName: 'Instituição ${(index + 1).toString().padLeft(2, '0')}',
      tradeName: source.tradeName,
      legalName: source.legalName,
      primaryDomain: source.primaryDomain,
      status: source.status,
      typeId: source.typeId,
      typeName: source.typeName,
      district: source.district,
      street: source.street,
      addressNumber: source.addressNumber,
      complement: source.complement,
      postalCode: source.postalCode,
      city: source.city,
      state: source.state,
      contactEmail: source.contactEmail,
      contactPhone: source.contactPhone,
      contactMobilePhone: source.contactMobilePhone,
      planId: source.planId,
      planName: source.planName,
      unitsCount: source.unitsCount,
      groupsCount: source.groupsCount,
    ),
  );
}

final class _PendingRepository implements InstitutionDirectoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  final Completer<domain.InstitutionDirectoryPage> _page =
      Completer<domain.InstitutionDirectoryPage>();

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) =>
      _page.future;

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async => InstitutionDirectoryFilterOptions.empty;

  void complete() {
    if (!_page.isCompleted) {
      _page.complete(
        const domain.InstitutionDirectoryPage(
          items: [],
          totalCount: 0,
          page: 0,
          pageSize: InstitutionDirectoryQuery.defaultPageSize,
        ),
      );
    }
  }
}

final class _FailureRepository implements InstitutionDirectoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  const _FailureRepository();

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) {
    throw const InstitutionDirectoryUnavailableException();
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async => InstitutionDirectoryFilterOptions.empty;
}

final class _UnauthorizedRepository implements InstitutionDirectoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  const _UnauthorizedRepository();

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) {
    throw const InstitutionDirectoryUnauthorizedException();
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async => InstitutionDirectoryFilterOptions.empty;
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
