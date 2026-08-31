import 'package:coelo_superadmin/features/forms/presentation/operations/forms_operations_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('monitor representa hierarquia e elegibilidade', (tester) async {
    await _pump(tester, const FormsOperationsPage.monitor(development: true));

    expect(find.text('Monitoramento'), findsOneWidget);
    expect(find.text('Elegíveis'), findsOneWidget);
    expect(find.text('Responderam'), findsOneWidget);
    expect(find.text('Não responderam'), findsOneWidget);
    expect(find.text('Perdeu elegibilidade'), findsOneWidget);
    expect(find.byKey(const Key('forms-monitor-hierarchy')), findsOneWidget);
  });

  testWidgets('respostas alternam identificadas e anônimas e usam cursor', (tester) async {
    await _pump(tester, const FormsOperationsPage.responses(development: true));

    expect(find.text('Respostas'), findsOneWidget);
    expect(find.text('Identificadas'), findsOneWidget);
    expect(find.text('Anônimas'), findsOneWidget);
    expect(find.byKey(const Key('forms-cursor-next')), findsOneWidget);
    expect(find.textContaining('storage_path'), findsNothing);
  });

  testWidgets('detalhe anônimo não inventa identidade e alerta segredo perdido', (tester) async {
    await _pump(
      tester,
      const FormsOperationsPage.responseDetail(development: true, anonymous: true),
    );

    expect(find.text('Resposta anônima'), findsOneWidget);
    expect(find.textContaining('não podem ser recuperadas'), findsOneWidget);
    expect(find.text('Nome da pessoa'), findsNothing);
  });

  testWidgets('arquivos representam upload e todos os estados de jobs', (tester) async {
    await _pump(tester, const FormsOperationsPage.files(development: true));

    expect(find.text('Arquivos e exportações'), findsOneWidget);
    for (final label in const [
      'Aguardando',
      'Processando',
      'Concluído',
      'Dividido',
      'Expirado',
      'Falhou',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.byKey(const Key('forms-upload-progress')), findsOneWidget);
    expect(find.textContaining('storage_path'), findsNothing);
    expect(find.textContaining('https://'), findsNothing);
  });

  testWidgets('produção mantém composição e ações fail-closed', (tester) async {
    await _pump(tester, const FormsOperationsPage.files());

    expect(find.text('Arquivos e exportações'), findsOneWidget);
    expect(find.byKey(const Key('forms-operations-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('forms-upload-progress')), findsOneWidget);
    expect(find.text('Nenhum arquivo autorizado carregado'), findsOneWidget);
    expect(find.text('comprovante-familia.pdf'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Exportar'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Exportar')).onPressed,
      isNull,
    );
  });

  testWidgets('arquivo protegido expira e exclusão exige confirmação negativa', (tester) async {
    await _pump(tester, const FormsOperationsPage.files(development: true));

    await tester.tap(find.text('Expirar acesso'));
    await tester.pump();
    expect(find.text('Acesso temporário expirado'), findsOneWidget);

    await tester.tap(find.text('Excluir arquivo'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir arquivo protegido?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir arquivo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('forms-file-absent-after-reload')), findsOneWidget);
  });

  testWidgets('fixtures expõem estados operacionais sem sucesso produtivo falso', (tester) async {
    for (final state in FormsOperationsState.values.where(
      (value) => value != FormsOperationsState.content,
    )) {
      await _pump(
        tester,
        FormsOperationsPage.responses(development: true, state: state),
        settle: state != FormsOperationsState.loading,
      );
      final key = state == FormsOperationsState.unavailable
          ? 'forms-operations-unavailable'
          : 'forms-operations-state-${state.name}';
      expect(find.byKey(Key(key)), findsOneWidget, reason: state.name);
    }
  });

  testWidgets('operações não apresentam overflow na matriz responsiva', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1200);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: FormsOperationsPage.files(development: true)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$width px');
    }
  });
}

Future<void> _pump(WidgetTester tester, Widget page, {bool settle = true}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1024, 1000);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(MaterialApp(theme: CoeloTheme.light, home: page));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
