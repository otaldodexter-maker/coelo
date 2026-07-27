import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
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
  testWidgets('starts with cards and the approved dependent filter order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Instituições'), findsWidgets);
    expect(find.text('Gerencie as instituições da plataforma.'), findsOneWidget);
    expect(find.byKey(const Key('institution-filter-toolbar')), findsOneWidget);
    expect(find.text('Todos os tipos'), findsOneWidget);
    expect(find.text('Todos os status'), findsOneWidget);
    expect(find.text('Todas as UFs'), findsOneWidget);
    expect(find.text('Todos os planos'), findsNothing);
    expect(find.byKey(const Key('institution-city-filter')), findsNothing);
    expect(find.byKey(const Key('institution-district-filter')), findsNothing);
    final typeLeft = tester.getTopLeft(find.byKey(const Key('institution-type-filter'))).dx;
    final statusLeft = tester.getTopLeft(find.byKey(const Key('institution-status-filter'))).dx;
    final stateLeft = tester.getTopLeft(find.byKey(const Key('institution-state-filter'))).dx;
    expect(
      typeLeft,
      lessThan(statusLeft),
      reason: 'type=$typeLeft status=$statusLeft state=$stateLeft',
    );
    expect(
      statusLeft,
      lessThan(stateLeft),
      reason: 'type=$typeLeft status=$statusLeft state=$stateLeft',
    );
    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.decoration?.hintText, 'Buscar por nome');
    expect(searchField.decoration?.hintText, isNot(contains('domínio')));
    expect(tester.getSize(find.byType(TextField)).width, 216);
    final searchBorder = searchField.decoration!.enabledBorder! as OutlineInputBorder;
    expect(searchBorder.borderRadius.topLeft.x, CoeloRadius.full);
    expect(find.text('Importar instituições'), findsNothing);
    expect(find.byKey(const Key('create-institution-card')), findsOneWidget);
    expect(find.text('Instituto Aurora'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);

    await tester.tap(find.byKey(const Key('create-institution-card')));
    await tester.pumpAndSettle();

    expect(find.text('O cadastro de instituições será implementado em breve.'), findsOneWidget);
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
    expect(find.text('PR — Paraná'), findsOneWidget);
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
      expect(find.text('PR — Paraná'), findsOneWidget);
      expect(find.text('AC — Acre'), findsNothing);
      expect(find.text('RJ — Rio de Janeiro'), findsNothing);
      expect(
        tester.getTopLeft(find.text('SP — São Paulo')).dy,
        lessThan(tester.getTopLeft(find.text('PR — Paraná')).dy),
      );

      await tester.tap(find.text('SP — São Paulo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('institution-state-filter')));
      await tester.pumpAndSettle();

      expect(find.text('PR — Paraná'), findsOneWidget);
    },
  );

  testWidgets('disables the UF filter when no registered UFs are accessible', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(repository: const FakeInstitutionDirectoryRepository(items: [])));
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

    await tester.tap(find.byKey(const Key('institution-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativa'));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsOneWidget);
    await tester.tap(find.text('Em implantação'));
    await tester.pump();
    expect(find.text('Aplicar'), findsOneWidget);

    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('2 selecionados'), findsOneWidget);
    expect(find.text('Limpar filtros'), findsOneWidget);
    expect(find.text('Instituto Aurora'), findsOneWidget);
    expect(find.text('Centro Horizonte'), findsOneWidget);
  });

  testWidgets('discards unapplied selections and supports local clear', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final trigger = find.byKey(const Key('institution-status-filter'));
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativa'));
    await tester.pumpAndSettle();
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    expect(find.text('Todos os status'), findsOneWidget);

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    final activeOption = find.ancestor(
      of: find.text('Ativa'),
      matching: find.byType(MenuItemButton),
    );
    expect(
      tester
          .widget<Checkbox>(find.descendant(of: activeOption, matching: find.byType(Checkbox)))
          .value,
      isFalse,
    );
    await tester.tap(find.text('Ativa'));
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

    await tester.tap(find.byKey(const Key('institution-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativa'));
    await tester.pumpAndSettle();

    final row = tester.widget<MenuItemButton>(
      find.ancestor(of: find.text('Ativa'), matching: find.byType(MenuItemButton)),
    );
    final checkbox = tester.widget<Checkbox>(
      find.descendant(
        of: find.ancestor(of: find.text('Ativa'), matching: find.byType(MenuItemButton)),
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

    final anchorFinder = find.byKey(const Key('institution-status-filter-anchor'));
    final anchor = tester.widget<MenuAnchor>(anchorFinder);
    final shape = anchor.style!.shape!.resolve({})! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(CoeloRadius.lg));

    final triggerBottom = tester
        .getBottomLeft(find.byKey(const Key('institution-status-filter')))
        .dy;
    await tester.tap(find.byKey(const Key('institution-status-filter')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Rascunho')).dy, greaterThanOrEqualTo(triggerBottom));
  });

  testWidgets('keeps the rounded toolbar aligned at the desktop reference width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final searchTop = tester.getTopLeft(find.byType(TextField)).dy;
    final displayIconTop = tester.getTopLeft(find.byKey(const Key('institution-view-cards'))).dy;
    expect((displayIconTop - searchTop).abs(), lessThan(CoeloSpacing.space4));
  });

  testWidgets('switches to table without resetting the current search', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'aurora');
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
      'groups': 'Grupos',
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
    expect(find.byKey(const Key('copy-domain-demo-institution-aurora')), findsOneWidget);
    expect(find.byKey(const Key('copy-email-demo-institution-aurora')), findsOneWidget);
    expect(find.byKey(const Key('copy-phone-demo-institution-aurora')), findsOneWidget);
    expect(find.byKey(const Key('copy-mobile-phone-demo-institution-aurora')), findsOneWidget);
    expect(find.text('01310-100'), findsOneWidget);

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
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(nameColumn).width, greaterThan(oldWidth));
  });

  testWidgets('search ignores a matching domain and keeps only matching names', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'aurora');
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
    expect(find.text('Adicionar nova instituição ao sistema.'), findsOneWidget);
    expect(find.byKey(const Key('create-institution-dashed-border')), findsOneWidget);
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
    for (final label in ['Tipo', 'Plano', 'Unidades', 'Grupos (Turmas)']) {
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
    final copyEmail = find.byKey(const Key('copy-email-demo-institution-aurora'));
    await tester.ensureVisible(copyEmail);
    await tester.pumpAndSettle();
    await tester.tap(copyEmail);
    await tester.pump();

    expect(clipboardCalls, hasLength(1));
    expect(clipboardCalls.single.arguments, {'text': 'contato@aurora.coelo.me'});
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

    await gesture.moveTo(tester.getCenter(cardSurface));
    await tester.pumpAndSettle();
    final cardHover = _renderedDecoration(tester, cardSurface);
    expect(cardHover.border!.top.color, colors.primary.withValues(alpha: 0.5));
    expect(cardHover.boxShadow!.single.color, colors.primary.withValues(alpha: 0.15));
    await gesture.removePointer();
  });

  testWidgets('places the files action in the toolbar on compact layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final filesAction = find.byKey(const Key('institution-files-action'));
    expect(filesAction, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('institution-filter-toolbar')),
        matching: filesAction,
      ),
      findsOneWidget,
    );
    final shell = tester.widget<SuperadminShell>(find.byType(SuperadminShell));
    expect(shell.actions, isEmpty);
    expect(shell.compactActions, isEmpty);
    expect(find.byKey(const Key('institution-import-action')), findsNothing);
    expect(find.byKey(const Key('institution-export-action')), findsNothing);
  });

  testWidgets('keeps view and file controls grouped at the responsive trailing edge', (
    tester,
  ) async {
    for (final width in [375.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final actions = find.byKey(const Key('institution-toolbar-actions'));
      final view = find.byKey(const Key('institution-display-toggle'));
      final files = find.byKey(const Key('institution-files-action'));
      expect(actions, findsOneWidget);
      expect(tester.getSize(view).height, CoeloSize.touchMin);
      expect(tester.getTopRight(files).dx, lessThanOrEqualTo(width - CoeloSpacing.space4));
      expect(tester.getTopLeft(files).dx, greaterThan(tester.getTopLeft(view).dx));
      expect(tester.takeException(), isNull, reason: 'toolbar width $width');
    }
  });

  testWidgets('keeps the compact files submenu inset on a narrowed desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    final menuItem = tester.getRect(find.byKey(const Key('institution-files-import')));
    expect(menuItem.right, lessThanOrEqualTo(1320 - CoeloSpacing.space4));
  });

  testWidgets('keeps import progress in the notification center without blocking the page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-files-import')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-demo-file-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-import-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-import-confirm')));
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const Key('superadmin-transient-notice')), findsOneWidget);

    expect(find.byKey(const Key('institution-filter-toolbar')), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();
    expect(find.textContaining('%'), findsOneWidget);
    expect(find.text('instituicoes-julho.xlsx'), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-activity-close')));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 2400));
    expect(
      find.descendant(
        of: find.byKey(const Key('superadmin-notification-badge')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('24 importadas, 2 rejeitadas'), findsOneWidget);
  });

  testWidgets('uses one card column at 375 and multiple columns at 1440', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final createCard = find.byKey(const Key('create-institution-card'));
    final firstInstitutionCard = find.byKey(
      const Key('institution-card-demo-institution-horizonte'),
    );
    final firstCompact = tester.getTopLeft(createCard);
    final institutionCompact = tester.getTopLeft(firstInstitutionCard);
    expect(institutionCompact.dy, greaterThan(firstCompact.dy));

    await tester.binding.setSurfaceSize(const Size(1440, 900));
    await tester.pumpAndSettle();

    final firstLarge = tester.getTopLeft(createCard);
    final institutionLarge = tester.getTopLeft(firstInstitutionCard);
    expect((institutionLarge.dy - firstLarge.dy).abs(), lessThan(2));
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
        'institution-table-row-demo-institution-aurora',
      ),
    );
    expect(find.byKey(const Key('institution-table-row-demo-institution-aurora')), findsOneWidget);
    final pinned = find.byKey(
      const Key(
        'coelo-admin-table-pinned-row-background-'
        'institution-table-row-demo-institution-aurora',
      ),
    );
    final pinnedColumn = find.byKey(const Key('coelo-admin-table-pinned-column'));
    expect(pinned, findsOneWidget);
    expect(pinnedColumn, findsOneWidget);
    expect(tester.getTopLeft(pinned).dy, tester.getTopLeft(row).dy);
    expect(tester.getSize(pinned).height, tester.getSize(row).height);
    final table = find.byKey(const Key('institution-directory-table'));
    expect(
      tester.getBottomLeft(table).dy - tester.getBottomLeft(pinnedColumn).dy,
      CoeloSpacing.space3,
    );

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
    expect(find.byType(Scrollbar), findsOneWidget);

    final scrollable = find.byKey(const Key('coelo-admin-table-scroll'));
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

  testWidgets('paginates the directory in groups of twenty items', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        repository: FakeInstitutionDirectoryRepository(
          items: List.generate(
            21,
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
    expect(find.text('Página 1 de 2'), findsOneWidget);
    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Página 2 de 2'),
      600,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('institution-directory-content-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Página 2 de 2'), findsOneWidget);
    expect(find.text('Instituição 21'), findsOneWidget);
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
      tester.getSemantics(find.byType(TextField).first),
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

  testWidgets('Escape closes the status filter menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-status-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Aplicar'), findsNothing);
  });

  testWidgets('supports 200 percent text at all approved viewports', (tester) async {
    final widthsWithLayoutExceptions = <double>[];
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(_app(textScaler: const TextScaler.linear(2)));
      await tester.pumpAndSettle();

      if (tester.takeException() != null) {
        widthsWithLayoutExceptions.add(width);
      }
      expect(find.text('Instituições'), findsWidgets);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
    expect(widthsWithLayoutExceptions, isEmpty);
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
        repository: const FakeInstitutionDirectoryRepository(),
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

Widget _app({
  Brightness brightness = Brightness.light,
  InstitutionDirectoryRepository repository = const FakeInstitutionDirectoryRepository(),
  TextScaler textScaler = TextScaler.noScaling,
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
      repository: repository,
      logout: () async => const LogoutResult.success(),
    ),
  );
}

final class _PendingFilterOptionsRepository implements InstitutionDirectoryRepository {
  final _options = Completer<InstitutionDirectoryFilterOptions>();

  @override
  Future<domain.InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) async {
    return domain.InstitutionDirectoryPage(items: const [], totalCount: 0, page: query.page);
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
