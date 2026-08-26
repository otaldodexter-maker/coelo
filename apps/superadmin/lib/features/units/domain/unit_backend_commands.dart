import 'package:flutter/foundation.dart';

import 'unit_status.dart';

const unitIdentityStorageBucket = 'coelo-unit-identities';
const unitIdentityMaxBytes = 5 * 1024 * 1024;

enum UnitGatewayErrorCode { unauthorized, notFound, conflict, validation, unavailable, unexpected }

final class UnitGatewayException implements Exception {
  const UnitGatewayException({
    required this.code,
    required this.operation,
    required this.message,
    this.retriable = false,
  });

  factory UnitGatewayException.unauthorized({required String operation}) => UnitGatewayException(
    code: UnitGatewayErrorCode.unauthorized,
    operation: operation,
    message: 'Access denied for this unit operation.',
  );

  factory UnitGatewayException.notFound({required String operation}) => UnitGatewayException(
    code: UnitGatewayErrorCode.notFound,
    operation: operation,
    message: 'The requested unit resource was not found.',
  );

  factory UnitGatewayException.conflict({required String operation}) => UnitGatewayException(
    code: UnitGatewayErrorCode.conflict,
    operation: operation,
    message: 'The unit state has changed and the operation must be retried.',
  );

  factory UnitGatewayException.validation({required String operation, String? message}) =>
      UnitGatewayException(
        code: UnitGatewayErrorCode.validation,
        operation: operation,
        message: message ?? 'The provided unit data was rejected.',
      );

  factory UnitGatewayException.unavailable({required String operation}) => UnitGatewayException(
    code: UnitGatewayErrorCode.unavailable,
    operation: operation,
    message: 'The unit service is temporarily unavailable.',
    retriable: true,
  );

  factory UnitGatewayException.unexpected({required String operation}) => UnitGatewayException(
    code: UnitGatewayErrorCode.unexpected,
    operation: operation,
    message: 'The unit operation could not be completed.',
  );

  final UnitGatewayErrorCode code;
  final String operation;
  final String message;
  final bool retriable;

  @override
  String toString() => 'UnitGatewayException($code, $operation)';
}

enum UnitIdentityMediaKind { profile, cover, featured }

extension UnitIdentityMediaKindValues on UnitIdentityMediaKind {
  String get databaseValue => switch (this) {
    UnitIdentityMediaKind.profile => 'profile',
    UnitIdentityMediaKind.cover => 'cover',
    UnitIdentityMediaKind.featured => 'featured',
  };

  String get pathSegment => databaseValue;

  String? get preferredMimeType => switch (this) {
    UnitIdentityMediaKind.profile ||
    UnitIdentityMediaKind.cover ||
    UnitIdentityMediaKind.featured => null,
  };

  static UnitIdentityMediaKind fromDatabaseValue(String value) =>
      switch (value.trim().toLowerCase()) {
        'profile' => UnitIdentityMediaKind.profile,
        'cover' => UnitIdentityMediaKind.cover,
        'featured' => UnitIdentityMediaKind.featured,
        _ => throw ArgumentError.value(value, 'value', 'Unknown unit identity media kind.'),
      };

  static String fileExtensionForMimeType(String mimeType) => switch (mimeType
      .trim()
      .toLowerCase()) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    _ => throw ArgumentError.value(mimeType, 'mimeType', 'Unsupported unit identity mime type.'),
  };
}

final class UnitIdentityStoragePath {
  const UnitIdentityStoragePath._({
    required this.value,
    required this.institutionId,
    required this.unitId,
    required this.kind,
    required this.mediaId,
    required this.extension,
  });

