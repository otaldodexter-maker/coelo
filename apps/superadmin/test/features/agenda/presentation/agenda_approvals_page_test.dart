import 'package:coelo_superadmin/features/agenda/presentation/agenda_approvals_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fixtures locais cobrem pendente, aprovado e recusado', (tester) async {
    await _pumpPage(tester, const Size(1440, 1000));

    expect(find.text('Aprovações de publicação'), findsOneWidget);
    expect(find.text('Festival de esportes'), findsWidgets);
    expect(find.text('Feira cultural 2026'), findsWidgets);
    expect(find.text('Passeio pedagógico'), findsWidgets);
    expect(find.text('Aguardando publicação'), findsWidgets);
    expect(find.text('Aprovado'), findsWidgets);
    expect(find.text('Recusado'), findsWidgets);
    expect(find.byKey(const Key('agenda-approvals-table')), findsOneWidget);
  });

  testWidgets('decisão exige justificativa e registra histórico local', (tester) async {
    await _pumpPage(tester, const Size(1440, 1000));

    await tester.tap(find.byKey(const Key('agenda-approval-decide-pending-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-approval-confirm-approve')));
    await tester.pump();

    expect(find.text('Informe a justificativa da decisão.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('agenda-approval-reason')),
      'Programação e audiência conferidas.',
    );
    await tester.tap(find.byKey(const Key('agenda-approval-confirm-approve')));
    await tester.pumpAndSettle();

    expect(find.text('Decisão registrada por Marina Oliveira.'), findsOneWidget);
    expect(find.text('Programação e audiência conferidas.'), findsOneWidget);
  });

  testWidgets('recusa preserva justificativa no histórico', (tester) async {
    await _pumpPage(tester, const Size(1440, 1000));

    await tester.tap(find.byKey(const Key('agenda-approval-decide-pending-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('agenda-approval-reason')),
      'Conflito com a reserva do auditório.',
    );
    await tester.tap(find.byKey(const Key('agenda-approval-confirm-reject')));
    await tester.pumpAndSettle();

    expect(find.text('Recusado'), findsWidgets);
    expect(find.text('Decisão registrada por Marina Oliveira.'), findsOneWidget);
    expect(find.text('Conflito com a reserva do auditório.'), findsOneWidget);
  });

  testWidgets('mobile usa lista de cartões sem overflow', (tester) async {
    await _pumpPage(tester, const Size(375, 900));

    expect(find.byKey(const Key('agenda-approvals-card-list')), findsOneWidget);
    expect(find.byKey(const Key('agenda-approvals-table')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('produção indisponível permanece fail-closed', (tester) async {
    await _pumpPage(tester, const Size(1024, 768), unavailable: true);

    expect(find.byKey(const Key('agenda-approvals-unavailable')), findsOneWidget);
    expect(find.text('Aprovações indisponíveis'), findsOneWidget);
    expect(find.text('Festival de esportes'), findsNothing);
    expect(find.byKey(const Key('agenda-approval-confirm-approve')), findsNothing);
  });
}

Future<void> _pumpPage(WidgetTester tester, Size size, {bool unavailable = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: unavailable
            ? const AgendaApprovalsPage.unavailable()
            : const AgendaApprovalsPage.localFixtures(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
