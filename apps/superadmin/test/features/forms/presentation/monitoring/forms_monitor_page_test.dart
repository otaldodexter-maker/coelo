import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/monitoring/forms_monitor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows authorized metrics and identified people with cursor pagination', (
    tester,
  ) async {
    final api = _MonitorApi(isAnonymous: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsMonitorPage(api: api, formId: 'form-1', canListPeople: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('42'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Ana Família'), findsOneWidget);
    expect(find.text('Próxima página'), findsOneWidget);
  });

  testWidgets('keeps ordinary anonymous monitoring aggregate only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsMonitorPage(
            api: _MonitorApi(isAnonymous: true),
            formId: 'form-1',
            canListPeople: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Participação anônima'), findsOneWidget);
    expect(find.text('Ana Família'), findsNothing);
    expect(find.textContaining('agregados'), findsOneWidget);
    expect(find.text('Consultar participação anônima'), findsNothing);
  });

  testWidgets('shows authorized hierarchy and keeps owner anonymous operations separate', (
    tester,
  ) async {
    final api = _MonitorApi(isAnonymous: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsMonitorPage(
            api: api,
            formId: 'form-1',
            canListPeople: true,
            canReadAnonymousParticipation: true,
            canExportAnonymousParticipation: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hierarquia'), findsOneWidget);
    await tester.tap(find.text('Instituição Aurora'));
    await tester.pumpAndSettle();
    expect(api.hierarchyQueries.last.scopeId, 'institution-1');
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Instituição Aurora'), findsOneWidget);
    expect(find.text('Consultar participação anônima'), findsOneWidget);
    expect(find.text('Exportar participação anônima'), findsOneWidget);
    expect(find.text('Ana Família'), findsNothing);

    await tester.tap(find.text('Consultar participação anônima'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Continuar'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuar')).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextFormField).last, 'Auditoria de participação necessária');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();
    expect(api.anonymousJustifications, ['Auditoria de participação necessária']);
  });
}

final class _MonitorApi implements FormsApi {
  _MonitorApi({required this.isAnonymous});
  final bool isAnonymous;
  final hierarchyQueries = <FormMonitorQuery>[];
  final anonymousJustifications = <String>[];

  @override
  Future<FormMonitorProjection> getMonitor(FormMonitorQuery query) async => FormMonitorProjection(
    eligibleCount: 42,
    respondedCount: 31,
    pendingCount: 11,
    isAnonymous: isAnonymous,
  );

  @override
  Future<FormCursorPage<FormMonitorPerson>> listMonitorPeople(FormMonitorQuery query) async =>
      FormCursorPage(
        items: const [
          FormMonitorPerson(
            personId: 'person-1',
            displayName: 'Ana Família',
            profileLabel: 'Responsável',
            contextLabel: 'Turma Azul',
            responded: true,
          ),
        ],
        nextCursor: 'opaque-next',
      );

  @override
  Future<FormCursorPage<FormMonitorScope>> listMonitorHierarchy(FormMonitorQuery query) async {
    hierarchyQueries.add(query);
    return FormCursorPage(
      items: [
        FormMonitorScope(
          scopeId: 'institution-1',
          scopeKind: FormMonitorScopeKind.institution,
          label: 'Instituição Aurora',
          eligibleCount: 42,
          respondedCount: 31,
          pendingCount: 11,
        ),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<FormCursorPage<FormMonitorPerson>> anonymousParticipationLookup(
    FormAnonymousParticipationQuery query,
  ) async {
    anonymousJustifications.add(query.justification);
    return FormCursorPage(items: const [], nextCursor: null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
