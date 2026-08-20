import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_directory_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/monitoring/forms_monitor_page.dart';
import 'package:coelo_superadmin/features/forms/presentation/responses/forms_responses_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _goldenRoot = Key('forms-visual-golden-root');

void main() {
  final configurations = <({String name, Size size, Brightness brightness})>[
    (name: '375_light', size: const Size(375, 800), brightness: Brightness.light),
    (name: '768_dark', size: const Size(768, 900), brightness: Brightness.dark),
    (name: '1024_light', size: const Size(1024, 900), brightness: Brightness.light),
    (name: '1440_dark', size: const Size(1440, 900), brightness: Brightness.dark),
  ];

  for (final config in configurations) {
    testWidgets('directory visual contract ${config.name}', (tester) async {
      await _pumpSurface(
        tester,
        size: config.size,
        brightness: config.brightness,
        child: FormsDirectoryPage(api: _VisualFormsApi(), canManage: true),
      );
      await _expectGolden('goldens/forms_directory_${config.name}.png');
    });

    testWidgets('editor visual contract ${config.name}', (tester) async {
      await _pumpSurface(
        tester,
        size: config.size,
        brightness: config.brightness,
        child: FormsEditorPage(api: _VisualFormsApi(), initialDefinition: _definition),
      );
      await _expectGolden('goldens/forms_editor_${config.name}.png');
    });

    testWidgets('monitor visual contract ${config.name}', (tester) async {
      await _pumpSurface(
        tester,
        size: config.size,
        brightness: config.brightness,
        child: FormsMonitorPage(api: _VisualFormsApi(), formId: 'form-1', canListPeople: true),
      );
      await _expectGolden('goldens/forms_monitor_${config.name}.png');
    });

    testWidgets('responses visual contract ${config.name}', (tester) async {
      await _pumpSurface(
        tester,
        size: config.size,
        brightness: config.brightness,
        child: FormsResponsesPage(api: _VisualFormsApi(), formId: 'form-1'),
      );
      await _expectGolden('goldens/forms_responses_${config.name}.png');
    });
  }

  testWidgets('directory cards remain responsive with 200 percent text', (tester) async {
    await _pumpSurface(
      tester,
      size: const Size(375, 900),
      brightness: Brightness.light,
      textScaler: TextScaler.linear(2),
      child: FormsDirectoryPage(api: _VisualFormsApi(), canManage: true),
    );
    final cardsToggle = find.byKey(const Key('forms-directory-view-cards'));
    await tester.ensureVisible(cardsToggle);
    await tester.pumpAndSettle();
    await tester.tap(cardsToggle);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _expectGolden('goldens/forms_directory_cards_text_200_light_375.png');
  });

  testWidgets('editor structure remains responsive with 200 percent text', (tester) async {
    await _pumpSurface(
      tester,
      size: const Size(375, 800),
      brightness: Brightness.light,
      textScaler: TextScaler.linear(2),
      child: FormsEditorPage(api: _VisualFormsApi(), initialDefinition: _definition),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _expectGolden('goldens/forms_editor_structure_text_200_light_375.png');
  });

  testWidgets('owner anonymous dialog remains responsive with 200 percent text', (tester) async {
    await _pumpSurface(
      tester,
      size: const Size(375, 800),
      brightness: Brightness.light,
      textScaler: TextScaler.linear(2),
      child: FormsMonitorPage(
        api: _VisualFormsApi(isAnonymous: true),
        formId: 'form-1',
        canListPeople: true,
        canReadAnonymousParticipation: true,
      ),
    );
    final anonymousAction = find.text('Consultar participação anônima');
    await tester.scrollUntilVisible(
      anonymousAction,
      300,
      scrollable: find
          .descendant(of: find.byType(FormsMonitorPage), matching: find.byType(Scrollable))
          .first,
    );
    await tester.ensureVisible(anonymousAction);
    await tester.pumpAndSettle();
    await tester.tap(anonymousAction);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _expectGolden('goldens/forms_monitor_owner_dialog_text_200_light_375.png');
  });

  testWidgets('anonymous responses hide identity with 200 percent text', (tester) async {
    await _pumpSurface(
      tester,
      size: const Size(375, 800),
      brightness: Brightness.light,
      textScaler: TextScaler.linear(2),
      child: FormsResponsesPage(api: _VisualFormsApi(isAnonymous: true), formId: 'form-1'),
    );
    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.text('Ana Família'), findsNothing);
    expect(tester.takeException(), isNull);
    await _expectGolden('goldens/forms_responses_anonymous_text_200_light_375.png');
  });
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required Size size,
  required Brightness brightness,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    RepaintBoundary(
      key: _goldenRoot,
      child: MaterialApp(
        theme: brightness == Brightness.dark ? CoeloTheme.dark : CoeloTheme.light,
        builder: (context, appChild) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: appChild!,
        ),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(String path) async {
  await expectLater(find.byKey(_goldenRoot), matchesGoldenFile(path));
}

final _definition = FormDefinition(
  id: 'form-1',
  institutionId: 'institution-1',
  kind: FormKind.form,
  identityMode: FormIdentityMode.identified,
  responseUnit: FormResponseUnit.person,
  title: 'Pesquisa das famílias',
  managementVersion: 1,
  sections: [
    FormSection(
      id: 'section-1',
      title: 'Sobre a rotina',
      position: 0,
      items: [
        FormItem(
          id: 'item-1',
          kind: FormItemKind.shortText,
          label: 'Como foi a adaptação?',
          position: 0,
        ),
      ],
    ),
  ],
);

final class _VisualFormsApi implements FormsApi {
  _VisualFormsApi({this.isAnonymous = false});

  final bool isAnonymous;

  FormResponseSummary get _summary => FormResponseSummary(
    id: 'response-1',
    occurrenceId: 'occurrence-1',
    formVersionId: 'version-1',
    submittedAt: isAnonymous ? null : DateTime(2026, 8, 13, 10),
    respondentLabel: isAnonymous ? null : 'Ana Família',
  );

  @override
  Future<FormCursorPage<FormDirectoryItem>> listDirectory(FormDirectoryQuery query) async =>
      FormCursorPage(
        items: [
          FormDirectoryItem(
            id: 'form-1',
            title: 'Pesquisa das famílias',
            kind: FormKind.form,
            status: FormStatus.published,
            operationalStatus: FormOperationalStatus.scheduled,
            identityMode: FormIdentityMode.identified,
            updatedAt: DateTime(2026, 8, 13),
            managementVersion: 2,
          ),
        ],
        nextCursor: null,
      );

  @override
  Future<FormMonitorProjection> getMonitor(FormMonitorQuery query) async => FormMonitorProjection(
    eligibleCount: 42,
    respondedCount: 31,
    pendingCount: 11,
    isAnonymous: isAnonymous,
  );

  @override
  Future<FormCursorPage<FormMonitorScope>> listMonitorHierarchy(FormMonitorQuery query) async =>
      FormCursorPage(
        items: const [
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
        nextCursor: null,
      );

  @override
  Future<FormCursorPage<FormResponseSummary>> listResponses(FormResponsesQuery query) async =>
      FormCursorPage(items: [_summary], nextCursor: null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
