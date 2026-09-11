import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_events_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regra do Owner (10/09/2026, noite): em todo diretório administrativo a
/// busca, os filtros, o toggle grade/lista, o botão Arquivos, as abas da tela
/// e o Criar aparecem SEMPRE, inclusive com nada cadastrado e no "sem
/// resultados". A Agenda de eventos não tem abas de status: o conjunto da tela
/// é busca, filtros Tipo e Status, toggle, Arquivos e Criar item.
void main() {
  const widths = [1440.0, 375.0];

  for (final width in widths) {
    testWidgets('vazio em ${width.toInt()} px mantém toolbar e Criar', (tester) async {
      await _pump(tester, size: Size(width, 900));

      expect(find.text('Nenhum item na agenda'), findsOneWidget);
      _expectDirectoryChrome();
    });

    testWidgets('sem resultados em ${width.toInt()} px mantém toolbar e Criar', (tester) async {
      await _pump(tester, size: Size(width, 900));

      await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
      await tester.pump();

      expect(find.text('Nenhum item encontrado'), findsOneWidget);
      expect(find.text('Nenhum item na agenda'), findsNothing);
      expect(find.byKey(const Key('coelo-admin-directory-clear-filters')), findsOneWidget);
      _expectDirectoryChrome();
    });
  }

  testWidgets('vazio em tabela mantém o banner Criar em 1440 px', (tester) async {
    await _pump(tester, size: const Size(1440, 900));

    final toggle = tester.widget<CoeloAdminDirectoryViewToggle<CoeloAdminDirectoryDisplay>>(
      find.byType(CoeloAdminDirectoryViewToggle<CoeloAdminDirectoryDisplay>),
    );
    toggle.onTableViewSelected(CoeloAdminDirectoryDisplay.table);
    await tester.pump();

    expect(find.byKey(const Key('agenda-events-create-banner')), findsOneWidget);
    expect(find.byKey(const Key('agenda-events-create-card')), findsNothing);
    expect(find.text('Nenhum item na agenda'), findsOneWidget);
    _expectDirectoryChrome(expectTile: false);
  });
}

/// Afirma o conjunto obrigatório da tela em qualquer estado sem itens. A
/// página abre em cards em qualquer largura, então o Criar é o tile; a tabela
/// só aparece por escolha do usuário.
void _expectDirectoryChrome({bool expectTile = true}) {
  // Busca.
  expect(find.byType(CoeloSearchField), findsOneWidget);
  expect(find.text('Buscar por título ou local'), findsOneWidget);

  // Filtros Tipo e Status, com rótulo honesto mesmo sem itens.
  expect(find.byType(CoeloAdminSingleSelectField<AgendaItemType?>), findsOneWidget);
  expect(find.byType(CoeloAdminSingleSelectField<AgendaItemStatus?>), findsOneWidget);
  expect(find.text('Tipo'), findsOneWidget);
  expect(find.text('Status'), findsOneWidget);

  // Toggle grade/lista.
  expect(find.byKey(const Key('agenda-events-display-toggle')), findsOneWidget);
  expect(
    find.byType(CoeloAdminDirectoryViewToggle<CoeloAdminDirectoryDisplay>),
    findsOneWidget,
  );

  // Botão Arquivos (Importar / Exportar), honesto e visível.
  expect(find.byType(CoeloAdminFileActions), findsOneWidget);
  expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);

  // A Agenda não passa abas ao composto: nada a afirmar além da ausência.
  expect(find.byWidgetPredicate((widget) => widget is CoeloAdminUnderlineTabs), findsNothing);

  // Criar item: tile no modo cards, banner no modo tabela.
  expect(find.text('Criar item'), findsOneWidget);
  if (expectTile) {
    expect(find.byKey(const Key('agenda-events-create-card')), findsOneWidget);
    expect(find.byKey(const Key('agenda-events-create-banner')), findsNothing);
  }
}

Future<void> _pump(WidgetTester tester, {required Size size}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final store = AgendaPrototypeStore.empty(clock: () => DateTime(2026, 8, 3, 12));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: AgendaEventsPage(store: store, onCreate: () {}, onOpen: (_) {}, onEdit: (_) {}),
      ),
    ),
  );
  await tester.pump();
}
