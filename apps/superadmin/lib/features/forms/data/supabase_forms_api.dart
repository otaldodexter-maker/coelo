import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';

import 'forms_backend_gateway.dart';

final class SupabaseFormsApi implements FormsApi {
  const SupabaseFormsApi(this._backend, {FormCursorCodec cursorCodec = const FormCursorCodec()})
    : _cursorCodec = cursorCodec;

  final FormsBackendGateway _backend;
  final FormCursorCodec _cursorCodec;

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
    (value) => FormDefinitionDto.fromDomain(value).toJson(),
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
  Future<FormMonitorProjection> getMonitor(FormMonitorQuery query) => _guard(() async {
    final payload = _map(
      await _backend.rpc(FormsRpc.getMonitor.functionName, {
        'p_query': _monitorQuery(query, includeCursor: false),
      }),
    );
    return FormMonitorProjection(
      eligibleCount: _integer(payload, 'eligible_count'),
      respondedCount: _integer(payload, 'responded_count'),
      pendingCount: _integer(payload, 'pending_count'),
      isAnonymous: _boolean(payload, 'is_anonymous'),
    );
  });

  @override
  Future<FormCursorPage<FormMonitorScope>> listMonitorHierarchy(FormMonitorQuery query) =>
      _guard(() async {
        final cursor = _decodeCursor(query.cursor);
        final payload = _map(
          await _backend.rpc(FormsRpc.listMonitorHierarchy.functionName, {
            'p_query': {
              ..._monitorQuery(query, includeCursor: false),
              'cursor_label': cursor?.sortKey,
              'cursor_id': cursor?.id,
              'limit': query.limit,
            },
          }),
        );
        return _page(
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
        );
      });

  @override
  Future<FormCursorPage<FormMonitorPerson>> listMonitorPeople(FormMonitorQuery query) =>
      _guard(() async {
        final cursor = _decodeCursor(query.cursor);
        final payload = _map(
          await _backend.rpc(FormsRpc.listMonitorPeople.functionName, {
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
          }),
        );
        return _monitorPeoplePage(payload);
      });

  @override
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query) =>
      _guard(() async {
        final cursor = _decodeCursor(query.cursor);
        final payload = _map(
          await _backend.rpc(FormsRpc.listResponses.functionName, {
            'p_query': {
              'form_id': query.formId,
              'occurrence_id': query.occurrenceId,
              'cursor_submitted_at': cursor?.sortKey,
              'cursor_id': cursor?.id,
              'limit': query.limit,
            },
          }),
        );
        return _page(payload, _responseSummary, cursorKey: 'submitted_at');
      });

  @override
  Future<FormResponseDetail> getResponseDetail(String responseId) => _guard(() async {
    final payload = _map(
      await _backend.rpc(FormsRpc.getResponseDetail.functionName, {'p_response_id': responseId}),
    );
    final answers = _list(
      payload,
      'answers',
    ).map(_map).map(FormAnswerDto.fromJson).map((dto) => dto.toDomain());
    return FormResponseDetail(
      summary: _responseSummary(payload),
      answers: {for (final answer in answers) answer.itemId: answer},
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
              'edit_secret': value.editSecret,
            },
          ),
        );
        return FormAssetUploadTicket(
          assetId: _string(payload, 'asset_id'),
          signedUploadUrl: Uri.parse(_string(payload, 'signed_upload_url')),
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
            (value) => {'asset_id': value.assetId, 'edit_secret': value.editSecret},
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
      (value) => {'asset_id': value.assetId, 'edit_secret': value.editSecret},
    );
  });

  @override
  Future<FormFileJob> requestExport(FormCommand<FormExportPayload> command) =>
      _fileJobCommand(FormsRpc.requestExport, command);

  @override
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  }) => _guard(() async {
    final decoded = _decodeCursor(cursor);
    final payload = _map(
      await _backend.rpc(FormsRpc.listFileJobs.functionName, {
        'p_query': {
          'form_id': formId,
          'cursor_created_at': decoded?.sortKey,
          'cursor_id': decoded?.id,
          'limit': limit,
        },
      }),
    );
    return _page(payload, _fileJob, cursorKey: 'created_at');
  });

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
  Future<FormFileJob> requestAnonymousParticipationExport(FormCommand<FormExportPayload> command) =>
      _fileJobCommand(FormsRpc.requestAnonymousParticipationExport, command);

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
  ) => _guard(() async => _responseDraft(_map(await _command(rpc, command, encode))));

  Future<FormFileJob> _fileJobCommand(FormsRpc rpc, FormCommand<FormExportPayload> command) =>
      _guard(
        () async => _fileJob(
          _map(
            await _command(
              rpc,
              command,
              (value) => {
                'form_id': value.formId,
                'occurrence_id': value.occurrenceId,
                'kind': _exportKind(value.kind),
                'justification': value.justification,
              },
            ),
          ),
        ),
      );

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
      throw FormApiException(kind, _failureMessage(kind));
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

  FormCursorPage<FormMonitorPerson> _monitorPeoplePage(Map<String, Object?> payload) => _page(
    payload,
    (item) => FormMonitorPerson(
      personId: _string(item, 'person_id'),
      displayName: _string(item, 'display_name'),
      profileLabel: _string(item, 'profile_label'),
      contextLabel: _string(item, 'context_label'),
      responded: _boolean(item, 'responded'),
    ),
    cursorKey: 'name',
  );
}

Map<String, Object?> _applicationPayload(FormApplication value) => {
  'id': value.id,
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
  ).map(_map).map(FormAnswerDto.fromJson).map((dto) => dto.toDomain());
  return FormResponseDraft(
    id: _string(payload, 'id'),
    occurrenceId: _string(payload, 'occurrence_id'),
    status: _string(payload, 'status') == 'submitted'
        ? FormResponseDraftStatus.submitted
        : FormResponseDraftStatus.draft,
    answers: {for (final answer in answers) answer.itemId: answer},
    managementVersion: _integer(payload, 'management_version'),
  );
}

FormResponseSummary _responseSummary(Map<String, Object?> payload) => FormResponseSummary(
  id: _string(payload, 'id'),
  occurrenceId: _string(payload, 'occurrence_id'),
  formVersionId: _string(payload, 'form_version_id'),
  submittedAt: _nullableDateTime(payload['submitted_at']),
  respondentLabel: payload['respondent_label'] as String?,
);

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
  '502' || '503' || '504' => FormApiFailureKind.unavailable,
  _ => FormApiFailureKind.unknown,
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
String _exportKind(FormExportKind value) => switch (value) {
  FormExportKind.csv => 'csv',
  FormExportKind.xlsx => 'xlsx',
  FormExportKind.zip => 'zip',
  FormExportKind.anonymousParticipation => 'anonymous_participation',
};

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
