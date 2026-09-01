import 'package:coelo_superadmin/features/forms/presentation/editor/forms_editor_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('production preserves the editor hierarchy with neutral disabled controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FormsEditorPage()));

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('forms-editor-unavailable')), findsOneWidget);
    final titleField = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .firstWhere((field) => field.controller != null);
    expect(titleField.controller!.text, isEmpty);
    expect(titleField.enabled, isFalse);
    expect(find.text('01 - ANHEMBI - FOTOS'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Publicar ou agendar'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Publicar ou agendar'))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Salvar formulário')).onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.widgetList<ExcludeFocus>(find.byType(ExcludeFocus)).where((value) => value.excluding),
      hasLength(2),
    );
  });

  testWidgets('development editor uses the selected form fixture', (tester) async {
    await tester.pumpWidget(_app(const FormsEditorPage.development(formId: 'form-dev-02')));

    final titleField = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .firstWhere((field) => field.controller != null);
    expect(titleField.controller!.text, 'Enquete rápida sobre transporte');
    expect(find.byKey(const Key('forms-editor-periodicity')), findsOneWidget);
    expect(find.byKey(const Key('forms-editor-first-occurrence')), findsOneWidget);
  });

  testWidgets('keeps preview hidden until requested and owns the canonical footer', (tester) async {
    await tester.pumpWidget(_app(const FormsEditorPage.development()));

    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('forms-editor-preview')), findsNothing);
    expect(find.byKey(const Key('forms-editor-header-save')), findsNothing);
    expect(find.byKey(const Key('forms-editor-header-preview')), findsNothing);
    expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Salvar rascunho'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Salvar formulário'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('forms-editor-toggle-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-toggle-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forms-editor-preview')), findsOneWidget);
    expect(find.text('Fechar prévia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('question catalog is vertically categorized and owns its scroll', (tester) async {
    await tester.pumpWidget(_app(const FormsEditorPage.development()));

    await tester.ensureVisible(find.byKey(const Key('forms-editor-add-question')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-add-question')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forms-editor-question-catalog')), findsOneWidget);
    expect(find.byKey(const Key('forms-editor-question-catalog-scroll')), findsOneWidget);
    final textTop = tester.getTopLeft(find.text('Texto e números')).dy;
    final choicesTop = tester.getTopLeft(find.text('Escolhas')).dy;
    final mediaTop = tester.getTopLeft(find.text('Mídias')).dy;
    expect(choicesTop, greaterThan(textTop));
    expect(mediaTop, greaterThan(choicesTop));
    expect(find.text('Texto curto'), findsOneWidget);
    expect(find.text('Número inteiro'), findsOneWidget);
    expect(find.text('Número decimal'), findsOneWidget);
    expect(find.text('Dinheiro'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('Sim / Não'), findsWidgets);
    expect(find.text('Única escolha'), findsOneWidget);
    expect(find.text('Múltipla escolha'), findsOneWidget);
    expect(find.text('Escala'), findsOneWidget);
    expect(find.text('Foto'), findsWidgets);
    expect(find.text('Galeria'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('forms-editor-catalog-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-catalog-date')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('forms-editor-question-date')), findsOneWidget);
    expect(find.text('Validação da data'), findsOneWidget);
    expect(find.text('Livre'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('forms-editor-date-rule')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('forms-editor-date-rule')));
    await tester.pumpAndSettle();
    expect(find.text('A partir de'), findsOneWidget);
    expect(find.text('Até'), findsOneWidget);
    expect(find.text('Intervalo permitido'), findsOneWidget);

    final dynamic dateRuleField = tester.widget(find.byKey(const Key('forms-editor-date-rule')));
    dateRuleField.onChanged(dateRuleField.options.last);
    await tester.pump();
    expect(find.byKey(const Key('forms-editor-date-config-range')), findsOneWidget);
    expect(find.byKey(const Key('forms-editor-date-min')), findsOneWidget);
    expect(find.byKey(const Key('forms-editor-date-max')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preserves section and question operations without hiding required controls', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FormsEditorPage.development()));

    expect(find.byKey(const Key('forms-editor-section-list')), findsOneWidget);
    expect(find.byKey(const Key('forms-editor-section-reorder-list')), findsOneWidget);
    expect(find.byKey(const Key('forms-editor-question-reorder-list')), findsOneWidget);
    expect(find.byTooltip('Arrastar seção'), findsWidgets);
    expect(find.byTooltip('Arrastar pergunta'), findsWidgets);
    expect(find.byTooltip('Duplicar seção'), findsOneWidget);
    expect(find.byTooltip('Excluir seção'), findsOneWidget);
    expect(find.byTooltip('Mover pergunta para cima'), findsWidgets);
    expect(find.byTooltip('Mover pergunta para outra seção'), findsWidgets);
    expect(find.byTooltip('Duplicar pergunta'), findsWidgets);
    expect(find.text('Obrigatória'), findsWidgets);
    expect(find.text('Desdobrar por resposta'), findsOneWidget);

    await tester.ensureVisible(find.text('Adicionar pergunta ao ramo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar pergunta ao ramo'));
    await tester.pump();
    expect(find.text('Pergunta do ramo 1'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Excluir pergunta').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Excluir pergunta').last);
    await tester.pumpAndSettle();
    expect(find.text('Excluir pergunta?'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Manter pergunta'));
    await tester.pumpAndSettle();
    expect(find.text('Tem ponto extra?'), findsWidgets);

    await tester.tap(find.byTooltip('Duplicar seção'));
    await tester.pump();
    expect(find.textContaining('cópia'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configures information details and numeric bounds', (tester) async {
    await tester.pumpWidget(_app(const FormsEditorPage.development()));

    await tester.ensureVisible(find.byKey(const Key('forms-editor-add-question')));
    await tester.tap(find.byKey(const Key('forms-editor-add-question')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('forms-editor-catalog-information')));
    await tester.tap(find.byKey(const Key('forms-editor-catalog-information')));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes do bloco'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('forms-editor-add-question')));
    await tester.tap(find.byKey(const Key('forms-editor-add-question')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('forms-editor-catalog-money')));
    await tester.tap(find.byKey(const Key('forms-editor-catalog-money')));
    await tester.pumpAndSettle();
    expect(find.text('Valor mínimo'), findsOneWidget);
    expect(find.text('Valor máximo'), findsOneWidget);
  });

  testWidgets('publishes now or schedules only inside the development fixture', (tester) async {
    await tester.pumpWidget(_app(const FormsEditorPage.development()));

    expect(find.widgetWithText(OutlinedButton, 'Publicar ou agendar'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Publicar ou agendar'));
    await tester.pumpAndSettle();
    expect(find.text('Publicar formulário'), findsOneWidget);
    expect(find.byKey(const Key('forms-editor-publish-mode')), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Publicar agora'), findsWidgets);
    await tester.tap(find.byKey(const Key('forms-editor-confirm-publish')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Publicação concluída somente nesta fixture local'), findsOneWidget);
    expect(find.textContaining('nenhuma persistência remota'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Publicar ou agendar'));
    await tester.pumpAndSettle();
    final dynamic publishMode = tester.widget(find.byKey(const Key('forms-editor-publish-mode')));
    publishMode.onChanged(publishMode.options.last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-editor-publish-scheduled-at')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('forms-editor-confirm-publish'))).onPressed,
      isNull,
    );
    expect(find.textContaining('Escolha a data e a hora'), findsOneWidget);
    final dateField = tester.widget<CoeloDateTimeField>(
      find.byKey(const Key('forms-editor-publish-scheduled-at')),
    );
    dateField.onChanged(DateTime(2026, 9, 12, 8, 30));
    await tester.pump();
    await tester.tap(find.byKey(const Key('forms-editor-confirm-publish')));
    await tester.pumpAndSettle();
    expect(find.textContaining('12/09/2026 às 08:30'), findsOneWidget);
    expect(find.textContaining('nenhuma persistência remota'), findsOneWidget);
  });

  testWidgets('production exposes publication context without enabling its local flow', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const FormsEditorPage()));

    expect(find.text('Publicar ou agendar'), findsOneWidget);
    expect(find.text('Publicar agora'), findsNothing);
    expect(find.textContaining('Publicação concluída'), findsNothing);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('editor preserves actions and scroll at $width with ${scale}x text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _app(
            const FormsEditorPage.development(),
            dark: width == 1440,
            textScaler: TextScaler.linear(scale),
          ),
        );

        expect(find.byType(SuperadminFormFrame), findsOneWidget);
        expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
        expect(find.byKey(const Key('forms-editor-scroll')), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Salvar formulário'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Widget _app(Widget child, {bool dark = false, TextScaler textScaler = TextScaler.noScaling}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler, disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        backgroundColor: dark ? CoeloTheme.dark.colorScheme.surface : null,
        body: child,
      ),
    );
