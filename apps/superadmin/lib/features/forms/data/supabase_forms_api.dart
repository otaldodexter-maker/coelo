import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';

import 'forms_backend_gateway.dart';
import 'forms_editor_context.dart';
import 'forms_file_jobs_reader.dart';

final class SupabaseFormsApi
    implements FormsApi, FormsEditorContextApi, FormsResponseContextReader, FormsFileJobsReader {
  const SupabaseFormsApi(this._backend, {FormCursorCodec cursorCodec = const FormCursorCodec()})
    : _cursorCodec = cursorCodec;

  final FormsBackendGateway _backend;
  final FormCursorCodec _cursorCodec;

  @override
  Future<FormsEditorContext> getEditorContext() => _guard(() async {
    final payload = _map(await _backend.rpc('superadmin_forms_context', const {}));
    final sharedCapabilities = payload['capabilities'] is Map
        ? Map<String, Object?>.from(payload['capabilities']! as Map)
        : const <String, Object?>{};
    final institutions = _list(payload, 'institutions')
        .map(_map)
        .map((value) {
          final capabilities = value['capabilities'] is Map
              ? Map<String, Object?>.from(value['capabilities']! as Map)
              : sharedCapabilities;
          return FormsEditorInstitution(
            id: _string(value, 'id'),
            name:
                value['name'] as String? ?? value['public_name'] as String? ?? _string(value, 'id'),
            canManageForms: _capability(capabilities, const [
              'manage',
              'can_manage_forms',
              'can_create_forms',
              'forms_manage',
            ]),
            canPublishForms: _capability(capabilities, const [
              'publish',
              'can_publish_forms',
              'forms_publish',
            ]),
          );
        })
        .toList(growable: false);
    return FormsEditorContext(
      institutions: List.unmodifiable(institutions),
      canManageApplications: _capability(sharedCapabilities, const [
        'manage_applications',
        'can_manage_applications',
        'forms_manage_applications',
      ]),
      canTransferCrossInstitution: _capability(sharedCapabilities, const [
        'transfer_cross_institution',
        'forms_transfer_cross_institution',
      ]),
    );
  });

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) =>
      _guard(() async {
        final cursor = _decodeCursor(query.cursor);
        final payload = _map(
          await _backend.rpc(FormsRpc.list.functionName, {
            'p_query': {
              'institution_id': query.institutionId,
              'search': query.search,
              'statuses': query.statuses.map(_status).toList(growable: false),
              'operational_statuses': query.operationalStatuses
                  .map((status) => status.name)
                  .toList(growable: false),
              'kinds': query.kinds.map(_kind).toList(growable: false),
              'starts_on_or_after': _date(query.startsOnOrAfter),
              'ends_on_or_before': _date(query.endsOnOrBefore),
              'cursor_updated_at': cursor?.sortKey,
              'cursor_id': cursor?.id,
              'limit': query.limit,
            },
          }),
        );
        return _page(
          payload,
          (item) => FormDirectoryItem(
            id: _string(item, 'id'),
            title: _string(item, 'title'),
            kind: _formKind(_string(item, 'kind')),
            status: _formStatus(_string(item, 'status')),
            operationalStatus: _formOperationalStatus(_string(item, 'operational_status')),
            identityMode: _identityMode(_string(item, 'identity_mode')),
            updatedAt: _dateTime(item, 'updated_at'),
            managementVersion: _integer(item, 'management_version'),
          ),
          cursorKey: 'updated_at',
        );
      });

  @override
  Future<FormOverview> getOverview(String formId) => _guard(() async {
    final payload = _map(
      await _backend.rpc(FormsRpc.getOverview.functionName, {'p_form_id': formId}),
    );
    final definition = Map<String, Object?>.from(payload)
      ..remove('application_count')
      ..remove('occurrence_count')
      ..remove('response_count');
    return FormOverview(
      definition: FormDefinitionDto.fromJson(definition).toDomain(),
      applicationCount: _integer(payload, 'application_count'),
      occurrenceCount: _integer(payload, 'occurrence_count'),
      responseCount: _integer(payload, 'response_count'),
    );
  });

  @override
  Future<FormEditorProjection> getEditor(String formId) => _guard(
    () async => FormEditorProjectionDto.fromJson(
      _map(await _backend.rpc(FormsRpc.getEditor.functionName, {'p_form_id': formId})),
    ).toDomain(),
  );

  @override
  Future<FormCursorPage<FormAudienceCandidate>> listAudienceCandidates(
    FormAudienceCandidatesQuery query,
  ) => _guard(() async {
    final cursor = _decodeCursor(query.cursor);
    final payload = _map(
      await _backend.rpc(FormsRpc.listAudienceCandidates.functionName, {
        'p_query': {
          'institution_id': query.institutionId,
          'kind': _audienceKind(query.kind),
          'search': query.search,
          'cursor_label': cursor?.sortKey,
          'cursor_id': cursor?.id,
          'limit': query.limit,
        },
      }),
    );
    return _page(
      payload,
      (item) => FormAudienceCandidate(
        id: _string(item, 'id'),
        label: _string(item, 'label'),
        kind: _audienceKindFromWire(_string(item, 'kind')),
      ),
      cursorKey: 'label',
    );
  });

  @override
  Future<FormDefinition> saveDraft(FormCommand<FormDefinition> command) => _definitionCommand(
    FormsRpc.saveDraft,
    command,
    // Status e versao pertencem a projecao de leitura; form_save_draft
    // (app_private.form_assert_payload_keys) recusa o rascunho com
    // 22023 "form draft contains unknown keys" quando eles viajam no
    // payload. A versao esperada vai em p_expected_version.
    (value) => FormDefinitionDto.fromDomain(value).toJson()
      ..remove('status')
      ..remove('management_version'),
  );

  @override
  Future<FormDefinition> publish(FormCommand<FormIdPayload> command) =>
      _definitionCommand(FormsRpc.publish, command, (value) => {'form_id': value.formId});

  @override
  Future<FormDefinition> duplicate(FormCommand<FormIdPayload> command) =>
      _definitionCommand(FormsRpc.duplicate, command, (value) => {'form_id': value.formId});

  @override
  Future<FormDefinition> copyOrMove(FormCommand<FormCopyOrMovePayload> command) =>
      _definitionCommand(
        FormsRpc.copyOrMove,
        command,
        (value) => {
          'form_id': value.formId,
          'target_institution_id': value.targetInstitutionId,
          'mode': value.mode.name,
        },
      );

  @override
  Future<void> archiveOrDelete(FormCommand<FormArchiveOrDeletePayload> command) => _guard(() async {
    await _command(
      FormsRpc.archiveOrDelete,
      command,
      (value) => {'form_id': value.formId, 'action': value.action.name},
    );
  });

  @override
  Future<FormApplication> saveApplication(FormCommand<FormSaveApplicationPayload> command) =>
      _guard(
        () async => FormApplicationDto.fromJson(
          _map(
            await _command(
              FormsRpc.saveApplication,
              command,
              (value) => _applicationPayload(value.application),
            ),
          ),
        ).toDomain(),
      );

  @override
  Future<FormApplication> saveSchedule(FormCommand<FormSaveSchedulePayload> command) => _guard(
    () async => FormApplicationDto.fromJson(
      _map(await _command(FormsRpc.saveSchedule, command, _schedulePayload)),
    ).toDomain(),
  );

  @override
  Future<FormApplication> removeSchedule(FormCommand<FormRemoveSchedulePayload> command) => _guard(
    () async => FormApplicationDto.fromJson(
      _map(
        await _command(
          FormsRpc.removeSchedule,
          command,
          (value) => {'schedule_id': value.scheduleId},
        ),
      ),
    ).toDomain(),
  );

  @override
  Future<FormOccurrenceForResponse> getOccurrenceForResponse(String occurrenceId) =>
      _guard(() async {
        final payload = _map(
          await _backend.rpc(FormsRpc.getOccurrenceForResponse.functionName, {
            'p_occurrence_id': occurrenceId,
          }),
        );
        final occurrence = _map(payload['occurrence']);
        if (_string(occurrence, 'id') != occurrenceId) {
          throw const WireFormatException('Response occurrence correlation is invalid.');
        }
        final definition = FormDefinitionDto.fromJson(_map(payload['definition'])).toDomain();
        final domainOccurrence = FormOccurrence(
          id: _string(occurrence, 'id'),
          applicationId: _string(occurrence, 'application_id'),
          formVersionId: _string(occurrence, 'form_version_id'),
          opensAt: _dateTime(occurrence, 'opens_at'),
          closesAt: _dateTime(occurrence, 'closes_at'),
          status: _occurrenceStatus(_string(occurrence, 'status')),
          managementVersion: _integer(occurrence, 'management_version'),
        );
        return FormOccurrenceForResponse(
          occurrence: domainOccurrence,
          version: FormVersion(
            id: domainOccurrence.formVersionId,
            formId: definition.id,
            number: _integer(occurrence, 'form_version_number'),
            sections: definition.sections,
            isPublished: true,
          ),
          participationId: _string(payload, 'participation_id'),
          identityMode: definition.identityMode,
          canEdit: _boolean(payload, 'can_edit'),
        );
      });

  @override
  Future<FormResponseDraft> openResponseDraft(FormCommand<FormOpenResponseDraftPayload> command) =>
      _responseCommand(
        FormsRpc.openResponseDraft,
        command,
        (value) => {
          'occurrence_id': value.occurrenceId,
          'participation_id': value.participationId,
          'identity_mode': _identity(value.identityMode),
          'edit_secret': value.editSecret,
        },
      );

  @override
  Future<FormResponseDraft> saveResponseDraft(FormCommand<FormResponseDraftPayload> command) =>
      _responseCommand(FormsRpc.saveResponseDraft, command, _responsePayload);

  @override
  Future<FormResponseDraft> submitResponse(FormCommand<FormResponseDraftPayload> command) =>
      _responseCommand(FormsRpc.submitResponse, command, _responsePayload);

  @override
  Future<FormResponseDraft> editResponse(FormCommand<FormResponseDraftPayload> command) =>
      _responseCommand(FormsRpc.editResponse, command, _responsePayload);

  @override
  Future<FormMonitorProjection> getMonitor(FormMonitorQuery query) => _internalOperation(() async {
    final payload = await _internalRpc('superadmin_forms_monitor_v2', {
      'p_query': _monitorQuery(query, includeCursor: false),
    });
    return FormMonitorProjection(
      eligibleCount: _integer(payload, 'eligible_count'),
      respondedCount: _integer(payload, 'responded_count'),
      pendingCount: _integer(payload, 'pending_count'),
      isAnonymous: _boolean(payload, 'is_anonymous'),
    );
  });

  @override
  Future<FormCursorPage<FormMonitorScope>> listMonitorHierarchy(FormMonitorQuery query) =>
      _internalOperation(() async {
        final cursor = _decodeCursor(query.cursor);
        final payload = await _internalRpc('superadmin_forms_monitor_hierarchy_v2', {
          'p_query': {
            ..._monitorQuery(query, includeCursor: false),
            'cursor_label': cursor?.sortKey,
            'cursor_id': cursor?.id,
            'limit': query.limit,
          },
        });
        return _operationalPage(
          payload,
          (item) => FormMonitorScope(
            scopeId: _string(item, 'scope_id'),
            scopeKind: FormMonitorScopeKind.values.firstWhere(
              (kind) => kind.name == _string(item, 'scope_kind'),
            ),
            label: _string(item, 'label'),
            eligibleCount: _integer(item, 'eligible_count'),
            respondedCount: _integer(item, 'responded_count'),
            pendingCount: _integer(item, 'pending_count'),
          ),
          cursorKey: 'label',
          limit: query.limit,
        );
      });

  @override
  Future<FormCursorPage<FormMonitorPerson>> listMonitorPeople(FormMonitorQuery query) =>
      _internalOperation(() async {
        final cursor = _decodeCursor(query.cursor);
        final payload = await _internalRpc('superadmin_forms_monitor_people_v2', {
          'p_query': {
            'form_id': query.formId,
            'application_id': query.applicationId,
            'occurrence_id': query.occurrenceId,
            'starts_on_or_after': _date(query.startsOnOrAfter),
            'ends_on_or_before': _date(query.endsOnOrBefore),
            'scope_id': query.scopeId,
            'justification': null,
            'cursor_name': cursor?.sortKey,
            'cursor_id': cursor?.id,
            'limit': query.limit,
          },
        });
        return _operationalPage(payload, _monitorPerson, cursorKey: 'name', limit: query.limit);
      });

  @override
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query) =>
      _internalOperation(() async {
        final cursor = _decodeCursor(query.cursor);
        final payload = await _internalRpc('superadmin_forms_responses_v2', {
          'p_query': {
            'form_id': query.formId,
            'occurrence_id': query.occurrenceId,
            'cursor_submitted_at': cursor == null || cursor.sortKey.isEmpty ? null : cursor.sortKey,
            'cursor_id': cursor?.id,
            'limit': query.limit,
          },
        });
        if (payload['next_cursor'] != null &&
            _list(payload, 'items').map(_map).any((item) => item['identity_mode'] == 'anonymous') &&
            _map(payload['next_cursor']).containsKey('submitted_at')) {
          throw const WireFormatException(
            'Anonymous response cursor must not contain a timestamp.',
          );
        }
        return _operationalPage(
          payload,
          _responseSummary,
          cursorKey: 'submitted_at',
          limit: query.limit,
          allowIdOnlyCursor: true,
        );
      });

  @override
  Future<FormResponseDetail> getResponseDetail(String responseId) =>
      _readResponseDetail(responseId);

  @override
  Future<FormResponseDetail> getResponseDetailInForm(String formId, String responseId) =>
      _readResponseDetail(responseId, formId: formId);

  Future<FormResponseDetail> _readResponseDetail(String responseId, {String? formId}) =>
      _internalOperation(() async {
        final payload = await _internalRpc('superadmin_forms_response_detail_v2', {
          'p_query': {'response_id': responseId, 'form_id': ?formId},
        });
        if (_string(payload, 'id') != responseId ||
            (formId != null && _string(payload, 'form_id') != formId)) {
          throw const WireFormatException('Response detail correlation is invalid.');
        }
        final answers = _list(payload, 'answers')
            .map(_map)
            .map(FormAnswerDto.fromJson)
            .map((dto) => dto.toDomain())
            .toList(growable: false);
        if (answers.map((answer) => answer.itemId).toSet().length != answers.length) {
          throw const WireFormatException('Response detail contains duplicate answers.');
        }
        final summary = _responseSummary(payload);
        return FormResponseDetail(
          summary: summary,
          answers: {for (final answer in answers) answer.itemId: answer},
          originalVersion: _originalResponseVersion(payload, summary, answers),
        );
      });

  @override
  Future<FormAssetUploadTicket> prepareAssetUpload(FormCommand<FormAssetUploadPayload> command) =>
      _guard(() async {
        final payload = _map(
          await _mediaCommand(
            'prepare',
            command,
            (value) => {
              'occurrence_id': value.occurrenceId,
              'item_id': value.itemId,
              'mime_type': value.mimeType,
              'byte_length': value.byteLength,
              'checksum': value.checksum,
              if (value.editSecret != null) 'edit_secret': value.editSecret,
            },
          ),
        );
        return FormAssetUploadTicket(
          assetId: _string(payload, 'asset_id'),
          uploadUrl: Uri.parse(_string(payload, 'upload_url')),
          requiredHeaders: _stringMap(payload['required_headers']),
          expiresAt: _dateTime(payload, 'expires_at'),
        );
      });

  @override
  Future<FormAsset> finalizeAssetUpload(FormCommand<FormAssetIdPayload> command) =>
      _guard(() async {
        final payload = _map(
          await _mediaCommand(
            'finalize',
            command,
            (value) => {
              'asset_id': value.assetId,
              if (value.editSecret != null) 'edit_secret': value.editSecret,
            },
          ),
        );
        return FormAsset(
          id: _string(payload, 'id'),
          itemId: _string(payload, 'item_id'),
          mimeType: _string(payload, 'mime_type'),
          byteLength: _integer(payload, 'byte_length'),
        );
      });

  @override
  Future<void> discardAsset(FormCommand<FormAssetIdPayload> command) => _guard(() async {
    await _mediaCommand(
      'discard',
      command,
      (value) => {
        'asset_id': value.assetId,
        if (value.editSecret != null) 'edit_secret': value.editSecret,
      },
    );
  });

  @override
  Future<FormFileJob> requestExport(FormCommand<FormExportPayload> command) async {
    if (command.payload.kind != FormExportKind.xlsx) {
      throw const FormApiException(FormApiFailureKind.unavailable, 'Disponível depois do MVP');
    }
    if (command.payload.occurrenceId != null) {
      throw const FormApiException(
        FormApiFailureKind.validation,
        'A exportação XLSX reúne todas as respostas do formulário.',
      );
    }
    return _internalOperation(
      () async => _fileJob(
        await _internalRpc('superadmin_form_request_xlsx_v2', {
          'p_request_id': command.requestId,
          'p_expected_version': command.expectedVersion,
          'p_payload': {'form_id': command.payload.formId},
        }),
      ),
    );
  }

  @override
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  }) => _internalOperation(() async {
    final payload = await _fileJobsPayload(formId: formId, cursor: cursor, limit: limit);
    return _operationalPage(payload, _fileJob, cursorKey: 'created_at', limit: limit);
  });

  @override
  Future<FormsFileJobsContext> listFileJobsContext({
    required String formId,
    String? cursor,
    int limit = 25,
  }) => _internalOperation(() async {
    final payload = await _fileJobsPayload(formId: formId, cursor: cursor, limit: limit);
    final receivedFormId = _string(payload, 'form_id');
    final version = payload['management_version'];
    if (receivedFormId.isEmpty || receivedFormId != formId || version is! int || version < 1) {
      throw const WireFormatException('Invalid file-jobs context.');
    }
    return FormsFileJobsContext(
      formId: receivedFormId,
      managementVersion: version,
      page: _operationalPage(payload, _fileJob, cursorKey: 'created_at', limit: limit),
    );
  });

  Future<Map<String, Object?>> _fileJobsPayload({
    required String formId,
    required String? cursor,
    required int limit,
  }) {
    final decoded = _decodeCursor(cursor);
    return _internalRpc('superadmin_forms_file_jobs_v2', {
      'p_query': {
        'form_id': formId,
        'cursor_created_at': decoded?.sortKey,
        'cursor_id': decoded?.id,
        'limit': limit,
      },
    });
  }

  @override
  Future<FormCursorPage<FormMonitorPerson>> anonymousParticipationLookup(
    FormAnonymousParticipationQuery query,
  ) => _guard(() async {
    final cursor = _decodeCursor(query.cursor);
    final payload = _map(
      await _backend.rpc(FormsRpc.anonymousParticipationLookup.functionName, {
        'p_query': {
          'form_id': query.formId,
          'occurrence_id': query.occurrenceId,
          'justification': query.justification,
          'cursor_name': cursor?.sortKey,
          'cursor_id': cursor?.id,
          'limit': query.limit,
        },
      }),
    );
    return _monitorPeoplePage(payload);
  });

  @override
  Future<FormFileJob> requestAnonymousParticipationExport(
    FormCommand<FormExportPayload> command,
  ) async {
    throw const FormApiException(FormApiFailureKind.unavailable, 'Disponível depois do MVP');
  }

  Future<FormDefinition> _definitionCommand<T>(
    FormsRpc rpc,
    FormCommand<T> command,
    Map<String, Object?> Function(T value) encode,
  ) => _guard(
    () async => FormDefinitionDto.fromJson(_map(await _command(rpc, command, encode))).toDomain(),
  );

  Future<FormResponseDraft> _responseCommand<T>(
    FormsRpc rpc,
    FormCommand<T> command,
    Map<String, Object?> Function(T value) encode,
  ) => _guard(() async {
    final (occurrenceId, responseId) = switch (command.payload) {
      FormResponseDraftPayload(:final occurrenceId, :final responseId) => (
        occurrenceId,
        responseId,
      ),
      FormOpenResponseDraftPayload(:final occurrenceId) => (occurrenceId, null),
      _ => throw const WireFormatException('Response command type is invalid.'),
    };
    final payload = encode(command.payload);
    final result = _responseDraft(_map(await _command(rpc, command, (_) => payload)));
    if (result.occurrenceId != occurrenceId || (responseId != null && result.id != responseId)) {
      throw const WireFormatException('Response receipt correlation is invalid.');
    }
    // Editing records another revision of a submitted response; the canonical
    // mutation does not reopen it as a draft.
    if ((rpc == FormsRpc.submitResponse || rpc == FormsRpc.editResponse) &&
        result.status != FormResponseDraftStatus.submitted) {
      throw const WireFormatException('Response transition was not confirmed.');
    }
    return result;
  });

  Future<Map<String, Object?>> _internalRpc(
    String functionName,
    Map<String, Object?> parameters,
  ) async {
    final envelope = _map(await _backend.rpc(functionName, parameters));
    // A denied envelope never exposes data, even if it contains a projection.
    if (envelope['ok'] == false) throw _internalFailure(_map(envelope['error'])['code']);
    requireOnlyKeys(envelope, const {'ok', 'data', 'error'}, context: 'forms_operation');
    if (envelope['ok'] != true || envelope['error'] != null) throw const FormatException();
    return _map(envelope['data']);
  }

  Future<T> _internalOperation<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FormApiException {
      rethrow;
    } on FormsBackendFailure catch (error) {
      throw _internalFailure(error.code);
    } catch (_) {
      throw _internalFailure(null);
    }
  }

  FormCursorPage<T> _operationalPage<T>(
    Map<String, Object?> payload,
    T Function(Map<String, Object?> item) decode, {
    required String cursorKey,
    required int limit,
    bool allowIdOnlyCursor = false,
  }) {
    final items = _list(payload, 'items');
    final more = _boolean(payload, 'has_more');
    final next = payload['next_cursor'];
    if (items.length > limit ||
        (more && (items.isEmpty || next == null)) ||
        (!more && next != null)) {
      throw const WireFormatException('Invalid operational page.');
    }
    if (next != null) {
      final cursor = _map(next);
      final idOnly = allowIdOnlyCursor && !cursor.containsKey(cursorKey);
      requireOnlyKeys(cursor, {if (!idOnly) cursorKey, 'id'}, context: 'operation_cursor');
      final sortKey = idOnly ? '' : _string(cursor, cursorKey);
      final id = _string(cursor, 'id');
      if (id.isEmpty || (!idOnly && sortKey.isEmpty)) throw const FormatException();
      return FormCursorPage(
        items: items.map(_map).map(decode).toList(growable: false),
        nextCursor: _cursorCodec.encode(FormCursor(sortKey: sortKey, id: id)),
      );
    }
    return FormCursorPage(
      items: items.map(_map).map(decode).toList(growable: false),
      nextCursor: null,
    );
  }

  Future<Object?> _command<T>(
    FormsRpc rpc,
    FormCommand<T> command,
    Map<String, Object?> Function(T value) encode,
  ) => _backend.rpc(rpc.functionName, {
    'p_request_id': command.requestId,
    'p_expected_version': command.expectedVersion,
    'p_payload': encode(command.payload),
  });

  Future<Object?> _mediaCommand<T>(
    String action,
    FormCommand<T> command,
    Map<String, Object?> Function(T value) encode,
  ) => _backend.media({
    'action': action,
    'request_id': command.requestId,
    'expected_version': command.expectedVersion,
    'payload': encode(command.payload),
  });

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FormApiException {
      rethrow;
    } on FormsBackendFailure catch (error) {
      final kind = _failureKind(error.code);
      throw FormApiException(
        kind,
        _detailMessage(error.detail) ?? _failureMessage(kind),
        details: {if (error.detail != null) 'code': error.detail},
      );
    } on WireFormatException {
      throw FormApiException(
        FormApiFailureKind.unknown,
        _failureMessage(FormApiFailureKind.unknown),
      );
    } on FormatException {
      throw FormApiException(
        FormApiFailureKind.unknown,
        _failureMessage(FormApiFailureKind.unknown),
      );
    } on Object {
      throw FormApiException(
        FormApiFailureKind.unknown,
        _failureMessage(FormApiFailureKind.unknown),
      );
    }
  }

  FormCursor? _decodeCursor(String? value) => value == null ? null : _cursorCodec.decode(value);

  FormCursorPage<T> _page<T>(
    Map<String, Object?> payload,
    T Function(Map<String, Object?> item) decode, {
    required String cursorKey,
  }) {
    final items = _list(payload, 'items').map(_map).map(decode).toList(growable: false);
    final next = payload['next_cursor'];
    return FormCursorPage(
      items: items,
      nextCursor: next == null
          ? null
          : _cursorCodec.encode(
              FormCursor(sortKey: _string(_map(next), cursorKey), id: _string(_map(next), 'id')),
            ),
    );
  }

  FormCursorPage<FormMonitorPerson> _monitorPeoplePage(Map<String, Object?> payload) =>
      _page(payload, _monitorPerson, cursorKey: 'name');
}

