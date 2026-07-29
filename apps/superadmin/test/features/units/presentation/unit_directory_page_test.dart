import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart' as domain;
import 'package:coelo_superadmin/features/units/presentation/unit_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(find.text('Grupos'), findsWidgets);
    expect(find.text('Atividades'), findsWidgets);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);

    final firstCard = find.byKey(Key('unit-card-${firstItem.id}'));
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
    await tester.tap(find.byKey(const Key('unit-files-import')));
    await tester.pumpAndSettle();

    expect(find.text('Importar unidades'), findsOneWidget);
    expect(find.textContaining('CSV ou XLSX'), findsOneWidget);
    expect(find.byKey(const Key('unit-demo-file-picker')), findsOneWidget);
  });

  testWidgets('keeps filter selections as draft and closes the panel with Escape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository());

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

    final trigger = find.byKey(const Key('unit-status-filter'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativa'));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsNothing);

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Limpar filtros'), findsOneWidget);
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    expect(find.text('Limpar filtros'), findsNothing);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rascunho'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsNothing);
    expect(find.text('Limpar filtros'), findsNothing);
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
