import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/overview/forms_overview_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders backend counts and capability-scoped actions responsively', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsOverviewPage(api: _Api(), formId: 'form-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pesquisa das famílias'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fails closed when forms service is unavailable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FormsOverviewPage(api: null, formId: 'form-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar o formulário'), findsOneWidget);
  });
}

final class _Api implements FormsApi {
  @override
  Future<FormOverview> getOverview(String formId) async => FormOverview(
    definition: FormDefinition(
      id: formId,
      institutionId: 'institution-1',
      kind: FormKind.form,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      title: 'Pesquisa das famílias',
      managementVersion: 4,
      sections: const [],
    ),
    applicationCount: 3,
    occurrenceCount: 12,
    responseCount: 28,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