Map<String, Object?> _applicationPayload(FormApplication value) => {
  // id vazio = distribuicao nova; o servidor gera o uuid (ver forms_schedule_dialog).
  'id': value.id.isEmpty ? null : value.id,
  'form_id': value.formId,
  'institution_id': value.institutionId,
  'name': value.name,
  'status': value.status.name,
  'opens_for_days': value.opensForDays,
  'rules': [
    for (var index = 0; index < value.audienceRules.length; index++)
      {
        'kind': _audienceKind(value.audienceRules[index].kind),
        'mode': value.audienceRules[index].mode.name,
        'target_id': value.audienceRules[index].targetId,
        'filter': const <String, Object?>{},
        'position': index,
      },
  ],
};

Map<String, Object?> _schedulePayload(FormSaveSchedulePayload value) {
  final recurrence = value.schedule.recurrence;
  final end = value.schedule.end;
  return {
    'schedule_id': value.scheduleId,
    'application_id': value.applicationId,
    'time_zone': value.schedule.timeZone,
    'starts_at_local': value.schedule.startsAtLocal.toIso8601String(),
    'recurrence_kind': recurrence.kind.name,
    'interval': recurrence.interval,
    'weekdays': recurrence is FormWeeklyRecurrence ? recurrence.weekdays.toList() : <int>[],
    'monthly_day': recurrence is FormMonthlyRecurrence ? recurrence.day : null,
    'monthly_last_day': recurrence is FormMonthlyRecurrence && recurrence.useLastDay,
    'end_kind': switch (end) {
      FormScheduleNeverEnds() => 'never',
      FormScheduleEndsOnDate() => 'date',
      FormScheduleEndsAfterOccurrences() => 'count',
    },
    'ends_on': end is FormScheduleEndsOnDate ? _date(end.date) : null,
    'occurrence_count': end is FormScheduleEndsAfterOccurrences ? end.count : null,
    'reminders': [
      for (var index = 0; index < value.reminders.length; index++)
        {
          'kind': switch (value.reminders[index].kind) {
            FormReminderKind.onOpen => 'on_open',
            FormReminderKind.beforeClose => 'before_close',
            FormReminderKind.everyDays => 'every_days',
          },
          'amount': value.reminders[index].amount,
          'position': index,
        },
    ],
  };
}

