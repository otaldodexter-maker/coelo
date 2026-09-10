import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/forms/data/forms_backend_gateway.dart';
import 'package:coelo_superadmin/features/forms/data/supabase_forms_api.dart';

void main() {
  test('queues the whole-form XLSX through the internal concurrency envelope', () async {
    final backend = _Backend.internal({
      'id': 'job-1',
      'status': 'pending',
      'progress': 0,
      'download_available': false,
    });
    final job = await SupabaseFormsApi(backend).requestExport(
      const FormCommand(
        requestId: 'export-request',
        expectedVersion: 4,
        payload: FormExportPayload(formId: 'form-1', kind: FormExportKind.xlsx),
      ),
    );
    expect(job.id, 'job-1');
    expect(job.status, FormFileJobStatus.pending);
    expect(backend.functionName, 'superadmin_form_request_xlsx_v2');
    expect(backend.parameters, {
      'p_request_id': 'export-request',
      'p_expected_version': 4,
      'p_payload': {'form_id': 'form-1'},
    });
  });

  for (final kind in [
    FormExportKind.csv,
    FormExportKind.zip,
    FormExportKind.anonymousParticipation,
  ]) {
    test('defers $kind export without contacting the backend', () async {
      final backend = _Backend(null);
      await expectLater(
        SupabaseFormsApi(backend).requestExport(
          FormCommand(
            requestId: 'export-request',
            expectedVersion: 1,
            payload: FormExportPayload(formId: 'form-1', kind: kind),
          ),
        ),
        throwsA(
          isA<FormApiException>()
              .having((error) => error.kind, 'kind', FormApiFailureKind.unavailable)
              .having((error) => error.message, 'message', 'Disponível depois do MVP'),
        ),
      );
      expect(backend.functionName, isNull);
    });
  }

  test('defers nominal anonymous participation export for every format', () async {
    for (final kind in FormExportKind.values) {
      final backend = _Backend(null);
      await expectLater(
        SupabaseFormsApi(backend).requestAnonymousParticipationExport(
          FormCommand(
            requestId: 'export-request',
            expectedVersion: 1,
            payload: FormExportPayload(formId: 'form-1', kind: kind),
          ),
        ),
        throwsA(
          isA<FormApiException>()
              .having((error) => error.kind, 'kind', FormApiFailureKind.unavailable)
              .having((error) => error.message, 'message', 'Disponível depois do MVP'),
        ),
      );
      expect(backend.functionName, isNull);
    }
  });

  test('occurrence export cannot silently broaden into whole-form export', () async {
    final backend = _Backend(null);
    await expectLater(
      SupabaseFormsApi(backend).requestExport(
        const FormCommand(
          requestId: 'request-1',
          expectedVersion: 1,
          payload: FormExportPayload(
            formId: 'form-1',
            occurrenceId: 'occurrence-1',
            kind: FormExportKind.xlsx,
          ),
        ),
      ),
      throwsA(
        isA<FormApiException>().having(
          (error) => error.kind,
          'kind',
          FormApiFailureKind.validation,
        ),
      ),
    );
    expect(backend.functionName, isNull);
  });

  test(
    'directory maps opaque cursors without OFFSET and decodes the authorized projection',
    () async {
      final backend = _Backend({
        'items': [
          {
            'id': 'form-1',
            'title': 'Pesquisa',
            'kind': 'form',
            'status': 'published',
            'operational_status': 'scheduled',
            'identity_mode': 'identified',
            'updated_at': '2026-08-13T12:00:00Z',
            'management_version': 4,
          },
        ],
        'has_more': true,
        'next_cursor': {'updated_at': '2026-08-13T12:00:00Z', 'id': 'form-1'},
      });
      final api = SupabaseFormsApi(backend);

      final first = await api.listDirectory(
        const FormDirectoryQuery(institutionId: 'institution-1', statuses: {FormStatus.published}),
      );
      final query = Map<String, Object?>.from(backend.parameters!['p_query']! as Map);

      expect(first.items.single.title, 'Pesquisa');
      expect(first.items.single.operationalStatus, FormOperationalStatus.scheduled);
      expect(first.nextCursor, isNotNull);
      expect(query['institution_id'], 'institution-1');
      expect(query, isNot(contains('offset')));

      await api.listDirectory(
        FormDirectoryQuery(institutionId: 'institution-1', cursor: first.nextCursor),
      );
      final nextQuery = Map<String, Object?>.from(backend.parameters!['p_query']! as Map);
      expect(nextQuery['cursor_updated_at'], '2026-08-13T12:00:00Z');
      expect(nextQuery['cursor_id'], 'form-1');
    },
  );

  test('maps backend failures without exposing their messages', () async {
    const sensitiveMessage = 'tenant B / tabela privada / SQL sensível';
    const cases = <(String, FormApiFailureKind, String)>[
      ('42501', FormApiFailureKind.unauthorized, 'Você não possui permissão para esta ação.'),
      ('22023', FormApiFailureKind.validation, 'Revise os dados enviados e tente novamente.'),
      (
        '40001',
        FormApiFailureKind.conflict,
        'O formulário foi alterado em outra sessão. Recarregue e tente novamente.',
      ),
      ('503', FormApiFailureKind.unavailable, 'O serviço está indisponível. Tente novamente.'),
      // Falha de transporte: a requisicao nao chegou ao backend, entao nao ha
      // codigo do Postgres nem corpo. Cair em desconhecido diria a pessoa que
      // a acao falhou, quando o certo e dizer que o servico esta indisponivel.
      ('transport', FormApiFailureKind.unavailable, 'O serviço está indisponível. Tente novamente.'),
      (
        'unexpected',
        FormApiFailureKind.unknown,
        'Não foi possível concluir a ação. Tente novamente.',
      ),
    ];

    for (final (code, kind, message) in cases) {
      final api = SupabaseFormsApi(_Backend.failure(code, failureMessage: sensitiveMessage));

      await expectLater(
        api.getEditor('form-1'),
        throwsA(
          isA<FormApiException>()
              .having((error) => error.kind, 'kind', kind)
              .having((error) => error.message, 'message', message)
              .having((error) => error.message, 'redacted message', isNot(contains('tenant B'))),
        ),
      );
    }
  });

  test('loads only explicit institution form capabilities from the context RPC', () async {
    final backend = _Backend({
      'institutions': [
        {
          'id': 'institution-school',
          'name': 'Escola Horizonte',
          'capabilities': {'can_manage_forms': true, 'can_publish_forms': false},
        },
      ],
    });

    final context = await SupabaseFormsApi(backend).getEditorContext();

    expect(backend.functionName, 'superadmin_forms_context');
    expect(context.institutions.single.id, 'institution-school');
    expect(context.institutions.single.canManageForms, isTrue);
    expect(context.institutions.single.canPublishForms, isFalse);
  });

  test('applies the deployed top-level capabilities to authorized institutions', () async {
    final backend = _Backend({
      'capabilities': {'manage': true, 'publish': true, 'manage_applications': true},
      'institutions': [
        {'id': 'institution-aurora', 'name': 'Instituto Aurora'},
      ],
    });

    final context = await SupabaseFormsApi(backend).getEditorContext();

    expect(context.institutions.single.canManageForms, isTrue);
    expect(context.institutions.single.canPublishForms, isTrue);
    expect(context.canManageApplications, isTrue);
  });

  test('monitor hierarchy sends the scoped cursor to the authorized RPC', () async {
    final backend = _Backend.internal({
      'items': [
        {
          'scope_id': 'unit-1',
          'scope_kind': 'unit',
          'label': 'Unidade Centro',
          'eligible_count': 42,
          'responded_count': 31,
          'pending_count': 11,
        },
      ],
      'has_more': false,
      'next_cursor': null,
    });
    final api = SupabaseFormsApi(backend);

    final page = await api.listMonitorHierarchy(
      const FormMonitorQuery(formId: 'form-1', scopeId: 'institution-1'),
    );
    final query = Map<String, Object?>.from(backend.parameters!['p_query']! as Map);

    expect(backend.functionName, 'superadmin_forms_monitor_hierarchy_v2');
    expect(query['scope_id'], 'institution-1');
    expect(query, isNot(contains('offset')));
    expect(page.items.single.scopeKind, FormMonitorScopeKind.unit);
    expect(page.items.single.label, 'Unidade Centro');
  });

  test('response mutation preserves media kind and concurrency envelope', () async {
    final backend = _Backend({
      'id': 'response-1',
      'occurrence_id': 'occurrence-1',
      'status': 'draft',
      'management_version': 8,
      'identity_mode': 'identified',
      'answers': [
        FormAnswerDto.fromDomain(
          FormAnswer.photo(itemId: 'photo-1', assetIds: ['asset-1']),
        ).toJson(),
      ],
    });
    final api = SupabaseFormsApi(backend);

    await api.saveResponseDraft(
      FormCommand(
        requestId: 'request-1',
        expectedVersion: 7,
        payload: FormResponseDraftPayload(
          occurrenceId: 'occurrence-1',
          responseId: 'response-1',
          participationId: 'participation-1',
          answers: {
            'photo-1': FormAnswer.photo(itemId: 'photo-1', assetIds: ['asset-1']),
          },
        ),
      ),
    );
    final payload = Map<String, Object?>.from(backend.parameters!['p_payload']! as Map);
    final answers = List<Map<String, Object?>>.from(payload['answers']! as List);

    expect(backend.functionName, 'form_save_response_draft');
    expect(backend.parameters!['p_expected_version'], 7);
    expect(answers.single['kind'], 'photo');
    expect(payload['response_id'], 'response-1');
  });

  for (final operation in ['open', 'save', 'submit', 'edit']) {
    test('$operation accepts the correlated receipt and preserves its confirmed status', () async {
      final status = operation == 'submit' || operation == 'edit' ? 'submitted' : 'draft';
      final result = await _responseOperation(
        SupabaseFormsApi(_Backend({..._responseProjection(), 'status': status})),
        operation,
      );
      expect(result.id, 'response-1');
      expect(result.occurrenceId, 'occurrence-1');
      expect(result.status.name, status);
    });
    for (final wrongField in ['occurrence_id', if (operation != 'open') 'id']) {
      test('$operation rejects a receipt for another $wrongField', () async {
        final backend = _Backend({
          ..._responseProjection(),
          'status': operation == 'submit' || operation == 'edit' ? 'submitted' : 'draft',
          wrongField: 'other-context',
        });
        final api = SupabaseFormsApi(backend);
        await expectLater(
          _responseOperation(api, operation),
          throwsA(
            isA<FormApiException>()
                .having((error) => error.kind, 'safe protocol failure', FormApiFailureKind.unknown)
                .having((error) => error.message, 'redacted', isNot(contains('other-context'))),
          ),
        );
      });
    }
  }

  for (final operation in ['submit', 'edit']) {
    test('$operation rejects a receipt that does not confirm its state transition', () async {
      const status = 'draft';
      await expectLater(
        _responseOperation(
          SupabaseFormsApi(_Backend({..._responseProjection(), 'status': status})),
          operation,
        ),
        throwsA(isA<FormApiException>()),
      );
    });
  }

  test('response decoder rejects unknown status and duplicate answer IDs', () async {
    final answer = FormAnswerDto.fromDomain(
      FormAnswer.shortText(itemId: 'item-1', value: 'Sintético'),
    ).toJson();
    for (final patch in <Map<String, Object?>>[
      {'status': 'revoked'},
      {
        'answers': [answer, answer],
      },
    ]) {
      await expectLater(
        _responseOperation(
          SupabaseFormsApi(_Backend({..._responseProjection(), ...patch})),
          'save',
        ),
        throwsA(isA<FormApiException>()),
      );
    }
  });

  test('response reader rejects another occurrence before exposing its definition', () async {
    final definition = FormDefinition(
      id: 'form-1',
      institutionId: 'institution-1',
      title: 'Privado',
      kind: FormKind.form,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      status: FormStatus.published,
      managementVersion: 1,
      sections: const [],
    );
    final backend = _Backend({
      'occurrence': {
        'id': 'other-occurrence',
        'application_id': 'application-1',
        'form_version_id': 'version-1',
        'opens_at': '2026-09-01T00:00:00Z',
        'closes_at': '2026-10-01T00:00:00Z',
        'status': 'open',
        'management_version': 1,
        'form_version_number': 1,
      },
      'definition': FormDefinitionDto.fromDomain(definition).toJson(),
      'participation_id': 'participation-1',
      'can_edit': true,
    });
    await expectLater(
      SupabaseFormsApi(backend).getOccurrenceForResponse('occurrence-1'),
      throwsA(isA<FormApiException>()),
    );
  });

  test('schedule commands preserve schedule id and schedule management version', () async {
    final backend = _Backend(_applicationProjection());
    final api = SupabaseFormsApi(backend);
    final schedule = FormSchedule(
      startsAtLocal: DateTime(2026, 10, 30, 9),
      timeZone: 'America/Sao_Paulo',
      recurrence: const FormRecurrence.once(),
      end: const FormScheduleEnd.never(),
    );

    final saved = await api.saveSchedule(
      FormCommand(
        requestId: 'request-schedule-save',
        expectedVersion: 7,
        payload: FormSaveSchedulePayload(
          applicationId: 'application-1',
          scheduleId: 'schedule-1',
          schedule: schedule,
        ),
      ),
    );
    final savePayload = Map<String, Object?>.from(backend.parameters!['p_payload']! as Map);

    expect(backend.functionName, 'form_save_schedule');
    expect(backend.parameters!['p_expected_version'], 7);
    expect(savePayload['schedule_id'], 'schedule-1');
    expect(saved.schedules.map((item) => item.id), ['schedule-1', 'schedule-2']);

    await api.removeSchedule(
      const FormCommand(
        requestId: 'request-schedule-remove',
        expectedVersion: 9,
        payload: FormRemoveSchedulePayload(scheduleId: 'schedule-2'),
      ),
    );
    final removePayload = Map<String, Object?>.from(backend.parameters!['p_payload']! as Map);
    expect(backend.functionName, 'form_remove_schedule');
    expect(backend.parameters!['p_expected_version'], 9);
    expect(removePayload, {'schedule_id': 'schedule-2'});
  });

  test('asset preparation keeps the short-lived signed upload capability', () async {
    final backend = _Backend({
      'asset_id': 'asset-1',
      'signed_upload_url':
          'https://storage.example.test/object/upload/sign/coelo-forms-private/opaque/image.webp?token=short-lived',
      'expires_at': '2026-08-13T15:00:00Z',
    });
    final api = SupabaseFormsApi(backend);

    final ticket = await api.prepareAssetUpload(
      const FormCommand(
        requestId: 'request-upload-1',
        expectedVersion: 3,
        payload: FormAssetUploadPayload(
          occurrenceId: 'occurrence-1',
          itemId: 'photo-1',
          mimeType: 'image/webp',
          byteLength: 128,
          checksum: 'sha256-value',
        ),
      ),
    );

    expect(ticket.assetId, 'asset-1');
    expect(ticket.signedUploadUrl.queryParameters['token'], 'short-lived');
    expect(backend.mediaEnvelope?['action'], 'prepare');
    expect(backend.mediaEnvelope?['expected_version'], 3);
    expect((backend.mediaEnvelope!['payload']! as Map).containsKey('edit_secret'), isFalse);
  });

  for (final secret in [null, 's' * 43]) {
    test('asset finalize and discard encode optional secret $secret', () async {
      final backend = _Backend({
        'id': 'asset-1',
        'item_id': 'photo-1',
        'mime_type': 'image/webp',
        'byte_length': 128,
      });
      final api = SupabaseFormsApi(backend);
      final command = FormCommand(
        requestId: 'request-1',
        expectedVersion: 0,
        payload: FormAssetIdPayload('asset-1', editSecret: secret),
      );
      await api.finalizeAssetUpload(command);
      expect(backend.mediaEnvelope!['payload'], {'asset_id': 'asset-1', 'edit_secret': ?secret});
      await api.discardAsset(command);
      expect(backend.mediaEnvelope!['payload'], {'asset_id': 'asset-1', 'edit_secret': ?secret});
    });
  }

  test('file job list maps availability without accepting a storage path', () async {
    final backend = _Backend.internal({
      'items': [
        {
          'id': 'job-1',
          'status': 'succeeded',
          'progress': 1,
          'download_available': true,
          'error_code': null,
          'expires_at': '2026-08-20T15:00:00Z',
        },
      ],
      'has_more': false,
      'next_cursor': null,
    });

    final page = await SupabaseFormsApi(backend).listFileJobs(formId: 'form-1');

    expect(page.items.single.downloadAvailable, isTrue);
    expect(page.items.single.downloadPath, isNull);
  });

  test('internal monitor preserves every existing scope filter', () async {
    final backend = _Backend.internal({
      'eligible_count': 40,
      'responded_count': 13,
      'pending_count': 27,
      'is_anonymous': true,
    });
    final monitor = await SupabaseFormsApi(backend).getMonitor(
      FormMonitorQuery(
        formId: 'form-1',
        applicationId: 'application-1',
        occurrenceId: 'occurrence-1',
        scopeId: 'scope-1',
        startsOnOrAfter: DateTime(2026, 9, 1),
        endsOnOrBefore: DateTime(2026, 9, 8),
      ),
    );
    expect(monitor.eligibleCount, 40);
    expect(monitor.respondedCount, 13);
    expect(monitor.pendingCount, 27);
    expect(monitor.isAnonymous, isTrue);
    expect(backend.functionName, 'superadmin_forms_monitor_v2');
    expect(backend.parameters, {
      'p_query': {
        'form_id': 'form-1',
        'application_id': 'application-1',
        'occurrence_id': 'occurrence-1',
        'scope_id': 'scope-1',
        'starts_on_or_after': '2026-09-01',
        'ends_on_or_before': '2026-09-08',
      },
    });
  });

  test(
    'ordinary monitor people keep scoped name cursor and never justify anonymous lookup',
    () async {
      final backend = _Backend.internal(
        _operationPage([_person()], {'name': 'Pessoa', 'id': 'person-1'}),
      );
      final api = SupabaseFormsApi(backend);
      final page = await api.listMonitorPeople(
        const FormMonitorQuery(formId: 'form-1', scopeId: 'scope-1', limit: 12),
      );
      expect(page.items.single.displayName, 'Pessoa');
      expect(page.items.single.responded, isTrue);
      await api.listMonitorPeople(
        FormMonitorQuery(formId: 'form-1', scopeId: 'scope-1', limit: 12, cursor: page.nextCursor),
      );
      expect(backend.functionName, 'superadmin_forms_monitor_people_v2');
      expect(backend.parameters, {
        'p_query': {
          'form_id': 'form-1',
          'application_id': null,
          'occurrence_id': null,
          'starts_on_or_after': null,
          'ends_on_or_before': null,
          'scope_id': 'scope-1',
          'justification': null,
          'cursor_name': 'Pessoa',
          'cursor_id': 'person-1',
          'limit': 12,
        },
      });
    },
  );

  test('identified response cursor round trips its timestamp and response ID', () async {
    final backend = _Backend.internal(
      _operationPage(
        [_summaryProjection()],
        {'submitted_at': '2026-09-08T12:00:00Z', 'id': 'response-1'},
      ),
    );
    final api = SupabaseFormsApi(backend);
    final page = await api.listResponses(
      const FormResponsesQuery(formId: 'form-1', occurrenceId: 'occurrence-1', limit: 10),
    );
    expect(page.items.single.respondentLabel, 'Pessoa');
    expect(page.items.single.submittedAt, DateTime.utc(2026, 9, 8, 12));
    await api.listResponses(
      FormResponsesQuery(
        formId: 'form-1',
        occurrenceId: 'occurrence-1',
        limit: 10,
        cursor: page.nextCursor,
      ),
    );
    expect(backend.functionName, 'superadmin_forms_responses_v2');
    expect(backend.parameters, {
      'p_query': {
        'form_id': 'form-1',
        'occurrence_id': 'occurrence-1',
        'cursor_submitted_at': '2026-09-08T12:00:00Z',
        'cursor_id': 'response-1',
        'limit': 10,
      },
    });
  });

  test('anonymous response cursor needs only opaque ID and strips identity metadata', () async {
    final backend = _Backend.internal(
      _operationPage(
        [
          {..._summaryProjection(), 'identity_mode': 'anonymous'},
        ],
        {'id': 'response-1'},
      ),
    );
    final api = SupabaseFormsApi(backend);
    final page = await api.listResponses(const FormResponsesQuery(formId: 'form-1'));
    expect(page.items.single.respondentLabel, isNull);
    expect(page.items.single.submittedAt, isNull);
    expect(const FormCursorCodec().decode(page.nextCursor!).sortKey, isEmpty);
    await api.listResponses(FormResponsesQuery(formId: 'form-1', cursor: page.nextCursor));
    final query = backend.parameters!['p_query']! as Map;
    expect(query['cursor_id'], 'response-1');
    expect(query['cursor_submitted_at'], isNull);
  });

  test('anonymous page rejects a correlation timestamp in its cursor', () async {
    final backend = _Backend.internal(
      _operationPage(
        [
          {..._summaryProjection(), 'identity_mode': 'anonymous'},
        ],
        {'id': 'response-1', 'submitted_at': '2026-09-08T12:00:00Z'},
      ),
    );
    await expectLater(
      SupabaseFormsApi(backend).listResponses(const FormResponsesQuery(formId: 'form-1')),
      throwsA(
        isA<FormApiException>().having(
          (error) => error.kind,
          'kind',
          FormApiFailureKind.unavailable,
        ),
      ),
    );
  });

  for (final detail in [false, true]) {
    test(
      '${detail ? 'detail' : 'response list'} rejects absent or invalid identity mode',
      () async {
        for (final mode in <Object?>[
          null,
          '',
          'unknown',
          'Anonymous',
          1,
          true,
          <String, Object?>{},
        ]) {
          final summary = _summaryProjection()..['identity_mode'] = mode;
          for (final omitted in [false, true]) {
            if (omitted) summary.remove('identity_mode');
            final data = detail
                ? {...summary, 'answers': <Object?>[]}
                : _operationPage([summary], {'id': 'response-1'});
            final api = SupabaseFormsApi(_Backend.internal(data));
            await expectLater(
              detail
                  ? api.getResponseDetail('response-1')
                  : api.listResponses(const FormResponsesQuery(formId: 'form-1')),
              throwsA(
                isA<FormApiException>().having(
                  (error) => error.kind,
                  'kind',
                  FormApiFailureKind.unavailable,
                ),
              ),
              reason: 'mode=$mode; omitted=$omitted',
            );
          }
        }
      },
    );
  }

  test('anonymous detail strips unexpected identity and timestamp from the receipt', () async {
    final backend = _Backend.internal({
      ..._summaryProjection(),
      'identity_mode': 'anonymous',
      'answers': <Object?>[],
    });
    final detail = await SupabaseFormsApi(backend).getResponseDetail('response-1');
    expect(detail.summary.respondentLabel, isNull);
    expect(detail.summary.submittedAt, isNull);
    expect(detail.summary.id, 'response-1');
  });

  test(
    'detail uses internal envelope and preserves typed answers without invented labels',
    () async {
      final backend = _Backend.internal({
        ..._summaryProjection(),
        'answers': [
          FormAnswerDto.fromDomain(
            FormAnswer.shortText(itemId: 'item-1', value: 'Resposta autorizada'),
          ).toJson(),
        ],
      });
      final detail = await SupabaseFormsApi(backend).getResponseDetail('response-1');
      expect(detail.summary.formVersionId, 'version-1');
      expect(detail.originalVersion, isNull);
      expect(
        FormAnswerDto.fromDomain(detail.answers['item-1']!).toJson()['text_value'],
        'Resposta autorizada',
      );
      expect(backend.functionName, 'superadmin_forms_response_detail_v2');
      expect(backend.parameters, {
        'p_query': {'response_id': 'response-1'},
      });
    },
  );

  test('detail rejects mismatched response and duplicate answers', () async {
    final answer = FormAnswerDto.fromDomain(
      FormAnswer.shortText(itemId: 'item-1', value: 'Resposta'),
    ).toJson();
    for (final patch in [
      {
        'id': 'other-response',
        'answers': [answer],
      },
      {
        'answers': [answer, answer],
      },
    ]) {
      await expectLater(
        SupabaseFormsApi(
          _Backend.internal({..._summaryProjection(), ...patch}),
        ).getResponseDetail('response-1'),
        throwsA(
          isA<FormApiException>().having(
            (error) => error.kind,
            'kind',
            FormApiFailureKind.unavailable,
          ),
        ),
      );
    }
  });

  test('file job cursor preserves created time without forwarding private locators', () async {
    final backend = _Backend.internal(
      _operationPage(
        [
          {
            'id': 'job-1',
            'status': 'processing',
            'progress': .4,
            'download_path': 'https://private.invalid/token',
          },
        ],
        {'created_at': '2026-09-08T10:00:00Z', 'id': 'job-1'},
      ),
    );
    final api = SupabaseFormsApi(backend);
    final page = await api.listFileJobs(formId: 'form-1', limit: 8);
    expect(page.items.single.progress, .4);
    expect(page.items.single.downloadPath, isNull);
    await api.listFileJobs(formId: 'form-1', limit: 8, cursor: page.nextCursor);
    expect(backend.functionName, 'superadmin_forms_file_jobs_v2');
    expect(backend.parameters, {
      'p_query': {
        'form_id': 'form-1',
        'cursor_created_at': '2026-09-08T10:00:00Z',
        'cursor_id': 'job-1',
        'limit': 8,
      },
    });
  });

  test('every internal operation denies error envelopes before inspecting data', () async {
    for (final operation in _internalOperations) {
      final backend = _Backend({
        'ok': false,
        'data': {'secret': 'other-tenant'},
        'error': {'code': 'SAI_PERMISSION_DENIED', 'message': 'private SQL other-tenant'},
      });
      await expectLater(
        operation(SupabaseFormsApi(backend)),
        throwsA(
          isA<FormApiException>()
              .having((error) => error.kind, 'kind', FormApiFailureKind.unauthorized)
              .having((error) => error.message, 'redacted', isNot(contains('other-tenant'))),
        ),
      );
    }
  });

  test('internal errors map SAI codes and hide backend diagnostics', () async {
    for (final (code, kind) in [
      ('SAI_AUTH_REQUIRED', FormApiFailureKind.unauthorized),
      ('SAI_MEMBERSHIP_REVOKED', FormApiFailureKind.unauthorized),
      ('SAI_INVALID_ARGUMENT', FormApiFailureKind.validation),
      ('SAI_CONCURRENT_CHANGE', FormApiFailureKind.conflict),
      ('SAI_INTERNAL_ERROR', FormApiFailureKind.unavailable),
    ]) {
      for (final backend in [
        _Backend({
          'ok': false,
          'data': null,
          'error': {'code': code, 'message': 'private SQL'},
        }),
        _Backend.failure(code, failureMessage: 'private SQL'),
      ]) {
        await expectLater(
          SupabaseFormsApi(backend).getMonitor(const FormMonitorQuery(formId: 'form-1')),
          throwsA(
            isA<FormApiException>()
                .having((error) => error.kind, 'kind', kind)
                .having((error) => error.message, 'redacted', isNot(contains('SQL'))),
          ),
        );
      }
    }
  });

  test('every internal operation rejects missing or contradictory envelopes', () async {
    for (final operation in _internalOperations) {
      for (final envelope in [
        null,
        {'eligible_count': 1},
        {
          'ok': true,
          'data': <String, Object?>{},
          'error': {'code': 'SAI_PERMISSION_DENIED'},
        },
        {'ok': 'true', 'data': <String, Object?>{}, 'error': null},
        {'ok': true, 'data': null, 'error': null},
        {'ok': true, 'data': <String, Object?>{}, 'error': null, 'unexpected': true},
      ]) {
        await expectLater(
          operation(SupabaseFormsApi(_Backend(envelope))),
          throwsA(
            isA<FormApiException>().having(
              (error) => error.kind,
              'kind',
              FormApiFailureKind.unavailable,
            ),
          ),
        );
      }
    }
  });

  test('operational pages reject contradictory cursors and oversized pages', () async {
    for (final data in [
      {
        'items': <Object?>[],
        'has_more': true,
        'next_cursor': {'id': 'response-1'},
      },
      {
        'items': [_summaryProjection()],
        'has_more': true,
        'next_cursor': null,
      },
      {
        'items': [_summaryProjection()],
        'has_more': false,
        'next_cursor': {'id': 'response-1'},
      },
      _operationPage([_summaryProjection()], {'id': 'response-1', 'person_id': 'leaked'}),
      _operationPage([_summaryProjection(), _summaryProjection()], null),
    ]) {
      await expectLater(
        SupabaseFormsApi(
          _Backend.internal(data),
        ).listResponses(const FormResponsesQuery(formId: 'form-1', limit: 1)),
        throwsA(
          isA<FormApiException>().having(
            (error) => error.kind,
            'kind',
            FormApiFailureKind.unavailable,
          ),
        ),
      );
    }
  });

  test('nominal anonymous lookup preserves legacy realm and explicit justification', () async {
    final backend = _Backend(_operationPage([_person()], null));
    await SupabaseFormsApi(backend).anonymousParticipationLookup(
      const FormAnonymousParticipationQuery(
        formId: 'form-1',
        occurrenceId: 'occurrence-1',
        justification: 'Motivo autorizado',
      ),
    );
    expect(backend.functionName, FormsRpc.anonymousParticipationLookup.functionName);
    expect((backend.parameters!['p_query']! as Map)['justification'], 'Motivo autorizado');
  });
}

