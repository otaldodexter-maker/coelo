import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_calendar_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';

void main() {
  testWidgets('matriz responsiva não apresenta overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$width px');
    }
  });

  testWidgets('compacto inicia na timeline e abre a agenda completa sem trocar de rota', (
    tester,
  ) async {
    await _setSize(tester, const Size(375, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-timeline')), findsOneWidget);
    expect(find.text('Colégio Horizonte'), findsOneWidget);
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Unidades'), findsOneWidget);
    expect(find.text('Turmas'), findsOneWidget);
    expect(find.text('Atividades'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('agenda-open-full-calendar')));
    await tester.tap(find.byKey(const Key('agenda-open-full-calendar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-month-grid')), findsOneWidget);
    expect(find.byKey(const Key('agenda-back-to-timeline')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline permanece legível a 200 por cento', (tester) async {
    await _setSize(tester, const Size(375, 1000));
    await tester.pumpWidget(_app(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-timeline')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filtro de atividades mantém apenas ocorrências de atividade', (tester) async {
    await _setSize(tester, const Size(768, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atividades'));
    await tester.pumpAndSettle();

    expect(find.text('Ballet'), findsWidgets);
    expect(find.text('Festa do Pijama'), findsNothing);
    expect(find.text('Atividade'), findsWidgets);
  });

  testWidgets('bookmark da timeline alterna estado sem persistência externa', (tester) async {
    await _setSize(tester, const Size(375, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final bookmark = find.byKey(const Key('agenda-bookmark-event-paint'));
    expect(bookmark, findsOneWidget);
    expect(tester.widget<Semantics>(bookmark).properties.toggled, isFalse);

    await tester.ensureVisible(bookmark);
    await tester.tap(bookmark);
    await tester.pump();

    expect(tester.widget<Semantics>(bookmark).properties.toggled, isTrue);
  });

  testWidgets('cards e filtros seguem os estados interativos de Instituições', (tester) async {
    await _setSize(tester, const Size(1440, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('agenda-event-card-routine-school'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(CoeloAdminInteractiveCard)),
      findsOneWidget,
    );
    expect(
      find.text('Atividades e acompanhamento durante todo o período escolar.'),
      findsOneWidget,
    );

    final surface = find.byKey(const Key('agenda-event-card-surface-routine-school'));
    final before = tester.widget<AnimatedContainer>(surface).decoration! as BoxDecoration;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(card));
    await tester.pumpAndSettle();
    final after = tester.widget<AnimatedContainer>(surface).decoration! as BoxDecoration;

    expect(after.border, isNot(before.border));

    final units = tester.widget<TextButton>(find.byKey(const Key('agenda-scope-units')));
    final colors = Theme.of(
      tester.element(find.byKey(const Key('agenda-scope-units'))),
    ).colorScheme;
    expect(units.style?.backgroundColor?.resolve({WidgetState.hovered}), colors.primaryContainer);
    expect(units.style?.foregroundColor?.resolve({WidgetState.focused}), colors.primary);
  });

  testWidgets('calendário completo começa a semana no domingo e abre detalhe', (tester) async {
    await _setSize(tester, const Size(1440, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('agenda-open-full-calendar')));
    await tester.tap(find.byKey(const Key('agenda-open-full-calendar')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-month-grid')), findsOneWidget);
    final weekdayLabels = tester
        .widgetList<Text>(find.byKey(const Key('agenda-calendar-weekday-label')))
        .map((widget) => widget.data)
        .toList();
    expect(weekdayLabels, const ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']);
    final dayButtons = find.descendant(
      of: find.byKey(const Key('agenda-month-grid')),
      matching: find.byType(TextButton),
    );
    await tester.tap(dayButtons.at(9));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes do item'), findsOneWidget);
    expect(find.textContaining('Prioridade normal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  theme: CoeloTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: textScaler),
    child: AgendaCalendarPage(
      store: AgendaPrototypeStore.seeded(),
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