Map<String, Object?> _responsePayload(FormResponseDraftPayload value) => {
  'response_id': value.responseId,
  'participation_id': value.participationId,
  'edit_secret': value.editSecret,
  'answers': value.answers.values
      .map((answer) => FormAnswerDto.fromDomain(answer).toJson())
      .toList(),
};

Map<String, Object?> _monitorQuery(FormMonitorQuery query, {required bool includeCursor}) => {
  'form_id': query.formId,
  'application_id': query.applicationId,
  'occurrence_id': query.occurrenceId,
  'starts_on_or_after': _date(query.startsOnOrAfter),
  'ends_on_or_before': _date(query.endsOnOrBefore),
  'scope_id': query.scopeId,
};

FormResponseDraft _responseDraft(Map<String, Object?> payload) {
  final answers = _list(
    payload,
    'answers',
  ).map(_map).map(FormAnswerDto.fromJson).map((dto) => dto.toDomain()).toList(growable: false);
  if (answers.map((answer) => answer.itemId).toSet().length != answers.length) {
    throw const WireFormatException('Response contains duplicate answers.');
  }
  return FormResponseDraft(
    id: _string(payload, 'id'),
    occurrenceId: _string(payload, 'occurrence_id'),
    status: switch (_string(payload, 'status')) {
      'submitted' => FormResponseDraftStatus.submitted,
      'draft' => FormResponseDraftStatus.draft,
      _ => throw const WireFormatException('Response status is invalid.'),
    },
    answers: {for (final answer in answers) answer.itemId: answer},
    managementVersion: _integer(payload, 'management_version'),
  );
}

