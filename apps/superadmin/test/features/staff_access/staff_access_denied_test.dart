import 'dart:convert';

import 'package:coelo_superadmin/features/staff_access/data/staff_access_denied_http_client.dart';
import 'package:coelo_superadmin/features/staff_access/domain/staff_access_denied.dart';
import 'package:coelo_superadmin/features/staff_access/domain/staff_access_surface_binding.dart';
import 'package:coelo_superadmin/features/staff_access/presentation/staff_access_denied_listener.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Lote 91: PT403/STAFF_ACCESS_DENIED com motivo -> popup de contexto bloqueado.
void main() {
  const body =
      '{"code":"PT403","message":"STAFF_ACCESS_DENIED","hint":null,'
      '"details":"{\\"code\\":\\"STAFF_ACCESS_DENIED\\",\\"membership_id\\":\\"m-1\\",\\"reason\\":\\"schedule\\",'
      '\\"popup\\":{\\"kind\\":\\"schedule\\",\\"windows\\":[{\\"weekday\\":1,\\"start\\":\\"08:00\\",\\"end\\":\\"18:00\\"}]}}"}';

  setUp(() => staffAccessDenied.value = null);

  test('reconhece o corpo do PostgREST com motivo e popup', () {
    final denial = StaffAccessDenial.fromPostgrestBody(body)!;
    expect(denial.membershipId, 'm-1');
    expect(denial.reason, 'schedule');
    expect(denial.popup!['kind'], 'schedule');
    expect(StaffAccessDenial.fromPostgrestBody('{"code":"42501","message":"permission denied"}'), isNull);
  });

  test('cliente HTTP publica a negação e devolve a resposta intacta', () async {
    final client = StaffAccessDeniedHttpClient(
      MockClient((request) async => http.Response(body, 403, headers: {'content-type': 'application/json'})),
    );
    final response = await client.post(Uri.parse('https://x/rest/v1/rpc/now_list'));
    expect(response.statusCode, 403);
    expect(jsonDecode(response.body)['message'], 'STAFF_ACCESS_DENIED');
    expect(staffAccessDenied.value?.membershipId, 'm-1');

    staffAccessDenied.value = null;
    final plain = StaffAccessDeniedHttpClient(
      MockClient((request) async => http.Response('{"code":"42501"}', 403)),
    );
    await plain.get(Uri.parse('https://x/rest/v1/rpc/other'));
    expect(staffAccessDenied.value, isNull);
  });

  testWidgets('observador grava x-coelo-surface e recalcula ao mudar a métrica', (tester) async {
    final headers = <String, String>{};
    final observer = StaffAccessSurfaceObserver(
      headers: headers,
      userAgent: 'Mozilla/5.0 (Windows NT 10.0)',
      debounce: const Duration(milliseconds: 50),
      isWeb: true, // o teste roda na VM; o detector decide como no web
    );
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    observer.bind();
    expect(headers['x-coelo-surface'], 'web');

    tester.view.physicalSize = const Size(375, 800);
    observer.didChangeMetrics();
    await tester.pump(const Duration(milliseconds: 60));
    expect(headers['x-coelo-surface'], 'mobile_web');
    observer.dispose();
  });

  testWidgets('listener mostra o popup com o motivo e chama onDismissed', (tester) async {
    StaffAccessDenial? dismissed;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: StaffAccessDeniedListener(
          onDismissed: (denial) => dismissed = denial,
          child: const Scaffold(body: Text('conteúdo')),
        ),
      ),
    );
    staffAccessDenied.value = StaffAccessDenial.fromPostgrestBody(body);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff-access-denied-dialog')), findsOneWidget);
    expect(find.textContaining('Seg 08:00–18:00'), findsOneWidget);
    expect(staffAccessDenied.value, isNull);

    await tester.tap(find.byKey(const Key('staff-access-denied-switch')));
    await tester.pumpAndSettle();
    expect(dismissed?.membershipId, 'm-1');
    expect(find.byKey(const Key('staff-access-denied-dialog')), findsNothing);
  });
}
