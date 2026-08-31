import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/development_forms_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('seeded development directory searches and paginates real fixtures', (tester) async {
    FormDirectoryItem? opened;
    final api = DevelopmentFormsApi.seeded();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsDirectoryPage(api: api, onOpen: (item) => opened = item),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminPagination), findsOneWidget);
    await tester.tap(find.text('Pesquisa anual das famílias').first);
    expect(opened?.id, 'form-family-annual-survey');

    await tester.enterText(find.byKey(const Key('forms-directory-search')), 'transporte');
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pumpAndSettle();

    expect(find.text('Enquete rápida sobre transporte'), findsWidgets);
    expect(find.text('Pesquisa anual das famílias'), findsNothing);
  });

  testWidgets('starts table-first with the canonical create banner and row metrics', (
    tester,
  ) async {
    final api = _FormsApi(page: FormCursorPage(items: [_item], nextCursor: null));
    FormDirectoryItem? opened;
    var createCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsDirectoryPage(
            api: api,
            canManage: true,
            visualMetadata: {
              _item.id: DevelopmentFormVisualMetadata(
                contextLabel: 'Unidade Centro',
                audienceLabel: 'Famílias',
                responseCount: 18,
                scheduleCount: 2,
                createdAt: DateTime(2026, 8, 1),
              ),
            },
            onCreate: () => createCount++,
            onOpen: (value) => opened = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pesquisa das famílias'), findsWidgets);
    expect(find.text('Publicado'), findsNothing);
    expect(find.text('Unidade Centro'), findsOneWidget);
    expect(find.text('Famílias'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('01/08/2026'), findsOneWidget);
    expect(find.byKey(const Key('forms-directory-create')), findsOneWidget);
    expect(find.text('Novo formulário'), findsOneWidget);
    expect(find.byKey(const Key('forms-directory-card-grid')), findsNothing);
    final table = tester.widget<CoeloAdminResizableTable<FormDirectoryItem>>(
      find.byType(CoeloAdminResizableTable<FormDirectoryItem>),
    );
    expect(table.headerHeight, 56);
    expect(table.rowHeight, 64);
    await tester.tap(find.byKey(const Key('forms-directory-create')));
    expect(createCount, 1);
    await tester.tap(find.text('Pesquisa das famílias').first);
    expect(opened?.id, 'form-1');

    await tester.tap(find.byKey(const Key('forms-directory-view-cards')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-directory-card-grid')), findsOneWidget);
    final card = tester.widget<CoeloAdminInteractiveCard>(
      find.byKey(const Key('forms-directory-card-form-1')),
    );
    expect(card.minHeight, 216);
    expect(
      find.descendant(
        of: find.byKey(const Key('forms-directory-card-form-1')),
        matching: find.bySemanticsLabel('Status: Programado'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('forms-directory-create')), findsOneWidget);
  });

  testWidgets('renders fail-closed authorization and 200% text without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: FormsDirectoryPage(
              api: _FormsApi(unauthorized: true),
              canManage: true,
              onCreate: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byKey(const Key('forms-directory-search')), findsNothing);
    expect(find.byKey(const Key('forms-directory-view-cards')), findsNothing);
    expect(find.byKey(const Key('forms-directory-create')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps canonical creation in empty no-results and failure states', (tester) async {
    Future<void> pump(_FormsApi api, {Key? key}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: FormsDirectoryPage(key: key, api: api, canManage: true, onCreate: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(_FormsApi());
    expect(find.text('Nenhum formulário disponível'), findsOneWidget);
    expect(find.byKey(const Key('forms-directory-create')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('forms-directory-search')), 'sem resultado');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado'), findsOneWidget);
    expect(find.byKey(const Key('forms-directory-create')), findsOneWidget);

    await pump(_FormsApi(failure: true), key: const Key('failure'));
    expect(find.text('Não foi possível carregar os formulários'), findsOneWidget);
    expect(find.byKey(const Key('forms-directory-create')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('uses canonical responsive insets without a duplicated local title', (tester) async {
    for (final (size, expectedInset) in [
      (const Size(375, 900), CoeloSpacing.space4),
      (const Size(768, 900), CoeloSpacing.space6),
      (const Size(1440, 900), CoeloSpacing.space10),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(body: FormsDirectoryPage(api: _FormsApi())),
        ),
      );
      await tester.pumpAndSettle();

      final inset = tester.widget<ListView>(
        find.byKey(const Key('forms-directory-content-scroll')),
      );
      expect(inset.padding, EdgeInsets.all(expectedInset));
      expect(find.text('Formulários'), findsNothing);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('keeps cursor pagination in the sticky canonical footer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsDirectoryPage(
            api: _FormsApi(
              page: FormCursorPage(items: [_item], nextCursor: 'next'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forms-directory-pagination-footer')), findsOneWidget);
    expect(find.byType(CoeloAdminPagination), findsOneWidget);
  });

  testWidgets('an older query response cannot replace the latest search', (tester) async {
    final api = _OrderedFormsApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(body: FormsDirectoryPage(api: api)),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('forms-directory-view-cards')));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('forms-directory-search')), 'novo');
    await tester.pump(const Duration(milliseconds: 351));
    expect(api.calls, 2);

    api.second.complete(
      FormCursorPage(items: [_itemWithTitle('Resultado novo')], nextCursor: null),
    );
    await tester.pump();
    expect(find.text('Resultado novo'), findsWidgets);

    api.first.complete(
      FormCursorPage(items: [_itemWithTitle('Resultado antigo')], nextCursor: null),
    );
    await tester.pump();
    expect(find.text('Resultado novo'), findsWidgets);
    expect(find.text('Resultado antigo'), findsNothing);
  });

  testWidgets('api swap clears query cursor and pending debounce before loading B', (tester) async {
    final apiA = _FormsApi(
      page: FormCursorPage(
        items: [_itemWithTitle('Formulário exclusivo A')],
        nextCursor: 'cursor-a',
      ),
    );
    final apiB = _FormsApi(
      page: FormCursorPage(items: [_itemWithTitle('Formulário exclusivo B')], nextCursor: null),
    );
    final key = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsDirectoryPage(key: key, api: apiA),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)).onNext!();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('forms-directory-search')), 'contexto A');
    tester
        .widget<CoeloAdminMultiSelectField<FormOperationalStatus>>(
          find.byType(CoeloAdminMultiSelectField<FormOperationalStatus>),
        )
        .onChanged({FormOperationalStatus.scheduled});
    tester
        .widget<CoeloDateRangeField>(find.byType(CoeloDateRangeField))
        .onChanged(DateTimeRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 31)));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsDirectoryPage(key: key, api: apiB),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(apiB.queries, hasLength(1));
    final query = apiB.queries.single;
    expect(query.search, isNull);
    expect(query.operationalStatuses, isEmpty);
    expect(query.startsOnOrAfter, isNull);
    expect(query.endsOnOrBefore, isNull);
    expect(query.cursor, isNull);
    expect(find.text('Formulário exclusivo B'), findsWidgets);
    expect(find.text('Formulário exclusivo A'), findsNothing);
    expect(
      tester
          .widget<CoeloSearchField>(find.byKey(const Key('forms-directory-search')))
          .controller
          .text,
      isEmpty,
    );
  });

  testWidgets('cards and table preserve the responsive matrix at 200 percent', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final scale in [1.0, 1.5, 2.0]) {
      for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1400);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MaterialApp(
              theme: CoeloTheme.light,
              home: Scaffold(
                body: FormsDirectoryPage(
                  key: ValueKey((width, scale)),
                  api: _FormsApi(page: FormCursorPage(items: [_item], nextCursor: null)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CoeloAdminResizableTable<FormDirectoryItem>), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('forms-directory-view-cards')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('forms-directory-card-grid')), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow at ${width}px and ${scale * 100}% text',
        );
      }
    }
  });
}

