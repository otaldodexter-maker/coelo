import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final surface in FormsOperationsSurface.values) {
    for (final fails in [false, true]) {
      testWidgets('$surface rejects late ${fails ? 'failure' : 'success'} from old API', (
        tester,
      ) async {
        final oldApi = _PendingApi();
        final newApi = _PendingApi();
        await tester.pumpWidget(_page(surface, oldApi));
        await tester.pump();
        await tester.pumpWidget(_page(surface, newApi));
        newApi.pending.complete(_value(surface, 2));
        await tester.pumpAndSettle();
        expect(find.text(_message(surface, 2)), findsOneWidget);
        if (fails) {
          oldApi.pending.completeError(
            const FormApiException(FormApiFailureKind.unauthorized, 'Old context denied'),
          );
        } else {
          oldApi.pending.complete(_value(surface, 7));
        }
        await tester.pumpAndSettle();
        expect(find.text(_message(surface, 2)), findsOneWidget);
        expect(find.text(_message(surface, 7)), findsNothing);
        expect(find.text('Acesso não autorizado'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('switching surface with the same API starts the matching read', (tester) async {
    final api = _PendingApi();
    await tester.pumpWidget(_page(FormsOperationsSurface.monitor, api));
    await tester.pump();
    await tester.pumpWidget(_page(FormsOperationsSurface.responses, api));
    expect(api.calls, ['monitor', 'responses']);
    await tester.pumpWidget(const SizedBox());
    api.pending.complete(_value(FormsOperationsSurface.monitor, 2));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing required context invalidates the pending read', (tester) async {
    final api = _PendingApi();
    await tester.pumpWidget(_page(FormsOperationsSurface.monitor, api));
    await tester.pump();
    await tester.pumpWidget(MaterialApp(home: FormsOperationsPage.monitor(api: api)));
    api.pending.complete(_value(FormsOperationsSurface.monitor, 7));
    await tester.pumpAndSettle();
    expect(find.text(_message(FormsOperationsSurface.monitor, 7)), findsNothing);
    expect(find.text('Operação indisponível'), findsOneWidget);
  });

  testWidgets('disposed operations page ignores a completed read', (tester) async {
    final api = _PendingApi();
    await tester.pumpWidget(_page(FormsOperationsSurface.monitor, api));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    api.pending.complete(_value(FormsOperationsSurface.monitor, 7));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Widget _page(FormsOperationsSurface surface, FormsApi api) => MaterialApp(
  home: switch (surface) {
    FormsOperationsSurface.monitor => FormsOperationsPage.monitor(api: api, formId: 'form-1'),
    FormsOperationsSurface.responses => FormsOperationsPage.responses(api: api, formId: 'form-1'),
    FormsOperationsSurface.responseDetail => FormsOperationsPage.responseDetail(
      api: api,
      responseId: 'response-1',
    ),
    FormsOperationsSurface.files => FormsOperationsPage.files(api: api, formId: 'form-1'),
  },
);

String _message(FormsOperationsSurface surface, int count) => switch (surface) {
  FormsOperationsSurface.monitor => '$count respostas de 10 pessoas elegíveis.',
  FormsOperationsSurface.responses => '$count resposta(s) carregada(s) nesta página.',
  FormsOperationsSurface.responseDetail => '$count resposta(s) carregada(s) para consulta.',
  FormsOperationsSurface.files => '$count job(s) de arquivo carregado(s).',
};

Object _value(FormsOperationsSurface surface, int count) => switch (surface) {
  FormsOperationsSurface.monitor => FormMonitorProjection(
    eligibleCount: 10,
    respondedCount: count,
    pendingCount: 10 - count,
    isAnonymous: false,
  ),
  FormsOperationsSurface.responses => FormCursorPage<FormResponseSummary>(
    nextCursor: null,
    items: List.generate(count, (index) => _summary('response-$index')),
  ),
  FormsOperationsSurface.responseDetail => FormResponseDetail(
    summary: _summary('response-1'),
    answers: {
      for (var index = 0; index < count; index++)
        'item-$index': FormAnswer.shortText(
          itemId: 'item-$index',
          value: 'Synthetic answer $index',
        ),
    },
  ),
  FormsOperationsSurface.files => FormCursorPage<FormFileJob>(
    nextCursor: null,
    items: List.generate(
      count,
      (index) => FormFileJob(id: 'job-$index', status: FormFileJobStatus.pending, progress: 0),
    ),
  ),
};

FormResponseSummary _summary(String id) =>
    FormResponseSummary(id: id, occurrenceId: 'occurrence-1', formVersionId: 'version-1');

final class _PendingApi implements FormsApi {
  final pending = Completer<Object>();
  final calls = <String>[];
  @override
  Future<FormMonitorProjection> getMonitor(FormMonitorQuery query) async {
    calls.add('monitor');
    return await pending.future as FormMonitorProjection;
  }

  @override
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query) async {
    calls.add('responses');
    return await pending.future as FormCursorPage<FormResponseSummary>;
  }

  @override
  Future<FormResponseDetail> getResponseDetail(String responseId) async {
    calls.add('responseDetail');
    return await pending.future as FormResponseDetail;
  }

  @override
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  }) async {
    calls.add('files');
    return await pending.future as FormCursorPage<FormFileJob>;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
