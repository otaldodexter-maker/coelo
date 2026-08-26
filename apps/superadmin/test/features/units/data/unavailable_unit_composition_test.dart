import 'dart:typed_data';

import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/unavailable_unit_composition.dart';
import 'package:coelo_superadmin/features/units/domain/unit_backend_commands.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:flutter_test/flutter_test.dart';

const _requestId = '00000000-0000-4000-8000-000000000001';
const _unitId = '00000000-0000-4000-8000-000000000002';
const _institutionId = '00000000-0000-4000-8000-000000000003';
const _mediaId = '00000000-0000-4000-8000-000000000004';
const _jobId = '00000000-0000-4000-8000-000000000005';

void main() {
  test('unit directory repository fails closed without placeholder success', () async {
    const repository = UnavailableUnitDirectoryRepository();

    expect(repository.records, isEmpty);
    expect(repository.findById(_unitId), isNull);
    expect(
      () => repository.createId(_institutionId, 'campus'),
      throwsA(isA<UnavailableUnitDirectoryException>()),
    );
    final record = FakeUnitDirectoryRepository(FakeInstitutionDirectoryRepository()).records.first;
    await expectLater(repository.upsert(record), throwsA(isA<UnavailableUnitDirectoryException>()));
    await expectLater(repository.loadForm(), throwsA(isA<UnavailableUnitDirectoryException>()));
    await expectLater(
      repository.fetchPage(UnitDirectoryQuery()),
      throwsA(isA<UnavailableUnitDirectoryException>()),
    );
    await expectLater(
      repository.fetchFilterOptions(),
      throwsA(isA<UnavailableUnitDirectoryException>()),
    );
  });

  test('management gateway methods fail closed with stable operations', () async {
    const gateway = UnavailableUnitBackendCommandsGateway();

    await _expectUnavailable(
      'requestUnitType',
      () => gateway.requestUnitType(
        const UnitTypeRequestCommand(
          requestId: _requestId,
          unitId: _unitId,
          description: 'Campus bilíngue',
          context: {},
        ),
      ),
    );
    await _expectUnavailable(
      'changeHandle',
      () => gateway.changeHandle(
        const UnitHandleChangeCommand(
          requestId: _requestId,
          unitId: _unitId,
          expectedVersion: 1,
          requestedHandle: 'campus-centro',
        ),
      ),
    );
    await _expectUnavailable(
      'previewTransfer',
      () => gateway.previewTransfer(
        const UnitTransferPreviewRequest(unitId: _unitId, destinationInstitutionId: _institutionId),
      ),
    );
    await _expectUnavailable(
      'transferInstitution',
      () => gateway.transferInstitution(
        const UnitTransferCommand(
          requestId: _requestId,
          unitId: _unitId,
          destinationInstitutionId: _institutionId,
          expectedVersion: 1,
          confirmed: true,
        ),
      ),
    );
  });

  test('identity and media gateway methods fail closed with stable operations', () async {
    const gateway = UnavailableUnitBackendCommandsGateway();
    const uploadCommand = UnitIdentityUploadIntentCommand(
      requestId: _requestId,
      unitId: _unitId,
      kind: UnitIdentityMediaKind.profile,
      mimeType: 'image/png',
      sizeBytes: 1,
    );
    const deleteCommand = UnitIdentityDeleteCommand(requestId: _requestId, mediaId: _mediaId);

    await _expectUnavailable(
      'prepareIdentityUpload',
      () => gateway.prepareIdentityUpload(uploadCommand),
    );
    await _expectUnavailable(
      'finalizeIdentityUpload',
      () => gateway.finalizeIdentityUpload(
        const UnitIdentityFinalizeUploadCommand(
          requestId: _requestId,
          checksumSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      ),
    );
    await _expectUnavailable(
      'requestIdentityDelete',
      () => gateway.requestIdentityDelete(deleteCommand),
    );
    await _expectUnavailable(
      'confirmIdentityDelete',
      () => gateway.confirmIdentityDelete(mediaId: _mediaId),
    );
    await _expectUnavailable(
      'fetchIdentityDownloadDescriptor',
      () => gateway.fetchIdentityDownloadDescriptor(_mediaId),
    );
    await _expectUnavailable(
      'createIdentitySignedUrl',
      () => gateway.createIdentitySignedUrl(_mediaId),
    );
    await _expectUnavailable(
      'uploadIdentityMedia',
      () =>
          gateway.uploadIdentityMedia(command: uploadCommand, bytes: Uint8List.fromList(const [1])),
    );
    await _expectUnavailable(
      'deleteIdentityMedia',
      () => gateway.deleteIdentityMedia(command: deleteCommand),
    );
  });

  test('import and export gateway methods fail closed with stable operations', () async {
    const gateway = UnavailableUnitBackendCommandsGateway();

    await _expectUnavailable('fetchImportTemplate', gateway.fetchImportTemplate);
    await _expectUnavailable(
      'confirmImport',
      () => gateway.confirmImport(
        const UnitImportConfirmRequest(requestId: _requestId, importJobId: _jobId),
      ),
    );
    await _expectUnavailable(
      'retryImport',
      () => gateway.retryImport(
        const UnitImportRetryRequest(requestId: _requestId, importJobId: _jobId),
      ),
    );
    await _expectUnavailable(
      'downloadImportTemplate',
      () => gateway.downloadImportTemplate(UnitFileFormat.csv),
    );
    await _expectUnavailable(
      'uploadImportPreview',
      () => gateway.uploadImportPreview(
        requestId: _requestId,
        fileName: 'unidades.csv',
        mimeType: 'text/csv',
        bytes: Uint8List.fromList(const [1]),
      ),
    );
    await _expectUnavailable(
      'generateExport',
      () => gateway.generateExport(
        const UnitExportRequest(
          format: UnitFileFormat.csv,
          filters: UnitExportFilters(),
          currentView: UnitExportCurrentView(
            sort: UnitExportSortField.name,
            sortAscending: true,
            groupByInstitution: false,
            columns: ['name'],
          ),
          idempotencyKey: _requestId,
        ),
      ),
    );
  });
}

Future<void> _expectUnavailable(String operation, Future<Object?> Function() invoke) async {
  await expectLater(
    invoke(),
    throwsA(
      isA<UnitGatewayException>()
          .having((error) => error.code, 'code', UnitGatewayErrorCode.unavailable)
          .having((error) => error.operation, 'operation', operation),
    ),
  );
}
