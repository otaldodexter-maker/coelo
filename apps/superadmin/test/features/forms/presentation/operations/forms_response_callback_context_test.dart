import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('retained response callback stays invalid through A to B to A', (tester) async {
    final form = ValueNotifier('form-a');
    final api = _Api();
    final router = _router(form, api);
    addTearDown(form.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    final retained = _responseCallback(tester);

    form.value = 'form-b';
    await tester.pumpAndSettle();
    retained();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');

    // The API deliberately returns the exact same A projection again. An ID or
    // projection check alone must not reactivate the old callback.
    form.value = 'form-a';
    await tester.pumpAndSettle();
    retained();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');

    _responseCallback(tester)();
    await tester.pumpAndSettle();
    expect(find.text('form-a/response-a'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retained response callback does nothing after page disposal', (tester) async {
    final form = ValueNotifier('form-a');
    final router = _router(form, _Api());
    addTearDown(form.dispose);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    final retained = _responseCallback(tester);
    await tester.pumpWidget(const SizedBox.shrink());

    expect(retained, returnsNormally);
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(tester.takeException(), isNull);
  });
}

VoidCallback _responseCallback(WidgetTester tester) =>
    tester.widget<CoeloAdminInteractiveCard>(find.byType(CoeloAdminInteractiveCard)).onPressed!;

GoRouter _router(ValueNotifier<String> form, FormsApi api) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => ValueListenableBuilder<String>(
        valueListenable: form,
        builder: (_, formId, _) => FormsOperationsPage.responses(api: api, formId: formId),
      ),
    ),
    GoRoute(
      path: SuperadminRoutes.formResponseDetail,
      name: SuperadminRoutes.formResponseDetailName,
      builder: (_, state) => Scaffold(
        body: Text('${state.pathParameters['formId']}/${state.pathParameters['responseId']}'),
      ),
    ),
  ],
);

final class _Api implements FormsApi {
  final _pages = {
    for (final suffix in ['a', 'b'])
      'form-$suffix': FormCursorPage<FormResponseSummary>(
        items: [
          FormResponseSummary(
            id: 'response-$suffix',
            occurrenceId: 'occurrence-$suffix',
            formVersionId: 'version-$suffix',
          ),
        ],
        nextCursor: null,
      ),
  };

  @override
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query) async =>
      _pages[query.formId]!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