FormResponseSummary _responseSummary(Map<String, Object?> payload) {
  final identityMode = _identityMode(_string(payload, 'identity_mode'));
  return FormResponseSummary(
    id: _string(payload, 'id'),
    occurrenceId: _string(payload, 'occurrence_id'),
    formVersionId: _string(payload, 'form_version_id'),
    identityMode: identityMode,
    submittedAt: identityMode == FormIdentityMode.anonymous
        ? null
        : _nullableDateTime(payload['submitted_at']),
    respondentLabel: identityMode == FormIdentityMode.anonymous
        ? null
        : payload['respondent_label'] as String?,
  );
}

FormVersion? _originalResponseVersion(
  Map<String, Object?> payload,
  FormResponseSummary summary,
  List<FormAnswer> answers,
) {
  if (payload['definition'] == null) return null;
  final definition = FormDefinitionDto.fromJson(_map(payload['definition'])).toDomain();
  final rawNumber = payload['form_version_number'];
  if (rawNumber is! num || !rawNumber.isFinite || rawNumber != rawNumber.truncateToDouble()) {
    throw const WireFormatException('Original response version number must be an integer.');
  }
  final number = _integer(payload, 'form_version_number');
  final state = _string(payload, 'form_version_state');
  if (definition.id != _string(payload, 'form_id') ||
      definition.identityMode != summary.identityMode ||
      number <= 0 ||
      !const {'working', 'published', 'superseded'}.contains(state)) {
    throw const WireFormatException('Original response version correlation is invalid.');
  }
  final sections = <String>{};
  final items = <String, FormItem>{};
  final options = <String>{};
  for (final section in definition.sections) {
    if (!sections.add(section.id)) {
      throw const WireFormatException('Original response graph contains duplicate sections.');
    }
    for (final item in section.items) {
      if (items.containsKey(item.id) || item.options.any((option) => !options.add(option.id))) {
        throw const WireFormatException(
          'Original response graph contains duplicate items or options.',
        );
      }
      items[item.id] = item;
    }
  }
  for (final answer in answers) {
    final item = items[answer.itemId];
    if (item == null || item.kind.name != answer.kind.name) {
      throw const WireFormatException('Answer does not belong to the original question.');
    }
    if (answer.value case FormChoiceValue(:final optionIds)) {
      final allowed = item.options.map((option) => option.id).toSet();
      if (!allowed.containsAll(optionIds)) {
        throw const WireFormatException('Answer contains an option outside the original question.');
      }
    }
  }
  return FormVersion(
    id: summary.formVersionId,
    formId: definition.id,
    number: number,
    sections: definition.sections,
    isPublished: state != 'working',
  );
}

