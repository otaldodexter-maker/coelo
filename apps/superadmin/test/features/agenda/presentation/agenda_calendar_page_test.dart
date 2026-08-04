import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
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

  testWidgets('compacto inicia em Agenda e troca para Mês sem overflow', (tester) async {
    await _setSize(tester, const Size(375, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-occurrence-list')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mês'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-month-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop mostra mês denso e abre painel de detalhe', (tester) async {
    await _setSize(tester, const Size(1440, 1000));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-month-grid')), findsOneWidget);
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

Widget _app() => MaterialApp(
  theme: CoeloTheme.light,
  home: AgendaCalendarPage(
    store: AgendaPrototypeStore.seeded(),
    logout: () async => const LogoutResult.success(),
    onAreaSelected: (_) {},
    onCreateItem: () {},
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
