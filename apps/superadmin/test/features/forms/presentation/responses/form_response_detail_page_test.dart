import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/responses/form_response_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps anonymous response identity and correlation data redacted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormResponseDetailPage(api: _DetailApi(anonymous: true), responseId: 'response-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.textContaining('Identidade, horário e ordem'), findsOneWidget);
    expect(find.text('Ana Família'), findsNothing);
    expect(find.textContaining('2026'), findsNothing);
    expect(find.text('Sim'), findsOneWidget);
  });

  testWidgets('fails closed when the backend denies response access', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormResponseDetailPage(api: _DetailApi(denied: true), responseId: 'response-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.text('Resposta anônima'), findsNothing);
  });

  testWidgets('delegates protected media opening by opaque asset id without exposing it', (
    tester,
  ) async {
    String? openedAssetId;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormResponseDetailPage(
            api: _DetailApi(withAsset: true),
            responseId: 'response-1',
            onOpenAsset: (assetId) => openedAssetId = assetId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ver foto 1'), findsOneWidget);
    expect(find.textContaining('asset-1'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);

    await tester.tap(find.text('Ver foto 1'));

    expect(openedAssetId, 'asset-1');
  });
}

final class _DetailApi implements FormsApi {
  _DetailApi({this.anonymous = false, this.denied = false, this.withAsset = false});

  final bool anonymous;
  final bool denied;
  final bool withAsset;

  @override
  Future<FormResponseDetail> getResponseDetail(String responseId) async {
    if (denied) {
      throw const FormApiException(FormApiFailureKind.unauthorized, 'Sem permissão.');
    }
    return FormResponseDetail(
      summary: FormResponseSummary(
        id: responseId,
        occurrenceId: 'occurrence-1',
        formVersionId: 'version-1',
        submittedAt: anonymous ? null : DateTime(2026, 8, 13, 10),
        respondentLabel: anonymous ? null : 'Ana Família',
      ),
      answers: <String, FormAnswer>{
        'item-1': withAsset
            ? FormAnswer.photo(itemId: 'item-1', assetIds: const ['asset-1'])
            : FormAnswer.yesNo(itemId: 'item-1', value: true),
      },
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