Map<String, Object?> _operationPage(List<Object?> items, Map<String, Object?>? cursor) => {
  'items': items,
  'has_more': cursor != null,
  'next_cursor': cursor,
};
Map<String, Object?> _person() => {
  'person_id': 'person-1',
  'display_name': 'Pessoa',
  'profile_label': 'Perfil',
  'context_label': 'Contexto',
  'responded': true,
};
Map<String, Object?> _summaryProjection() => {
  'id': 'response-1',
  'occurrence_id': 'occurrence-1',
  'form_version_id': 'version-1',
  'identity_mode': 'identified',
  'submitted_at': '2026-09-08T12:00:00Z',
  'respondent_label': 'Pessoa',
};
final _internalOperations = <Future<Object?> Function(SupabaseFormsApi)>[
  (api) => api.getMonitor(const FormMonitorQuery(formId: 'form-1')),
  (api) => api.listMonitorHierarchy(const FormMonitorQuery(formId: 'form-1')),
  (api) => api.listMonitorPeople(const FormMonitorQuery(formId: 'form-1')),
  (api) => api.listResponses(const FormResponsesQuery(formId: 'form-1')),
  (api) => api.getResponseDetail('response-1'),
  (api) => api.listFileJobs(formId: 'form-1'),
  (api) => api.requestExport(
    const FormCommand(
      requestId: 'request-1',
      expectedVersion: 1,
      payload: FormExportPayload(formId: 'form-1', kind: FormExportKind.xlsx),
    ),
  ),
];

