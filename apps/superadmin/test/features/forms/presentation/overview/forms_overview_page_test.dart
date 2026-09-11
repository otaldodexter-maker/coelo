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

  testWidgets('Distribuir aparece so com callback e recarrega a visao geral ao salvar', (
    tester,
  ) async {
    VoidCallback? reload;
    final api = _CountingOverviewApi();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormsOverviewPage(
            api: api,
            formId: 'form-1',
            onDistribute: (callback) => reload = callback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.calls, 1);
    await tester.tap(find.byKey(const Key('forms-overview-distribute')));
    await tester.pump();
    expect(reload, isNotNull);
    reload!();
    await tester.pumpAndSettle();
    // O que o servidor confirmou depois da distribuicao e relido, nao suposto.
    expect(api.calls, 2);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FormsOverviewPage.development(formId: 'form-fixture')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-overview-distribute')), findsNothing);
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

  // Superficie PRODUTIVA (a rota /forms/:formId passa api real) e ate aqui sem
  // nenhuma cobertura de texto ampliado. O padrao de metrica com rotulo rigido
  // e o que costuma estourar a 150% e 200%, e a 100% nada aparece.
  for (final scale in [1.5, 2.0]) {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      testWidgets('overview stays overflow-free at $width px and ${scale}x text', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 2000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(body: FormsOverviewPage(api: _Api(), formId: 'form-1')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('forms-overview-metrics')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'overflow at $width px, ${scale}x');
      });
    }
  }
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

final class _CountingOverviewApi implements FormsApi {
  var calls = 0;

  @override
  Future<FormOverview> getOverview(String formId) async {
    calls++;
    return FormOverview(
      definition: FormDefinition(
        id: formId,
        institutionId: 'inst-1',
        title: 'Contado',
        kind: FormKind.form,
        status: FormStatus.published,
        identityMode: FormIdentityMode.identified,
        responseUnit: FormResponseUnit.person,
        sections: const [],
        managementVersion: 1,
      ),
      applicationCount: 0,
      occurrenceCount: 0,
      responseCount: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
