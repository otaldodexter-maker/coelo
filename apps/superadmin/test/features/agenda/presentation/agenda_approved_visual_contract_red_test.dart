import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_calendar_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_module_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_underline_tabs.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expõe somente as visões aprovadas Calendário e Lista', (tester) async {
    await _pumpAgenda(tester, const Size(1440, 1000));

    expect(find.text('Agenda institucional'), findsOneWidget);
    expect(find.text('Calendário'), findsOneWidget);
    expect(find.text('Lista'), findsOneWidget);
    expect(find.text('Semana'), findsNothing);
    expect(find.text('Dia'), findsNothing);
  });

  testWidgets('remove hero e tabs antigas da composição institucional', (tester) async {
    await _pumpAgenda(tester, const Size(1440, 1000));

    expect(find.byType(SuperadminUnderlineTabs<AgendaModuleArea>), findsNothing);
    expect(find.text('Eventos'), findsNothing);
    expect(find.text('Solicitações'), findsNothing);
    expect(find.text('Permissões'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('institution-cover'),
      ),
      findsNothing,
    );
  });

  testWidgets('Lista abre a timeline institucional aprovada', (tester) async {
    await _pumpAgenda(tester, const Size(1440, 1000));

    await tester.tap(find.text('Lista'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-list-timeline')), findsOneWidget);
    expect(find.text('Feira cultural 2026'), findsOneWidget);
    expect(find.text('Reunião de responsáveis'), findsOneWidget);
    expect(find.text('Passeio pedagógico'), findsOneWidget);
    expect(find.text('Festival de esportes'), findsOneWidget);
    expect(find.text('Mostra de projetos'), findsOneWidget);
  });

  testWidgets('clicar no dia abre detalhe diário em tela inteira no mobile', (tester) async {
    await _pumpAgenda(tester, const Size(375, 1000));

    final day = find.byKey(const Key('agenda-day-2026-08-03'));
    expect(day, findsOneWidget);
    await tester.tap(day);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-day-fullscreen')), findsOneWidget);
    expect(find.byKey(const Key('agenda-day-detail-panel')), findsNothing);
    expect(find.text('Segunda-feira, 3 de agosto'), findsOneWidget);
  });

  testWidgets('clicar no dia abre painel expansível em tablet', (tester) async {
    await _pumpAgenda(tester, const Size(768, 1000));

    final day = find.byKey(const Key('agenda-day-2026-08-03'));
    expect(day, findsOneWidget);
    await tester.tap(day);
    await tester.pumpAndSettle();

    expect(find.byType(CoeloAdminWorkspaceLayout), findsOneWidget);
    expect(find.byKey(const Key('agenda-day-detail-panel')), findsOneWidget);
    expect(find.byKey(const Key('agenda-day-panel-expand')), findsOneWidget);
    expect(find.byKey(const Key('agenda-day-fullscreen')), findsNothing);
  });

  testWidgets('sem ações produtivas apresenta estado fail-closed', (tester) async {
    await _pumpUnavailableAgenda(tester, const Size(1440, 1000));

    expect(find.byKey(const Key('agenda-production-unavailable')), findsOneWidget);
    expect(find.text('Agenda indisponível'), findsOneWidget);
    expect(find.text('Calendário'), findsOneWidget);
    expect(find.text('Lista'), findsOneWidget);
    expect(find.byType(CoeloAdminWorkspaceLayout), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('agenda-production-unavailable')),
              matching: find.byType(TextField),
            ),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('agenda-view-list'))).onPressed,
      isNull,
    );
    expect(find.text('Permanência na escola'), findsNothing);
  });
}

Future<void> _pumpUnavailableAgenda(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: AgendaCalendarPage.unavailable(
        logout: () async => const LogoutResult.success(),
        onAreaSelected: (_) {},
        onCreateItem: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

Future<void> _pumpAgenda(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: AgendaCalendarPage(
        store: AgendaPrototypeStore.seeded(),
        logout: () async => const LogoutResult.success(),
        onAreaSelected: (_) {},
        onCreateItem: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