Map<String, Object?> _responseProjection() => {
  'id': 'response-1',
  'occurrence_id': 'occurrence-1',
  'status': 'draft',
  'management_version': 2,
  'answers': <Object?>[],
};

Future<FormResponseDraft> _responseOperation(SupabaseFormsApi api, String operation) {
  final command = FormCommand(
    requestId: 'request-1',
    expectedVersion: 1,
    payload: FormResponseDraftPayload(
      occurrenceId: 'occurrence-1',
      responseId: 'response-1',
      participationId: 'participation-1',
      answers: {},
    ),
  );
  return switch (operation) {
    'open' => api.openResponseDraft(
      const FormCommand(
        requestId: 'request-1',
        expectedVersion: 0,
        payload: FormOpenResponseDraftPayload(
          occurrenceId: 'occurrence-1',
          participationId: 'participation-1',
          identityMode: FormIdentityMode.identified,
        ),
      ),
    ),
    'save' => api.saveResponseDraft(command),
    'submit' => api.submitResponse(command),
    'edit' => api.editResponse(command),
    _ => throw StateError('Invalid fixture operation'),
  };
}

Map<String, Object?> _applicationProjection() => {
  'id': 'application-1',
  'form_id': 'form-1',
  'institution_id': 'institution-1',
  'name': 'Famílias',
  'status': 'active',
  'opens_for_days': 7,
  'audience_rules': <Object?>[],
  'schedules': [
    {
      'id': 'schedule-1',
      'status': 'active',
      'management_version': 7,
      'starts_at_local': '2026-10-30T09:00:00',
      'time_zone': 'America/Sao_Paulo',
      'recurrence': {
        'kind': 'once',
        'interval': 1,
        'weekdays': <Object?>[],
        'day': null,
        'use_last_day': false,
      },
      'end': {'kind': 'never', 'date': null, 'count': null},
      'reminders': <Object?>[],
    },
    {
      'id': 'schedule-2',
      'status': 'active',
      'management_version': 9,
      'starts_at_local': '2026-11-02T14:00:00',
      'time_zone': 'America/Sao_Paulo',
      'recurrence': {
        'kind': 'once',
        'interval': 1,
        'weekdays': <Object?>[],
        'day': null,
        'use_last_day': false,
      },
      'end': {'kind': 'never', 'date': null, 'count': null},
      'reminders': <Object?>[],
    },
  ],
  'management_version': 3,
};

final class _Backend implements FormsBackendGateway {
  _Backend(this.response) : failureCode = null, failureMessage = '';
  _Backend.internal(Map<String, Object?> data)
    : response = {'ok': true, 'data': data, 'error': null},
      failureCode = null,
      failureMessage = '';
  _Backend.failure(this.failureCode, {this.failureMessage = 'denied'}) : response = null;

  final Object? response;
  final String? failureCode;
  final String failureMessage;
  String? functionName;
  Map<String, Object?>? parameters;
  Map<String, Object?>? mediaEnvelope;

  @override
  Future<Object?> media(Map<String, Object?> envelope) async {
    mediaEnvelope = envelope;
    return response;
  }

  @override
  Future<Object?> rpc(String functionName, Map<String, Object?> parameters) async {
    this.functionName = functionName;
    this.parameters = parameters;
    if (failureCode case final code?) {
      throw FormsBackendFailure(code: code, message: failureMessage);
    }
    return response;
  }
}
