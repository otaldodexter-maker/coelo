import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/overview/forms_overview_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/form_response_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/forms_test_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final surface in <String, Widget>{
    'editor': const FormsEditorPage(),
    'response': const FormResponsePage(),
    'test': const FormsTestPage(),
  }.entries) {
    testWidgets('${surface.key} is a static unavailable surface', (tester) async {
      await tester.pumpWidget(MaterialApp(home: surface.value));

      expect(find.textContaining('indisponível'), findsWidgets);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('directory stays read-only even when legacy callbacks are supplied', (tester) async {
    final api = _ReadOnlyFormsApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsDirectoryPage(
            api: api,
            canManage: true,
            canManageLifecycle: true,
            onCreate: () => fail('create callback must not be exposed'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Novo formulário'), findsNothing);
    expect(find.byTooltip('Ações do formulário Pesquisa'), findsNothing);
    expect(api.calls, ['listDirectory']);
  });

  testWidgets('overview exposes data without dormant action affordances', (tester) async {
    final api = _ReadOnlyFormsApi();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsOverviewPage(
            api: api,
            formId: 'form-1',
            canManageLifecycle: true,
            onEdit: () => fail('edit callback must not be exposed'),
            onTest: () => fail('test callback must not be exposed'),
            onMonitor: () => fail('monitor callback must not be exposed'),
            onResponses: () => fail('responses callback must not be exposed'),
            onFiles: () => fail('files callback must not be exposed'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in const ['Editar', 'Testar', 'Monitorar', 'Respostas', 'Arquivos']) {
      expect(find.widgetWithText(ButtonStyleButton, label), findsNothing, reason: label);
    }
    expect(find.byTooltip('Ações do formulário Pesquisa'), findsNothing);
    expect(api.calls, ['getOverview']);
  });
}

final class _ReadOnlyFormsApi implements FormsApi {
  final calls = <String>[];

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async {
    calls.add('listDirectory');
    return FormCursorPage(items: [_directoryItem], nextCursor: null);
  }

  @override
  Future<FormOverview> getOverview(String formId) async {
    calls.add('getOverview');
    return FormOverview(
      definition: _definition,
      applicationCount: 1,
      occurrenceCount: 2,
      responseCount: 3,
    );
  }

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
  managementVersion: 1,
  sections: const [],
);

final _directoryItem = FormDirectoryItem(
  id: _definition.id,
  title: _definition.title,
  kind: _definition.kind,
  status: FormStatus.draft,
  operationalStatus: FormOperationalStatus.draft,
  identityMode: _definition.identityMode,
  updatedAt: DateTime(2026, 8, 26),
  managementVersion: _definition.managementVersion,
);
