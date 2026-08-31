import 'dart:async';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/overview/forms_overview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders backend counts and capability-scoped actions responsively', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsOverviewPage(api: _Api(), formId: 'form-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pesquisa das famílias'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fails closed when forms service is unavailable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FormsOverviewPage(api: null, formId: 'form-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar o formulário'), findsOneWidget);
    expect(find.byKey(const Key('forms-overview-content')), findsOneWidget);
  });

  testWidgets('fixture local cobre distribuição audiência agendamento e versionamento', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FormsOverviewPage.development(formId: 'form-fixture')),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in const [
      'Distribuições e audiências',
      'Instituição · Unidade · Turma · Atividade · Perfil · Pessoa',
      'Agendamento único e recorrente',
      'Ocorrências, fuso e lembretes',
      'Versão publicada 3',
      'Rascunho de edição 4',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Fixture local · sem persistência remota'), findsOneWidget);
  });

  testWidgets('fixture local preserva o formulário selecionado', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FormsOverviewPage.development(formId: 'form-dev-02')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enquete rápida sobre transporte'), findsOneWidget);
    expect(find.text('Pesquisa das famílias'), findsNothing);
  });

  testWidgets('ações do resumo navegam somente quando callbacks são fornecidos', (tester) async {
    var monitorOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsOverviewPage.development(
            formId: 'form-fixture',
            onMonitor: () => monitorOpened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Editar')).onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Monitorar'));
    expect(monitorOpened, isTrue);
  });

  testWidgets('uses responsive insets and canonical card gaps', (tester) async {
    for (final (size, expectedInset) in [
      (const Size(375, 800), CoeloSpacing.space4),
      (const Size(768, 800), CoeloSpacing.space6),
      (const Size(1440, 900), CoeloSpacing.space10),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FormsOverviewPage(api: _Api(), formId: 'form-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final content = tester.widget<ListView>(find.byKey(const Key('forms-overview-content')));
      expect(content.padding, EdgeInsets.all(expectedInset));
      final metrics = tester.widget<Wrap>(find.byKey(const Key('forms-overview-metrics')));
      expect(metrics.spacing, CoeloSpacing.space6);
      expect(metrics.runSpacing, CoeloSpacing.space6);
    }
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('route A cannot overwrite route B when responses finish out of order', (
    tester,
  ) async {
    final api = _OrderedOverviewApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsOverviewPage(api: api, formId: 'form-a'),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsOverviewPage(api: api, formId: 'form-b'),
        ),
      ),
    );
    await tester.pump();

    api.forId('form-b').complete(_overview('form-b', 'Formulário B'));
    await tester.pump();
    expect(find.text('Formulário B'), findsOneWidget);

    api.forId('form-a').complete(_overview('form-a', 'Formulário A'));
    await tester.pump();
    expect(find.text('Formulário B'), findsOneWidget);
    expect(find.text('Formulário A'), findsNothing);
  });
}

FormOverview _overview(String id, String title) => FormOverview(
  definition: FormDefinition(
    id: id,
    institutionId: 'institution-1',
    kind: FormKind.form,
    identityMode: FormIdentityMode.identified,
    responseUnit: FormResponseUnit.person,
    title: title,
    managementVersion: 1,
    sections: const [],
  ),
  applicationCount: 0,
  occurrenceCount: 0,
  responseCount: 0,
);

final class _OrderedOverviewApi implements FormsApi {
  final _requests = <String, Completer<FormOverview>>{};

  Completer<FormOverview> forId(String id) => _requests[id]!;

  @override
  Future<FormOverview> getOverview(String formId) =>
      (_requests[formId] = Completer<FormOverview>()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Api implements FormsApi {
  @override
  Future<FormOverview> getOverview(String formId) async => FormOverview(
    definition: FormDefinition(
      id: formId,
      institutionId: 'institution-1',
      kind: FormKind.form,
      identityMode: FormIdentityMode.identified,
      responseUnit: FormResponseUnit.person,
      title: 'Pesquisa das famílias',
      managementVersion: 4,
      sections: const [],
    ),
    applicationCount: 3,
    occurrenceCount: 12,
    responseCount: 28,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
