import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/unit_backend_commands.dart';

final class SupabaseUnitBackendCommandsGateway implements UnitBackendCommandsGateway {
  const SupabaseUnitBackendCommandsGateway(this._client, {DateTime Function()? now})
    : _now = now ?? _systemUtcNow;

  final SupabaseClient _client;
  final DateTime Function() _now;

  @override
  Future<UnitTypeRequestReceipt> requestUnitType(UnitTypeRequestCommand command) async {
    return _request<UnitTypeRequestReceipt>(
      'request_unit_type_for_superadmin',
      command.toRpc(),
      (row) => _typeRequestReceipt(_asMap(row)),
    );
  }

  @override
  Future<UnitHandleChangeReceipt> changeHandle(UnitHandleChangeCommand command) async {
    return _request<UnitHandleChangeReceipt>(
      'change_unit_handle_for_superadmin',
      command.toRpc(),
      (row) => _unitReceipt(_asMap(row)),
    );
  }

  @override
  Future<UnitTransferPreview> previewTransfer(UnitTransferPreviewRequest request) async {
    return _request<UnitTransferPreview>(
      'preview_unit_institution_transfer_for_superadmin',
      request.toRpc(),
      (row) => _transferPreview(_asMap(row)),
    );
  }

  @override
  Future<UnitTransferReceipt> transferInstitution(UnitTransferCommand command) async {
    if (!command.confirmed) {
      throw UnitGatewayException.validation(
        operation: 'transfer_unit_institution_for_superadmin',
        message: 'Transfer confirmation is required.',
      );
    }
    return _request<UnitTransferReceipt>(
      'transfer_unit_institution_for_superadmin',
      command.toRpc(),
      (row) => _transferReceipt(_asMap(row)),
    );
  }

  @override
  Future<UnitIdentityUploadIntent> prepareIdentityUpload(
    UnitIdentityUploadIntentCommand command,
  ) async {
    _validateBytes(command.sizeBytes);
    return _request<UnitIdentityUploadIntent>(
      'superadmin_prepare_unit_identity_upload',
      command.toRpc(),
      (row) => _uploadIntent(_asMap(row), command.kind),
    );
  }

  @override
  Future<UnitIdentityMediaReceipt> finalizeIdentityUpload(
    UnitIdentityFinalizeUploadCommand command,
  ) async {
    _validateSha256(command.checksumSha256, operation: 'superadmin_finalize_unit_identity_upload');
    return _request<UnitIdentityMediaReceipt>(
      'superadmin_finalize_unit_identity_upload',
      command.toRpc(),
      (row) => _mediaReceipt(_asMap(row)),
    );
  }

  @override
  Future<UnitIdentityDeleteReceipt> requestIdentityDelete(UnitIdentityDeleteCommand command) async {
    return _request<UnitIdentityDeleteReceipt>(
      'superadmin_request_unit_identity_delete',
      command.toRpc(),
      (row) => _deleteReceipt(_asMap(row)),
    );
  }

  @override
  Future<UnitIdentityMediaReceipt> confirmIdentityDelete({required String mediaId}) async {
    return _request<UnitIdentityMediaReceipt>('superadmin_confirm_unit_identity_delete', {
      'p_media_id': _validateUuid(mediaId),
    }, (row) => _mediaReceipt(_asMap(row)));
  }

  @override
  Future<UnitIdentityDownloadDescriptor> fetchIdentityDownloadDescriptor(String mediaId) async {
    return _request<UnitIdentityDownloadDescriptor>(
      'superadmin_unit_identity_download_descriptor',
      {'p_media_id': _validateUuid(mediaId)},
      (row) => _downloadDescriptor(_asMap(row)),
    );
  }

  @override
  Future<Uri> createIdentitySignedUrl(String mediaId) async {
    final descriptor = await fetchIdentityDownloadDescriptor(mediaId);
    final signedUrl = await _client.storage
        .from(descriptor.bucket)
        .createSignedUrl(descriptor.path.value, descriptor.signedUrlTtlSeconds);
    return Uri.parse(signedUrl);
  }