  factory UnitIdentityStoragePath.build({
    required String institutionId,
    required String unitId,
    required UnitIdentityMediaKind kind,
    required String mediaId,
    required String mimeType,
  }) {
    final extension = UnitIdentityMediaKindValues.fileExtensionForMimeType(mimeType);
    final normalizedInstitutionId = _normalizeUuid(institutionId);
    final normalizedUnitId = _normalizeUuid(unitId);
    final normalizedMediaId = _normalizeUuid(mediaId);
    return UnitIdentityStoragePath._(
      value:
          'institutions/$normalizedInstitutionId/units/$normalizedUnitId/${kind.pathSegment}/$normalizedMediaId.$extension',
      institutionId: normalizedInstitutionId,
      unitId: normalizedUnitId,
      kind: kind,
      mediaId: normalizedMediaId,
      extension: extension,
    );
  }

  factory UnitIdentityStoragePath.parse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      throw ArgumentError.value(value, 'value', 'Invalid unit identity storage path.');
    }
    return UnitIdentityStoragePath._(
      value: value.trim(),
      institutionId: match.group(1)!,
      unitId: match.group(2)!,
      kind: UnitIdentityMediaKindValues.fromDatabaseValue(match.group(3)!),
      mediaId: match.group(4)!,
      extension: match.group(5)!,
    );
  }

  static final RegExp _pattern = RegExp(
    r'^institutions/([0-9a-f-]+)/units/([0-9a-f-]+)/(profile|cover|featured)/([0-9a-f-]+)\.(jpg|png)$',
  );

  final String value;
  final String institutionId;
  final String unitId;
  final UnitIdentityMediaKind kind;
  final String mediaId;
  final String extension;

  @override
  String toString() => value;
}

enum UnitTypeRequestStatus { pending, approved, rejected, withdrawn }

extension UnitTypeRequestStatusValues on UnitTypeRequestStatus {
  String get databaseValue => switch (this) {
    UnitTypeRequestStatus.pending => 'pending',
    UnitTypeRequestStatus.approved => 'approved',
    UnitTypeRequestStatus.rejected => 'rejected',
    UnitTypeRequestStatus.withdrawn => 'withdrawn',
  };

  static UnitTypeRequestStatus fromDatabaseValue(String value) =>
      switch (value.trim().toLowerCase()) {
        'pending' => UnitTypeRequestStatus.pending,
        'approved' => UnitTypeRequestStatus.approved,
        'rejected' => UnitTypeRequestStatus.rejected,
        'withdrawn' => UnitTypeRequestStatus.withdrawn,
        _ => UnitTypeRequestStatus.pending,
      };
}

enum UnitFileFormat { csv, xlsx }

extension UnitFileFormatValues on UnitFileFormat {
  String get databaseValue => name;

  String get mimeType => switch (this) {
    UnitFileFormat.csv => 'text/csv',
    UnitFileFormat.xlsx => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  String get fileExtension => switch (this) {
    UnitFileFormat.csv => 'csv',
    UnitFileFormat.xlsx => 'xlsx',
  };

  static UnitFileFormat fromDatabaseValue(String value) => switch (value.trim().toLowerCase()) {
    'xlsx' => UnitFileFormat.xlsx,
    _ => UnitFileFormat.csv,
  };
}

enum UnitFileJobStatus { draft, processing, success, rejected, error }

extension UnitFileJobStatusValues on UnitFileJobStatus {
  bool get isTerminal =>
      this == UnitFileJobStatus.success ||
      this == UnitFileJobStatus.rejected ||
      this == UnitFileJobStatus.error;

  String get databaseValue => switch (this) {
    UnitFileJobStatus.draft => 'PENDENTE',
    UnitFileJobStatus.processing => 'PROCESSANDO',
    UnitFileJobStatus.success => 'SUCESSO',
    UnitFileJobStatus.rejected => 'REJEICAO',
    UnitFileJobStatus.error => 'ERRO',
  };

