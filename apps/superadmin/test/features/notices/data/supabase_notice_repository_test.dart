import 'dart:convert';

import 'package:coelo_superadmin/features/notices/data/supabase_notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/notice_repository.dart';
import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_form_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('blocked image publication gives honest feedback without a request', () async {
    var requests = 0;
    final client = _client((request) async {
      requests++;
      return _json(request, _noticeJson());
    });
    addTearDown(client.dispose);
    final repository = SupabaseNoticeRepository(client);
    final notice = await repository.getById('image-notice');
    requests = 0;

    await expectLater(
      repository.publish(
        notice.copyWith(contentFormat: NoticeContentFormat.image),
        requestId: '10000000-0000-4000-8000-000000000001',
        expectedVersion: notice.managementVersion,
      ),
      throwsA(
        isA<NoticeMediaDecisionRequiredException>().having(
          (error) => error.safeMessage,
          'safeMessage',
          'A publicação com imagem ainda não está disponível. '
              'Converta o aviso para texto antes de publicar.',
        ),
      ),
    );
    expect(requests, 0);
  });

  test('media blocked envelope ignores stale or sensitive server feedback', () async {
    final client = _client(
      (request) async => Response(
        jsonEncode({
          'ok': false,
          'data': null,
          'error': {
            'code': 'NOTICE_MEDIA_BLOCKED',
            'message': 'sensitive internal storage detail',
            'http_status': 409,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseNoticeRepository(client).getById('image-notice'),
      throwsA(
        isA<NoticeMediaDecisionRequiredException>().having(
          (error) => error.safeMessage,
          'safeMessage',
          'A publicação com imagem ainda não está disponível. '
              'Converta o aviso para texto antes de publicar.',
        ),
      ),
    );
  });

  test('controller accepts v2 create version one and queued publication version two', () async {
    final requests = <Request>[];
    final client = _client((request) async {
      requests.add(request);
      final publishing = request.url.path.endsWith('/superadmin_notice_publish_v2');
      return _json(request, {
        ..._noticeJson(),
        'status': publishing ? 'scheduled' : 'draft',
        'management_version': publishing ? 2 : 1,
      });
    });
    addTearDown(client.dispose);
    final controller = NoticeFormController(repository: SupabaseNoticeRepository(client));
    addTearDown(controller.dispose);
    controller.titleController.text = 'Rotina';
    controller.messageController.text = 'Mensagem';
    final result = await controller.saveAndPublish();
    expect(result?.status, NoticeStatus.scheduled);
    expect(result?.managementVersion, 2);
    expect(requests, hasLength(2));
    expect(requests.first.url.path, endsWith('/superadmin_notice_save_draft_v2'));
    expect(requests.last.url.path, endsWith('/superadmin_notice_publish_v2'));
    expect((jsonDecode(requests.first.body) as Map)['p_expected_version'], isNull);
    expect((jsonDecode(requests.last.body) as Map)['p_expected_version'], 1);
  });

  test('lists notices through the authorized cursor RPC', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json(request, {
        'items': [_noticeJson()],
        'next_cursor_occurred_at': '2026-08-11T12:00:00Z',
        'next_cursor_id': '20000000-0000-4000-8000-000000000001',
      });
    });
    addTearDown(client.dispose);

    final page = await SupabaseNoticeRepository(client).fetchPage(
      const NoticeDirectoryQuery(
        search: 'Rotina',
        types: {CommunicationType.notice, CommunicationType.forYou},
        pageSize: 24,
      ),
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_notice_directory_v2'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_search'], 'Rotina');
    expect(body['p_limit'], 24);
    expect(body['p_types'], ['popup', 'for_you']);
    expect(page.items.single.title, 'Rotina');
    expect(page.nextCursorId, '20000000-0000-4000-8000-000000000001');
    expect(captured!.body, isNot(contains('service_role')));
  });

  test('save sends request id, expected version and structured appearance', () async {
    Request? captured;
    final client = _client((request) async {
      captured = request;
      return _json(request, _noticeJson());
    });
    addTearDown(client.dispose);

    await SupabaseNoticeRepository(client).saveDraft(
      NoticeDraft(
        type: CommunicationType.highlight,
        title: 'Rotina',
        message: 'Mensagem',
        priority: NoticePriority.important,
        audience: NoticeAudience.institution,
        audienceLabel: 'Instituições filtradas',
        behavior: NoticeBehavior.confirmation,
        mandatory: true,
        targetDevice: NoticeTargetDevice.all,
        contentFormat: NoticeContentFormat.textBackground,
        buttonColorValue: 0xFFD63C00,
        popupSize: NoticePopupSize.large,
        hasOuterInset: true,
        audienceSelection: const NoticeAudienceSelection(
          rules: [
            NoticeAudienceRule(
              dimension: NoticeAudienceDimension.institution,
              selectAll: true,
              excludedIds: ['30000000-0000-4000-8000-000000000001'],
              filters: {
                'search': ['Centro'],
              },
            ),
          ],
        ),
        buttonLabel: 'Confirmar',
        startsAt: DateTime.utc(2026, 8, 11, 12),
      ),
      requestId: '10000000-0000-4000-8000-000000000001',
      expectedVersion: 7,
    );

    expect(captured!.url.path, endsWith('/rpc/superadmin_notice_save_draft_v2'));
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['p_request_id'], '10000000-0000-4000-8000-000000000001');
    expect(body['p_expected_version'], 7);
    final payload = body['p_payload'] as Map<String, dynamic>;
    expect(payload['type'], 'highlight');
    expect(payload['button_color'], '#D63C00');
    expect(payload['popup_size'], 'standard');
    expect(payload['behavior'], 'dismissible');
    expect(
      ((payload['audience'] as Map<String, dynamic>)['rules'] as List).single,
      containsPair('filters', {
        'search': ['Centro'],
      }),
    );
  });

  test('maps legacy and current communication types from the RPC', () async {
    for (final entry in {
      'popup': CommunicationType.notice,
      'notice': CommunicationType.notice,
      'critical_notice': CommunicationType.notice,
      'content_card': CommunicationType.content,
      'highlight': CommunicationType.highlight,
      'for_you': CommunicationType.forYou,
    }.entries) {
      final client = _client(
        (request) async => _json(request, {..._noticeJson(), 'type': entry.key}),
      );
      final item = await SupabaseNoticeRepository(client).getById('id');
      expect(item.type, entry.value, reason: entry.key);
      client.dispose();
    }
  });

  test('maps the approved legacy status cutover and rejects unknown values', () async {
    for (final entry in {
      'published': NoticeStatus.active,
      'archived': NoticeStatus.cancelled,
    }.entries) {
      final client = _client(
        (request) async => _json(request, {..._noticeJson(), 'status': entry.key}),
      );
      expect((await SupabaseNoticeRepository(client).getById('id')).status, entry.value);
      client.dispose();
    }

    final client = _client(
      (request) async => _json(request, {..._noticeJson(), 'status': 'unknown'}),
    );
    await expectLater(
      SupabaseNoticeRepository(client).getById('id'),
      throwsA(isA<NoticeUnexpectedException>()),
    );
    client.dispose();
  });

  test('maps stable internal gateway envelopes without exposing details', () async {
    final client = _client(
      (request) async => Response(
        jsonEncode({
          'ok': false,
          'data': null,
          'error': {
            'code': 'SAI_MFA_REQUIRED',
            'message': 'Confirme o segundo fator.',
            'correlation_id': '10000000-0000-4000-8000-000000000001',
            'http_status': 403,
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseNoticeRepository(client).getById('id'),
      throwsA(isA<NoticeUnauthorizedException>()),
    );
  });

  test('maps forbidden responses without exposing server details', () async {
    final client = _client(
      (request) async => Response(
        jsonEncode({'code': '42501', 'message': 'sensitive internal detail'}),
        403,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    expect(
      () => SupabaseNoticeRepository(client).getById('20000000-0000-4000-8000-000000000001'),
      throwsA(isA<NoticeUnauthorizedException>()),
    );
  });
  for (final envelope in <({String name, Map<String, Object?> body})>[
    // `ok: true` sem `data` nao e sucesso vazio: e envelope quebrado. Tratar
    // como sucesso entregaria nulo ao mapeador e a tela renderizaria a partir
    // de nada.
    (name: 'ok sem data', body: {'ok': true, 'error': null}),
    // Qualquer valor que nao seja `false` no `ok` tambem nao e recusa de
    // dominio: sem um `error.code` de verdade, virar erro de dominio inventaria
    // uma causa que o servidor nao deu.
    (name: 'ok ausente', body: {'data': <String, Object?>{}}),
    (name: 'ok nulo', body: {'ok': null, 'data': <String, Object?>{}}),
    (name: 'ok textual', body: {'ok': 'true', 'data': <String, Object?>{}}),
  ]) {
    test('um envelope ${envelope.name} e recusado como inesperado', () async {
      final client = _client(
        (request) async => Response(
          jsonEncode(envelope.body),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      );
      addTearDown(client.dispose);

      await expectLater(
        SupabaseNoticeRepository(client).getById('20000000-0000-4000-8000-000000000001'),
        throwsA(isA<NoticeUnexpectedException>()),
      );
    });
  }

  test('uma listagem com envelope quebrado nao vira "nenhum aviso"', () async {
    // O caso perigoso do `containsKey('data')`: sem ele, `ok: true` sem `data`
    // devolve nulo, a listagem le lista vazia e a tela diz que nao ha avisos.
    // Um envelope quebrado passaria por ausencia de conteudo.
    final client = _client(
      (request) async => Response(
        jsonEncode({'ok': true, 'error': null}),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseNoticeRepository(client).fetchPage(const NoticeDirectoryQuery()),
      throwsA(isA<NoticeUnexpectedException>()),
    );
  });

  test('um ok malformado nao vira recusa de dominio, mesmo com codigo de erro', () async {
    // O caso perigoso do `ok == false`: com `!= true`, um envelope cujo `ok`
    // veio quebrado seria lido como recusa legitima e o operador receberia
    // "nao encontrado" no lugar de "resposta invalida".
    final client = _client(
      (request) async => Response(
        jsonEncode({
          'ok': 'true',
          'data': null,
          'error': {'code': 'NOTICE_NOT_FOUND'},
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseNoticeRepository(client).getById('20000000-0000-4000-8000-000000000001'),
      throwsA(isA<NoticeUnexpectedException>()),
    );
  });
}

SupabaseClient _client(Future<Response> Function(Request request) handler) => SupabaseClient(
  'https://example.supabase.co',
  'publishable-key',
  httpClient: MockClient(handler),
);

Response _json(Request request, Object value) => Response(
  jsonEncode({'ok': true, 'data': value, 'error': null}),
  200,
  headers: {'content-type': 'application/json'},
  request: request,
);

Map<String, Object?> _noticeJson() => {
  'id': '20000000-0000-4000-8000-000000000001',
  'title': 'Rotina',
  'body': 'Mensagem',
  'priority': 'important',
  'status': 'draft',
  'starts_at': '2026-08-11T12:00:00Z',
  'audience': {
    'rules': [
      {'dimension': 'platform', 'select_all': true},
    ],
    'role_codes': <String>[],
    'plan_ids': <String>[],
  },
  'audience_label': 'Todos',
  'behavior': 'confirmation',
  'target_device': 'all',
  'content_format': 'text_background',
  'button_color': '#D63C00',
  'popup_size': 'standard',
  'has_outer_inset': true,
  'button_label': 'Confirmar',
  'recurrence': 'one_time',
  'weekly_days': <int>[],
  'management_version': 7,
};
