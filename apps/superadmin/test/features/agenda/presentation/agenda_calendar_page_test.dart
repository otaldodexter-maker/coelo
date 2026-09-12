import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_calendar_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('matriz responsiva aprovada não apresenta overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1200);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$width px');
    }
  });

  testWidgets('matriz a 200 por cento funciona em claro e escuro', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final theme in [CoeloTheme.light, CoeloTheme.dark]) {
      for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1600);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_app(theme: theme, textScaler: const TextScaler.linear(2)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'width=$width theme=${theme.brightness}');
      }
    }
  });

  testWidgets('calendário inicia no domingo e o dia abre detalhe no mobile', (tester) async {
    await _setSize(tester, const Size(375, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-month-grid')), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    await tester.tap(find.byKey(const Key('agenda-day-2026-08-17')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-day-fullscreen')), findsOneWidget);
    expect(find.textContaining('17 de agosto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lista institucional filtra pela busca sem persistência externa', (tester) async {
    await _setSize(tester, const Size(1440, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final agendaSearch = find.byWidgetPredicate(
      (widget) => widget is CoeloSearchField && widget.semanticLabel == 'Buscar eventos da Agenda',
    );
    await tester.enterText(
      find.descendant(of: agendaSearch, matching: find.byType(EditableText)),
      'Festival',
    );
    await tester.tap(find.byKey(const Key('agenda-view-list')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-list-timeline')), findsOneWidget);
    expect(find.text('Festival de esportes'), findsOneWidget);
    expect(find.text('Feira cultural 2026'), findsNothing);
  });

  testWidgets('cards da lista preservam estado interativo canônico', (tester) async {
    await _setSize(tester, const Size(1440, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-view-list')));
    await tester.pumpAndSettle();

    final card = find.byType(CoeloAdminInteractiveCard).first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();

    expect(find.text('Feira cultural 2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('referência iOS (P33): hoje em círculo cheio, cancelado hachurado e Hoje no rodapé', (
    tester,
  ) async {
    await _setSize(tester, const Size(1440, 1000));
    final store = AgendaPrototypeStore.seeded(clock: () => DateTime(2026, 8, 3, 12));
    store.cancelItem('event-parents', actorName: 'QA');
    await tester.pumpWidget(_app(store: store));
    await tester.pumpAndSettle();

    // Cancelado continua visível no mês, com o prefixo e o horário.
    expect(find.textContaining('CANCELADO: Feira cultural 2026'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    // Hoje (data de referência) tem círculo cheio na cor primária.
    final today = find.descendant(
      of: find.byKey(const Key('agenda-day-2026-08-03')),
      matching: find.byType(DecoratedBox),
    );
    final decoration = tester.widget<DecoratedBox>(today.first).decoration as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(decoration.color, CoeloTheme.light.colorScheme.primary);
    // Botão Hoje fica no rodapé e volta ao mês de referência.
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();
    expect(find.text('setembro de 2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('agenda-today')));
    await tester.pumpAndSettle();
    expect(find.text('agosto de 2026'), findsOneWidget);
    // V-8 (Owner, 11/09): no web o par Calendário/Lista volta ao R (dois botões
    // de 88 px à direita da toolbar); o 50/50 centralizado fica só no mobile.
    final calendar = tester.getSize(find.byKey(const Key('agenda-view-calendar')));
    final list = tester.getSize(find.byKey(const Key('agenda-view-list')));
    expect(calendar.width, greaterThanOrEqualTo(88));
    expect(list.width, greaterThanOrEqualTo(88));
    expect(calendar.width + list.width, lessThan(400));
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  TextScaler textScaler = TextScaler.noScaling,
  ThemeData? theme,
  AgendaPrototypeStore? store,
}) => MaterialApp(
  theme: theme ?? CoeloTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: textScaler),
    child: AgendaCalendarPage(
      store: store ?? AgendaPrototypeStore.seeded(),
      logout: () async => const LogoutResult.success(),
      onAreaSelected: (_) {},
      onCreateItem: () {},
    ),
  ),
);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}
