import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
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
    expect(typeLeft, lessThan(statusLeft));
    expect(statusLeft, lessThan(stateLeft));
    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.decoration?.hintText, 'Buscar por nome');
    expect(searchField.decoration?.hintText, isNot(contains('domínio')));
    expect(tester.getSize(find.byType(TextField)).width, 300);
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
    expect(find.text('AC — Acre'), findsOneWidget);
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

    final option = tester.widget<MenuItemButton>(
      find.ancestor(of: find.text('Ativa'), matching: find.byType(MenuItemButton)),
    );
    final colors = CoeloTheme.light.colorScheme;
    expect(option.style?.backgroundColor?.resolve({}), Colors.transparent);
    expect(option.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(option.style?.foregroundColor?.resolve({}), colors.primary);
    expect(option.style?.iconColor?.resolve({}), colors.primary);
    expect(option.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.ancestor(of: find.text('Ativa'), matching: find.byType(MenuItemButton)),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
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
    expect(find.text('Instituto Aurora'), findsOneWidget);
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
      'city': 'Município',
      'state': 'UF',
    };
    final headerPositions = <double>[];
    for (final entry in expectedHeaders.entries) {
      final header = find.byKey(Key('institution-column-header-${entry.key}'));
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

    final viewportWidth = tester
        .getSize(find.byKey(const Key('institution-directory-table-viewport')))
        .width;
    final bannerWidth = tester.getSize(find.byKey(const Key('create-institution-banner'))).width;
    final tableWidth = tester.getSize(find.byKey(const Key('institution-directory-table'))).width;
    expect(bannerWidth, lessThanOrEqualTo(viewportWidth));
    expect(tableWidth, greaterThan(viewportWidth));

    final nameColumn = find.byKey(const Key('institution-column-header-institution'));
    final oldWidth = tester.getSize(nameColumn).width;
    await tester.drag(
      find.byKey(const Key('institution-column-resizer-institution')),
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
    final createRest = tester.widget<AnimatedContainer>(createSurface).decoration! as BoxDecoration;
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
    final createHover =
        tester.widget<AnimatedContainer>(createSurface).decoration! as BoxDecoration;
    expect(createHover.boxShadow!.single.color, colors.primary.withValues(alpha: 0.15));

    await gesture.moveTo(tester.getCenter(cardSurface));
    await tester.pumpAndSettle();
    final cardHover = tester.widget<AnimatedContainer>(cardSurface).decoration! as BoxDecoration;
    expect(cardHover.border!.top.color, colors.primary.withValues(alpha: 0.5));
    expect(cardHover.boxShadow!.single.color, colors.primary.withValues(alpha: 0.15));
    await gesture.removePointer();
  });

  testWidgets('condenses file actions on compact layouts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-file-actions-menu')), findsOneWidget);
    expect(find.byKey(const Key('institution-import-action')), findsNothing);
    expect(find.byKey(const Key('institution-export-action')), findsNothing);
  });

  testWidgets('keeps import progress in the notification center without blocking the page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-import-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-demo-file-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-import-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-import-confirm')));
    await tester.pump();

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
    final tableScroll = find.byKey(const Key('institution-directory-table-scroll'));
    expect(tableScroll, findsOneWidget);
    await tester.ensureVisible(tableScroll);
    await tester.drag(tableScroll, const Offset(-250, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
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

    final scrollable = find.byKey(const Key('institution-directory-table-scroll'));
    final before = tester.getTopLeft(find.text('Instituição')).dx;
    await tester.drag(scrollable, const Offset(-600, 0));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.text('Instituição')).dx;
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
}

Widget _app({
  Brightness brightness = Brightness.light,
  InstitutionDirectoryRepository repository = const FakeInstitutionDirectoryRepository(),
}) {
  return MaterialApp(
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: InstitutionDirectoryPage(
      repository: repository,
      logout: () async => const LogoutResult.success(),
    ),
  );
}
