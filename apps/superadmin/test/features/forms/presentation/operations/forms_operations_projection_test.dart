import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('monitor renders only the authorized aggregate metrics', (tester) async {
    await _pump(tester, FormsOperationsPage.monitor(api: _Api(), formId: 'form-a'));
    for (final value in ['40', '13', '27']) {
      expect(find.text(value), findsOneWidget);
    }
    expect(find.text('Participação anônima'), findsOneWidget);
    expect(find.text('Colégio Horizonte'), findsNothing);
    expect(find.text('Perdeu elegibilidade'), findsNothing);
    expect(find.byKey(const Key('forms-monitor-hierarchy')), findsNothing);
  });

  testWidgets('responses use opaque cursors forward and backward and reset on form change', (
    tester,
  ) async {
    final api = _Api();
    await _pump(tester, FormsOperationsPage.responses(api: api, formId: 'form-a'));
    expect(find.text('Pessoa autorizada'), findsOneWidget);
    expect(api.detailIds, isEmpty);
    await tester.tap(find.byKey(const Key('forms-cursor-next')));
    await tester.pumpAndSettle();
    expect(api.responseQueries.last.cursor, 'opaque-page-b');
    expect(api.responseQueries.last.formId, 'form-a');
    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.text('Pessoa autorizada'), findsNothing);
    expect(find.textContaining('private-'), findsNothing);
    expect(find.textContaining('2026'), findsNothing);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('forms-cursor-next'))).onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Anterior'));
    await tester.pumpAndSettle();
    expect(api.responseQueries.last.cursor, isNull);
    await tester.tap(find.byKey(const Key('forms-cursor-next')));
    await tester.pumpAndSettle();
    await _pump(tester, FormsOperationsPage.responses(api: api, formId: 'form-b'));
    expect(api.responseQueries.last.formId, 'form-b');
    expect(api.responseQueries.last.cursor, isNull);
    expect(find.text('Página 1'), findsOneWidget);
  });

  testWidgets('late cursor result cannot replace the next form', (tester) async {
    final api = _Api()..pendingPage = Completer<FormCursorPage<FormResponseSummary>>();
    await _pump(tester, FormsOperationsPage.responses(api: api, formId: 'form-a'));
    await tester.tap(find.byKey(const Key('forms-cursor-next')));
    await tester.pump();
    await _pump(tester, FormsOperationsPage.responses(api: api, formId: 'form-b'));
    api.pendingPage!.complete(
      FormCursorPage(items: [_summary(label: 'Old private context')], nextCursor: null),
    );
    await tester.pumpAndSettle();
    expect(find.text('Old private context'), findsNothing);
    expect(find.text('Pessoa autorizada'), findsOneWidget);
    expect(find.text('Página 1'), findsOneWidget);
  });

  testWidgets('keyboard opens authorized response route and loads detail on demand', (
    tester,
  ) async {
    final api = _Api();
    final router = GoRouter(
      initialLocation: '/forms/form-a/responses',
      routes: [
        GoRoute(
          path: SuperadminRoutes.formResponses,
          builder: (_, state) =>
              FormsOperationsPage.responses(api: api, formId: state.pathParameters['formId']),
        ),
        GoRoute(
          path: SuperadminRoutes.formResponseDetail,
          name: SuperadminRoutes.formResponseDetailName,
          builder: (_, state) => FormsOperationsPage.responseDetail(
            api: api,
            responseId: state.pathParameters['responseId'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.pumpAndSettle();
    expect(api.detailIds, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(api.detailIds, ['response-a']);
    expect(find.text('Detalhe da resposta'), findsOneWidget);
    expect(find.text('Conteúdo das perguntas indisponível'), findsOneWidget);
    expect(find.text('Do not invent a question for this value'), findsNothing);
  });

  testWidgets('anonymous detail omits even unexpected identifying metadata', (tester) async {
    await _pump(
      tester,
      FormsOperationsPage.responseDetail(api: _Api(), responseId: 'response-a', anonymous: true),
    );
    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.text('Pessoa autorizada'), findsNothing);
    expect(find.textContaining('private-'), findsNothing);
    expect(find.textContaining('2026'), findsNothing);
  });

  testWidgets('anonymous response list suppresses unexpected respondent metadata', (tester) async {
    await _pump(
      tester,
      FormsOperationsPage.responses(api: _Api(), formId: 'form-a', anonymous: true),
    );
    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.text('Pessoa autorizada'), findsNothing);
    expect(find.textContaining('private-'), findsNothing);
    expect(find.textContaining('2026'), findsNothing);
  });

  testWidgets('jobs render real states and cursor without exposing download paths', (tester) async {
    final api = _Api();
    await _pump(tester, FormsOperationsPage.files(api: api, formId: 'form-a'));
    expect(find.text('Processando'), findsOneWidget);
    expect(find.text('Concluído'), findsOneWidget);
    expect(find.textContaining('https://'), findsNothing);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Baixar exportação finished',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Exportar respostas em XLSX'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('forms-cursor-next')));
    await tester.pumpAndSettle();
    expect(api.jobCursors, [null, 'opaque-job-page']);
    expect(find.text('Expirado'), findsOneWidget);
    expect(find.text('Concluído'), findsNothing);
  });

  testWidgets('empty responses and jobs show a real empty state', (tester) async {
    final api = _Api()..empty = true;
    for (final page in [
      FormsOperationsPage.responses(api: api, formId: 'form-a'),
      FormsOperationsPage.files(api: api, formId: 'form-a'),
    ]) {
      await _pump(tester, page);
      expect(find.text('Nenhum item ainda'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('forms-cursor-next'))).onPressed,
        isNull,
      );
    }
  });

  testWidgets('production projections remain usable at 200 percent in light and dark', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final dark in [false, true]) {
        for (final page in [
          FormsOperationsPage.monitor(api: _Api(), formId: 'form-a'),
          FormsOperationsPage.responses(api: _Api(), formId: 'form-a'),
          FormsOperationsPage.files(api: _Api(), formId: 'form-a'),
        ]) {
          tester.view.physicalSize = Size(width, 1400);
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? CoeloTheme.dark : CoeloTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: page,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$width / dark=$dark / ${page.surface}');
        }
      }
    }
  });
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: page));
  await tester.pumpAndSettle();
}

