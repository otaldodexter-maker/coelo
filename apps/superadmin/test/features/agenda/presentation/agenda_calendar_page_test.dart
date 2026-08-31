import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_calendar_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_module_shell.dart';
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
}

Widget _app({TextScaler textScaler = TextScaler.noScaling, ThemeData? theme}) => MaterialApp(
  theme: theme ?? CoeloTheme.light,
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
