import 'dart:ui';

import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_permissions_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AgendaPrototypeStore store() => AgendaPrototypeStore.seeded();

  testWidgets('desktop exibe sete capacidades como matriz somente leitura', (tester) async {
    await _size(tester, const Size(1440, 1200));
    await tester.pumpWidget(_app(AgendaPermissionsPage(store: store())));
    await tester.pumpAndSettle();

    final table = tester.widget<CoeloAdminResizableTable<AgendaContext>>(
      find.byKey(const Key('agenda-permissions-table')),
    );
    expect(table.columns, hasLength(7));
    expect(table.columns.map((column) => column.label), [
      'Criar',
      'Editar próprios',
      'Editar todos',
      'Publicar',
      'Cancelar/restaurar',
      'Gerenciar respostas',
      'Override de reserva',
    ]);
    expect(find.byType(CoeloAdminToggleField), findsNothing);
    expect(find.textContaining('fonte de verdade é Perfis e Permissões'), findsOneWidget);
  });

  testWidgets('mostra permitido herdado restrito e bloqueado com origem sem ação', (tester) async {
    final prototype = store();
    prototype.setCapabilityRestricted('unit-cambui', AgendaCapability.publishAgendaItems, true);
    await _size(tester, const Size(375, 1400));
    await tester.pumpWidget(_app(AgendaPermissionsPage(store: prototype)));
    await tester.pumpAndSettle();

    expect(find.text('Permitido neste nível'), findsWidgets);
    expect(find.textContaining('Herdado de Centro Horizonte'), findsWidgets);
    expect(find.text('Restringido neste nível'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('agenda-permission-card-group-girassol')),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('agenda-permissions-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('Bloqueado por Unidade Cambuí'), findsWidgets);
    final semantics = tester
        .getSemantics(
          find.byKey(const Key('agenda-permission-semantics-group-girassol-publishAgendaItems')),
        )
        .getSemanticsData();
    expect(semantics.hasAction(SemanticsAction.tap), isFalse);
    expect(find.byType(CoeloAdminToggleField), findsNothing);
  });

  testWidgets('compacto permanece responsivo com texto ampliado', (tester) async {
    await _size(tester, const Size(375, 1600));
    await tester.pumpWidget(
      _app(AgendaPermissionsPage(store: store()), textScaler: const TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agenda-permissions-table')), findsNothing);
    expect(find.byKey(const Key('agenda-permission-card-inst-horizonte')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable e 403 não expõem dados antes da autorização', (tester) async {
    await tester.pumpWidget(_app(const AgendaPermissionsPage.unavailable()));
    expect(find.byKey(const Key('agenda-permissions-unavailable')), findsOneWidget);
    expect(find.text('Permissões indisponíveis'), findsOneWidget);
    expect(find.text('Centro Horizonte'), findsNothing);

    await tester.pumpWidget(_app(const AgendaPermissionsPage.unauthorized()));
    expect(find.byKey(const Key('agenda-permissions-unauthorized')), findsOneWidget);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.textContaining('403'), findsOneWidget);
    expect(find.text('Centro Horizonte'), findsNothing);
  });
}

Widget _app(Widget child, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  theme: CoeloTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: textScaler),
    child: Scaffold(body: child),
  ),
);

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}
