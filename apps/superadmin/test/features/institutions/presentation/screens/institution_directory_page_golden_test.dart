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

  testWidgets('matches no-results and disabled pagination references', (tester) async {
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _goldenApp(repository: FakeInstitutionDirectoryRepository(items: _paginationItems())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Página 1 de 2'),
      600,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('institution-directory-content-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_pagination_disabled_light_1440.png'),
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
    await tester.tap(find.byKey(const Key('institution-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativa').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_filter_selected_light_1440.png'),
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
      tester.getCenter(find.byKey(const Key('superadmin-navigation-internal-users'))),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const Key('institution-directory-golden-root')),
      matchesGoldenFile('goldens/institution_directory_collapsed_flyout_hover_light_1024.png'),
    );
    await mouse.removePointer();
  });
}

Widget _goldenApp({
  Brightness brightness = Brightness.light,
  InstitutionDirectoryRepository? repository,
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
      _page.complete(const domain.InstitutionDirectoryPage(items: [], totalCount: 0, page: 0));
    }
  }
}

final class _FailureRepository implements InstitutionDirectoryRepository {
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
