import 'dart:async';
import 'dart:ui';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_page.dart'
    as domain;
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_directory_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_view_toggle.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers grouped, units, groups, and activities table views', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) => widget is SuperadminDirectoryViewToggle),
      findsOneWidget,
    );
    await tester.longPress(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();

    for (final label in ['Agrupado', 'Unidades', 'Turmas', 'Atividades']) {
      expect(find.widgetWithText(MenuItemButton, label), findsOneWidget);
    }

    await tester.tap(find.widgetWithText(MenuItemButton, 'Unidades'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-directory-table-units')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-unit-name')), findsOneWidget);
    expect(_institutionDetailRows('units'), findsWidgets);

    await tester.longPress(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Turmas'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-directory-table-groups')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-unit-name')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-group-name')), findsOneWidget);
    expect(_institutionDetailRows('groups'), findsWidgets);

    await tester.longPress(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Atividades'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-directory-table-activities')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-unit-name')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-group-name')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-table-header-activity-name')), findsOneWidget);
    expect(_institutionDetailRows('activities'), findsWidgets);
  });

  testWidgets('shows each deduplicated local institution metric once in grouped view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();

    for (final label in [
      'Representantes legais',
      'Administradores',
      'Equipe institucional',
      'Responsáveis',
      'Crianças',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('starts with cards and the approved dependent filter order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var createRequested = false;

    await tester.pumpWidget(_app(onCreate: () => createRequested = true));
    await tester.pumpAndSettle();

    expect(find.text('Instituições'), findsWidgets);
    expect(find.text('Gerencie as instituições da plataforma.'), findsOneWidget);
    expect(find.byKey(const Key('institution-filter-toolbar')), findsOneWidget);
    expect(find.text('Todos os tipos'), findsOneWidget);
    expect(find.byKey(const Key('institution-status-tabs')), findsOneWidget);
    expect(find.byKey(const Key('institution-status-filter')), findsNothing);
    for (final label in ['Todos', 'Ativos', 'Em Implantação', 'Inativos']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Todas as UFs'), findsOneWidget);
    expect(find.text('Todos os planos'), findsNothing);
    expect(find.byKey(const Key('institution-city-filter')), findsNothing);
    expect(find.byKey(const Key('institution-district-filter')), findsNothing);
    final typeLeft = tester.getTopLeft(find.byKey(const Key('institution-type-filter'))).dx;
    final stateLeft = tester.getTopLeft(find.byKey(const Key('institution-state-filter'))).dx;
    expect(typeLeft, lessThan(stateLeft), reason: 'type=$typeLeft state=$stateLeft');
    final searchField = tester.widget<TextField>(_institutionSearchField());
    expect(searchField.decoration?.hintText, 'Buscar por nome');
    expect(searchField.decoration?.hintText, isNot(contains('domínio')));
    expect(tester.getSize(_institutionSearchField()).width, 216);
    final searchBorder = searchField.decoration!.enabledBorder! as OutlineInputBorder;
    expect(searchBorder.borderRadius.topLeft.x, CoeloRadius.full);
    expect(find.text('Importar instituições'), findsNothing);
    expect(find.byKey(const Key('create-institution-card')), findsOneWidget);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.text('Instituto Aurora'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);

    await tester.tap(find.byKey(const Key('create-institution-card')));
    await tester.pumpAndSettle();

    expect(createRequested, isTrue);
  });

  testWidgets('matches the approved directory filter flow at every width', (tester) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_app(pageKey: ValueKey(width)));
      await tester.pumpAndSettle();

      final controlsRect = tester.getRect(find.byKey(const Key('institution-filter-controls')));
      final searchRect = tester.getRect(_institutionSearchField());
      final typeRect = tester.getRect(find.byKey(const Key('institution-type-filter')));
      final stateRect = tester.getRect(find.byKey(const Key('institution-state-filter')));
      final expectedSearchWidth = width == 375
          ? controlsRect.width
          : width == 1440
          ? 300.0
          : 216.0;
      expect(searchRect.left, closeTo(controlsRect.left, 1));
      expect(searchRect.width, closeTo(expectedSearchWidth, 1));
      expect(typeRect.width, closeTo(stateRect.width, 1));
      if (width == 375) {
        expect((typeRect.width * 2) + CoeloSpacing.space3, closeTo(searchRect.width, 1));
      } else {
        expect(typeRect.width, 160);
      }
      expect(stateRect.top, greaterThanOrEqualTo(typeRect.top));
      if ((stateRect.top - typeRect.top).abs() < 1) {
        expect(stateRect.left, greaterThan(typeRect.right));
      }
      expect(tester.takeException(), isNull, reason: 'responsive filter flow');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('reduces filters to one column with text scaled to 200 percent', (tester) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        _app(textScaler: const TextScaler.linear(2), pageKey: ValueKey(width)),
      );
      await tester.pumpAndSettle();

      final controlsRect = tester.getRect(find.byKey(const Key('institution-filter-controls')));
      final typeRect = tester.getRect(find.byKey(const Key('institution-type-filter')));
      final stateRect = tester.getRect(find.byKey(const Key('institution-state-filter')));
      expect(typeRect.width, closeTo(controlsRect.width, 1));
      expect(stateRect.width, closeTo(controlsRect.width, 1));
      expect(stateRect.top, greaterThan(typeRect.bottom));
      expect(find.text('Todos os tipos'), findsOneWidget);
      expect(find.text('Todas as UFs'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '200 percent text');
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
  testWidgets('filters institutions through the approved exclusive status tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RecordingDirectoryRepository(FakeInstitutionDirectoryRepository());
    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Em Implantação'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.statuses, {InstitutionStatus.onboarding});

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(repository.queries.last.statuses, isEmpty);
  });

  testWidgets('starts with eleven card items and switches to eight table rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(_institutionCards(), findsNWidgets(11));
    expect(find.byKey(const Key('create-institution-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();

    expect(_institutionTableRows(), findsNWidgets(8));
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-pagination-page-size-8')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-pagination-page-size-9')), findsNothing);
  });

  testWidgets('uses compact pagination at 375 with text scaled to 200 percent', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_app(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsNothing);
    expect(find.byKey(const Key('coelo-admin-pagination-page-1')), findsNothing);
    expect(find.textContaining('Página 1 de'), findsOneWidget);
    expect(find.bySemanticsLabel('Página anterior'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Próxima página'));
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 2'), findsOneWidget);

    expect(find.bySemanticsLabel('Próxima página'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('keeps canonical pagination at 768', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsOneWidget);
    expect(find.byKey(const Key('coelo-admin-pagination-page-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps pagination fixed at the bottom while cards scroll', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final footer = find.byKey(const Key('institution-directory-pagination-footer'));
    final scroll = find.byKey(const Key('institution-directory-content-scroll'));
    expect(footer, findsOneWidget);
    final bottomBefore = tester.getBottomLeft(footer).dy;

    await tester.drag(scroll, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(footer).dy, closeTo(bottomBefore, 1));
  });

  testWidgets('keeps the final card above the fixed pagination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final scroll = find.byKey(const Key('institution-directory-content-scroll'));
    await tester.drag(scroll, const Offset(0, -5000));
    await tester.pumpAndSettle();

    final footer = find.byKey(const Key('institution-directory-pagination-footer'));
    expect(
      tester.getBottomLeft(_institutionCards().last).dy,
      lessThanOrEqualTo(tester.getTopLeft(footer).dy - CoeloSpacing.space4),
    );
  });

  testWidgets('uses the approved glass footer surface in light and dark', (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.binding.setSurfaceSize(const Size(1440, 700));
      await tester.pumpWidget(_app(brightness: brightness));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('institution-directory-pagination-footer')),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      final surface = tester.widget<Container>(
        find
            .ancestor(
              of: find.byKey(const Key('institution-directory-pagination-footer-surface')),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = surface.decoration! as BoxDecoration;
      final colors = brightness == Brightness.light
          ? CoeloTheme.light.colorScheme
          : CoeloTheme.dark.colorScheme;
      expect(
        decoration.color,
        colors.surface.withValues(alpha: brightness == Brightness.light ? 0.84 : 0.88),
      );
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('keeps the chat launcher above the fixed pagination', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [375.0, 1024.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_app(pageKey: ValueKey(width), onConversationsOpen: () {}));

      final footer = find.byKey(const Key('institution-directory-pagination-footer'));
      final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
      expect(footer, findsNothing);
      expect(launcher, findsOneWidget);

      await tester.pump();

      expect(footer, findsOneWidget);
      expect(launcher, findsNothing);

      await tester.pump();

      expect(footer, findsOneWidget);
      expect(launcher, findsOneWidget);
      expect(
        tester.getBottomLeft(launcher).dy,
        lessThanOrEqualTo(tester.getTopLeft(footer).dy - CoeloSpacing.space4),
        reason: '$width px',
      );
    }
  });

  testWidgets('reveals municipality and district filters after their parents', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-state-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SP — São Paulo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-city-filter')), findsNothing);
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-city-filter')), findsOneWidget);
    final typeRect = tester.getRect(find.byKey(const Key('institution-type-filter')));
    final cityRect = tester.getRect(find.byKey(const Key('institution-city-filter')));
    expect(cityRect.width, closeTo(typeRect.width, 1));

    expect(find.byKey(const Key('institution-district-filter')), findsNothing);

    await tester.tap(find.byKey(const Key('institution-city-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Campinas').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-district-filter')), findsOneWidget);
  });

  testWidgets('searches geographic filters ignoring case and Portuguese accents', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-state-filter')));
    await tester.pumpAndSettle();
    final stateSearch = find.byKey(const Key('institution-state-filter-search'));
    expect(stateSearch, findsOneWidget);
    await tester.enterText(stateSearch, 'sao');
    await tester.pump();
    expect(find.text('SP — São Paulo'), findsOneWidget);
    expect(find.text('AC — Acre'), findsNothing);
    await tester.tap(find.text('SP — São Paulo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-city-filter')));
    await tester.pumpAndSettle();
    final citySearch = find.byKey(const Key('institution-city-filter-search'));
    expect(citySearch, findsOneWidget);
    await tester.enterText(citySearch, 'CAMP');
    await tester.pump();
    expect(find.text('Campinas'), findsOneWidget);
    expect(find.text('São Paulo'), findsNothing);
    await tester.tap(find.text('Campinas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-district-filter')));
    await tester.pumpAndSettle();
    final districtSearch = find.byKey(const Key('institution-district-filter-search'));
    expect(districtSearch, findsOneWidget);
    await tester.enterText(districtSearch, 'cambui');
    await tester.pump();
    expect(find.text('Cambuí'), findsOneWidget);
    expect(find.text('Jardins'), findsNothing);
  });

  testWidgets('clears a geographic menu search when the menu reopens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-state-filter')));
    await tester.pumpAndSettle();
    final stateSearch = find.byKey(const Key('institution-state-filter-search'));
    await tester.enterText(stateSearch, 'sao');
    await tester.pump();
    await tester.tap(find.text('SP — São Paulo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-state-filter')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(stateSearch).controller!.text, isEmpty);
    expect(find.text('BA — Bahia'), findsOneWidget);
  });

  testWidgets(
    'uses only accessible state options and keeps their source independent of selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('institution-state-filter')));
      await tester.pumpAndSettle();
      expect(find.text('SP — São Paulo'), findsOneWidget);
      expect(find.text('AC — Acre'), findsNothing);
      expect(find.text('BA — Bahia'), findsOneWidget);

      await tester.tap(find.text('SP — São Paulo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('institution-state-filter')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('institution-state-filter-search')), 'parana');
      await tester.pump();
      expect(find.text('PR — Paraná'), findsOneWidget);
    },
  );

  testWidgets('disables the UF filter when no registered UFs are accessible', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(repository: FakeInstitutionDirectoryRepository(items: [])));
    await tester.pumpAndSettle();

    final trigger = find.byKey(const Key('institution-state-filter'));
    expect(find.text('Sem UFs cadastradas'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(trigger).onPressed, isNull);
  });

  testWidgets('keeps the UF label neutral while filter options are loading', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _PendingFilterOptionsRepository();
    addTearDown(repository.complete);
    await tester.pumpWidget(_app(repository: repository));
    await tester.pump();

    final trigger = find.byKey(const Key('institution-state-filter'));
    expect(find.text('Todas as UFs'), findsOneWidget);
    expect(find.text('Sem UFs cadastradas'), findsNothing);
    expect(tester.widget<OutlinedButton>(trigger).onPressed, isNull);

    repository.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('keeps multiselect draft open and applies it in one action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Escola'));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsOneWidget);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Colégio'));
    await tester.pump();
    expect(find.text('Aplicar'), findsOneWidget);

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('2 selecionados'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);
  });

  testWidgets('discards unapplied selections and supports local clear', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final trigger = find.byKey(const Key('institution-type-filter'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Escola'));
    await tester.pumpAndSettle();
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('Todos os tipos'), findsOneWidget);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final activeOption = find.widgetWithText(MenuItemButton, 'Escola');
    expect(
      tester
          .widget<Checkbox>(find.descendant(of: activeOption, matching: find.byType(Checkbox)))
          .value,
      isFalse,
    );
    await tester.tap(find.widgetWithText(MenuItemButton, 'Escola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar'));
    await tester.pump();
    expect(
      tester
          .widget<Checkbox>(find.descendant(of: activeOption, matching: find.byType(Checkbox)))
          .value,
      isFalse,
    );
  });

  testWidgets('uses distinct semantic backgrounds for hover and selected options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-type-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Escola'));
    await tester.pumpAndSettle();

    final row = tester.widget<MenuItemButton>(find.widgetWithText(MenuItemButton, 'Escola'));
    final checkbox = tester.widget<Checkbox>(
      find.descendant(
        of: find.widgetWithText(MenuItemButton, 'Escola'),
        matching: find.byType(Checkbox),
      ),
    );
    final colors = CoeloTheme.light.colorScheme;
    expect(row.style?.backgroundColor?.resolve({}), Colors.transparent);
    expect(row.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(row.style?.foregroundColor?.resolve({}), colors.primary);
    expect(row.style?.iconColor?.resolve({}), colors.primary);
    expect(row.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    expect(checkbox.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    expect(checkbox.splashRadius, 0);
    expect(checkbox.materialTapTargetSize, MaterialTapTargetSize.shrinkWrap);
    expect(checkbox.value, isTrue);
  });

  testWidgets('uses rounded anchored menus below their filter trigger', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final anchorFinder = find.byKey(const Key('institution-type-filter-anchor'));
    final anchor = tester.widget<MenuAnchor>(anchorFinder);
    final shape = anchor.style!.shape!.resolve({})! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(CoeloRadius.lg));

    final triggerBottom = tester.getBottomLeft(find.byKey(const Key('institution-type-filter'))).dy;
    await tester.tap(find.byKey(const Key('institution-type-filter')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.widgetWithText(MenuItemButton, 'Escola')).dy,
      greaterThanOrEqualTo(triggerBottom),
    );
  });

  testWidgets('keeps the rounded toolbar aligned at the desktop reference width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final searchTop = tester.getTopLeft(_institutionSearchField()).dy;
    final displayIconTop = tester.getTopLeft(find.byKey(const Key('institution-view-cards'))).dy;
    expect((displayIconTop - searchTop).abs(), lessThan(CoeloSpacing.space4));
  });

  testWidgets('switches to table without resetting the current search', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(_institutionSearchField(), 'aurora');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-directory-table')), findsOneWidget);
    expect(find.byKey(const Key('create-institution-banner')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('institution-table-row-demo-institution-aurora')),
        matching: find.text('Instituto Aurora'),
      ),
      findsOneWidget,
    );
    expect(find.text('Centro Horizonte'), findsNothing);
  });

  testWidgets('opens creation from the banner and editing from a table row', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var createRequested = false;
    String? editedId;

    await tester.pumpWidget(
      _app(onCreate: () => createRequested = true, onEdit: (id) => editedId = id),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('create-institution-banner')));
    final pinnedRow = find.byKey(
      const Key(
        'coelo-admin-table-pinned-row-background-'
        'institution-table-row-demo-institution-horizonte',
      ),
    );
    await tester.drag(
      find.byKey(const Key('institution-directory-content-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final pinnedTopLeft = tester.getTopLeft(pinnedRow);
    await tester.tapAt(Offset(pinnedTopLeft.dx + 100, tester.getCenter(pinnedRow).dy));

    expect(createRequested, isTrue);
    expect(editedId, 'demo-institution-horizonte');
  });

  testWidgets('keeps the approved information hierarchy in the interactive table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();

    const expectedHeaders = <String, String>{
      'institution': 'Instituição',
      'type': 'Tipo',
      'units': 'Unidades',
      'groups': 'Turmas',
      'plan': 'Plano',
      'status': 'Status',
      'email': 'E-mail',
      'phone': 'Telefone',
      'mobile': 'Celular',
      'domain': 'Domínio',
      'street': 'Logradouro',
      'number': 'Número',
      'complement': 'Complemento',
      'district': 'Bairro',
      'postal-code': 'CEP',
      'city': 'Município',
      'state': 'UF',
    };
    final headerPositions = <double>[];
    for (final entry in expectedHeaders.entries) {
      final header = find.byKey(Key('coelo-admin-table-header-${entry.key}'));
      expect(header, findsOneWidget);
      expect(find.descendant(of: header, matching: find.text(entry.value)), findsOneWidget);
      headerPositions.add(tester.getTopLeft(header).dx);
    }
    expect(headerPositions, orderedEquals([...headerPositions]..sort()));
    expect(find.text('Razão social'), findsNothing);
    expect(find.byKey(const Key('copy-domain-demo-institution-horizonte')), findsOneWidget);
    expect(find.byKey(const Key('copy-email-demo-institution-horizonte')), findsOneWidget);
    expect(find.byKey(const Key('copy-phone-demo-institution-horizonte')), findsOneWidget);
    expect(find.byKey(const Key('copy-mobile-phone-demo-institution-horizonte')), findsOneWidget);
    expect(find.text('13025-100'), findsOneWidget);

    final viewportWidth = tester
        .getSize(find.byKey(const Key('institution-directory-table-viewport')))
        .width;
    final bannerWidth = tester.getSize(find.byKey(const Key('create-institution-banner'))).width;
    final tableScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('coelo-admin-table-scroll')),
    );
    expect(bannerWidth, lessThanOrEqualTo(viewportWidth));
    expect(tableScroll.controller!.position.maxScrollExtent, greaterThan(0));

    final nameColumn = find.byKey(const Key('coelo-admin-table-header-institution'));
    final oldWidth = tester.getSize(nameColumn).width;
    await tester.drag(
      find.byKey(const Key('coelo-admin-table-resizer-indicator-institution')),
      const Offset(80, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(nameColumn).width, greaterThan(oldWidth));
  });

  testWidgets('search ignores a matching domain and keeps only matching names', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(_institutionSearchField(), 'aurora');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Instituto Aurora'), findsOneWidget);
    expect(find.text('Centro Horizonte'), findsNothing);
  });

  testWidgets('shows the approved airy information hierarchy in institution cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Criar instituição'), findsOneWidget);
    expect(find.text('Adicionar nova instituição ao sistema.'), findsNothing);
    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    final auroraCard = find.byKey(const Key('institution-card-demo-institution-aurora'));
    expect(tester.getSize(auroraCard).height, 216);
    expect(
      tester.getSize(find.byKey(const Key('institution-avatar-demo-institution-aurora'))),
      const Size.square(44),
    );
    expect(
      find.descendant(of: auroraCard, matching: find.text('Instituto Aurora Educação LTDA')),
      findsNothing,
    );
    for (final label in ['Tipo', 'Plano', 'Unidades', 'Turmas']) {
      expect(find.descendant(of: auroraCard, matching: find.text(label)), findsOneWidget);
    }
    expect(find.descendant(of: auroraCard, matching: find.text('Domínio')), findsNothing);
    expect(find.descendant(of: auroraCard, matching: find.text('aurora.coelo.me')), findsNothing);
    final location = find.descendant(of: auroraCard, matching: find.text('Jardins, São Paulo/SP'));
    final typeLabel = find.descendant(of: auroraCard, matching: find.text('Tipo'));
    expect(tester.getTopLeft(location).dy, lessThan(tester.getTopLeft(typeLabel).dy));
    final labelStyle = tester.widget<Text>(typeLabel).style!;
    expect(labelStyle.fontWeight, FontWeight.w700);
    expect(find.byKey(const Key('copy-domain-demo-institution-aurora')), findsNothing);
  });

  testWidgets('uses a compact expandable status and centered card details', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final status = find.byKey(const Key('institution-status-demo-institution-aurora'));
    expect(status, findsOneWidget);
    expect(tester.getSize(status), const Size.square(24));
    expect(find.text('Ativa'), findsNothing);
    await tester.drag(
      find.byKey(const Key('institution-directory-content-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(status));
    await tester.pumpAndSettle();

    expect(find.text('Ativa'), findsOneWidget);
    expect(tester.getSize(status).width, greaterThan(CoeloSpacing.space8));

    final typeDetail = find.byKey(
      const Key('institution-card-detail-type-demo-institution-aurora'),
    );
    final detailRow = tester.widget<Row>(
      find.descendant(of: typeDetail, matching: find.byType(Row)),
    );
    expect(detailRow.crossAxisAlignment, CrossAxisAlignment.center);
    final typeLabel = find.descendant(of: typeDetail, matching: find.text('Tipo'));
    final typeValue = find.descendant(of: typeDetail, matching: find.text('Escola'));
    expect(
      tester.getTopLeft(typeValue).dy - tester.getBottomLeft(typeLabel).dy,
      greaterThanOrEqualTo(CoeloSpacing.spaceHalf),
    );
    await gesture.removePointer();
  });

  testWidgets('copies the institutional e-mail from the table action', (tester) async {
    final clipboardCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls.add(call);
        }
        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();
    final copyEmail = find.byKey(const Key('copy-email-demo-institution-horizonte'));
    await tester.ensureVisible(copyEmail);
    await tester.pumpAndSettle();
    await tester.tap(copyEmail);
    await tester.pump();

    expect(clipboardCalls, hasLength(1));
    expect(clipboardCalls.single.arguments, {'text': 'contato@centrohorizonte.coelo.me'});
    expect(find.text('E-mail copiado.'), findsOneWidget);
  });

  testWidgets('uses transparent create and subtle orange hover surfaces', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final createSurface = find.byKey(const Key('create-institution-surface'));
    final cardSurface = find.byKey(const Key('institution-card-surface-demo-institution-aurora'));
    expect(createSurface, findsOneWidget);
    expect(cardSurface, findsOneWidget);
    final createRest = _renderedDecoration(tester, createSurface);
    expect(createRest.color, Colors.transparent);
    final createInk = tester.widget<InkWell>(
      find.descendant(of: createSurface, matching: find.byType(InkWell)),
    );
    expect(createInk.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    final createMaterial = tester.widget<Material>(
      find.descendant(of: createSurface, matching: find.byType(Material)).first,
    );
    expect(createMaterial.color, Theme.of(tester.element(createSurface)).scaffoldBackgroundColor);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(createSurface));
    await tester.pumpAndSettle();
    final colors = Theme.of(tester.element(createSurface)).colorScheme;
    final createHover = _renderedDecoration(tester, createSurface);
    expect(createHover.boxShadow!.single.color, colors.primary.withValues(alpha: 0.15));

    await tester.drag(
      find.byKey(const Key('institution-directory-content-scroll')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(cardSurface));
    await tester.pumpAndSettle();
    final cardHover = _renderedDecoration(tester, cardSurface);
    expect(cardHover.border!.top.color, colors.primary.withValues(alpha: 0.5));
    expect(cardHover.boxShadow!.single.color, colors.primary.withValues(alpha: 0.15));
    await gesture.removePointer();
  });

  testWidgets('keeps unavailable file actions hidden at every supported width', (tester) async {
    for (final width in [375.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final actions = find.byKey(const Key('institution-toolbar-actions'));
      final view = find.byKey(const Key('institution-display-toggle'));
      expect(actions, findsOneWidget);
      expect(tester.getSize(view).height, CoeloSize.touchMin);
      expect(tester.getTopRight(view).dx, lessThanOrEqualTo(width - CoeloSpacing.space4));
      expect(find.byKey(const Key('institution-files-action')), findsNothing);
      expect(find.text('Arquivos'), findsNothing);
      expect(find.text('Importar'), findsNothing);
      expect(tester.takeException(), isNull, reason: 'toolbar width $width');
    }
  });

  testWidgets('uses one card column at 375 and multiple columns at 1440', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final createCard = find.byKey(const Key('create-institution-card'));
    final firstInstitutionCard = find.byKey(const Key('institution-card-demo-institution-aurora'));
    final firstCompact = tester.getTopLeft(createCard);
    final institutionCompact = tester.getTopLeft(firstInstitutionCard);
    expect(institutionCompact.dy, greaterThan(firstCompact.dy));

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpAndSettle();

    final cardPositions = tester
        .widgetList<ConstrainedBox>(
          find.descendant(
            of: find.byKey(const Key('institution-card-grid')),
            matching: find.byType(ConstrainedBox),
          ),
        )
        .length;
    expect(cardPositions, greaterThan(2));
    expect(tester.getSize(createCard).width, lessThan(375));
  });

  testWidgets('keeps the complete table horizontally scrollable on compact widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('institution-view-table')));
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-institution-banner')), findsOneWidget);
    final tableScroll = find.byKey(const Key('coelo-admin-table-scroll'));
    expect(tableScroll, findsOneWidget);
    await tester.ensureVisible(tableScroll);
    await tester.drag(tableScroll, const Offset(-250, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the pinned institution row aligned and highlighted with its table row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();

    final row = find.byKey(
      const Key(
        'coelo-admin-table-row-background-'
        'institution-table-row-demo-institution-horizonte',
      ),
    );
    expect(
      find.byKey(const Key('institution-table-row-demo-institution-horizonte')),
      findsOneWidget,
    );
    final pinned = find.byKey(
      const Key(
        'coelo-admin-table-pinned-row-background-'
        'institution-table-row-demo-institution-horizonte',
      ),
    );
    final pinnedColumn = find.byKey(const Key('coelo-admin-table-pinned-column'));
    expect(pinned, findsOneWidget);
    expect(pinnedColumn, findsOneWidget);
    expect(tester.getTopLeft(pinned).dy, tester.getTopLeft(row).dy);
    expect(tester.getSize(pinned).height, tester.getSize(row).height);
    final table = find.byKey(const Key('institution-directory-table'));
    expect(tester.getBottomLeft(table).dy - tester.getBottomLeft(pinnedColumn).dy, 0);
    await tester.drag(
      find.byKey(const Key('institution-directory-content-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(pinned));
    await tester.pumpAndSettle();
    final pinnedDecoration = _renderedDecoration(tester, pinned);
    expect(pinnedDecoration.color, CoeloTheme.light.colorScheme.primaryContainer);
    await gesture.removePointer();

    final statusChip = tester.widget<Chip>(find.byType(Chip).first);
    expect(statusChip.side, isNot(BorderSide.none));
  });

  testWidgets('keeps table scrolling inside the page viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();

    final viewport = find.byKey(const Key('institution-directory-table-viewport'));
    expect(viewport, findsOneWidget);
    expect(tester.getSize(viewport).width, lessThanOrEqualTo(1024));
    expect(find.descendant(of: viewport, matching: find.byType(Scrollbar)), findsOneWidget);

    final scrollable = find.byKey(const Key('coelo-admin-table-scroll'));
    await tester.scrollUntilVisible(
      scrollable,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('institution-directory-content-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final before = tester
        .getTopLeft(find.byKey(const Key('coelo-admin-table-header-institution')))
        .dx;
    await tester.drag(scrollable, const Offset(-600, 0));
    await tester.pumpAndSettle();
    final after = tester
        .getTopLeft(find.byKey(const Key('coelo-admin-table-header-institution')))
        .dx;
    expect(after, lessThan(before));
  });

  testWidgets('paginates the directory in groups of eleven items', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        repository: FakeInstitutionDirectoryRepository(
          items: List.generate(
            12,
            (index) => InstitutionDirectoryItem(
              id: 'institution-$index',
              publicName: 'Instituição ${(index + 1).toString().padLeft(2, '0')}',
              tradeName: null,
              legalName: null,
              primaryDomain: null,
              status: InstitutionStatus.active,
              typeId: null,
              typeName: null,
              city: null,
              state: null,
              planId: null,
              planName: null,
              unitsCount: 0,
              groupsCount: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('coelo-admin-pagination-page-1')),
      600,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('institution-directory-content-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-pagination-page-1')), findsOneWidget);
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('coelo-admin-pagination-page-2')),
      600,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('institution-directory-content-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-pagination-page-2')), findsOneWidget);
    expect(find.text('Instituição 12'), findsOneWidget);
  });

  testWidgets('uses the same paginated records in cards and table views', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RecordingDirectoryRepository(
      FakeInstitutionDirectoryRepository(
        items: List.generate(
          11,
          (index) => InstitutionDirectoryItem(
            id: 'institution-$index',
            publicName: 'Institution ${(index + 1).toString().padLeft(2, '0')}',
            tradeName: null,
            legalName: null,
            primaryDomain: null,
            status: InstitutionStatus.active,
            typeId: null,
            typeName: null,
            city: null,
            state: null,
            planId: null,
            planName: null,
            unitsCount: 0,
            groupsCount: 0,
          ),
        ),
      ),
    );

    await tester.pumpWidget(_app(repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-institution-card')), findsOneWidget);
    for (var index = 0; index < 11; index += 1) {
      expect(find.byKey(Key('institution-card-institution-$index')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();
    for (var index = 0; index < 8; index += 1) {
      expect(find.byKey(Key('institution-table-row-institution-$index')), findsOneWidget);
    }
    expect(find.byKey(const Key('institution-table-row-institution-8')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const Key('coelo-admin-pagination-page-2')),
      600,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('institution-directory-content-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byKey(const Key('coelo-admin-pagination-page-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-2')));
    await tester.pumpAndSettle();

    expect(repository.queries.last.page, 1);
    expect(repository.queries.last.pageSize, 8);
    expect(find.byKey(const Key('institution-table-row-institution-10')), findsOneWidget);

    final requestsBeforeSwitch = repository.queries.length;
    await tester.tap(find.byKey(const Key('institution-view-cards')));
    await tester.pumpAndSettle();
    expect(repository.queries, hasLength(requestsBeforeSwitch + 1));
    expect(repository.queries.last.page, 0);
    expect(repository.queries.last.pageSize, 11);
    expect(find.byKey(const Key('institution-card-institution-10')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('coelo-admin-pagination-page-size')),
      600,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('institution-directory-content-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('coelo-admin-pagination-page-size')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50').last);
    await tester.pumpAndSettle();

    expect(repository.queries.last.page, 0);
    expect(repository.queries.last.pageSize, 50);
    expect(find.byKey(const Key('institution-card-institution-10')), findsOneWidget);
  });

  testWidgets('keeps the page-size selector for a non-empty single-page result', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        repository: FakeInstitutionDirectoryRepository(
          items: demoInstitutionDirectoryItems.take(1).toList(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsOneWidget);
  });

  testWidgets('hides pagination for empty and no-results states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var createRequested = false;

    await tester.pumpWidget(
      _app(
        repository: FakeInstitutionDirectoryRepository(items: []),
        onCreate: () => createRequested = true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsNothing);
    expect(find.byKey(const Key('institution-directory-pagination-footer')), findsNothing);
    expect(find.byKey(const Key('create-institution-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-institution-card')));
    expect(createRequested, isTrue);

    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-institution-banner')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(
        repository: FakeInstitutionDirectoryRepository(
          items: demoInstitutionDirectoryItems.take(1).toList(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsOneWidget);
    expect(find.byKey(const Key('institution-directory-pagination-footer')), findsOneWidget);

    await tester.enterText(_institutionSearchField(), 'no matches');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsNothing);
    expect(find.byKey(const Key('institution-directory-pagination-footer')), findsNothing);
    expect(find.byKey(const Key('create-institution-card')), findsOneWidget);
  });

  testWidgets('keeps creation available when loading the directory fails', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var createRequested = false;

    await tester.pumpWidget(
      _app(repository: const _FailingDirectoryRepository(), onCreate: () => createRequested = true),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível carregar as instituições. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byKey(const Key('create-institution-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-institution-card')));
    expect(createRequested, isTrue);

    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-institution-banner')), findsOneWidget);
  });

  testWidgets('hides pagination when a successful page reports zero total count', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final item = demoInstitutionDirectoryItems.first;
    await tester.pumpWidget(_app(repository: _ZeroTotalCountRepository(item)));
    await tester.pumpAndSettle();

    expect(find.text(item.publicName), findsWidgets);
    expect(find.byKey(const Key('institution-directory-pagination-footer')), findsNothing);
  });

  testWidgets('centers pagination below cards and table', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        repository: FakeInstitutionDirectoryRepository(
          items: List.generate(
            21,
            (index) => InstitutionDirectoryItem(
              id: 'centered-institution-$index',
              publicName: 'Instituição ${index + 1}',
              tradeName: null,
              legalName: null,
              primaryDomain: null,
              status: InstitutionStatus.active,
              typeId: null,
              typeName: null,
              city: null,
              state: null,
              planId: null,
              planName: null,
              unitsCount: 0,
              groupsCount: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pagination = find.byKey(const Key('coelo-admin-pagination-content'));
    expect(
      tester.getCenter(pagination).dx,
      closeTo(tester.getCenter(find.byKey(const Key('institution-card-grid'))).dx, 1),
    );

    await tester.ensureVisible(find.byKey(const Key('institution-view-table')));
    await tester.tap(find.byKey(const Key('institution-view-table')));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(pagination).dx,
      closeTo(
        tester.getCenter(find.byKey(const Key('institution-directory-table-viewport'))).dx,
        1,
      ),
    );
  });

  testWidgets('supports requested widths in light and dark themes without layout exceptions', (
    tester,
  ) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(_app(brightness: brightness));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'width $width / $brightness');
        expect(find.text('Instituições'), findsWidgets);
      }
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('exposes search semantics and reaches it by keyboard', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(_institutionSearchField()),
      isSemantics(label: 'Buscar por nome', isTextField: true),
    );
    semantics.dispose();

    final editableText = tester.state<EditableTextState>(find.byType(EditableText).first);
    for (var step = 0; step < 20 && !editableText.widget.focusNode.hasFocus; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    expect(editableText.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('Escape closes the type filter menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-type-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsNothing);
  });

  testWidgets('supports 200 percent text at all approved viewports', (tester) async {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        _app(textScaler: const TextScaler.linear(2), pageKey: ValueKey(width)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$width cards');
      expect(find.text('Instituições'), findsWidgets);
      expect(find.byKey(const Key('institution-directory-pagination-footer')), findsOneWidget);

      final tableToggle = find.byKey(const Key('institution-view-table'), skipOffstage: false);
      await tester.ensureVisible(tableToggle);
      await tester.tap(tableToggle);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$width table');
      expect(find.byKey(const Key('institution-directory-pagination-footer')), findsOneWidget);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('finishes themed card surfaces with the global transition without a local tail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ThemeTransitionDirectoryApp());
    await tester.pumpAndSettle();

    final surface = find.byKey(const Key('institution-card-surface-demo-institution-aurora'));
    final light = _renderedDecoration(tester, surface);

    await tester.tap(find.byKey(const Key('institution-theme-test-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    final dark = _renderedDecoration(tester, surface);
    expect(dark.color, CoeloTheme.dark.colorScheme.surface);
    expect(dark.border?.top.color, CoeloTheme.dark.colorScheme.outlineVariant);
    expect(dark.color, isNot(light.color));

    await tester.pump(const Duration(milliseconds: 220));
    expect(_renderedDecoration(tester, surface), dark);
  });

  testWidgets('switches themed card surfaces in one frame under reduced motion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _ThemeTransitionDirectoryApp(disableAnimations: true));
    await tester.pumpAndSettle();

    final surface = find.byKey(const Key('institution-card-surface-demo-institution-aurora'));
    await tester.tap(find.byKey(const Key('institution-theme-test-toggle')));
    await tester.pump();

    final dark = _renderedDecoration(tester, surface);
    expect(dark.color, CoeloTheme.dark.colorScheme.surface);
    expect(dark.border?.top.color, CoeloTheme.dark.colorScheme.outlineVariant);
  });
}

class _ThemeTransitionDirectoryApp extends StatefulWidget {
  const _ThemeTransitionDirectoryApp({this.disableAnimations = false});

  final bool disableAnimations;

  @override
  State<_ThemeTransitionDirectoryApp> createState() => _ThemeTransitionDirectoryAppState();
}

class _ThemeTransitionDirectoryAppState extends State<_ThemeTransitionDirectoryApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: _mode,
      themeAnimationStyle: widget.disableAnimations
          ? AnimationStyle.noAnimation
          : const AnimationStyle(duration: Duration(milliseconds: 420), curve: Curves.easeInOut),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: widget.disableAnimations),
        child: Stack(
          children: [
            child!,
            Positioned(
              right: 0,
              bottom: 0,
              child: Material(
                child: IconButton(
                  key: const Key('institution-theme-test-toggle'),
                  onPressed: () => setState(() {
                    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
                  }),
                  icon: const Icon(Icons.brightness_6_outlined),
                ),
              ),
            ),
          ],
        ),
      ),
      home: InstitutionDirectoryPage(
        repository: FakeInstitutionDirectoryRepository(),
        logout: () async => const LogoutResult.success(),
      ),
    );
  }
}

BoxDecoration _renderedDecoration(WidgetTester tester, Finder finder) {
  final widget = tester.widget<Widget>(finder);
  if (widget is Container) {
    return widget.decoration! as BoxDecoration;
  }
  final rendered = find.descendant(of: finder, matching: find.byType(Container)).first;
  return tester.widget<Container>(rendered).decoration! as BoxDecoration;
}

Finder _institutionCards() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('institution-card-demo-institution-');
  });
}

Finder _institutionTableRows() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith('institution-table-row-');
  });
}

