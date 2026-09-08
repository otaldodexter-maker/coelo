import 'dart:async';

import 'package:coelo_superadmin/app/router/superadmin_routes.dart';
import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:coelo_superadmin/features/forms/data/supabase_forms_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _formA = '10000000-0000-4000-8000-000000000001';
const _formB = '10000000-0000-4000-8000-000000000002';
const _responseA = '20000000-0000-4000-8000-000000000001';
const _responseB = '20000000-0000-4000-8000-000000000002';

void main() {
  testWidgets(
    'anonymous RPC pages and on-demand detail preserve privacy through the real adapter',
    (tester) async {
      final backend = _RpcBackend((name, parameters) {
        final query = parameters['p_query']! as Map;
        if (name == 'superadmin_forms_response_detail_v2') {
          return _ok({..._summary(_responseB, anonymous: true), 'answers': <Object?>[]});
        }
        final next = query['cursor_id'] == null;
        return _responses([
          _summary(next ? _responseA : _responseB, anonymous: true),
        ], nextCursor: next ? {'id': _responseA} : null);
      });
      final api = SupabaseFormsApi(backend);
      final router = GoRouter(
        initialLocation: '/forms/$_formA/responses',
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
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
      await tester.pumpAndSettle();
      expect(backend.calls.map((call) => call.$1), ['superadmin_forms_responses_v2']);
      _expectPrivateResponse();

      await tester.tap(find.byKey(const Key('forms-cursor-next')));
      await tester.pumpAndSettle();
      expect(backend.calls.last.$2, {
        'p_query': {
          'form_id': _formA,
          'occurrence_id': null,
          'cursor_submitted_at': null,
          'cursor_id': _responseA,
          'limit': 25,
        },
      });
      expect(find.text('Página 2'), findsOneWidget);
      _expectPrivateResponse();

      await tester.tap(find.text('Visualizar resposta'));
      await tester.pumpAndSettle();
      expect(backend.calls.last.$1, 'superadmin_forms_response_detail_v2');
      expect(backend.calls.last.$2, {
        'p_query': {'response_id': _responseB},
      });
      expect(find.text('Detalhe da resposta'), findsOneWidget);
      expect(find.text('Conteúdo das perguntas indisponível'), findsOneWidget);
      _expectPrivateResponse();
      semantics.dispose();
    },
  );

  testWidgets('a 403 envelope with injected data reaches the denied state without disclosure', (
    tester,
  ) async {
    final backend = _RpcBackend(
      (_, _) => {
        'ok': false,
        'data': {
          'items': [_summary(_responseA)],
          'has_more': false,
          'next_cursor': null,
        },
        'error': {'code': '403', 'message': 'Private SQL diagnostic'},
      },
    );
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      FormsOperationsPage.responses(api: SupabaseFormsApi(backend), formId: _formA),
    );
    expect(backend.calls.single.$1, 'superadmin_forms_responses_v2');
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.textContaining('Pessoa reservada'), findsNothing);
    expect(find.textContaining('Private SQL'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Pessoa reservada|Private SQL')), findsNothing);
    expect(find.text('Visualizar resposta'), findsNothing);
    expect(find.byKey(const Key('forms-cursor-next')), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'context replacement clears the cursor and ignores a late RPC before a fresh reload',
    (tester) async {
      final oldPage = Completer<Object?>();
      var formBLoads = 0;
      final backend = _RpcBackend((_, parameters) {
        final query = parameters['p_query']! as Map;
        if (query['form_id'] == _formB) {
          formBLoads++;
          return _responses([
            _summary(
              _responseB,
              label: formBLoads == 1 ? 'Contexto atual' : 'Atualizado no reload',
            ),
          ]);
        }
        if (query['cursor_id'] != null) return oldPage.future;
        return _responses(
          [_summary(_responseA, label: 'Contexto anterior')],
          nextCursor: {'submitted_at': '2026-09-08T12:00:00Z', 'id': _responseA},
        );
      });
      final api = SupabaseFormsApi(backend);
      await _pump(tester, FormsOperationsPage.responses(api: api, formId: _formA));
      await tester.tap(find.byKey(const Key('forms-cursor-next')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Contexto anterior'), findsNothing);

      await _pump(tester, FormsOperationsPage.responses(api: api, formId: _formB));
      final newQuery = backend.calls.last.$2['p_query']! as Map;
      expect(newQuery['form_id'], _formB);
      expect(newQuery['cursor_id'], isNull);
      expect(newQuery['cursor_submitted_at'], isNull);
      oldPage.complete(_responses([_summary(_responseA, label: 'Resposta tardia privada')]));
      await tester.pumpAndSettle();
      expect(find.text('Contexto atual'), findsOneWidget);
      expect(find.text('Resposta tardia privada'), findsNothing);
      expect(find.text('Página 1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _pump(tester, FormsOperationsPage.responses(api: api, formId: _formB));
      expect(formBLoads, 2);
      expect(find.text('Atualizado no reload'), findsOneWidget);
      expect(find.text('Contexto atual'), findsNothing);
      expect(find.text('Resposta tardia privada'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retry reloads authorized monitor metrics through the internal RPC', (tester) async {
    var attempts = 0;
    final backend = _RpcBackend((_, _) {
      attempts++;
      if (attempts == 1) {
        return {
          'ok': false,
          'data': null,
          'error': {'code': '503', 'message': 'Private operational diagnostic'},
        };
      }
      return _ok({
        'eligible_count': 40,
        'responded_count': 13,
        'pending_count': 27,
        'is_anonymous': true,
      });
    });
    await _pump(
      tester,
      FormsOperationsPage.monitor(api: SupabaseFormsApi(backend), formId: _formA),
    );
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.textContaining('Private operational'), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(backend.calls.map((call) => call.$1).toSet(), {'superadmin_forms_monitor_v2'});
    expect(backend.calls.first.$2, backend.calls.last.$2);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);
    expect(find.text('27'), findsOneWidget);
    expect(find.text('Participação anônima'), findsOneWidget);
    expect(find.text('Não foi possível carregar'), findsNothing);
  });

  testWidgets(
    'file-job wire states reach the normal page without exposing private download locators',
    (tester) async {
      final backend = _RpcBackend(
        (_, _) => _ok({
          'items': [
            {
              'id': 'job-ready',
              'status': 'succeeded',
              'progress': 1,
              'download_available': true,
              'download_path': 'https://private.invalid/signed-token',
              'error_code': null,
            },
            {
              'id': 'job-expired',
              'status': 'expired',
              'progress': 1,
              'download_available': false,
              'download_path': null,
              'error_code': null,
            },
          ],
          'has_more': false,
          'next_cursor': null,
        }),
      );
      await _pump(
        tester,
        FormsOperationsPage.files(api: SupabaseFormsApi(backend), formId: _formA),
      );
      expect(backend.calls.single.$1, 'superadmin_forms_file_jobs_v2');
      expect(find.text('Concluído'), findsOneWidget);
      expect(find.text('Expirado'), findsOneWidget);
      expect(find.textContaining('https://'), findsNothing);
      expect(find.textContaining('signed-token'), findsNothing);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Baixar exportação job-ready',
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
    },
  );
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: page));
  await tester.pumpAndSettle();
}

void _expectPrivateResponse() {
  expect(find.text('Resposta anônima'), findsOneWidget);
  expect(find.textContaining('Pessoa reservada'), findsNothing);
  expect(find.textContaining('2026'), findsNothing);
  expect(find.textContaining('private-context'), findsNothing);
  expect(find.bySemanticsLabel(RegExp('Pessoa reservada|2026|private-context')), findsNothing);
}

Map<String, Object?> _ok(Map<String, Object?> data) => {'ok': true, 'data': data, 'error': null};
Map<String, Object?> _responses(
  List<Map<String, Object?>> items, {
  Map<String, Object?>? nextCursor,
}) => _ok({'items': items, 'has_more': nextCursor != null, 'next_cursor': nextCursor});
Map<String, Object?> _summary(
  String id, {
  bool anonymous = false,
  String label = 'Pessoa reservada',
}) => {
  'id': id,
  'occurrence_id': 'private-context-occurrence',
  'form_version_id': 'private-context-version',
  'identity_mode': anonymous ? 'anonymous' : 'identified',
  'respondent_label': label,
  'submitted_at': '2026-09-08T12:00:00Z',
};

final class _RpcBackend implements FormsBackendGateway {
  _RpcBackend(this.respond);
  final FutureOr<Object?> Function(String, Map<String, Object?>) respond;
  final calls = <(String, Map<String, Object?>)>[];

  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) async {
    calls.add((functionName, parameters));
    return respond(functionName, parameters);
  }

  @override
  Future<Object?> media(Map<String, Object?> envelope) =>
      throw StateError('Operations reads must not call media.');
}