  @override
  Future<UnitIdentityMediaReceipt> uploadIdentityMedia({
    required UnitIdentityUploadIntentCommand command,
    required Uint8List bytes,
    String? replaceMediaId,
  }) async {
    _validateBytes(command.sizeBytes);
    if (bytes.length != command.sizeBytes) {
      throw UnitGatewayException.validation(
        operation: 'unit-identity.upload',
        message: 'The declared media size does not match the uploaded bytes.',
      );
    }
    final payload = await _invokeEdge('unit-identity', {
      'action': 'upload',
      'request_id': _validateUuid(command.requestId),
      'unit_id': _validateUuid(command.unitId),
      'kind': command.kind.databaseValue,
      'mime_type': command.mimeType.trim().toLowerCase(),
      'size_bytes': bytes.length,
      'content_base64': base64Encode(bytes),
      'replace_media_id': replaceMediaId == null ? null : _validateUuid(replaceMediaId),
    });
    return _mediaReceipt(payload);
  }

  @override
  Future<UnitIdentityMediaReceipt> deleteIdentityMedia({
    required UnitIdentityDeleteCommand command,
  }) async {
    final payload = await _invokeEdge('unit-identity', {
      'action': 'delete',
      'request_id': _validateUuid(command.requestId),
      'media_id': _validateUuid(command.mediaId),
    });
    return _mediaReceipt(payload);
  }

  @override
  Future<UnitImportTemplate> fetchImportTemplate() async {
    return _request<UnitImportTemplate>(
      'superadmin_unit_import_template',
      const <String, dynamic>{},
      (row) => _importTemplate(_asMap(row)),
    );
  }

  @override
  Future<UnitFileJob> confirmImport(UnitImportConfirmRequest request) async {
    return _request<UnitFileJob>(
      'superadmin_confirm_unit_import',
      request.toRpc(),
      (row) => _fileJob(_asMap(row)),
    );
  }

  @override
  Future<UnitFileJob> retryImport(UnitImportRetryRequest request) async {
    return _request<UnitFileJob>(
      'superadmin_retry_unit_import',
      request.toRpc(),
      (row) => _fileJob(_asMap(row)),
    );
  }

  @override
  Future<UnitImportTemplateArtifact> downloadImportTemplate(UnitFileFormat format) async {
    final payload = await _invokeEdge('unit-import', {
      'action': 'template',
      'format': format.databaseValue,
    });
    final encoded = payload['content_base64'];
    final fileName = payload['file_name'];
    final mimeType = payload['mime_type'];
    if (encoded is! String || fileName is! String || mimeType is! String) {
      throw UnitGatewayException.unexpected(operation: 'unit-import.template');
    }
    try {
      return UnitImportTemplateArtifact(
        fileName: fileName,
        mimeType: mimeType,
        bytes: base64Decode(encoded),
      );
    } on FormatException {
      throw UnitGatewayException.unexpected(operation: 'unit-import.template');
    }
  }

  @override
  Future<UnitFileJob> uploadImportPreview({
    required String requestId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    Map<String, String> mapping = const {},
  }) async {
    if (bytes.isEmpty || bytes.length > unitIdentityMaxBytes) {
      throw UnitGatewayException.validation(operation: 'import-export-jobs.upload');
    }
    final normalizedMimeType = mimeType.trim().toLowerCase();
    final sourceFormat = switch (normalizedMimeType) {
      'text/csv' => UnitFileFormat.csv.databaseValue,
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' =>
        UnitFileFormat.xlsx.databaseValue,
      _ => throw UnitGatewayException.validation(operation: 'import-export-jobs.create_import'),
    };
    final created = await _invokeEdge('import-export-jobs', {
      'action': 'create_import',
      'domain': 'units',
      'file_name': fileName.trim(),
      'mime_type': normalizedMimeType,
      'source_format': sourceFormat,
      'idempotency_key': _validateUuid(requestId),
    });
    final jobId = _string(created['job_id']);
    if (jobId.isEmpty) {
      throw UnitGatewayException.unexpected(operation: 'import-export-jobs.create_import');
    }
    final payload = await _invokeEdge(
      'import-export-jobs',
      bytes,
      headers: {
        'Content-Type': normalizedMimeType,
        'x-coelo-import-action': 'upload',
        'x-coelo-import-job-id': jobId,
      },
    );
    return _fileJob(payload);
  }

