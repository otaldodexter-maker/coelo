import 'package:coelo_superadmin/features/agenda/presentation/agenda_requests_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fixtures locais cobrem tipos, políticas e estados aprovados', (tester) async {
    await _pumpPage(tester, const Size(1440, 1000));

    expect(find.text('Solicitações e retornos'), findsOneWidget);
    expect(find.text('Autorização'), findsWidgets);
    expect(find.text('RSVP'), findsWidgets);
    expect(find.text('Ciência'), findsWidgets);
    expect(find.text('Pendente'), findsWidgets);
    expect(find.text('Respondido'), findsWidgets);
    expect(find.text('Perdeu elegibilidade'), findsWidgets);
    expect(find.textContaining('Basta um responsável'), findsWidgets);
    expect(find.textContaining('Todos os responsáveis'), findsWidgets);
    expect(find.byKey(const Key('agenda-requests-table')), findsOneWidget);
  });

  testWidgets('resposta por criança avisa os demais responsáveis', (tester) async {
    await _pumpPage(tester, const Size(1440, 1000));

    await tester.tap(find.byKey(const Key('agenda-request-authorize-authorization-lia')).first);
    await tester.pump();

    expect(find.text('Respondido'), findsWidgets);
    expect(find.text('Lia · Turma Girassol'), findsWidgets);
    expect(
      find.text(
        'Resposta registrada para Lia. Os demais responsáveis foram avisados e não precisam responder.',
      ),
      findsOneWidget,
    );
    expect(find.text('Autorizado por Marina Oliveira.'), findsWidgets);
  });

  testWidgets('política todos mantém retorno pendente até a última resposta', (tester) async {
    await _pumpPage(tester, const Size(1440, 1000));

    expect(find.text('1 de 2 responsáveis responderam'), findsWidgets);
    await tester.tap(find.byKey(const Key('agenda-request-rsvp-rsvp-noah')).first);
    await tester.pump();

    expect(find.text('2 de 2 responsáveis responderam'), findsWidgets);
    expect(find.text('Todos os responsáveis responderam por Noah.'), findsOneWidget);
  });

  testWidgets('perda de elegibilidade bloqueia retorno e explica o estado', (tester) async {
    await _pumpPage(tester, const Size(1440, 1000));

    expect(find.text('Perdeu elegibilidade'), findsWidgets);
    expect(find.text('O vínculo com a audiência terminou antes da resposta.'), findsWidgets);
    expect(find.byKey(const Key('agenda-request-respond-science-lost')), findsNothing);
  });

  testWidgets('mobile usa cartões sem overflow', (tester) async {
    await _pumpPage(tester, const Size(375, 900));

    expect(find.byKey(const Key('agenda-requests-card-list')), findsOneWidget);
    expect(find.byKey(const Key('agenda-requests-table')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('produção sem fonte autorizada permanece fail-closed', (tester) async {
    await _pumpPage(tester, const Size(1024, 768), unavailable: true);

    expect(find.byKey(const Key('agenda-requests-unavailable')), findsOneWidget);
    expect(find.text('Solicitações indisponíveis'), findsOneWidget);
    expect(find.text('Lia · Turma Girassol'), findsNothing);
    expect(find.byKey(const Key('agenda-request-authorize-authorization-lia')), findsNothing);
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
            ? const AgendaRequestsPage.unavailable()
            : const AgendaRequestsPage.localFixtures(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
