import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/responses/forms_responses_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists one row per submission and loads detail lazily', (tester) async {
    final api = _ResponsesApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsResponsesPage(api: api, formId: 'form-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.detailLoads, 0);
    expect(find.text('Ana Família'), findsOneWidget);
    await tester.tap(find.text('Ver resposta'));
    await tester.pumpAndSettle();
    expect(api.detailLoads, 1);
    expect(find.text('Muito bom'), findsOneWidget);
  });

  testWidgets('delegates detail navigation without loading the detail locally', (tester) async {
    final api = _ResponsesApi();
    FormResponseSummary? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsResponsesPage(
            api: api,
            formId: 'form-1',
            onOpenDetail: (summary) => opened = summary,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver resposta'));
    await tester.pumpAndSettle();

    expect(opened?.id, 'response-1');
    expect(api.detailLoads, 0);
    expect(find.text('Muito bom'), findsNothing);
  });

  testWidgets('anonymous submissions expose neither identity nor timestamp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsResponsesPage(api: _ResponsesApi(anonymous: true), formId: 'form-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.text('Ana Família'), findsNothing);
    expect(find.textContaining('2026'), findsNothing);
  });
}

final class _ResponsesApi implements FormsApi {
  _ResponsesApi({this.anonymous = false});
  final bool anonymous;
  int detailLoads = 0;

  FormResponseSummary get summary => FormResponseSummary(
    id: 'response-1',
    occurrenceId: 'occurrence-1',
    formVersionId: 'version-1',
    submittedAt: anonymous ? null : DateTime(2026, 8, 13, 10),
    respondentLabel: anonymous ? null : 'Ana Família',
  );

  @override
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query) async =>
      FormCursorPage(items: [summary], nextCursor: null);

  @override
  Future<FormResponseDetail> getResponseDetail(String responseId) async {
    detailLoads++;
    return FormResponseDetail(
      summary: summary,
      answers: {'item-1': FormAnswer.shortText(itemId: 'item-1', value: 'Muito bom')},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