  @override
  Future<UnitExportDownload> generateExport(UnitExportRequest request) async {
    _validateExportColumns(request.currentView.columns);
    final requestedPayload = await _invokeExportEdge('request_export', {
      'action': 'request_export',
      'domain': 'units',
      'idempotency_key': _validateUuid(request.idempotencyKey),
      'format': request.format.databaseValue,
      'filters': request.filters.toRpc(),
      'current_view': request.currentView.toRpc(),
    });
    final requestedJob = _exportFileJob(
      requestedPayload,
      expectedFormat: request.format,
      allowDownloadArtifact: false,
    );
    _requireSuccessfulExportJob(requestedJob);
    final statusPayload = await _invokeExportEdge('status', {
      'action': 'status',
      'job_id': requestedJob.id,
    });
    final statusJob = _exportFileJob(
      statusPayload,
      expectedFormat: request.format,
      expectedJobId: requestedJob.id,
      allowDownloadArtifact: false,
    );
    _requireSuccessfulExportJob(statusJob);
    final downloadPayload = await _invokeExportEdge('download', {
      'action': 'download',
      'job_id': statusJob.id,
    });
    final job = _exportFileJob(
      downloadPayload,
      expectedFormat: request.format,
      expectedJobId: statusJob.id,
      allowDownloadArtifact: true,
    );
    _requireSuccessfulExportJob(job);
    final rawExpiresIn = downloadPayload['expires_in'];
    if (rawExpiresIn is! int || rawExpiresIn < 1 || rawExpiresIn > 300) {
      throw const UnitExportException(
        code: UnitExportFailureCode.expired,
        message: 'The export download has expired.',
      );
    }
    final expiresAt = _now().toUtc().add(Duration(seconds: rawExpiresIn));
    final url = _validateExportDownloadUrl(
      downloadPayload['download_url'],
      storageUrl: _client.storage.url,
      jobId: job.id,
      jobFormat: job.format,
      format: request.format,
    );
    return UnitExportDownload(
      job: job,
      url: url,
      expiresInSeconds: rawExpiresIn,
      expiresAt: expiresAt,
    );
  }

  Future<Map<String, dynamic>> _invokeExportEdge(String action, Object body) async {
    final operation = 'import-export-jobs.$action';
    try {
      final response = await _client.functions.invoke('import-export-jobs', body: body);
      if (response.status < 200 || response.status >= 300) {
        throw _exportHttpException(response.status, operation: operation);
      }
      final raw = response.data;
      if (raw is! Map || raw.keys.any((key) => key is! String) || raw.containsKey('error')) {
        throw const UnitExportException(
          code: UnitExportFailureCode.invalidResponse,
          message: 'The export service returned an invalid response.',
        );
      }
      return <String, dynamic>{for (final entry in raw.entries) entry.key as String: entry.value};
    } on UnitGatewayException {
      rethrow;
    } on UnitExportException {
      rethrow;
    } on FormatException {
      throw const UnitExportException(
        code: UnitExportFailureCode.invalidResponse,
        message: 'The export service returned an invalid response.',
      );
    } on FunctionException catch (error) {
      throw _exportHttpException(error.status, operation: operation);
    } on ClientException {
      throw UnitGatewayException.unavailable(operation: operation);
    } on SocketException {
      throw UnitGatewayException.unavailable(operation: operation);
    } on Object {
      throw UnitGatewayException.unavailable(operation: operation);
    }
  }

