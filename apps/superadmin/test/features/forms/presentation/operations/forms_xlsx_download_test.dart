import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/data/form_export_download_resolver.dart';
import 'package:coelo_superadmin/features/forms/data/forms_file_jobs_reader.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _url = 'https://media.example.test/export?ticket=synthetic-private';
final _now = DateTime.utc(2026, 9, 8, 12);
final _download = find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == 'Baixar exportação $_id',
);

void main() {
  testWidgets('explicit download reauthorizes once, transfers and never exposes raw path', (
    tester,
  ) async {
    final gateway = _Gateway();
    final authorization = Completer<Object?>();
    final transfer = Completer<bool>();
    gateway.read = () => authorization.future;
    final urls = <String>[];
    final resolver = _resolver(gateway);
    await _pump(
      tester,
      FormsOperationsPage.files(
        api: _Api(),
        formId: 'form-a',
        downloadResolver: resolver,
        openDownloadUrl: (url) {
          urls.add(url);
          return transfer.future;
        },
      ),
    );
    expect(gateway.calls, 0);
    final action = tester.widget<IconButton>(_download).onPressed!;
    action();
    action();
    await tester.pump();
    expect(gateway.calls, 1);
    expect(tester.widget<IconButton>(_download).onPressed, isNull);
    authorization.complete(_ticket());
    await tester.pump();
    expect(urls, [_url]);
    expect(tester.widget<IconButton>(_download).onPressed, isNull);
    expect(find.textContaining('synthetic-private'), findsNothing);
    expect(find.textContaining('forbidden-raw-path'), findsNothing);
    transfer.complete(true);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(_download).onPressed, isNotNull);
    expect(find.text('Download solicitado ao navegador.'), findsOneWidget);
    expect(gateway.calls, 1);
  });

  for (final missing in ['resolver', 'launcher']) {
    testWidgets('missing $missing leaves download unavailable', (tester) async {
      final gateway = _Gateway();
      await _pump(
        tester,
        FormsOperationsPage.files(
          api: _Api(),
          formId: 'form-a',
          downloadResolver: missing == 'resolver' ? null : _resolver(gateway),
          openDownloadUrl: missing == 'launcher' ? null : (_) async => true,
        ),
      );
      expect(tester.widget<IconButton>(_download).onPressed, isNull);
      expect(gateway.calls, 0);
    });
  }

  for (final job in [
    const FormFileJob(id: _id, status: FormFileJobStatus.succeeded, progress: 1),
    const FormFileJob(
      id: _id,
      status: FormFileJobStatus.partial,
      progress: 1,
      downloadAvailable: true,
    ),
    const FormFileJob(
      id: _id,
      status: FormFileJobStatus.expired,
      progress: 1,
      downloadAvailable: true,
    ),
    const FormFileJob(
      id: _id,
      status: FormFileJobStatus.processing,
      progress: .5,
      downloadAvailable: true,
    ),
  ]) {
    testWidgets('job ${job.status.name}/${job.downloadAvailable} cannot authorize', (tester) async {
      final gateway = _Gateway();
      await _pump(
        tester,
        FormsOperationsPage.files(
          api: _Api(job: job),
          formId: 'form-a',
          downloadResolver: _resolver(gateway),
          openDownloadUrl: (_) async => true,
        ),
      );
      if (_download.evaluate().isNotEmpty) {
        expect(tester.widget<IconButton>(_download).onPressed, isNull);
      }
      expect(gateway.calls, 0);
    });
  }

  for (final failure in [
    'denied',
    'wrong-id',
    'expired',
    'session',
    'launcher-false',
    'launcher-throws',
  ]) {
    testWidgets('$failure is contained and explicit retry reauthorizes', (tester) async {
      final session = MediaSession();
      final gateway = _Gateway();
      var failed = true;
      var transfers = 0;
      gateway.read = () async {
        if (!failed) return _ticket();
        if (failure == 'denied') throw StateError('private denial $_url');
        if (failure == 'wrong-id') {
          return {..._ticket(), 'job_id': '22222222-2222-4222-8222-222222222222'};
        }
        if (failure == 'expired') return {..._ticket(), 'expires_at': _now.toIso8601String()};
        if (failure == 'session') await session.invalidate();
        return _ticket();
      };
      await _pump(
        tester,
        FormsOperationsPage.files(
          api: _Api(),
          formId: 'form-a',
          downloadResolver: _resolver(gateway, session: session),
          openDownloadUrl: (_) async {
            transfers++;
            if (failed && failure == 'launcher-throws') throw StateError(_url);
            return !(failed && failure == 'launcher-false');
          },
        ),
      );
      await tester.tap(_download);
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível iniciar o download. Tente novamente.'), findsOneWidget);
      expect(find.textContaining('synthetic-private'), findsNothing);
      expect(transfers, failure.startsWith('launcher') ? 1 : 0);
      expect(tester.takeException(), isNull);
      failed = false;
      await tester.tap(_download);
      await tester.pumpAndSettle();
      if (failure == 'session') {
        expect(transfers, 0);
        expect(gateway.calls, 1);
      } else {
        expect(gateway.calls, 2);
        expect(find.text('Download solicitado ao navegador.'), findsOneWidget);
      }
    });
  }

  for (final change in ['form', 'api', 'resolver', 'launcher', 'surface', 'state', 'dispose']) {
    testWidgets('late authorization after $change cannot transfer', (tester) async {
      final pending = Completer<Object?>();
      final gateway = _Gateway()..read = () => pending.future;
      final api = _Api();
      final resolver = _resolver(gateway);
      var transfers = 0;
      Future<bool> launch(String _) async {
        transfers++;
        return true;
      }

      await _pump(
        tester,
        FormsOperationsPage.files(
          api: api,
          formId: 'form-a',
          downloadResolver: resolver,
          openDownloadUrl: launch,
        ),
      );
      final retained = tester.widget<IconButton>(_download).onPressed!;
      await tester.tap(_download);
      await tester.pump();
      await _pump(tester, switch (change) {
        'dispose' => const SizedBox(),
        'surface' => FormsOperationsPage.responses(api: api, formId: 'form-a'),
        _ => FormsOperationsPage.files(
          api: change == 'api' ? _Api() : api,
          formId: change == 'form' ? 'form-b' : 'form-a',
          downloadResolver: change == 'resolver' ? _resolver(_Gateway()) : resolver,
          openDownloadUrl: change == 'launcher'
              ? (_) async {
                  transfers++;
                  return true;
                }
              : launch,
          state: change == 'state'
              ? FormsOperationsState.unauthorized
              : FormsOperationsState.content,
        ),
      });
      retained();
      pending.complete(_ticket());
      await tester.pumpAndSettle();
      expect(transfers, 0);
      expect(gateway.calls, 1);
      expect(find.text('Download solicitado ao navegador.'), findsNothing);
      if (change == 'state') expect(find.text('Acesso não autorizado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('old pagination cannot send its cursor to replacement form', (tester) async {
    final api = _Api()..nextCursor = 'cursor-form-a';
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    final next = tester
        .widget<OutlinedButton>(find.byKey(const Key('forms-cursor-next')))
        .onPressed!;
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-b'));
    next();
    await tester.pumpAndSettle();
    expect(api.reads, ['form-a', 'form-b']);
    expect(api.cursors, [null, null]);
  });

  testWidgets('pagination from an earlier visit cannot advance after A B A', (tester) async {
    final api = _Api();
    final cachedPage = FormCursorPage(items: [api.job], nextCursor: 'old-cursor');
    api.pending = Future.value(cachedPage);
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    final next = tester
        .widget<OutlinedButton>(find.byKey(const Key('forms-cursor-next')))
        .onPressed!;
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-b'));
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    next();
    await tester.pumpAndSettle();
    expect(api.reads, ['form-a', 'form-b', 'form-a']);
    expect(api.cursors, [null, null, null]);
    await tester.tap(find.byKey(const Key('forms-cursor-next')));
    await tester.pumpAndSettle();
    final previous = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Anterior'))
        .onPressed!;
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-b'));
    previous();
    await tester.pumpAndSettle();
    expect(api.reads, ['form-a', 'form-b', 'form-a', 'form-a', 'form-b']);
    expect(find.text('Página 1'), findsOneWidget);
  });

  for (final completeWithError in [false, true]) {
    testWidgets(
      'late transfer ${completeWithError ? 'failure' : 'success'} has no effect after callback replacement',
      (tester) async {
        final pending = Completer<bool>();
        final api = _Api();
        final gateway = _Gateway();
        final resolver = _resolver(gateway);
        var newCalls = 0;
        await _pump(
          tester,
          FormsOperationsPage.files(
            api: api,
            formId: 'form-a',
            downloadResolver: resolver,
            openDownloadUrl: (_) => pending.future,
          ),
        );
        await tester.tap(_download);
        await tester.pump();
        await _pump(
          tester,
          FormsOperationsPage.files(
            api: api,
            formId: 'form-a',
            downloadResolver: resolver,
            openDownloadUrl: (_) async {
              newCalls++;
              return true;
            },
          ),
        );
        if (completeWithError) {
          pending.completeError(StateError(_url));
        } else {
          pending.complete(true);
        }
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('forms-xlsx-download-feedback')), findsNothing);
        expect(newCalls, 0);
        await tester.tap(_download);
        await tester.pumpAndSettle();
        expect(newCalls, 1);
        expect(gateway.calls, 2);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('external unauthorized state blocks initial read until explicitly released', (
    tester,
  ) async {
    final api = _Api();
    await _pump(
      tester,
      FormsOperationsPage.files(
        api: api,
        formId: 'form-a',
        state: FormsOperationsState.unauthorized,
      ),
    );
    expect(api.reads, isEmpty);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    expect(api.reads, ['form-a']);
    expect(_download, findsOneWidget);
  });

  testWidgets('late export cannot reopen externally unauthorized state', (tester) async {
    final api = _ExportApi();
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    await tester.tap(find.byKey(const Key('forms-xlsx-request')));
    await tester.pump();
    await _pump(
      tester,
      FormsOperationsPage.files(
        api: api,
        formId: 'form-a',
        state: FormsOperationsState.unauthorized,
      ),
    );
    api.saved.complete(const FormFileJob(id: _id, status: FormFileJobStatus.pending, progress: 0));
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byKey(const Key('forms-xlsx-request')), findsNothing);
    expect(api.reads, 1);
  });

  testWidgets('generating XLSX never automatically authorizes or opens a ready job', (
    tester,
  ) async {
    final api = _ExportApi();
    final gateway = _Gateway();
    var transfers = 0;
    await _pump(
      tester,
      FormsOperationsPage.files(
        api: api,
        formId: 'form-a',
        downloadResolver: _resolver(gateway),
        openDownloadUrl: (_) async {
          transfers++;
          return true;
        },
      ),
    );
    await tester.tap(find.byKey(const Key('forms-xlsx-request')));
    await tester.pump();
    api.saved.complete(
      const FormFileJob(
        id: _id,
        status: FormFileJobStatus.succeeded,
        progress: 1,
        downloadAvailable: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(api.reads, 2);
    expect(tester.widget<IconButton>(_download).onPressed, isNotNull);
    expect(gateway.calls, 0);
    expect(transfers, 0);
    await tester.tap(_download);
    await tester.pumpAndSettle();
    expect(gateway.calls, 1);
    expect(transfers, 1);
  });

  testWidgets('late load cannot reopen externally unauthorized state', (tester) async {
    final pending = Completer<FormCursorPage<FormFileJob>>();
    final api = _Api()..pending = pending.future;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: FormsOperationsPage.files(api: api, formId: 'form-a'),
        ),
      ),
    );
    await _pump(
      tester,
      FormsOperationsPage.files(
        api: api,
        formId: 'form-a',
        state: FormsOperationsState.unauthorized,
      ),
    );
    pending.complete(FormCursorPage(items: [api.job], nextCursor: null));
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(_download, findsNothing);
    expect(api.reads, ['form-a']);
  });
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

Map<String, Object?> _ticket() => {
  'job_id': _id,
  'download_url': _url,
  'expires_at': _now.add(const Duration(seconds: 30)).toIso8601String(),
};

FormExportDownloadResolver _resolver(_Gateway gateway, {MediaSession? session}) =>
    FormExportDownloadResolver(
      gateway: gateway,
      session: session ?? MediaSession(),
      now: () => _now,
    );

final class _Gateway implements FormExportDownloadGateway {
  int calls = 0;
  Future<Object?> Function() read = () async => _ticket();
  @override
  Future<Object?> resolve(String jobId) {
    calls++;
    expect(jobId, _id);
    return read();
  }
}

final class _Api implements FormsApi {
  _Api({
    this.job = const FormFileJob(
      id: _id,
      status: FormFileJobStatus.succeeded,
      progress: 1,
      downloadAvailable: true,
      downloadPath: 'https://forbidden-raw-path.test/private',
    ),
  });
  final FormFileJob job;
  final reads = <String>[];
  final cursors = <String?>[];
  String? nextCursor;
  Future<FormCursorPage<FormFileJob>>? pending;
  @override
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  }) {
    reads.add(formId);
    cursors.add(cursor);
    return pending ?? Future.value(FormCursorPage(items: [job], nextCursor: nextCursor));
  }

  @override
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query) async =>
      FormCursorPage(items: [], nextCursor: null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ExportApi implements FormsApi, FormsFileJobsReader {
  int reads = 0;
  List<FormFileJob> jobs = [];
  final saved = Completer<FormFileJob>();
  @override
  Future<FormsFileJobsContext> listFileJobsContext({
    required String formId,
    String? cursor,
    int limit = 25,
  }) async {
    reads++;
    return FormsFileJobsContext(
      formId: formId,
      managementVersion: 7,
      page: FormCursorPage(items: jobs, nextCursor: null),
    );
  }

  @override
  Future<FormFileJob> requestExport(FormCommand<FormExportPayload> command) async {
    final receipt = await saved.future;
    jobs = [receipt];
    return receipt;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