Finder _institutionDetailRows(String level) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('institution-detail-row-$level-');
});

Finder _institutionSearchField() => find.descendant(
  of: find.byKey(const Key('institution-directory-search')),
  matching: find.byType(TextField),
);

Widget _app({
  Key? pageKey,
  Brightness brightness = Brightness.light,
  InstitutionDirectoryRepository? repository,
  TextScaler textScaler = TextScaler.noScaling,
  VoidCallback? onCreate,
  ValueChanged<String>? onEdit,
  VoidCallback? onConversationsOpen,
}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: InstitutionDirectoryPage(
      key: pageKey,
      repository: repository ?? FakeInstitutionDirectoryRepository(),
      logout: () async => const LogoutResult.success(),
      onCreate: onCreate,
      onEdit: onEdit,
      onConversationsOpen: onConversationsOpen,
    ),
  );
}

final class _ZeroTotalCountRepository implements InstitutionDirectoryRepository {
  const _ZeroTotalCountRepository(this.item);

  final InstitutionDirectoryItem item;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    return domain.InstitutionDirectoryPage(
      items: [item],
      totalCount: 0,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async {
    return InstitutionDirectoryFilterOptions.empty;
  }
}

final class _FailingDirectoryRepository implements InstitutionDirectoryRepository {
  const _FailingDirectoryRepository();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    throw Exception('offline');
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) async {
    return InstitutionDirectoryFilterOptions.empty;
  }
}

final class _PendingFilterOptionsRepository implements InstitutionDirectoryRepository {
  final _options = Completer<InstitutionDirectoryFilterOptions>();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    return domain.InstitutionDirectoryPage(
      items: const [],
      totalCount: 0,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) => _options.future;

  void complete() {
    if (!_options.isCompleted) {
      _options.complete(InstitutionDirectoryFilterOptions.empty);
    }
  }
}

final class _RecordingDirectoryRepository implements InstitutionDirectoryRepository {
  _RecordingDirectoryRepository(this._delegate);

  final InstitutionDirectoryRepository _delegate;
  final queries = <InstitutionDirectoryQuery>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) {
    queries.add(query);
    return _delegate.fetchPage(query);
  }

  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) {
    return _delegate.fetchFilterOptions(states: states, cities: cities);
  }
}