FormMonitorPerson _monitorPerson(Map<String, Object?> item) => FormMonitorPerson(
  personId: _string(item, 'person_id'),
  displayName: _string(item, 'display_name'),
  profileLabel: _string(item, 'profile_label'),
  contextLabel: _string(item, 'context_label'),
  responded: _boolean(item, 'responded'),
);

FormApiException _internalFailure(Object? code) {
  final kind = switch (code) {
    'SAI_AUTH_REQUIRED' ||
    'SAI_SESSION_INVALID' ||
    'SAI_INTERNAL_CONTEXT_DENIED' ||
    'SAI_MEMBERSHIP_SUSPENDED' ||
    'SAI_MEMBERSHIP_REVOKED' ||
    'SAI_PERMISSION_DENIED' ||
    'SAI_MFA_REQUIRED' ||
    '42501' ||
    'PGRST301' ||
    '401' ||
    '403' => FormApiFailureKind.unauthorized,
    'SAI_INVALID_ARGUMENT' || '22023' => FormApiFailureKind.validation,
    'SAI_CONCURRENT_CHANGE' || '40001' || '409' => FormApiFailureKind.conflict,
    _ => FormApiFailureKind.unavailable,
  };
  return FormApiException(kind, _failureMessage(kind));
}

FormFileJob _fileJob(Map<String, Object?> payload) => FormFileJob(
  id: _string(payload, 'id'),
  status: switch (_string(payload, 'status')) {
    'pending' => FormFileJobStatus.pending,
    'processing' => FormFileJobStatus.processing,
    'succeeded' => FormFileJobStatus.succeeded,
    'partial' => FormFileJobStatus.partial,
    'failed' => FormFileJobStatus.failed,
    'expired' => FormFileJobStatus.expired,
    final value => throw WireFormatException('Unknown form file job status: $value.'),
  },
  progress: (payload['progress'] as num).toDouble(),
  downloadAvailable: payload['download_available'] == true,
  errorCode: payload['error_code'] as String?,
);

