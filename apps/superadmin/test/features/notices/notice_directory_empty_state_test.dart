import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/notices/presentation/notice_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_notice_repository.dart';

/// Regra do Owner (10/09/2026, noite): em todo diretório administrativo a
/// busca, os filtros, o toggle grade/lista, o botão Arquivos, as abas da tela
/// e o Criar aparecem SEMPRE, inclusive com nada cadastrado e no "sem
/// resultados". Comunicações/Avisos usa abas de tipo (Todos, Avisos,
/// Conteúdos, Destaques, Para você) e o filtro Estado.
void main() {
  const widths = [1440.0, 375.0];

  for (final width in widths) {
    final compact = width < CoeloBreakpoints.medium.minWidth;

    testWidgets('vazio em ${width.toInt()} px mantém toolbar, abas e Criar', (tester) async {
      await _pumpDirectory(tester, size: Size(width, 900));

      expect(find.text('Nenhuma comunicação'), findsOneWidget);
      _expectDirectoryChrome(compact: compact);
    });

    testWidgets('sem resultados em ${width.toInt()} px mantém toolbar, abas e Criar', (
      tester,
    ) async {
      await _pumpDirectory(tester, size: Size(width, 900));

      await tester.enterText(find.byType(EditableText).first, 'sem correspondência');
      // A busca dispara a recarga depois do debounce de 300 ms.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('Nenhum resultado'), findsOneWidget);
      expect(find.text('Nenhuma comunicação'), findsNothing);
      _expectDirectoryChrome(compact: compact);
    });
  }
}

/// Afirma o conjunto obrigatório da tela em qualquer estado sem itens. Abaixo
/// do breakpoint médio a página força cards (Criar em tile); acima, abre em
/// tabela (Criar em banner).
void _expectDirectoryChrome({required bool compact}) {
  // Busca.
  expect(find.byType(CoeloSearchField), findsOneWidget);
  expect(find.text('Buscar comunicação'), findsOneWidget);

  // Filtro Estado, com rótulo honesto mesmo sem itens.
  expect(find.byWidgetPredicate((widget) => widget is CoeloAdminSingleSelectField), findsOneWidget);
  expect(find.text('Estado'), findsOneWidget);

  // Toggle grade/lista.
  expect(
    find.byType(CoeloAdminDirectoryViewToggle<CoeloAdminDirectoryDisplay>),
    findsOneWidget,
  );

  // Botão Arquivos (Importar / Exportar), honesto e visível.
  expect(find.byType(CoeloAdminFileActions), findsOneWidget);
  expect(find.byKey(const Key('coelo-admin-files-action')), findsOneWidget);

  // Abas de tipo da tela.
  expect(find.byWidgetPredicate((widget) => widget is CoeloAdminUnderlineTabs), findsOneWidget);
  for (final label in ['Todos', 'Avisos', 'Conteúdos', 'Destaques', 'Para você']) {
    expect(find.text(label), findsWidgets, reason: 'aba "$label" ausente');
  }

  // Criar: tile no modo cards (compacto), banner no modo tabela.
  expect(find.text('Nova comunicação'), findsOneWidget);
  if (compact) {
    expect(find.byKey(const Key('create-notice-card')), findsOneWidget);
    expect(find.byKey(const Key('create-notice-banner')), findsNothing);
  } else {
    expect(find.byKey(const Key('create-notice-banner')), findsOneWidget);
    expect(find.byKey(const Key('create-notice-card')), findsNothing);
  }
}

Future<void> _pumpDirectory(WidgetTester tester, {required Size size}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final now = DateTime.utc(2026, 8, 3, 12);
  final activities = SuperadminActivityController(now: () => now);
  final store = SuperadminPrototypeStore(activityController: activities, now: () => now);
  final repository = FakeNoticeRepository(store: store, now: () => now);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: NoticeDirectoryPage(
          repository: repository,
          canManageLifecycle: true,
          onCreate: () {},
          onEdit: (_) {},
        ),
      ),
    ),
  );
  // A carga inicial é assíncrona: um pump para o frame, outro para o resultado.
  await tester.pump();
  await tester.pump();
}