  Future<Map<String, dynamic>> _invokeEdge(
    String functionName,
    Object body, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _client.functions.invoke(functionName, body: body, headers: headers);
      final payload = _asMap(response.data);
      if (response.status < 200 || response.status >= 300 || payload.containsKey('error')) {
        throw UnitGatewayException.validation(operation: functionName);
      }
      return payload;
    } on UnitGatewayException {
      rethrow;
    } on FunctionException {
      throw UnitGatewayException.unavailable(operation: functionName);
    } on Object {
      throw UnitGatewayException.unavailable(operation: functionName);
    }
  }

  Future<T> _request<T>(
    String rpc,
    Map<String, dynamic> params,
    T Function(Object? raw) parser,
  ) async {
    try {
      final raw = await _client.rpc<Object?>(rpc, params: params);
      return parser(raw);
    } on PostgrestException catch (error) {
      throw _mapError(error, rpc);
    } on ClientException {
      throw UnitGatewayException.unavailable(operation: rpc);
    } on SocketException {
      throw UnitGatewayException.unavailable(operation: rpc);
    }
  }
}

DateTime _systemUtcNow() => DateTime.now().toUtc();

Object _exportHttpException(int status, {required String operation}) => switch (status) {
  400 || 422 => UnitGatewayException.validation(operation: operation),
  401 || 403 => UnitGatewayException.unauthorized(operation: operation),
  404 => UnitGatewayException.notFound(operation: operation),
  409 => UnitGatewayException.conflict(operation: operation),
  410 => const UnitExportException(
    code: UnitExportFailureCode.expired,
    message: 'The export download has expired.',
  ),
  503 => UnitGatewayException.unavailable(operation: operation),
  _ => UnitGatewayException.unavailable(operation: operation),
};

void _validateExportColumns(List<String> columns) {
  const allowed = <String>{
    'id',
    'institution_id',
    'institution_name',
    'institution_type_name',
    'name',
    'unit_type_name',
    'unit_type_other_text',
    'unit_status',
    'effective_plan_name',
    'groups_count',
    'activities_count',
    'updated_at',
  };
  if (columns.length > allowed.length || columns.any((column) => !allowed.contains(column))) {
    throw UnitGatewayException.validation(operation: 'import-export-jobs.request_export');
  }
}

void _requireSuccessfulExportJob(UnitFileJob job) {
  if (job.status == UnitFileJobStatus.draft || job.status == UnitFileJobStatus.processing) {
    throw const UnitExportException(
      code: UnitExportFailureCode.notReady,
      message: 'The export is not ready for download.',
    );
  }
  if (job.status == UnitFileJobStatus.rejected || job.status == UnitFileJobStatus.error) {
    throw const UnitExportException(
      code: UnitExportFailureCode.terminal,
      message: 'The export finished without a downloadable artifact.',
    );
  }
}

UnitFileJob _exportFileJob(
  Map<String, dynamic> row, {
  required UnitFileFormat expectedFormat,
  required bool allowDownloadArtifact,
  String? expectedJobId,
}) {
  final jobId = row['job_id'];
  final domain = row['domain'];
  final direction = row['direction'];
  final format = row['format'];
  final state = row['state'];
  final rawCreatedAt = row['created_at'];
  final summary = row['summary'];
  final createdAt = rawCreatedAt is String ? DateTime.tryParse(rawCreatedAt) : null;
  final startedAt = _exportUtcTimestamp(row['started_at'], optional: true);
  final finishedAt = _exportUtcTimestamp(row['finished_at'], optional: true);
  const validStates = <String>{'PENDENTE', 'PROCESSANDO', 'SUCESSO', 'REJEICAO', 'ERRO'};
  const jobKeys = <String>{
    'job_id',
    'domain',
    'direction',
    'format',
    'state',
    'created_at',
    'started_at',
    'finished_at',
    'summary',
  };
  final allowedKeys = allowDownloadArtifact ? {...jobKeys, 'download_url', 'expires_in'} : jobKeys;
  final isValid =
      row.keys.every(allowedKeys.contains) &&
      jobId is String &&
      _canonicalUuidPattern.hasMatch(jobId) &&
      (expectedJobId == null || jobId == expectedJobId) &&
      domain == 'units' &&
      direction == 'export' &&
      format == expectedFormat.databaseValue &&
      state is String &&
      validStates.contains(state) &&
      rawCreatedAt is String &&
      (rawCreatedAt.endsWith('Z') || rawCreatedAt.endsWith('+00:00')) &&
      createdAt != null &&
      createdAt.isUtc &&
      _isStringKeyedMap(summary) &&
      startedAt.isValid &&
      finishedAt.isValid;
  if (!isValid) {
    throw const UnitExportException(
      code: UnitExportFailureCode.invalidResponse,
      message: 'The export service returned invalid job metadata.',
    );
  }
  return UnitFileJob(
    id: jobId,
    institutionId: '',
    domain: domain as String,
    format: expectedFormat,
    status: UnitFileJobStatusValues.fromDatabaseValue(state),
    summary: Map<String, dynamic>.from(summary as Map),
    createdAt: createdAt,
    startedAt: startedAt.value,
    finishedAt: finishedAt.value,
    result: const UnitFileJobResult(),
    errors: const <UnitFileJobError>[],
  );
}

