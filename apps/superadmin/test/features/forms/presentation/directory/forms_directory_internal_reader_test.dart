import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/forms_directory_reader.dart';
import 'package:coelo_superadmin/features/forms/data/forms_editor_context.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FormCursorPage<FormDirectoryItem> _page(String title, {String? cursor}) => FormCursorPage(
  items: [
    FormDirectoryItem(
      id: title,
      title: title,
      kind: FormKind.form,
      status: FormStatus.draft,
      operationalStatus: FormOperationalStatus.draft,
      identityMode: FormIdentityMode.identified,
      updatedAt: DateTime(2026, 9, 7),
      managementVersion: 1,
    ),
  ],
  nextCursor: cursor,
);

Future<void> _pump(WidgetTester tester, FormsDirectoryReader? reader, {FormsApi? api}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: FormsDirectoryPage(
          key: const ValueKey('directory'),
          api: api,
          reader: reader,
          canManage: true,
          canManageLifecycle: true,
          canTransferCrossInstitution: true,
          onCreate: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('pending People context cannot restore capabilities after A reader A round trip', (
    tester,
  ) async {
    final legacy = _PendingContextLegacy();
    Future<void> pump(FormsDirectoryReader? reader) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: FormsDirectoryPage(
              key: const ValueKey('context-test'),
              api: legacy,
              reader: reader,
              onCreate: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump(null);
    await pump(_Reader((_) async => _page('Interno')));
    await pump(null);
    legacy.current.complete(const FormsEditorContext(institutions: []));
    await tester.pumpAndSettle();
    legacy.old.complete(
      const FormsEditorContext(
        institutions: [
          FormsEditorInstitution(
            id: 'synthetic',
            name: 'Synthetic',
            canManageForms: true,
            canPublishForms: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-directory-create')), findsNothing);
  });

  for (final fail in [false, true]) {
    testWidgets('disposed reader ignores pending ${fail ? 'failure' : 'success'}', (tester) async {
      final pending = Completer<FormCursorPage<FormDirectoryItem>>();
      await _pump(tester, _Reader((_) => pending.future));
      await tester.pumpWidget(const SizedBox.shrink());
      if (fail) {
        pending.completeError(const FormApiException(FormApiFailureKind.unauthorized, 'Revogado'));
      } else {
        pending.complete(_page('Não exibir'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Não exibir'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'internal reader is exclusive and never requests People context or mutation capabilities',
    (tester) async {
      final legacy = _Legacy();
      final reader = _Reader((_) async => _page('Interno autorizado'));
      await _pump(tester, reader, api: legacy);
      await tester.pumpAndSettle();
      expect(find.text('Interno autorizado'), findsWidgets);
      expect(legacy.calls, isEmpty);
      expect(reader.queries, hasLength(1));
      expect(find.byKey(const Key('forms-directory-create')), findsNothing);
    },
  );

  testWidgets('authorized internal reader works with api null', (tester) async {
    await _pump(tester, _Reader((_) async => _page('Sem fallback')));
    await tester.pumpAndSettle();
    expect(find.text('Sem fallback'), findsWidgets);
    expect(find.text('O serviço de Formulários não está disponível neste ambiente.'), findsNothing);
  });

  testWidgets('denied reader never falls back to the supplied legacy API', (tester) async {
    final legacy = _Legacy();
    await _pump(
      tester,
      _Reader((_) async => throw const FormApiException(FormApiFailureKind.unauthorized, 'negado')),
      api: legacy,
    );
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byKey(const Key('forms-directory-search')), findsNothing);
    expect(legacy.calls, isEmpty);
  });

  testWidgets('reader swap clears visible data filters cursor and pending debounce', (
    tester,
  ) async {
    final readerA = _Reader((_) async => _page('Contexto A', cursor: 'cursor-a'));
    final readerB = _Reader((_) async => _page('Contexto B'));
    await _pump(tester, readerA);
    await tester.pumpAndSettle();
    tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)).onNext!();
    await tester.pumpAndSettle();
    expect(readerA.queries.last.cursor, 'cursor-a');
    await tester.enterText(find.byKey(const Key('forms-directory-search')), 'busca A');
    tester
        .widget<CoeloAdminMultiSelectField<FormOperationalStatus>>(
          find.byType(CoeloAdminMultiSelectField<FormOperationalStatus>),
        )
        .onChanged({FormOperationalStatus.active});
    tester
        .widget<CoeloDateRangeField>(find.byType(CoeloDateRangeField))
        .onChanged(DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 7)));
    await _pump(tester, readerB);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.text('Contexto A'), findsNothing);
    expect(find.text('Contexto B'), findsWidgets);
    expect(readerB.queries, hasLength(1));
    final query = readerB.queries.single;
    expect(query.cursor, isNull);
    expect(query.search, isNull);
    expect(query.operationalStatuses, isEmpty);
    expect(query.startsOnOrAfter, isNull);
    expect(query.endsOnOrBefore, isNull);
    expect(
      tester
          .widget<CoeloSearchField>(find.byKey(const Key('forms-directory-search')))
          .controller
          .text,
      isEmpty,
    );
  });

  for (final failOld in [false, true]) {
    testWidgets('stale reader ${failOld ? 'failure' : 'success'} cannot replace B', (tester) async {
      final pending = Completer<FormCursorPage<FormDirectoryItem>>();
      await _pump(tester, _Reader((_) => pending.future));
      await _pump(tester, _Reader((_) async => _page('Contexto B')));
      await tester.pumpAndSettle();
      if (failOld) {
        pending.completeError(
          const FormApiException(FormApiFailureKind.unauthorized, 'Negação obsoleta'),
        );
      } else {
        pending.complete(_page('Contexto A'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Contexto B'), findsWidgets);
      expect(find.text('Contexto A'), findsNothing);
      expect(find.text('Acesso não autorizado'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('retry reloads the same reader and then removes old content on revocation', (
    tester,
  ) async {
    var count = 0;
    final reader = _Reader((_) async {
      count++;
      if (count == 1) throw const FormApiException(FormApiFailureKind.unavailable, 'Indisponível');
      if (count == 3) throw const FormApiException(FormApiFailureKind.unauthorized, 'Revogado');
      return _page('Recuperado', cursor: 'next');
    });
    await _pump(tester, reader);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Recuperado'), findsWidgets);
    tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)).onNext!();
    await tester.pumpAndSettle();
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.text('Recuperado'), findsNothing);
    expect(count, 3);
  });

  testWidgets('removing the reader and API clears data instead of retaining prior context', (
    tester,
  ) async {
    await _pump(tester, _Reader((_) async => _page('Contexto antigo')));
    await tester.pumpAndSettle();
    expect(find.text('Contexto antigo'), findsWidgets);
    await _pump(tester, null);
    await tester.pumpAndSettle();
    expect(find.text('Contexto antigo'), findsNothing);
    expect(
      find.text('O serviço de Formulários não está disponível neste ambiente.'),
      findsOneWidget,
    );
  });
}

final class _Reader implements FormsDirectoryReader {
  _Reader(this.read);
  final Future<FormCursorPage<FormDirectoryItem>> Function(FormDirectoryQuery) read;
  final queries = <FormDirectoryQuery>[];
  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) {
    queries.add(query);
    return read(query);
  }
}

final class _Legacy implements FormsApi, FormsEditorContextApi {
  final calls = <String>[];
  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async {
    calls.add('legacy-list');
    return _page('Legado');
  }

  @override
  Future<FormsEditorContext> getEditorContext() async {
    calls.add('People-context');
    return const FormsEditorContext(institutions: []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _PendingContextLegacy implements FormsApi, FormsEditorContextApi {
  final old = Completer<FormsEditorContext>();
  final current = Completer<FormsEditorContext>();
  var calls = 0;
  @override
  Future<FormsEditorContext> getEditorContext() => ++calls == 1 ? old.future : current.future;
  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async =>
      _page('Legado');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
