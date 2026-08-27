import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the authorized projection read-only in table and cards', (tester) async {
    final api = _FormsApi(page: FormCursorPage(items: [_item], nextCursor: null));
    FormDirectoryItem? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsDirectoryPage(api: api, canManage: true, onOpen: (value) => opened = value),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pesquisa das famílias'), findsWidgets);
    expect(find.text('Programado'), findsWidgets);
    expect(find.text('Publicado'), findsNothing);
    expect(find.text('Novo formulário'), findsNothing);
    await tester.tap(find.text('Pesquisa das famílias').first);
    expect(opened?.id, 'form-1');

    await tester.tap(find.byKey(const Key('forms-directory-view-cards')));
    await tester.pumpAndSettle();
    expect(find.text('Pesquisa das famílias'), findsWidgets);
    final cards = tester.widget<Wrap>(find.byKey(const Key('forms-directory-card-grid')));
    expect(cards.spacing, CoeloSpacing.space6);
    expect(cards.runSpacing, CoeloSpacing.space6);
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
  _FormsApi({this.page, this.unauthorized = false});

  final FormCursorPage<FormDirectoryItem>? page;
  final bool unauthorized;

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async {
    if (unauthorized) {
      throw const FormApiException(FormApiFailureKind.unauthorized, 'denied');
    }
    return page ?? FormCursorPage(items: const [], nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
