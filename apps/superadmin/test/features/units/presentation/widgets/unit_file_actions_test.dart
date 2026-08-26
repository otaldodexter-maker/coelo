import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Tristate;

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/units/data/unavailable_unit_composition.dart';
import 'package:coelo_superadmin/features/units/domain/unit_backend_commands.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:coelo_superadmin/features/units/presentation/widgets/unit_file_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('names the current unit view in the export preview', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
            viewLabel: 'Agrupado',
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar CSV'));
    await tester.pump();

    expect(controller.activities.single.subject, 'Unidades · Agrupado');
    expect(controller.activities.single.fileName, 'unidades-agrupado.csv');
  });

  testWidgets('does not expose fixture or demonstration labels in import', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
            viewLabel: 'Cards',
          ),
        ),
      ),
    );

    final forbidden = RegExp(r'fake|demo|dev|catálogo|teste', caseSensitive: false);
    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    expect(find.textContaining(forbidden), findsNothing);

    await tester.tap(find.byKey(const Key('unit-import-template-export')));
    await tester.pump();
    expect(find.textContaining(forbidden), findsNothing);
  });

  testWidgets('unavailable gateway rejects export without a demo activity', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            backendCommands: const UnavailableUnitBackendCommandsGateway(),
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar CSV'));
    await tester.pumpAndSettle();

    expect(controller.activities, isEmpty);
    expect(find.text('Não foi possível gerar a exportação autorizada. Tente novamente.'), findsOne);
    expect(find.text('A exportação está em andamento. Acompanhe pelo sininho.'), findsNothing);
  });

  testWidgets('export is single-flight and exposes honest busy semantics', (tester) async {
    final pending = Completer<UnitExportDownload>();
    final gateway = _ExportGateway((request) => pending.future);
    var requestIds = 0;
    await _pumpExportActions(
      tester,
      gateway: gateway,
      requestIdFactory: () {
        requestIds += 1;
        return '11111111-1111-4111-8111-${requestIds.toString().padLeft(12, '0')}';
      },
    );

    await _openExportMenu(tester);
    await tester.tap(find.text('Exportar CSV'));
    await tester.tap(find.text('Exportar CSV'));
    await tester.pump();
    await tester.pump();

    expect(gateway.requests, hasLength(1));
    expect(requestIds, 1);
    final semantics = tester.getSemantics(find.byKey(const Key('unit-files-export-semantics')));
    expect(semantics.label, contains('Exportação de unidades em andamento'));
    expect(semantics.flagsCollection.isEnabled, Tristate.isFalse);
    expect(semantics.flagsCollection.isLiveRegion, isTrue);

    pending.complete(_download());
    await tester.pumpAndSettle();
  });

  testWidgets('does not open a stale export after the directory query changes', (tester) async {
    final pending = Completer<UnitExportDownload>();
    final gateway = _ExportGateway((request) => pending.future);
    final opened = <String>[];
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);

    Widget actions(UnitDirectoryQuery query) => MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: UnitFileActions(
          activityController: controller,
          backendCommands: gateway,
          query: query,
          requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
          groupByInstitution: false,
          openUrl: (url) async {
            opened.add(url);
            return true;
          },
        ),
      ),
    );

    await tester.pumpWidget(actions(UnitDirectoryQuery()));
    await _openExportMenu(tester);
    await tester.tap(find.text('Exportar CSV'));
    await tester.pump();

    await tester.pumpWidget(actions(UnitDirectoryQuery(search: 'outra unidade')));
    pending.complete(_download());
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(find.textContaining('filtros ou a visão mudaram'), findsOne);
  });

  testWidgets('retriable failure reuses the same request snapshot and idempotency key', (
    tester,
  ) async {
    var calls = 0;
    final gateway = _ExportGateway((request) async {
      calls += 1;
      if (calls == 1) {
        throw UnitGatewayException.unavailable(operation: 'request_export');
      }
      return _download();
    });
    var requestIds = 0;
    await _pumpExportActions(
      tester,
      gateway: gateway,
      requestIdFactory: () {
        requestIds += 1;
        return '11111111-1111-4111-8111-${requestIds.toString().padLeft(12, '0')}';
      },
    );

    await _tapExport(tester, 'Exportar CSV');
    await _tapExport(tester, 'Exportar CSV');

    expect(gateway.requests, hasLength(2));
    expect(gateway.requests[1].idempotencyKey, gateway.requests[0].idempotencyKey);
    expect(gateway.requests[1].toRpc(), gateway.requests[0].toRpc());
    expect(requestIds, 1);
  });

  testWidgets('format change after retriable failure creates a new request', (tester) async {
    final gateway = _ExportGateway((request) async {
      throw UnitGatewayException.unavailable(operation: 'request_export');
    });
    var requestIds = 0;
    await _pumpExportActions(
      tester,
      gateway: gateway,
      requestIdFactory: () {
        requestIds += 1;
        return '11111111-1111-4111-8111-${requestIds.toString().padLeft(12, '0')}';
      },
    );

    await _tapExport(tester, 'Exportar CSV');
    await _tapExport(tester, 'Exportar XLSX');

    expect(gateway.requests, hasLength(2));
    expect(gateway.requests[1].idempotencyKey, isNot(gateway.requests[0].idempotencyKey));
    expect(requestIds, 2);
  });

  testWidgets('non-retriable failure clears the idempotency attempt', (tester) async {
    final gateway = _ExportGateway((request) async {
      throw UnitGatewayException.unauthorized(operation: 'request_export');
    });
    var requestIds = 0;
    await _pumpExportActions(
      tester,
      gateway: gateway,
      requestIdFactory: () {
        requestIds += 1;
        return '11111111-1111-4111-8111-${requestIds.toString().padLeft(12, '0')}';
      },
    );

    await _tapExport(tester, 'Exportar CSV');
    await _tapExport(tester, 'Exportar CSV');

    expect(gateway.requests[1].idempotencyKey, isNot(gateway.requests[0].idempotencyKey));
    expect(requestIds, 2);
    expect(find.textContaining('sessão não autoriza'), findsOne);
  });

  testWidgets('not-ready retry preserves the request and idempotency key', (tester) async {
    var calls = 0;
    final gateway = _ExportGateway((request) async {
      calls += 1;
      if (calls == 1) {
        throw const UnitExportException(
          code: UnitExportFailureCode.notReady,
          message: 'processing',
        );
      }
      return _download();
    });
    var requestIds = 0;
    await _pumpExportActions(
      tester,
      gateway: gateway,
      requestIdFactory: () {
        requestIds += 1;
        return '11111111-1111-4111-8111-${requestIds.toString().padLeft(12, '0')}';
      },
    );

    await _tapExport(tester, 'Exportar CSV');
    await _tapExport(tester, 'Exportar CSV');

    expect(gateway.requests[1].idempotencyKey, gateway.requests[0].idempotencyKey);
    expect(gateway.requests[1].toRpc(), gateway.requests[0].toRpc());
    expect(requestIds, 1);
  });

  testWidgets('popup-blocked retry reopens once without rerunning export', (tester) async {
    final gateway = _ExportGateway((request) async => _download());
    var opens = 0;
    await _pumpExportActions(
      tester,
      gateway: gateway,
      opener: (url) async {
        opens += 1;
        return false;
      },
    );

    await _tapExport(tester, 'Exportar CSV');
    await _tapExport(tester, 'Exportar CSV');

    expect(gateway.requests, hasLength(1));
    expect(opens, 2);
    expect(find.textContaining('navegador bloqueou'), findsOne);
  });

  testWidgets('opener exception is safe and does not rerun export', (tester) async {
    final gateway = _ExportGateway((request) async => _download());
    await _pumpExportActions(
      tester,
      gateway: gateway,
      opener: (url) => throw StateError('raw popup failure'),
    );

    await _tapExport(tester, 'Exportar CSV');

    expect(gateway.requests, hasLength(1));
    expect(find.textContaining('navegador bloqueou'), findsOne);
    expect(find.textContaining('raw popup failure'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('locally expired download is never opened', (tester) async {
    final gateway = _ExportGateway(
      (request) async =>
          _download(expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1))),
    );
    var opens = 0;
    await _pumpExportActions(
      tester,
      gateway: gateway,
      opener: (url) async {
        opens += 1;
        return true;
      },
    );

    await _tapExport(tester, 'Exportar CSV');

    expect(opens, 0);
    expect(find.textContaining('link de download expirou'), findsOne);
  });

  for (final failure in <(UnitExportFailureCode, String)>[
    (UnitExportFailureCode.invalidDownloadUrl, 'link de download recebido não é seguro'),
    (UnitExportFailureCode.expired, 'link de download expirou'),
    (UnitExportFailureCode.notReady, 'ainda está sendo processada'),
    (UnitExportFailureCode.terminal, 'não pôde ser concluída'),
    (UnitExportFailureCode.invalidResponse, 'resposta da exportação não pôde ser validada'),
  ]) {
    testWidgets('shows a safe notice for ${failure.$1}', (tester) async {
      final gateway = _ExportGateway((request) async {
        throw UnitExportException(code: failure.$1, message: 'raw backend detail');
      });
      await _pumpExportActions(tester, gateway: gateway);

      await _tapExport(tester, 'Exportar CSV');

      expect(find.textContaining(failure.$2), findsOne);
      expect(find.textContaining('raw backend detail'), findsNothing);
    });
  }

  testWidgets('does not notify or open after the widget is disposed', (tester) async {
    final pending = Completer<UnitExportDownload>();
    final gateway = _ExportGateway((request) => pending.future);
    var opens = 0;
    await _pumpExportActions(
      tester,
      gateway: gateway,
      opener: (url) async {
        opens += 1;
        return true;
      },
    );
    await _openExportMenu(tester);
    await tester.tap(find.text('Exportar CSV'));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    pending.complete(_download());
    await tester.pump();

    expect(opens, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact file actions fit 375px at 200% text scale', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(size: Size(375, 800), textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: UnitFileActions(
              activityController: controller,
              backendCommands: _ExportGateway((request) async => _download()),
              query: UnitDirectoryQuery(),
              requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
              groupByInstitution: false,
              compact: true,
            ),
          ),
        ),
      ),
    );

    await _openExportMenu(tester);

    expect(find.text('Exportar CSV'), findsOne);
    expect(find.text('Exportar XLSX'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable gateway rejects import preview without a demo job', (tester) async {
    FilePicker.platform = _FakeFilePicker(
      FilePickerResult([
        PlatformFile(
          name: 'unidades.csv',
          size: 8,
          bytes: Uint8List.fromList('name\nA\n'.codeUnits),
        ),
      ]),
    );
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            backendCommands: const UnavailableUnitBackendCommandsGateway(),
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-demo-file-picker')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('unit-import-review')));
    await tester.pumpAndSettle();

    expect(controller.activities, isEmpty);
    expect(find.byKey(const Key('unit-import-confirm')), findsNothing);
    expect(
      find.text('O arquivo foi rejeitado. Revise formato, cabeçalhos e permissões.'),
      findsOne,
    );
    expect(find.text('24 linhas válidas'), findsNothing);
  });

  testWidgets('unavailable gateway rejects template without demo success', (tester) async {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: UnitFileActions(
            activityController: controller,
            backendCommands: const UnavailableUnitBackendCommandsGateway(),
            query: UnitDirectoryQuery(),
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            groupByInstitution: false,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-import-template-export')));
    await tester.pumpAndSettle();

    expect(controller.activities, isEmpty);
    expect(find.text('Não foi possível gerar o modelo autorizado.'), findsOne);
    expect(find.text('Modelo XLSX preparado para download.'), findsNothing);
  });
}