FormApiFailureKind _failureKind(String code) => switch (code) {
  '42501' || 'PGRST301' || '401' || '403' || 'unauthorized' => FormApiFailureKind.unauthorized,
  '22023' || '23514' || 'invalid_payload' || 'invalid_envelope' => FormApiFailureKind.validation,
  '40001' || '409' || '23505' => FormApiFailureKind.conflict,
  '502' || '503' || '504' || formsBackendTransportCode => FormApiFailureKind.unavailable,
  _ => FormApiFailureKind.unknown,
};

/// Codigos estaveis do servidor (P16) com mensagem honesta em portugues.
String? _detailMessage(String? detail) => switch (detail) {
  'FORMS_LOCATION_REVOKED' =>
    'O local escolhido não está mais disponível no catálogo da instituição. Escolha outro local.',
  'FORMS_LOCATION_NO_AVAILABLE_OPTION' =>
    'Esta pergunta obrigatória de local não tem nenhum local disponível. A instituição precisa reativar um local antes do envio.',
  _ => null,
};

String _failureMessage(FormApiFailureKind kind) => switch (kind) {
  FormApiFailureKind.unauthorized => 'Você não possui permissão para esta ação.',
  FormApiFailureKind.validation => 'Revise os dados enviados e tente novamente.',
  FormApiFailureKind.conflict =>
    'O formulário foi alterado em outra sessão. Recarregue e tente novamente.',
  FormApiFailureKind.unavailable => 'O serviço está indisponível. Tente novamente.',
  FormApiFailureKind.unknown => 'Não foi possível concluir a ação. Tente novamente.',
};

