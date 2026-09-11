import 'package:coelo_superadmin/features/circulars/presentation/circular_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regra do Owner (10/09/2026, noite): em todo diretório administrativo a
/// busca, os filtros, o toggle grade/lista, o botão Arquivos, as abas da tela
/// e o Criar aparecem SEMPRE, inclusive com nada cadastrado e no "sem
/// resultados". Circulares usa abas de status (Todas, Rascunhos, Agendadas,
/// Publicadas, Encerradas) e o filtro Contexto, que sem itens só oferece
/// "Todos" e ainda assim mantém o rótulo.
void main() {
  const widths = [1440.0, 375.0];

  for (final width in widths) {
    final compact = width < CoeloBreakpoints.medium.minWidth;

    testWidgets('vazio em ${width.toInt()} px mantém toolbar, abas e Criar', (tester) async {
      await _pump(tester, size: Size(width, 900));

      expect(find.text('Nenhuma Circular'), findsOneWidget);
      _expectDirectoryChrome(compact: compact);
    });

    testWidgets('sem resultados em ${width.toInt()} px mantém toolbar, abas e Criar', (
      tester,
    ) async {
      await _pump(tester, size: Size(width, 900));

      await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
      await tester.pump();

      expect(find.text('Nenhum resultado'), findsOneWidget);
      expect(find.text('Nenhuma Circular'), findsNothing);
      expect(find.byKey(const Key('coelo-admin-directory-clear-filters')), findsOneWidget);
      _expectDirectoryChrome(compact: compact);
    });
  }
}

/// Afirma o conjunto obrigatório da tela em qualquer estado sem itens. Sem
/// escolha do usuário, compacto abre em cards (Criar em tile) e tablet/desktop
/// em tabela (Criar em banner).
void _expectDirectoryChrome({required bool compact}) {
  // Busca.
  expect(find.byType(CoeloSearchField), findsOneWidget);
  expect(find.text('Buscar circular'), findsOneWidget);

  // Filtro Contexto, com rótulo honesto mesmo sem opções além de "Todos".
  expect(find.byType(CoeloAdminSingleSelectField<String>), findsOneWidget);
  expect(find.text('Contexto'), findsOneWidget);
  final filter = _singleSelect();
  expect(filter.options, ['Todos']);

  // Toggle grade/lista.
  expect(
    find.byType(CoeloAdminDirectoryViewToggle<CoeloAdminDirectoryDisplay>),
    findsOneWidget,
  );

  // Botão Arquivos (Importar / Exportar), honesto e visível.
  expect(find.byType(CoeloAdminFileActions), findsOneWidget);
  expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);

  // Abas de status da tela.
  expect(find.byWidgetPredicate((widget) => widget is CoeloAdminUnderlineTabs), findsOneWidget);
  for (final label in ['Todas', 'Rascunhos', 'Agendadas', 'Publicadas', 'Encerradas']) {
    expect(find.text(label), findsOneWidget, reason: 'aba "$label" ausente');
  }

  // Criar: tile no modo cards (compacto), banner no modo tabela.
  expect(find.text('Nova circular'), findsOneWidget);
  if (compact) {
    expect(find.byKey(const Key('create-circular-card')), findsOneWidget);
    expect(find.byKey(const Key('create-circular-banner')), findsNothing);
  } else {
    expect(find.byKey(const Key('create-circular-banner')), findsOneWidget);
    expect(find.byKey(const Key('create-circular-card')), findsNothing);
  }
}

CoeloAdminSingleSelectField<String> _singleSelect() {
  final finder = find.byType(CoeloAdminSingleSelectField<String>);
  return finder.evaluate().single.widget as CoeloAdminSingleSelectField<String>;
}

Future<void> _pump(WidgetTester tester, {required Size size}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: CircularDirectoryPage(
          items: const [],
          onCreate: () {},
          onOpen: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}