Future<void> _pumpExportActions(
  WidgetTester tester, {
  required UnitBackendCommandsGateway gateway,
  String Function()? requestIdFactory,
  Future<bool> Function(String url)? opener,
}) async {
  final controller = SuperadminActivityController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: UnitFileActions(
          activityController: controller,
          backendCommands: gateway,
          query: UnitDirectoryQuery(),
          requestIdFactory: requestIdFactory ?? () => '11111111-1111-4111-8111-111111111111',
          groupByInstitution: false,
          openUrl: opener,
        ),
      ),
    ),
  );
}

Future<void> _openExportMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
  await tester.pumpAndSettle();
}

Future<void> _tapExport(WidgetTester tester, String label) async {
  await _openExportMenu(tester);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

UnitExportDownload _download({DateTime? expiresAt}) => UnitExportDownload(
  job: UnitFileJob(
    id: '22222222-2222-4222-8222-222222222222',
    institutionId: '33333333-3333-4333-8333-333333333333',
    domain: 'units',
    format: UnitFileFormat.csv,
    status: UnitFileJobStatus.success,
    summary: const {'row_count': 1},
    createdAt: DateTime.utc(2026, 8, 26),
    finishedAt: DateTime.utc(2026, 8, 26, 0, 1),
    result: const UnitFileJobResult(),
    errors: const [],
  ),
  url: Uri.parse(
    'https://example.supabase.co/storage/v1/object/sign/coelo-operations/'
    'exports/units/22222222-2222-4222-8222-222222222222/'
    '44444444-4444-4444-8444-444444444444.csv?token=signed',
  ),
  expiresInSeconds: 300,
  expiresAt: expiresAt ?? DateTime.now().toUtc().add(const Duration(minutes: 5)),
);

final class _ExportGateway extends Fake implements UnitBackendCommandsGateway {
  _ExportGateway(this.onGenerateExport);

  final Future<UnitExportDownload> Function(UnitExportRequest request) onGenerateExport;
  final List<UnitExportRequest> requests = [];

  @override
  Future<UnitExportDownload> generateExport(UnitExportRequest request) {
    requests.add(request);
    return onGenerateExport(request);
  }
}

final class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this.result);

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => result;
}