bool _isStringKeyedMap(Object? value) => value is Map && value.keys.every((key) => key is String);

({bool isValid, DateTime? value}) _exportUtcTimestamp(Object? raw, {required bool optional}) {
  if (raw == null) return (isValid: optional, value: null);
  if (raw is! String || !(raw.endsWith('Z') || raw.endsWith('+00:00'))) {
    return (isValid: false, value: null);
  }
  final value = DateTime.tryParse(raw);
  return (isValid: value != null && value.isUtc, value: value);
}

Uri _validateExportDownloadUrl(
  Object? rawUrl, {
  required String storageUrl,
  required String jobId,
  required UnitFileFormat jobFormat,
  required UnitFileFormat format,
}) {
  final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
  final storageBase = Uri.tryParse(storageUrl);
  final tokenValues = url?.queryParametersAll['token'];
  final downloadValues = url?.queryParametersAll['download'];
  final normalizedStoragePath = storageBase == null
      ? ''
      : storageBase.path.replaceFirst(RegExp(r'/$'), '');
  final artifactPattern = RegExp(
    '^${RegExp.escape(normalizedStoragePath)}/object/sign/coelo-operations/'
    'exports/units/${RegExp.escape(jobId)}/'
    r'[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.'
    '${RegExp.escape(format.fileExtension)}\$',
  );
  final isValid =
      url != null &&
      storageBase != null &&
      _canonicalUuidPattern.hasMatch(jobId) &&
      jobFormat == format &&
      url.scheme == 'https' &&
      storageBase.scheme == 'https' &&
      url.host.toLowerCase() == storageBase.host.toLowerCase() &&
      url.port == storageBase.port &&
      url.userInfo.isEmpty &&
      url.fragment.isEmpty &&
      !url.path.contains('%') &&
      artifactPattern.hasMatch(url.path) &&
      url.queryParametersAll.keys.every((key) => key == 'token' || key == 'download') &&
      tokenValues != null &&
      tokenValues.length == 1 &&
      tokenValues.single.trim().isNotEmpty &&
      (downloadValues == null || downloadValues.length == 1);
  if (!isValid) {
    throw const UnitExportException(
      code: UnitExportFailureCode.invalidDownloadUrl,
      message: 'The signed export URL is invalid.',
    );
  }
  return url;
}

final RegExp _canonicalUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

UnitTypeRequestReceipt _typeRequestReceipt(Map<String, dynamic> row) => UnitTypeRequestReceipt(
  requestId: _string(row['request_id']),
  institutionId: _string(row['institution_id']),
  unitId: _string(row['unit_id']),
  description: _string(row['requested_description']),
  context: _map(row['context_json']),
  status: UnitTypeRequestStatusValues.fromDatabaseValue(_string(row['status'])),
  approvedUnitTypeId: _nullableString(row['approved_unit_type_id']),
  reviewedByPersonId: _nullableString(row['reviewed_by_person_id']),
  reviewedAt: _dateTime(row['reviewed_at']),
  reviewReason: _nullableString(row['review_reason']),
);

