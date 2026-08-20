import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads the authorized projection and keeps actions equivalent in table and cards', (
    tester,
  ) async {
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
    expect(find.text('Novo formulário'), findsOneWidget);
    await tester.tap(find.text('Pesquisa das famílias').first);
    expect(opened?.id, 'form-1');

    await tester.tap(find.byKey(const Key('forms-directory-view-cards')));
    await tester.pumpAndSettle();
    expect(find.text('Pesquisa das famílias'), findsWidgets);
  });

  testWidgets('renders fail-closed authorization and 200% text without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(body: FormsDirectoryPage(api: _FormsApi(unauthorized: true))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
