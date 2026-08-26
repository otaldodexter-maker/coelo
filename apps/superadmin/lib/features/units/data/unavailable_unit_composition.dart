import 'dart:typed_data';

import '../domain/unit_backend_commands.dart';
import '../domain/unit_directory.dart';

final class UnavailableUnitDirectoryException implements Exception {
  const UnavailableUnitDirectoryException();
}

final class UnavailableUnitDirectoryRepository implements UnitDirectoryRepository {
  const UnavailableUnitDirectoryRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const UnavailableUnitDirectoryException());

  @override
  List<UnitRecord> get records => const [];

  @override
  UnitRecord? findById(String id) => null;

  @override
  String createId(String institutionId, String slug) {
    throw const UnavailableUnitDirectoryException();
  }

  @override
  Future<void> upsert(UnitRecord record) => _unavailable();

  @override
  Future<UnitFormData> loadForm({String? unitId}) => _unavailable();

  @override
  Future<UnitDirectoryPage> fetchPage(UnitDirectoryQuery query) => _unavailable();

  @override
  Future<UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) => _unavailable();
}

final class UnavailableUnitBackendCommandsGateway implements UnitBackendCommandsGateway {
  const UnavailableUnitBackendCommandsGateway();

  Future<T> _unavailable<T>(String operation) =>
      Future<T>.error(UnitGatewayException.unavailable(operation: operation));

  @override
  Future<UnitTypeRequestReceipt> requestUnitType(UnitTypeRequestCommand command) =>
      _unavailable('requestUnitType');

  @override
  Future<UnitHandleChangeReceipt> changeHandle(UnitHandleChangeCommand command) =>
      _unavailable('changeHandle');

  @override
  Future<UnitTransferPreview> previewTransfer(UnitTransferPreviewRequest request) =>
      _unavailable('previewTransfer');

  @override
  Future<UnitTransferReceipt> transferInstitution(UnitTransferCommand command) =>
      _unavailable('transferInstitution');

  @override
  Future<UnitIdentityUploadIntent> prepareIdentityUpload(UnitIdentityUploadIntentCommand command) =>
      _unavailable('prepareIdentityUpload');

  @override
  Future<UnitIdentityMediaReceipt> finalizeIdentityUpload(
    UnitIdentityFinalizeUploadCommand command,
  ) => _unavailable('finalizeIdentityUpload');

  @override
  Future<UnitIdentityDeleteReceipt> requestIdentityDelete(UnitIdentityDeleteCommand command) =>
      _unavailable('requestIdentityDelete');

  @override
  Future<UnitIdentityMediaReceipt> confirmIdentityDelete({required String mediaId}) =>
      _unavailable('confirmIdentityDelete');

  @override
  Future<UnitIdentityDownloadDescriptor> fetchIdentityDownloadDescriptor(String mediaId) =>
      _unavailable('fetchIdentityDownloadDescriptor');

  @override
  Future<Uri> createIdentitySignedUrl(String mediaId) => _unavailable('createIdentitySignedUrl');

  @override
  Future<UnitIdentityMediaReceipt> uploadIdentityMedia({
    required UnitIdentityUploadIntentCommand command,
    required Uint8List bytes,
    String? replaceMediaId,
  }) => _unavailable('uploadIdentityMedia');

  @override
  Future<UnitIdentityMediaReceipt> deleteIdentityMedia({
    required UnitIdentityDeleteCommand command,
  }) => _unavailable('deleteIdentityMedia');

  @override
  Future<UnitImportTemplate> fetchImportTemplate() => _unavailable('fetchImportTemplate');

  @override
  Future<UnitFileJob> confirmImport(UnitImportConfirmRequest request) =>
      _unavailable('confirmImport');

  @override
  Future<UnitFileJob> retryImport(UnitImportRetryRequest request) => _unavailable('retryImport');

  @override
  Future<UnitImportTemplateArtifact> downloadImportTemplate(UnitFileFormat format) =>
      _unavailable('downloadImportTemplate');

  @override
  Future<UnitFileJob> uploadImportPreview({
    required String requestId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    Map<String, String> mapping = const {},
  }) => _unavailable('uploadImportPreview');

  @override
  Future<UnitExportDownload> generateExport(UnitExportRequest request) =>
      _unavailable('generateExport');
}