UnitHandleChangeReceipt _unitReceipt(Map<String, dynamic> row) => UnitHandleChangeReceipt(
  unitId: _string(row['id']),
  institutionId: _string(row['institution_id']),
  handle: _string(_map(row['public_profile'])['handle'] ?? row['handle']),
  managementVersion: _int(row['management_version']),
  updatedAt: _dateTime(row['updated_at']),
);

UnitTransferPreview _transferPreview(Map<String, dynamic> row) => UnitTransferPreview(
  unitId: _string(row['unit_id']),
  sourceInstitutionId: _string(row['source_institution_id']),
  destinationInstitutionId: _string(row['destination_institution_id']),
  dependencies: _map(row['dependencies']).map((key, value) => MapEntry(key, _int(value))),
  incompatibleDependencies: _stringList(row['incompatible_dependencies']),
);

UnitTransferReceipt _transferReceipt(Map<String, dynamic> row) => UnitTransferReceipt(
  unitId: _string(row['id']),
  institutionId: _string(row['institution_id']),
  handle: _string(_map(row['public_profile'])['handle']),
  managementVersion: _int(row['management_version']),
  updatedAt: _dateTime(row['updated_at']),
);

UnitIdentityUploadIntent _uploadIntent(Map<String, dynamic> row, UnitIdentityMediaKind kind) {
  final path = UnitIdentityStoragePath.parse(_string(row['upload_path']));
  return UnitIdentityUploadIntent(
    mediaId: _string(row['media_id']),
    bucket: _string(row['bucket']),
    path: path.kind == kind
        ? path
        : UnitIdentityStoragePath.build(
            institutionId: path.institutionId,
            unitId: path.unitId,
            kind: kind,
            mediaId: path.mediaId,
            mimeType: _mimeTypeFromExtension(path.extension),
          ),
    expiresAt: _dateTime(row['expires_at']) ?? DateTime.now(),
  );
}

UnitIdentityMediaReceipt _mediaReceipt(Map<String, dynamic> row) {
  final path = UnitIdentityStoragePath.parse(_string(row['storage_path']));
  return UnitIdentityMediaReceipt(
    mediaId: _string(row['id']),
    institutionId: _string(row['institution_id']),
    unitId: _string(row['unit_id']),
    kind: path.kind,
    status: UnitIdentityMediaStatusValues.fromDatabaseValue(_string(row['status'])),
    storagePath: path,
    mimeType: _string(row['mime_type']),
    sizeBytes: _int(row['size_bytes']),
    checksumSha256: _nullableString(row['checksum_sha256']),
    replacedMediaId: _nullableString(row['replaced_media_id']),
    activatedAt: _dateTime(row['activated_at']),
    deletedAt: _dateTime(row['deleted_at']),
    cleanupMediaId: _nullableString(row['cleanup_media_id']),
    cleanupPath: _nullableString(row['cleanup_path']) == null
        ? null
        : UnitIdentityStoragePath.parse(_string(row['cleanup_path'])),
  );
}

UnitIdentityDeleteReceipt _deleteReceipt(Map<String, dynamic> row) => UnitIdentityDeleteReceipt(
  mediaId: _string(row['media_id']),
  bucket: _string(row['bucket']),
  path: UnitIdentityStoragePath.parse(_string(row['delete_path'])),
);

UnitIdentityDownloadDescriptor _downloadDescriptor(Map<String, dynamic> row) =>
    UnitIdentityDownloadDescriptor(
      mediaId: _string(row['media_id']),
      bucket: _string(row['bucket']),
      path: UnitIdentityStoragePath.parse(_string(row['path'])),
      signedUrlTtlSeconds: _int(row['signed_url_ttl_seconds']),
    );