String _kind(FormKind value) => value == FormKind.quickPoll ? 'quick_poll' : 'form';
String _status(FormStatus value) => value.name;
String _identity(FormIdentityMode value) => value.name;
String _audienceKind(FormAudienceRuleKind value) => switch (value) {
  FormAudienceRuleKind.institution => 'institution',
  FormAudienceRuleKind.unit => 'unit',
  FormAudienceRuleKind.group => 'group',
  FormAudienceRuleKind.activity => 'activity',
  FormAudienceRuleKind.guardian => 'guardian',
  FormAudienceRuleKind.teacher => 'teacher',
  FormAudienceRuleKind.employee => 'employee',
  FormAudienceRuleKind.profile => 'profile',
  FormAudienceRuleKind.person => 'person',
};

FormAudienceRuleKind _audienceKindFromWire(String value) => FormAudienceRuleKind.values.firstWhere(
  (kind) => _audienceKind(kind) == value,
  orElse: () => throw WireFormatException('Unknown audience kind: $value.'),
);
FormKind _formKind(String value) => value == 'quick_poll' ? FormKind.quickPoll : FormKind.form;
FormStatus _formStatus(String value) => FormStatus.values.firstWhere(
  (status) => status.name == value,
  orElse: () => throw WireFormatException('Unknown form status: $value.'),
);
FormOperationalStatus _formOperationalStatus(String value) =>
    FormOperationalStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw WireFormatException('Unknown form operational status: $value.'),
    );
