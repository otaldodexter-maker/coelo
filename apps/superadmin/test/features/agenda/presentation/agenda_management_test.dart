import 'dart:ui';

import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_event_form_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_events_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_permissions_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_requests_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AgendaPrototypeStore store() =>
      AgendaPrototypeStore.seeded(clock: () => DateTime(2026, 8, 3, 12));

  Widget app(Widget child, {TextScaler textScaler = TextScaler.noScaling, ThemeData? theme}) =>
      MaterialApp(
        theme: theme ?? CoeloTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: textScaler),
          child: Scaffold(body: child),
        ),
      );

  testWidgets('diretório abre e wizard preserva título entre etapas', (tester) async {
    final prototype = store();
    await tester.pumpWidget(
      app(AgendaEventsPage(store: prototype, onCreate: () {}, onOpen: (_) {}, onEdit: (_) {})),
    );
    expect(find.text('Eventos'), findsOneWidget);
    expect(find.byKey(const Key('agenda-events-create')), findsOneWidget);

    await tester.pumpWidget(
      app(AgendaEventFormPage(store: prototype, onCancel: () {}, onSaved: (_) {})),
    );
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.textContaining('somente nesta sessão local'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, 'Encontro da turma');
    await tester.tap(find.byKey(const Key('agenda-wizard-continue')));
    await tester.pump();
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('agenda-wizard-continue'))),
      isA<OutlinedButton>(),
    );
    await tester.tap(find.byKey(const Key('agenda-wizard-previous')));
    await tester.pump();
    expect(find.text('Encontro da turma'), findsOneWidget);
  });

  testWidgets('aprovação decide uma vez e cria rascunho', (tester) async {
    final prototype = store();
    await tester.pumpWidget(app(AgendaRequestsPage(store: prototype)));
    await tester.tap(find.byKey(const Key('agenda-request-approve-request-pending')));
    await tester.pump();
    expect(find.text('Aprovada e convertida em rascunho.'), findsOneWidget);
    expect(
      prototype.items.any(
        (item) =>
            item.origin == AgendaItemOrigin.guardianRequest &&
            item.status == AgendaItemStatus.draft,
      ),
      isTrue,
    );
    expect(prototype.requestById('request-pending')!.decision, isNotNull);
  });

  testWidgets('responsável envia somente solicitação de aniversário', (tester) async {
    final prototype = store();
    final requestCount = prototype.requests.length;
    final itemCount = prototype.items.length;
    await tester.pumpWidget(app(AgendaRequestsPage(store: prototype)));
    await tester.tap(find.byKey(const Key('agenda-request-create')));
    await tester.pump();
    expect(find.text('1. Criança e contexto'), findsOneWidget);
    expect(find.text('Tipo'), findsNothing);
    await tester.tap(find.byKey(const Key('agenda-request-continue')));
    await tester.pump();
    expect(find.byType(CoeloDateTimeField), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('agenda-request-continue')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('agenda-request-submit')));
    await tester.pump();
    expect(prototype.requests, hasLength(requestCount + 1));
    expect(prototype.requests.last.status, GuardianRequestStatus.sent);
    expect(prototype.items, hasLength(itemCount));
  });

  testWidgets('permissão bloqueada no ancestral não pode ser ampliada', (tester) async {
    final prototype = store();
    prototype.setCapabilityRestricted('inst-horizonte', AgendaCapability.publishAgendaItems, true);
    await tester.pumpWidget(app(AgendaPermissionsPage(store: prototype)));
    expect(find.byType(CoeloAdminResizableTable<AgendaContext>), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    final control = find.byKey(const Key('agenda-permission-group-girassol-publishAgendaItems'));
    final toggle = tester.widget<CoeloAdminToggleField>(control);
    expect(toggle.onChanged, isNull);
    expect(find.textContaining('Bloqueado por'), findsWidgets);
    final semanticsFinder = find.byKey(
      const Key('agenda-permission-semantics-group-girassol-publishAgendaItems'),
    );
    final semantics = tester.getSemantics(semanticsFinder).getSemanticsData();
    expect(
      find.bySemanticsLabel('Publicar itens em Turma Girassol. Bloqueado por Centro Horizonte'),
      findsOneWidget,
    );
    expect(semantics.flagsCollection.isToggled, Tristate.isFalse);
    expect(semantics.hasAction(SemanticsAction.tap), isFalse);
  });

  testWidgets('permissão disponível expõe um único toggle acionável', (tester) async {
    await tester.pumpWidget(app(AgendaPermissionsPage(store: store())));
    final semanticsFinder = find.byKey(
      const Key('agenda-permission-semantics-inst-horizonte-publishAgendaItems'),
    );
    final semantics = tester.getSemantics(semanticsFinder).getSemanticsData();

    expect(
      find.bySemanticsLabel('Publicar itens em Centro Horizonte. Permitido neste nível'),
      findsOneWidget,
    );
    expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets('permissões preservam tabela Coelo com densidade responsiva', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final scale in [1.0, 2.0]) {
      for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1400);
        await tester.pumpWidget(
          app(
            AgendaPermissionsPage(key: ValueKey((width, scale)), store: store()),
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow at ${width}px and ${scale * 100}% text',
        );
        final tableBreakpoint = scale > 1
            ? CoeloBreakpoints.expanded.minWidth
            : CoeloBreakpoints.medium.minWidth;
        final usesCompactCards = width / scale < tableBreakpoint;
        if (usesCompactCards) {
          expect(find.byKey(const Key('agenda-permissions-table')), findsNothing);
        } else {
          final table = tester.widget<CoeloAdminResizableTable<AgendaContext>>(
            find.byKey(const Key('agenda-permissions-table')),
          );
          expect(table.rowHeight, 88);
        }
      }
    }
  });
}