  static UnitFileJobStatus fromDatabaseValue(String value) => switch (value.trim().toUpperCase()) {
    'PROCESSANDO' => UnitFileJobStatus.processing,
    'SUCESSO' => UnitFileJobStatus.success,
    'REJEICAO' => UnitFileJobStatus.rejected,
    'ERRO' => UnitFileJobStatus.error,
    _ => UnitFileJobStatus.draft,
  };
}

enum UnitExportSortField {
  name,
  institutionName,
  institutionType,
  unitType,
  status,
  plan,
  groups,
  activities,
}

extension UnitExportSortFieldValues on UnitExportSortField {
  String get databaseValue => switch (this) {
    UnitExportSortField.name => 'name',
    UnitExportSortField.institutionName => 'institution_name',
    UnitExportSortField.institutionType => 'institution_type',
    UnitExportSortField.unitType => 'unit_type',
    UnitExportSortField.status => 'status',
    UnitExportSortField.plan => 'plan',
    UnitExportSortField.groups => 'groups',
    UnitExportSortField.activities => 'activities',
  };
}

@immutable
final class UnitTypeRequestCommand {
  const UnitTypeRequestCommand({
    required this.requestId,
    required this.unitId,
    required this.description,
    required this.context,
  });

  final String requestId;
  final String unitId;
  final String description;
  final Map<String, Object?> context;

  Map<String, dynamic> toRpc() => {
    'p_request_id': _normalizeUuid(requestId),
    'p_unit_id': _normalizeUuid(unitId),
    'p_description': description.trim(),
    'p_context': context,
  };
}

@immutable
final class UnitTypeRequestReceipt {
  const UnitTypeRequestReceipt({
    required this.requestId,
    required this.institutionId,
    required this.unitId,
    required this.description,
    required this.context,
    required this.status,
    this.approvedUnitTypeId,
    this.reviewedByPersonId,
    this.reviewedAt,
    this.reviewReason,
  });

  final String requestId;
  final String institutionId;
  final String unitId;
  final String description;
  final Map<String, dynamic> context;
  final UnitTypeRequestStatus status;
  final String? approvedUnitTypeId;
  final String? reviewedByPersonId;
  final DateTime? reviewedAt;
  final String? reviewReason;
}

@immutable
final class UnitHandleChangeCommand {
  const UnitHandleChangeCommand({
    required this.requestId,
    required this.unitId,
    required this.expectedVersion,
    required this.requestedHandle,
  });

  final String requestId;
  final String unitId;
  final int expectedVersion;
  final String requestedHandle;

  String get normalizedHandle => _normalizeHandle(requestedHandle);

  Map<String, dynamic> toRpc() => {
    'p_request_id': _normalizeUuid(requestId),
    'p_unit_id': _normalizeUuid(unitId),
    'p_expected_version': expectedVersion,
    'p_handle': normalizedHandle,
  };
}

@immutable
final class UnitHandleChangeReceipt {
  const UnitHandleChangeReceipt({
    required this.unitId,
    required this.institutionId,
    required this.handle,
    required this.managementVersion,
    this.updatedAt,
  });

  final String unitId;
  final String institutionId;
  final String handle;
  final int managementVersion;
  final DateTime? updatedAt;
}

@immutable
final class UnitTransferPreviewRequest {
  const UnitTransferPreviewRequest({required this.unitId, required this.destinationInstitutionId});

  final String unitId;
  final String destinationInstitutionId;

  Map<String, dynamic> toRpc() => {
    'p_unit_id': _normalizeUuid(unitId),
    'p_destination_institution_id': _normalizeUuid(destinationInstitutionId),
  };
}

@immutable
final class UnitTransferPreview {
  const UnitTransferPreview({
    required this.unitId,
    required this.sourceInstitutionId,
    required this.destinationInstitutionId,
    required this.dependencies,
    required this.incompatibleDependencies,
  });

  final String unitId;
  final String sourceInstitutionId;
  final String destinationInstitutionId;
  final Map<String, int> dependencies;
  final List<String> incompatibleDependencies;