UnitImportTemplate _importTemplate(Map<String, dynamic> row) => UnitImportTemplate(
  formats: _stringList(
    row['formats'],
  ).map(UnitFileFormatValues.fromDatabaseValue).toList(growable: false),
  headers: _stringList(row['headers']),
  requiredHeaders: _stringList(row['required']),
  maxRows: _int(row['max_rows']),
  maxBytes: _int(row['max_bytes']),
);

UnitFileJob _fileJob(Map<String, dynamic> row) {
  final summary = _map(row['summary']);
  final result = _map(row['result']);
  final errors = _list(row['errors']).map(_fileJobError).toList(growable: false);
  return UnitFileJob(
    id: _string(row['job_id']),
    institutionId: _string(row['institution_id']),
    domain: _string(row['domain']),
    format: UnitFileFormatValues.fromDatabaseValue(_string(row['format'])),
    status: UnitFileJobStatusValues.fromDatabaseValue(_string(row['state'])),
    summary: summary,
    createdAt: _dateTime(row['created_at']) ?? DateTime.now(),
    startedAt: _dateTime(row['started_at']),
    finishedAt: _dateTime(row['finished_at']),
    result: UnitFileJobResult(
      createdCount: _int(result['created_count']),
      updatedCount: _int(result['updated_count']),
      ignoredCount: _int(result['ignored_count']),
      rejectedCount: _int(result['rejected_count']),
    ),
    errors: errors,
  );
}

UnitFileJobError _fileJobError(Object? value) {
  final row = _asMap(value);
  return UnitFileJobError(
    rowNumber: _int(row['row_number']),
    field: _string(row['field']),
    code: _string(row['code']),
    message: _string(row['message']),
  );
}

UnitGatewayException _mapError(PostgrestException error, String operation) => switch (error.code) {
  '42501' || 'PGRST301' || 'PGRST302' => UnitGatewayException.unauthorized(operation: operation),
  'PGRST116' || 'P0002' => UnitGatewayException.notFound(operation: operation),
  '23505' || '40001' || 'P0003' => UnitGatewayException.conflict(operation: operation),
  '22023' || '23502' || '23503' || '23514' || 'P0001' => UnitGatewayException.validation(
    operation: operation,
    message: 'The unit data did not pass validation.',
  ),
  'PGRST000' ||
  'PGRST001' ||
  'PGRST002' ||
  'PGRST003' => UnitGatewayException.unavailable(operation: operation),
  _ => UnitGatewayException.unexpected(operation: operation),
};

void _validateBytes(int sizeBytes) {
  if (sizeBytes < 1 || sizeBytes > unitIdentityMaxBytes) {
    throw UnitGatewayException.validation(
      operation: 'superadmin_prepare_unit_identity_upload',
      message: 'Unit identity media must be between 1 byte and 5 MB.',
    );
  }
}

String _validateUuid(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(normalized)) {
    throw ArgumentError.value(value, 'value', 'Expected a UUID.');
  }
  return normalized;
}

void _validateSha256(String checksum, {required String operation}) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum.trim().toLowerCase())) {
    throw UnitGatewayException.validation(
      operation: operation,
      message: 'The checksum must be a SHA-256 hex digest.',
    );
  }
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.length == 1 && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  throw const FormatException('Invalid unit backend response.');
}

Map<String, dynamic> _map(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

List<Object?> _list(Object? raw) => raw is List ? raw : const <Object?>[];

List<String> _stringList(Object? raw) => _list(raw)
    .map((value) => value?.toString().trim() ?? '')
    .where((value) => value.isNotEmpty)
    .toList(growable: false);

String _string(Object? value) => value?.toString().trim() ?? '';

String? _nullableString(Object? value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(Object? value) => switch (value) {
  int result => result,
  num result => result.toInt(),
  String result => int.tryParse(result) ?? 0,
  _ => 0,
};

DateTime? _dateTime(Object? value) => DateTime.tryParse(_nullableString(value) ?? '');

String _mimeTypeFromExtension(String extension) => switch (extension.toLowerCase()) {
  'jpg' => 'image/jpeg',
  'png' => 'image/png',
  _ => 'application/octet-stream',
};
