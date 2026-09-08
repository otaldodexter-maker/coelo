import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/data/forms_file_jobs_reader.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final generate = find.byKey(const Key('forms-xlsx-request'));

  testWidgets('authorized files context generates whole-form XLSX once and reloads jobs', (
    tester,
  ) async {
    final pending = Completer<FormFileJob>();
    final api = _Api()..save = (_) => pending.future;
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    expect(api.reads, ['form-a']);
    expect(api.legacyReads, 0);
    final retained = tester.widget<FilledButton>(generate).onPressed!;
    retained();
    retained();
    await tester.pump();
    expect(api.commands, hasLength(1));
    final command = api.commands.single;
    expect(command.expectedVersion, 7);
    expect(
      command.requestId,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
    expect(command.payload.formId, 'form-a');
    expect(command.payload.kind, FormExportKind.xlsx);
    expect(command.payload.occurrenceId, isNull);
    expect(command.payload.justification, isNull);
    expect(tester.widget<FilledButton>(generate).onPressed, isNull);
    pending.complete(_job);
    await tester.pumpAndSettle();
    expect(api.reads, ['form-a', 'form-a']);
    expect(api.cursors.last, isNull);
    expect(
      find.text('Solicitação de XLSX recebida. Acompanhe o processamento na lista de arquivos.'),
      findsOneWidget,
    );
    expect(find.text('Exportação job-confirmed'), findsOneWidget);
    expect(find.text('Baixar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ambiguous failure retries the same immutable command and observed version', (
    tester,
  ) async {
    final api = _Api();
    api.save = (_) async {
      if (api.commands.length == 1) throw StateError('Ambiguous private transport failure');
      return _job;
    };
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(find.textContaining('private transport'), findsNothing);
    expect(find.text('Tentar novamente a solicitação'), findsOneWidget);
    api.version = 9;
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(2));
    expect(api.commands.last, same(api.commands.first));
    expect(api.commands.last.expectedVersion, 7);
    expect(api.reads, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflict requires refresh and a separate new export intention', (tester) async {
    final api = _Api();
    api.save = (_) async {
      if (api.commands.length == 1) {
        throw const FormApiException(FormApiFailureKind.conflict, 'changed');
      }
      return _job;
    };
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    final oldAction = tester.widget<FilledButton>(generate).onPressed!;
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(generate).onPressed, isNull);
    oldAction();
    expect(api.commands, hasLength(1));
    api.version = 8;
    await tester.tap(find.text('Atualizar formulário'));
    await tester.pumpAndSettle();
    expect(api.reads, hasLength(2));
    expect(api.commands, hasLength(1));
    oldAction();
    expect(api.commands, hasLength(1));
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(api.commands, hasLength(2));
    expect(api.commands.last.requestId, isNot(api.commands.first.requestId));
    expect(api.commands.last.expectedVersion, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend export denial clears authorized jobs and disables retained actions', (
    tester,
  ) async {
    final api = _Api()..jobs = [_job];
    api.save = (_) async =>
        throw const FormApiException(FormApiFailureKind.unauthorized, 'private denial');
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    final retained = tester.widget<FilledButton>(generate).onPressed!;
    retained();
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.text('Exportação job-confirmed'), findsNothing);
    expect(generate, findsNothing);
    retained();
    expect(api.commands, hasLength(1));
    expect(api.reads, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepted export survives a failed jobs reload without submitting again', (
    tester,
  ) async {
    final api = _Api();
    api.save = (_) async {
      api.readFailure = const FormApiException(FormApiFailureKind.unavailable, 'reload failed');
      return _job;
    };
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    await tester.tap(generate);
    await tester.pumpAndSettle();
    expect(
      find.text('Solicitação de XLSX recebida. Acompanhe o processamento na lista de arquivos.'),
      findsOneWidget,
    );
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(api.commands, hasLength(1));
    api.readFailure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Exportação job-confirmed'), findsOneWidget);
    expect(api.commands, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a legacy jobs reader cannot enable export or invoke overview', (tester) async {
    final api = _LegacyApi();
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    expect(api.reads, 1);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Exportar respostas em XLSX'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final invalid in ['form', 'version', 'denied']) {
    testWidgets('an invalid $invalid files context cannot enable export', (tester) async {
      final api = _Api();
      if (invalid == 'form') api.contextForm = 'form-b';
      if (invalid == 'version') api.version = 0;
      if (invalid == 'denied') {
        api.readFailure = const FormApiException(FormApiFailureKind.unauthorized, 'denied');
      }
      await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
      expect(generate, findsNothing);
      expect(api.commands, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final replacement in ['form', 'api', 'surface', 'dispose']) {
    for (final lateError in [false, true]) {
      testWidgets(
        'late export ${lateError ? 'failure' : 'success'} is ignored after $replacement replacement',
        (tester) async {
          final pending = Completer<FormFileJob>();
          final api = _Api()..save = (_) => pending.future;
          final nextApi = _Api();
          await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
          final retained = tester.widget<FilledButton>(generate).onPressed!;
          retained();
          await tester.pump();
          final next = switch (replacement) {
            'form' => FormsOperationsPage.files(api: api, formId: 'form-b'),
            'api' => FormsOperationsPage.files(api: nextApi, formId: 'form-a'),
            'surface' => FormsOperationsPage.responses(api: api, formId: 'form-a'),
            _ => const SizedBox.shrink(),
          };
          await _pump(tester, next);
          final before = api.reads.length;
          retained();
          expect(api.commands, hasLength(1));
          if (lateError) {
            pending.completeError(
              const FormApiException(FormApiFailureKind.unauthorized, 'old denial'),
            );
          } else {
            pending.complete(_job);
          }
          await tester.pumpAndSettle();
          expect(api.reads.length, before);
          expect(
            find.text(
              'Solicitação de XLSX recebida. Acompanhe o processamento na lista de arquivos.',
            ),
            findsNothing,
          );
          expect(find.text('Acesso não autorizado'), findsNothing);
          expect(nextApi.commands, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(body: page),
    ),
  );
  await tester.pumpAndSettle();
}

const _job = FormFileJob(id: 'job-confirmed', status: FormFileJobStatus.pending, progress: 0);

final class _Api implements FormsApi, FormsFileJobsReader {
  int version = 7;
  int legacyReads = 0;
  String? contextForm;
  Object? readFailure;
  List<FormFileJob> jobs = [];
  final reads = <String>[];
  final cursors = <String?>[];
  final commands = <FormCommand<FormExportPayload>>[];
  Future<FormFileJob> Function(FormCommand<FormExportPayload>) save = (_) async => _job;

  @override
  Future<FormsFileJobsContext> listFileJobsContext({
    required String formId,
    String? cursor,
    int limit = 25,
  }) async {
    reads.add(formId);
    cursors.add(cursor);
    if (readFailure case final failure?) throw failure;
    return FormsFileJobsContext(
      formId: contextForm ?? formId,
      managementVersion: version,
      page: FormCursorPage(items: List.of(jobs), nextCursor: null),
    );
  }

  @override
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  }) async {
    legacyReads++;
    return FormCursorPage(items: [], nextCursor: null);
  }

  @override
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query) async =>
      FormCursorPage(items: [], nextCursor: null);

  @override
  Future<FormFileJob> requestExport(FormCommand<FormExportPayload> command) async {
    commands.add(command);
    final job = await save(command);
    jobs = [job];
    return job;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _LegacyApi implements FormsApi {
  int reads = 0;
  @override
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  }) async {
    reads++;
    return FormCursorPage(items: [], nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