FormResponseSummary _summary({String? label = 'Pessoa autorizada'}) => FormResponseSummary(
  id: 'response-a',
  occurrenceId: 'private-occurrence',
  formVersionId: 'private-version',
  submittedAt: DateTime(2026, 9, 8, 14, 32),
  respondentLabel: label,
);

final class _Api implements FormsApi {
  final responseQueries = <FormResponsesQuery>[];
  final detailIds = <String>[];
  final jobCursors = <String?>[];
  Completer<FormCursorPage<FormResponseSummary>>? pendingPage;
  bool empty = false;

  @override
  Future<FormMonitorProjection> getMonitor(FormMonitorQuery query) async =>
      const FormMonitorProjection(
        eligibleCount: 40,
        respondedCount: 13,
        pendingCount: 27,
        isAnonymous: true,
      );

  @override
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query) async {
    responseQueries.add(query);
    if (query.cursor != null && pendingPage != null) return pendingPage!.future;
    return FormCursorPage(
      items: empty ? [] : [_summary(label: query.cursor == null ? 'Pessoa autorizada' : null)],
      nextCursor: empty || query.cursor != null ? null : 'opaque-page-b',
    );
  }

  @override
  Future<FormResponseDetail> getResponseDetail(String responseId) async {
    detailIds.add(responseId);
    return FormResponseDetail(
      summary: _summary(),
      answers: {
        'item-a': FormAnswer.shortText(
          itemId: 'item-a',
          value: 'Do not invent a question for this value',
        ),
      },
    );
  }

  @override
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  }) async {
    jobCursors.add(cursor);
    return FormCursorPage(
      items: empty
          ? []
          : cursor != null
          ? const [FormFileJob(id: 'expired', status: FormFileJobStatus.expired, progress: 1)]
          : const [
              FormFileJob(id: 'processing', status: FormFileJobStatus.processing, progress: .4),
              FormFileJob(
                id: 'finished',
                status: FormFileJobStatus.succeeded,
                progress: 1,
                downloadAvailable: true,
                downloadPath: 'https://private.invalid/secret',
              ),
            ],
      nextCursor: empty || cursor != null ? null : 'opaque-job-page',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
