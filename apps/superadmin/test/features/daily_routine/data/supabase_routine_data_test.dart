import 'dart:convert';

import 'package:coelo_superadmin/features/daily_routine/data/supabase_routine_repository.dart';
import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class _Backend {
  _Backend(this.responses);

  final Map<String, Object?> responses;
  final calls = <String, List<Map<String, Object?>>>{};
  final errors = <String, ({int status, String code})>{};

  Map<String, Object?> paramsOf(String function) => calls[function]!.last;

  MockClient get client => MockClient((request) async {
    final function = request.url.path.split('/rpc/').last;
    (calls[function] ??= <Map<String, Object?>>[]).add(
      jsonDecode(request.body) as Map<String, Object?>,
    );
    final failure = errors[function];
    if (failure != null) {
      return Response(
        jsonEncode({'code': failure.code, 'message': 'recusado'}),
        failure.status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }
    return Response(
      jsonEncode(responses[function]),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  });
}

SupabaseClient _clientFor(_Backend backend) =>
    SupabaseClient('https://example.supabase.co', 'publishable-key', httpClient: backend.client);

void main() {
  test('o diretório traduz a página do cliente para deslocamento do servidor', () async {
    final backend = _Backend({
      'superadmin_routine_directory': {
        'items': [
          {
            'id': 'model-1',
            'name': 'Rotina do berçário',
            'status': 'active',
            'version': 2,
            'origin_unit_id': null,
            'can_manage': true,
          },
        ],
        'total': 41,
        'limit': 20,
        'offset': 40,
      },
    });
    final client = _clientFor(backend);
    addTearDown(client.dispose);

    final page = await SupabaseRoutineRepository(client).fetchPage(
      const RoutineDirectoryQuery(kind: RoutineEntryKind.model, page: 3, pageSize: 20),
    );

    final params = backend.paramsOf('superadmin_routine_directory');
    expect(params['entry_kind'], 'model');
    expect(
      params['page_offset'],
      40,
      reason: 'o cliente conta páginas a partir de 1 e o servidor recebe deslocamento',
    );
    expect(page.page, 3);
    expect(page.totalCount, 41);
    expect(page.canManage, isTrue);
  });

  test('o modelo chega com seções, campos, opções e condições', () async {
    final backend = _Backend({
      'superadmin_routine_model_detail': {
        'id': 'model-1',
        'name': 'Rotina do berçário',
        'description': 'Descrição',
        'status': 'active',
        'management_version': 7,
        'institution_id': 'institution-1',
        'origin_unit_id': null,
        'can_manage': true,
        'definition': {
          'model_version_id': 'version-2',
          'version': 2,
          'sections': [
            {
              'id': 'section-1',
              'name': 'Alimentação',
              'sort_order': 0,
              'fields': [
                {
                  'id': 'field-1',
                  'label': 'Aceitou o almoço?',
                  'kind': 'single_choice',
                  'sort_order': 0,
                  'is_required': true,
                  'initial_value': null,
                  'minimum_value': null,
                  'maximum_value': null,
                  'options': [
                    {'id': 'option-1', 'label': 'Sim', 'sort_order': 0},
                    {'id': 'option-2', 'label': 'Não', 'sort_order': 1},
                  ],
                  'conditions': <Object?>[],
                },
              ],
            },
          ],
        },
      },
    });
    final client = _clientFor(backend);
    addTearDown(client.dispose);

    final model = await SupabaseRoutineRepository(client).fetchModel('model-1');
    // O uuid da versao vem da projecao; a aplicacao criada a partir do modelo
    // envia este valor (o rotulo id:vN e recusado pelo banco com 22P02).
    expect(model.versionId, 'version-2');

    expect(model.expectedVersion, 7, reason: 'a versão esperada é a do agregado');
    expect(model.version, 2, reason: 'a versão do conteúdo é a da definição');
    expect(model.originScope, RoutineModelOriginScope.institution);
    expect(model.sections.single.fields.single.kind, RoutineFieldKind.singleChoice);
    expect(model.sections.single.fields.single.options, hasLength(2));
  });

  test('o lançamento traz autoria contextual e vínculo de turma', () async {
    final backend = _Backend({
      'superadmin_routine_launch_detail': {
        'id': 'launch-1',
        'application_id': 'application-1',
        'application_revision_id': 'revision-1',
        'institution_id': 'institution-1',
        'unit_id': 'unit-1',
        'group_id': 'group-1',
        'author_membership_id': 'membership-1',
        'launch_date': '2026-09-10',
        'status': 'draft',
        'management_version': 2,
        'can_manage': true,
        'children': [
          {
            'entry_id': 'entry-1',
            'child_context_id': 'context-1',
            'child_group_link_id': 'link-1',
            'status': 'draft',
            'answers': [
              {'answer_id': 'answer-1', 'field_id': 'field-1', 'value': 'option-1'},
            ],
          },
        ],
      },
    });
    final client = _clientFor(backend);
    addTearDown(client.dispose);

    final launch = await SupabaseRoutineRepository(client).fetchLaunch('launch-1');

    expect(
      launch.authorMembershipId,
      'membership-1',
      reason: 'autoria de rotina é contextual: a pessoa sozinha não diz em que papel lançou',
    );
    expect(launch.children.single.childGroupLinkId, 'link-1');
    expect(launch.children.single.answers.single.value, 'option-1');
  });

  test('criar não manda id, editar manda; a versão esperada decide', () async {
    final backend = _Backend({
      'superadmin_routine_save_model': {'id': 'model-9', 'management_version': 1},
    });
    final client = _clientFor(backend);
    addTearDown(client.dispose);
    final repository = SupabaseRoutineRepository(client);

    const novo = RoutineModel(
      id: 'ignorado',
      name: 'Novo',
      description: '',
      version: 0,
      status: RoutineModelStatus.draft,
      sections: [],
      expectedVersion: 0,
      institutionId: 'institution-1',
    );
    await repository.saveModel(novo, requestId: 'request-1');
    expect(backend.paramsOf('superadmin_routine_save_model')['model_id'], isNull);

    const existente = RoutineModel(
      id: 'model-9',
      name: 'Existente',
      description: '',
      version: 1,
      status: RoutineModelStatus.active,
      sections: [],
      expectedVersion: 3,
      institutionId: 'institution-1',
    );
    await repository.saveModel(existente, requestId: 'request-2');
    final params = backend.paramsOf('superadmin_routine_save_model');
    expect(params['model_id'], 'model-9');
    expect(params['expected_version'], 3);
  });

  test('o rascunho manda o vínculo de turma de cada criança', () async {
    final backend = _Backend({
      'superadmin_routine_save_launch_draft': {'id': 'launch-1', 'management_version': 1},
    });
    final client = _clientFor(backend);
    addTearDown(client.dispose);

    await SupabaseRoutineRepository(client).saveLaunchDraft(
      RoutineLaunch(
        id: 'launch-1',
        applicationId: 'application-1',
        applicationRevisionId: 'revision-1',
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-1',
        authorMembershipId: 'membership-1',
        serviceDate: DateTime(2026, 9, 10),
        status: RoutineLaunchStatus.draft,
        expectedVersion: 1,
        children: const [
          RoutineChildEntryDraft(
            childContextId: 'context-1',
            childGroupLinkId: 'link-1',
            answers: [RoutineAnswerDraft(fieldId: 'field-1', value: 'option-1')],
          ),
        ],
      ),
      requestId: 'request-1',
    );

    final payload =
        backend.paramsOf('superadmin_routine_save_launch_draft')['payload']!
            as Map<String, Object?>;
    expect(payload['launch_date'], '2026-09-10');
    final entry = (payload['entries']! as List).single as Map<String, Object?>;
    expect(entry['child_group_link_id'], 'link-1');
    expect(
      payload.containsKey('author_membership_id'),
      isFalse,
      reason: 'a autoria é derivada da sessão no servidor, não aceita do payload',
    );
  });

  test('cada recusa do servidor vira o tipo de falha certo', () async {
    for (final (code, kind) in <(String, RoutineRepositoryFailureKind)>[
      ('42501', RoutineRepositoryFailureKind.unauthorized),
      ('P0002', RoutineRepositoryFailureKind.notFound),
      ('40001', RoutineRepositoryFailureKind.conflict),
      ('XX000', RoutineRepositoryFailureKind.unavailable),
    ]) {
      final backend = _Backend({})
        ..errors['superadmin_routine_model_detail'] = (status: 400, code: code);
      final client = _clientFor(backend);
      addTearDown(client.dispose);

      await expectLater(
        SupabaseRoutineRepository(client).fetchModel('model-1'),
        throwsA(
          isA<RoutineRepositoryException>().having((error) => error.kind, 'kind', kind),
        ),
        reason: 'código $code',
      );
    }
  });
}