final _item = FormDirectoryItem(
  id: 'form-1',
  title: 'Pesquisa das famílias',
  kind: FormKind.form,
  status: FormStatus.published,
  operationalStatus: FormOperationalStatus.scheduled,
  identityMode: FormIdentityMode.identified,
  updatedAt: DateTime(2026, 8, 13),
  managementVersion: 2,
);

FormDirectoryItem _itemWithTitle(String title) => FormDirectoryItem(
  id: title,
  title: title,
  kind: FormKind.form,
  status: FormStatus.published,
  operationalStatus: FormOperationalStatus.scheduled,
  identityMode: FormIdentityMode.identified,
  updatedAt: DateTime(2026, 8, 13),
  managementVersion: 1,
);

final class _OrderedFormsApi implements FormsApi {
  final first = Completer<FormCursorPage<FormDirectoryItem>>();
  final second = Completer<FormCursorPage<FormDirectoryItem>>();
  int calls = 0;

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) {
    calls++;
    return calls == 1 ? first.future : second.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FormsApi implements FormsApi {
  _FormsApi({this.page, this.unauthorized = false, this.failure = false});

  final FormCursorPage<FormDirectoryItem>? page;
  final bool unauthorized;
  final bool failure;
  final queries = <FormDirectoryQuery>[];

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async {
    queries.add(query);
    if (unauthorized) {
      throw const FormApiException(FormApiFailureKind.unauthorized, 'denied');
    }
    if (failure) {
      throw const FormApiException(FormApiFailureKind.unavailable, 'offline');
    }
    return page ?? FormCursorPage(items: const [], nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