FormIdentityMode _identityMode(String value) => FormIdentityMode.values.firstWhere(
  (mode) => mode.name == value,
  orElse: () => throw WireFormatException('Unknown identity mode: $value.'),
);
FormOccurrenceStatus _occurrenceStatus(String value) => FormOccurrenceStatus.values.firstWhere(
  (status) => status.name == value,
  orElse: () => throw WireFormatException('Unknown occurrence status: $value.'),
);
Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const WireFormatException('Expected an object response.');
  return Map<String, Object?>.from(value);
}

List<Object?> _list(Map<String, Object?> value, String key) {
  final list = value[key];
  if (list is! List) throw WireFormatException('$key must be a list.');
  return List<Object?>.from(list);
}

String _string(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! String) throw WireFormatException('$key must be a string.');
  return result;
}

Map<String, String> _stringMap(Object? value) {
  if (value == null) return const {};
  if (value is! Map) throw const WireFormatException('required_headers must be an object.');
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value.toString(),
  };
}

int _integer(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! num) throw WireFormatException('$key must be a number.');
  return result.toInt();
}

bool _boolean(Map<String, Object?> value, String key) {
  final result = value[key];
  if (result is! bool) throw WireFormatException('$key must be a boolean.');
  return result;
}

bool _capability(Map<String, Object?> values, List<String> keys) =>
    keys.any((key) => values[key] == true);

DateTime _dateTime(Map<String, Object?> value, String key) {
  final result = _nullableDateTime(value[key]);
  if (result == null) throw WireFormatException('$key must be a date-time.');
  return result;
}

DateTime? _nullableDateTime(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());
String? _date(DateTime? value) => value == null
    ? null
    : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
