import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart' as domain;
import 'package:coelo_superadmin/features/units/presentation/unit_directory_page.dart';
import 'package:coelo_superadmin/features/units/presentation/widgets/unit_status_presentation.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_listing_pagination_footer.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers grouped, turmas, and activities table views with local metrics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) => widget is SuperadminDirectoryViewToggle),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('unit-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-directory-table-grouped')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-groups')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-activities')), findsOneWidget);
    for (final id in ['administrators', 'team', 'guardians', 'children']) {
      expect(find.byKey(Key('coelo-admin-table-header-$id')), findsOneWidget);
    }

    await tester.longPress(find.byKey(const Key('unit-view-table')));
    await tester.pumpAndSettle();
    for (final label in ['Agrupado', 'Por turmas', 'Por atividades']) {
      expect(find.widgetWithText(MenuItemButton, label), findsOneWidget);
    }

    await tester.tap(find.widgetWithText(MenuItemButton, 'Por turmas'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-directory-table-groups')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-group-name')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-activities')), findsNothing);
    expect(_unitDetailRows('groups'), findsWidgets);

    await tester.longPress(find.byKey(const Key('unit-view-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Por atividades'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-directory-table-activities')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-group-name')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-activity-name')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-groups')), findsNothing);
    expect(_unitDetailRows('activities'), findsWidgets);
  });

  testWidgets('uses the shared pagination footer', (tester) async {
    final institutions = FakeInstitutionDirectoryRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminListingPaginationFooter), findsOneWidget);
  });

  testWidgets('renders active status with the canonical semantic surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const Scaffold(body: UnitStatusChip(status: domain.UnitStatus.active)),
      ),
    );

    expect(find.text('Ativa'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    final surface = tester.widget<Container>(find.byKey(const Key('unit-status-chip-active')));
    final statusColors = CoeloStatusColors.light;
    expect((surface.decoration! as BoxDecoration).color, statusColors.successContainer);
  });

  testWidgets('canonical unit status starts circular and expands on hover', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: Center(
            child: CoeloAdminExpandableStatusIndicator(
              label: domain.UnitStatus.active.label,
              backgroundColor: CoeloStatusColors.light.successContainer,
              foregroundColor: CoeloStatusColors.light.onSuccessContainer,
              surfaceKey: const Key('unit-status-unit-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = find.byKey(const Key('unit-status-unit-1'));
    expect(tester.getSize(surface).width, 24);
    expect(find.text('Ativa'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(surface));
    await tester.pumpAndSettle();

    expect(tester.getSize(surface).width, greaterThan(24));
    expect(find.text('Ativa'), findsOneWidget);
  });

  testWidgets('renders the unit card contract and switches to the canonical table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final firstItem = (await repository.fetchPage(domain.UnitDirectoryQuery())).items.first;
    String? editedId;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onEdit: (id) => editedId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unidades'), findsWidgets);
    expect(find.text('Gerencie as unidades da plataforma.'), findsOneWidget);
    expect(find.text('Instituição'), findsWidgets);
    expect(find.text('Tipo'), findsWidgets);
    expect(find.text('Plano'), findsWidgets);
    expect(find.text('Turmas'), findsWidgets);
    expect(find.text('Atividades'), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);

    final firstCard = find.byKey(Key('unit-card-${firstItem.id}'));
    expect(
      tester.getSize(find.byKey(const Key('create-unit-card'))).height,
      closeTo(tester.getSize(firstCard).height, 0.5),
    );
    await tester.tap(firstCard);
    expect(editedId, firstItem.id);

    await tester.tap(find.byKey(const Key('unit-view-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-directory-table')), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Município'), findsOneWidget);
    expect(find.text('UF'), findsOneWidget);
    final bannerCenter = tester.getCenter(find.byKey(const Key('create-unit-banner')));
    final bannerContentCenter = tester.getCenter(
      find.byKey(const Key('superadmin-directory-create-banner-content')),
    );
    expect(bannerContentCenter.dx, closeTo(bannerCenter.dx, 0.5));
  });

  testWidgets('has no overflow at 375 pixels with text at 200 percent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the sticky pagination and switches page size with the display', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-directory-pagination-footer')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsOneWidget);
    expect(find.byKey(const Key('unit-card-grid')).evaluate().length, 1);

    await tester.tap(find.byKey(const Key('unit-view-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coelo-admin-pagination-page-size-8')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-pagination-page-size-11')), findsNothing);
  });

  testWidgets('keeps the launcher above sticky pagination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onConversationsOpen: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final footer = find.byKey(const Key('unit-directory-pagination-footer'));
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    expect(footer, findsOneWidget);
    expect(launcher, findsOneWidget);
    expect(
      tester.getBottomLeft(launcher).dy,
      lessThanOrEqualTo(tester.getTopLeft(footer).dy - CoeloSpacing.space4),
    );
  });

  testWidgets('uses the plain surface background on compact widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final directoryContext = tester.element(find.byKey(const Key('unit-card-grid')));
    final directoryTheme = Theme.of(directoryContext);
    expect(directoryTheme.scaffoldBackgroundColor, directoryTheme.colorScheme.surface);
  });

  testWidgets('opens the unit CSV and XLSX import review dialog', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.text('Importar unidades'), findsOneWidget);
    expect(find.textContaining('CSV ou XLSX'), findsOneWidget);
    expect(find.byKey(const Key('unit-demo-file-picker')), findsOneWidget);
  });

  testWidgets('uses exclusive status tabs and removes the status dropdown', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());
    await repository.upsert(repository.records.first.copyWith(status: domain.UnitStatus.draft));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-status-filter')), findsNothing);
    expect(find.byKey(const Key('unit-status-tabs')), findsOneWidget);
    for (final label in ['Todos', 'Ativos', 'Em Implantação', 'Inativos']) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('Em Implantação'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Status: Rascunho'), findsWidgets);
    expect(find.bySemanticsLabel('Status: Ativa'), findsNothing);
  });

  testWidgets('unit cards reuse the canonical interactive card and status components', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository()),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminInteractiveCard), findsWidgets);
    expect(find.byType(CoeloAdminExpandableStatusIndicator), findsWidgets);
  });

  testWidgets('keeps the table scrollable, sortable, and resizable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitDirectoryPage(
          repository: FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository()),
          logout: () async => const LogoutResult.success(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-view-table')));
    await tester.pumpAndSettle();

    final tableScroll = find.byKey(const Key('coelo-admin-table-scroll'));
    expect(tableScroll, findsOneWidget);
    final scrollable = tester.widget<SingleChildScrollView>(tableScroll);
    expect(scrollable.controller!.position.maxScrollExtent, greaterThan(0));

    final header = find.byKey(const Key('coelo-admin-table-header-institution'));
    final oldWidth = tester.getSize(header).width;
    await tester.drag(
      find.byKey(const Key('coelo-admin-table-resizer-indicator-institution')),
      const Offset(60, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(header).width, greaterThan(oldWidth));

    await tester.tap(find.byKey(const Key('coelo-admin-table-sort-background-institution')));
    await tester.pumpAndSettle();
    await tester.drag(tableScroll, const Offset(-250, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports 200 percent text at all approved widths', (tester) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(width),
          theme: CoeloTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: UnitDirectoryPage(
            repository: FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository()),
            logout: () async => const LogoutResult.success(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$width cards');
      expect(find.byKey(const Key('unit-directory-pagination-footer')), findsOneWidget);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}

Finder _unitDetailRows(String level) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('unit-detail-row-$level-');
});
