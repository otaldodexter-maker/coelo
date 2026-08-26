import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/overview/forms_overview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('directory never exposes lifecycle mutations from local capability flags', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsDirectoryPage(
            api: _Api(),
            canManageLifecycle: true,
            canTransferCrossInstitution: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ações do formulário Pesquisa'), findsNothing);
    await tester.tap(find.byKey(const Key('forms-directory-view-cards')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ações do formulário Pesquisa'), findsNothing);
  });

  testWidgets('overview never exposes lifecycle mutations from local capability flags', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsOverviewPage(api: _Api(), formId: 'form-1', canManageLifecycle: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ações do formulário Pesquisa'), findsNothing);
  });
}

final class _Api implements FormsApi {
  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async =>
      FormCursorPage(
        items: [
          FormDirectoryItem(
            id: 'form-1',
            title: 'Pesquisa',
            kind: FormKind.form,
            status: FormStatus.published,
            operationalStatus: FormOperationalStatus.active,
            identityMode: FormIdentityMode.identified,
            updatedAt: DateTime(2026, 8, 20),
            managementVersion: 7,
          ),
        ],
        nextCursor: null,
      );

  @override
  Future<FormOverview> getOverview(String formId) async => FormOverview(
    definition: _definition,
    applicationCount: 1,
    occurrenceCount: 1,
    responseCount: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _definition = FormDefinition(
  id: 'form-1',
  institutionId: 'institution-1',
  kind: FormKind.form,
  identityMode: FormIdentityMode.identified,
  responseUnit: FormResponseUnit.person,
  title: 'Pesquisa',
  managementVersion: 7,
  sections: const [],
);