  bool get canTransfer => incompatibleDependencies.isEmpty;
}

@immutable
final class UnitTransferCommand {
  const UnitTransferCommand({
    required this.requestId,
    required this.unitId,
    required this.destinationInstitutionId,
    required this.expectedVersion,
    required this.confirmed,
  });

  final String requestId;
  final String unitId;
  final String destinationInstitutionId;
  final int expectedVersion;
  final bool confirmed;

  Map<String, dynamic> toRpc() => {
    'p_request_id': _normalizeUuid(requestId),
    'p_unit_id': _normalizeUuid(unitId),
    'p_destination_institution_id': _normalizeUuid(destinationInstitutionId),
    'p_expected_version': expectedVersion,
    'p_confirmed': confirmed,
  };
}

@immutable
final class UnitTransferReceipt {
  const UnitTransferReceipt({
    required this.unitId,
    required this.institutionId,
    required this.handle,
    required this.managementVersion,
    this.updatedAt,
  });

  final String unitId;
  final String institutionId;
  final String handle;
  final int managementVersion;
  final DateTime? updatedAt;
}

@immutable
final class UnitIdentityUploadIntentCommand {
  const UnitIdentityUploadIntentCommand({
    required this.requestId,
    required this.unitId,
    required this.kind,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String requestId;
  final String unitId;
  final UnitIdentityMediaKind kind;
  final String mimeType;
  final int sizeBytes;

  Map<String, dynamic> toRpc() => {
    'p_request_id': _normalizeUuid(requestId),
    'p_unit_id': _normalizeUuid(unitId),
    'p_kind': kind.databaseValue,
    'p_mime_type': mimeType.trim().toLowerCase(),
    'p_size_bytes': sizeBytes,
  };
}

@immutable
final class UnitIdentityUploadIntent {
  const UnitIdentityUploadIntent({
    required this.mediaId,
    required this.bucket,
    required this.path,
    required this.expiresAt,
  });

  final String mediaId;
  final String bucket;
  final UnitIdentityStoragePath path;
  final DateTime expiresAt;
}

@immutable
final class UnitIdentityFinalizeUploadCommand {
  const UnitIdentityFinalizeUploadCommand({
    required this.requestId,
    required this.checksumSha256,
    this.replaceMediaId,
  });

  final String requestId;
  final String checksumSha256;
  final String? replaceMediaId;

  Map<String, dynamic> toRpc() => {
    'p_request_id': _normalizeUuid(requestId),
    'p_checksum_sha256': checksumSha256.trim().toLowerCase(),
    'p_replace_id': replaceMediaId == null ? null : _normalizeUuid(replaceMediaId!),
  };
}

enum UnitIdentityMediaStatus { pendingUpload, active, pendingDelete, deleted }

extension UnitIdentityMediaStatusValues on UnitIdentityMediaStatus {
  String get databaseValue => switch (this) {
    UnitIdentityMediaStatus.pendingUpload => 'pending_upload',
    UnitIdentityMediaStatus.active => 'active',
    UnitIdentityMediaStatus.pendingDelete => 'pending_delete',
    UnitIdentityMediaStatus.deleted => 'deleted',
  };

  static UnitIdentityMediaStatus fromDatabaseValue(String value) =>
      switch (value.trim().toLowerCase()) {
        'active' => UnitIdentityMediaStatus.active,
        'pending_delete' => UnitIdentityMediaStatus.pendingDelete,
        'deleted' => UnitIdentityMediaStatus.deleted,
        _ => UnitIdentityMediaStatus.pendingUpload,
      };
}

@immutable
final class UnitIdentityMediaReceipt {
  const UnitIdentityMediaReceipt({
    required this.mediaId,
    required this.institutionId,
    required this.unitId,
    required this.kind,
    required this.status,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    this.checksumSha256,
    this.replacedMediaId,
    this.activatedAt,
    this.deletedAt,
    this.cleanupMediaId,
    this.cleanupPath,
  });

  final String mediaId;
  final String institutionId;
  final String unitId;
  final UnitIdentityMediaKind kind;
  final UnitIdentityMediaStatus status;
  final UnitIdentityStoragePath storagePath;
  final String mimeType;
  final int sizeBytes;
  final String? checksumSha256;
  final String? replacedMediaId;
  final DateTime? activatedAt;
  final DateTime? deletedAt;
  final String? cleanupMediaId;
  final UnitIdentityStoragePath? cleanupPath;
}

@immutable
final class UnitIdentityDeleteCommand {
  const UnitIdentityDeleteCommand({required this.requestId, required this.mediaId});

  final String requestId;
  final String mediaId;

  Map<String, dynamic> toRpc() => {
    'p_request_id': _normalizeUuid(requestId),
    'p_media_id': _normalizeUuid(mediaId),
  };
}

@immutable
final class UnitIdentityDeleteReceipt {
  const UnitIdentityDeleteReceipt({
    required this.mediaId,
    required this.bucket,
    required this.path,
  });

  final String mediaId;
  final String bucket;
  final UnitIdentityStoragePath path;
}

@immutable
final class UnitIdentityDownloadDescriptor {
  const UnitIdentityDownloadDescriptor({
    required this.mediaId,
    required this.bucket,
    required this.path,
    required this.signedUrlTtlSeconds,
  });

  final String mediaId;
  final String bucket;
  final UnitIdentityStoragePath path;
  final int signedUrlTtlSeconds;
}

@immutable
final class UnitImportTemplate {
  const UnitImportTemplate({
    required this.formats,
    required this.headers,
    required this.requiredHeaders,
    required this.maxRows,
    required this.maxBytes,
  });

  final List<UnitFileFormat> formats;
  final List<String> headers;
  final List<String> requiredHeaders;
  final int maxRows;
  final int maxBytes;
}

@immutable
final class UnitFileJobResult {
  const UnitFileJobResult({
    this.createdCount = 0,
    this.updatedCount = 0,
    this.ignoredCount = 0,
    this.rejectedCount = 0,
  });

  final int createdCount;
  final int updatedCount;
  final int ignoredCount;
  final int rejectedCount;
}

@immutable
final class UnitFileJobError {
  const UnitFileJobError({
    required this.rowNumber,
    required this.field,
    required this.code,
    required this.message,
  });

  final int rowNumber;
  final String field;
  final String code;
  final String message;
}

@immutable
final class UnitFileJob {
  const UnitFileJob({
    required this.id,
    required this.institutionId,
    required this.domain,
    required this.format,
    required this.status,
    required this.summary,
    required this.createdAt,
    required this.result,
    required this.errors,
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String institutionId;
  final String domain;
  final UnitFileFormat format;
  final UnitFileJobStatus status;
  final Map<String, dynamic> summary;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final UnitFileJobResult result;
  final List<UnitFileJobError> errors;

  bool get isTerminal => status.isTerminal;
}

@immutable
final class UnitImportJobRequest {
  const UnitImportJobRequest({
    required this.fileName,
    required this.mimeType,
    required this.sourceFormat,
    required this.idempotencyKey,
  });

  final String fileName;
  final String mimeType;
  final UnitFileFormat sourceFormat;
  final String idempotencyKey;

  Map<String, dynamic> toRpc() => {
    'p_file_name': fileName.trim(),
    'p_mime_type': mimeType.trim().toLowerCase(),
    'p_source_format': sourceFormat.databaseValue,
    'p_idempotency_key': _normalizeUuid(idempotencyKey),
  };
}

@immutable
final class UnitImportSourceFile {
  const UnitImportSourceFile({
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String storagePath;
  final String mimeType;
  final int sizeBytes;

  Map<String, dynamic> toRpc() => {
    'storage_path': storagePath.trim(),
    'mime_type': mimeType.trim().toLowerCase(),
    'size_bytes': sizeBytes,
  };
}

@immutable
final class UnitImportMapping {
  const UnitImportMapping({required this.file, required this.columns});

  final UnitImportSourceFile file;
  final Map<String, String> columns;

  Map<String, dynamic> toRpc() => {'file': file.toRpc(), 'columns': columns};
}

@immutable
final class UnitImportPreviewRequest {
  const UnitImportPreviewRequest({
    required this.requestId,
    required this.importJobId,
    required this.rows,
    required this.mapping,
  });

  final String requestId;
  final String importJobId;
  final List<Map<String, Object?>> rows;
  final UnitImportMapping mapping;

  Map<String, dynamic> toRpc() => {
    'p_request_id': _normalizeUuid(requestId),
    'p_import_job_id': _normalizeUuid(importJobId),
    'p_rows': rows,
    'p_mapping': mapping.toRpc(),
  };
}

@immutable
final class UnitImportConfirmRequest {
  const UnitImportConfirmRequest({required this.requestId, required this.importJobId});

  final String requestId;
  final String importJobId;

  Map<String, dynamic> toRpc() => {
    'p_request_id': _normalizeUuid(requestId),
    'p_import_job_id': _normalizeUuid(importJobId),
  };
}

@immutable
final class UnitImportRetryRequest {
  const UnitImportRetryRequest({required this.requestId, required this.importJobId});

  final String requestId;
  final String importJobId;

  Map<String, dynamic> toRpc() => {
    'p_request_id': _normalizeUuid(requestId),
    'p_import_job_id': _normalizeUuid(importJobId),
  };
}

@immutable
final class UnitExportFilters {
  const UnitExportFilters({
    this.search = '',
    this.institutionIds = const {},
    this.institutionTypeIds = const {},
    this.unitTypeIds = const {},
    this.statuses = const {},
    this.planIds = const {},
    this.states = const {},
    this.cities = const {},
    this.districts = const {},
  });

  final String search;
  final Set<String> institutionIds;
  final Set<String> institutionTypeIds;
  final Set<String> unitTypeIds;
  final Set<UnitStatus> statuses;
  final Set<String> planIds;
  final Set<String> states;
  final Set<String> cities;
  final Set<String> districts;

  Map<String, dynamic> toRpc() => {
    'search': search.trim(),
    'institution_ids': _sorted(institutionIds),
    'institution_type_ids': _sorted(institutionTypeIds),
    'unit_type_ids': _sorted(unitTypeIds),
    'statuses': _sorted(statuses.map((status) => status.databaseValue)),
    'plan_ids': _sorted(planIds),
    'states': _sorted(states),
    'cities': _sorted(cities),
    'districts': _sorted(districts),
  };
}

@immutable
final class UnitExportCurrentView {
  const UnitExportCurrentView({
    required this.sort,
    required this.sortAscending,
    required this.groupByInstitution,
    required this.columns,
  });

  final UnitExportSortField sort;
  final bool sortAscending;
  final bool groupByInstitution;
  final List<String> columns;

  Map<String, dynamic> toRpc() => {
    'sort': sort.databaseValue,
    'sort_ascending': sortAscending,
    'group_by_institution': groupByInstitution,
    'columns': columns,
  };
}

@immutable
final class UnitExportRequest {
  const UnitExportRequest({
    required this.format,
    required this.filters,
    required this.currentView,
    required this.idempotencyKey,
  });

  final UnitFileFormat format;
  final UnitExportFilters filters;
  final UnitExportCurrentView currentView;
  final String idempotencyKey;

  Map<String, dynamic> toRpc() => {
    'p_format': format.databaseValue,
    'p_filters': filters.toRpc(),
    'p_current_view': currentView.toRpc(),
    'p_idempotency_key': _normalizeUuid(idempotencyKey),
  };
}

@immutable
final class UnitExportArtifactRequest {
  const UnitExportArtifactRequest({
    required this.importJobId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.checksumSha256,
    required this.rowCount,
  });

  final String importJobId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String checksumSha256;
  final int rowCount;

  Map<String, dynamic> toRpc() => {
    'p_import_job_id': _normalizeUuid(importJobId),
    'p_storage_path': storagePath.trim(),
    'p_file_name': fileName.trim(),
    'p_mime_type': mimeType.trim().toLowerCase(),
    'p_size_bytes': sizeBytes,
    'p_checksum_sha256': checksumSha256.trim().toLowerCase(),
    'p_row_count': rowCount,
  };
}

@immutable
final class UnitFileJobFailureRequest {
  const UnitFileJobFailureRequest({required this.importJobId, required this.errorCode});

  final String importJobId;
  final String errorCode;

  Map<String, dynamic> toRpc() => {
    'p_import_job_id': _normalizeUuid(importJobId),
    'p_error_code': errorCode.trim(),
  };
}

@immutable
final class UnitImportTemplateArtifact {
  const UnitImportTemplateArtifact({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}

@immutable
final class UnitExportDownload {
  const UnitExportDownload({
    required this.job,
    required this.url,
    required this.expiresInSeconds,
    required this.expiresAt,
  });

  final UnitFileJob job;
  final Uri url;
  final int expiresInSeconds;
  final DateTime expiresAt;
}

enum UnitExportFailureCode { invalidDownloadUrl, expired, notReady, terminal, invalidResponse }

final class UnitExportException implements Exception {
  const UnitExportException({required this.code, required this.message});

  final UnitExportFailureCode code;
  final String message;

  @override
  String toString() => 'UnitExportException($code)';
}

abstract interface class UnitBackendCommandsGateway {
  Future<UnitTypeRequestReceipt> requestUnitType(UnitTypeRequestCommand command);
  Future<UnitHandleChangeReceipt> changeHandle(UnitHandleChangeCommand command);
  Future<UnitTransferPreview> previewTransfer(UnitTransferPreviewRequest request);
  Future<UnitTransferReceipt> transferInstitution(UnitTransferCommand command);

  Future<UnitIdentityUploadIntent> prepareIdentityUpload(UnitIdentityUploadIntentCommand command);
  Future<UnitIdentityMediaReceipt> finalizeIdentityUpload(
    UnitIdentityFinalizeUploadCommand command,
  );
  Future<UnitIdentityDeleteReceipt> requestIdentityDelete(UnitIdentityDeleteCommand command);
  Future<UnitIdentityMediaReceipt> confirmIdentityDelete({required String mediaId});
  Future<UnitIdentityDownloadDescriptor> fetchIdentityDownloadDescriptor(String mediaId);
  Future<Uri> createIdentitySignedUrl(String mediaId);
  Future<UnitIdentityMediaReceipt> uploadIdentityMedia({
    required UnitIdentityUploadIntentCommand command,
    required Uint8List bytes,
    String? replaceMediaId,
  });
  Future<UnitIdentityMediaReceipt> deleteIdentityMedia({
    required UnitIdentityDeleteCommand command,
  });

  Future<UnitImportTemplate> fetchImportTemplate();
  Future<UnitFileJob> confirmImport(UnitImportConfirmRequest request);
  Future<UnitFileJob> retryImport(UnitImportRetryRequest request);

  Future<UnitImportTemplateArtifact> downloadImportTemplate(UnitFileFormat format);
  Future<UnitFileJob> uploadImportPreview({
    required String requestId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    Map<String, String> mapping = const {},
  });
  Future<UnitExportDownload> generateExport(UnitExportRequest request);
}

String _normalizeHandle(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.startsWith('@') ? normalized.substring(1) : normalized;
}

String _normalizeUuid(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  ).hasMatch(normalized)) {
    throw ArgumentError.value(value, 'value', 'Expected a UUID.');
  }
  return normalized;
}

List<String> _sorted(Iterable<String> values) {
  final result = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  result.sort();
  return result;
}
