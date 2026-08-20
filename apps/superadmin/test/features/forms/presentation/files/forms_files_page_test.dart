import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/files/forms_files_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows export formats and observable job states', (tester) async {
    final api = _FilesApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsFilesPage(api: api, formId: 'form-1', managementVersion: 3),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('XLSX'), findsOneWidget);
    expect(find.text('ZIP + mídias'), findsOneWidget);
    expect(find.text('Processando · 40%'), findsOneWidget);
    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    expect(api.requested, FormExportKind.csv);
  });
}

final class _FilesApi implements FormsApi {
  FormExportKind? requested;

  @override
  Future<FormCursorPage<FormFileJob>> listFileJobs({
    required String formId,
    String? cursor,
    int limit = 25,
  }) async => FormCursorPage(
    items: const [FormFileJob(id: 'job-1', status: FormFileJobStatus.processing, progress: .4)],
    nextCursor: null,
  );

  @override
  Future<FormFileJob> requestExport(FormCommand<FormExportPayload> command) async {
    requested = command.payload.kind;
    return const FormFileJob(id: 'job-2', status: FormFileJobStatus.pending, progress: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
