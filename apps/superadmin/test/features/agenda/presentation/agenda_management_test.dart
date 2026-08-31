import 'dart:ui';

import 'package:coelo_superadmin/features/agenda/data/agenda_prototype_store.dart';
import 'package:coelo_superadmin/features/agenda/domain/agenda_models.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_event_form_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_events_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_permissions_page.dart';
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
    expect(find.byKey(const Key('agenda-events-create-card')), findsOneWidget);

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

  testWidgets('eventos alterna Cards e Tabela com criação e paginação canônicas', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      app(AgendaEventsPage(store: store(), onCreate: () {}, onOpen: (_) {}, onEdit: (_) {})),
    );

    expect(find.byKey(const Key('agenda-events-display-toggle')), findsOneWidget);
    expect(find.byKey(const Key('agenda-event-card-grid')), findsOneWidget);
    expect(find.byKey(const Key('agenda-events-create-card')), findsOneWidget);
    expect(find.byType(CoeloAdminResizableTable<AgendaItem>), findsNothing);
    final cardsPagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(cardsPagination.pageSize, 11);
    expect(cardsPagination.pageSizeOptions, const [11, 20, 50, 100]);

    await tester.tap(find.byKey(const Key('agenda-events-view-table')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-events-create-banner')), findsOneWidget);
    expect(find.byType(CoeloAdminResizableTable<AgendaItem>), findsOneWidget);
    final tablePagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    expect(tablePagination.pageSize, 8);
    expect(tablePagination.pageSizeOptions, const [8, 20, 50, 100]);

    await tester.tap(find.byKey(const Key('agenda-events-view-cards')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-event-card-grid')), findsOneWidget);
    expect(tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)).pageSize, 11);
  });

  testWidgets('cards e tabela preservam status e ação Editar equivalentes', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final prototype = store();
    final sortedItems = [...prototype.items]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final item = sortedItems.first;
    final edited = <String>[];

    await tester.pumpWidget(
      app(AgendaEventsPage(store: prototype, onCreate: () {}, onOpen: (_) {}, onEdit: edited.add)),
    );
    final statusLabel = switch (item.status) {
      AgendaItemStatus.draft => 'Rascunho',
      AgendaItemStatus.scheduled => 'Agendado',
      AgendaItemStatus.published => 'Publicado',
      AgendaItemStatus.canceled => 'Cancelado',
    };
    expect(
      find.descendant(
        of: find.byKey(Key('agenda-event-card-${item.id}')),
        matching: find.bySemanticsLabel('Status: $statusLabel'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(Key('agenda-event-actions-${item.id}')));
    await tester.pumpAndSettle();
    tester
        .widget<MenuItemButton>(
          find.ancestor(of: find.text('Editar'), matching: find.byType(MenuItemButton)),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(edited, [item.id]);

    await tester.tap(find.byKey(const Key('agenda-events-view-table')));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloStatusChip), findsWidgets);
    await tester.tap(find.byKey(Key('agenda-event-actions-${item.id}')));
    await tester.pumpAndSettle();
    tester
        .widget<MenuItemButton>(
          find.ancestor(of: find.text('Editar'), matching: find.byType(MenuItemButton)),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(edited, [item.id, item.id]);
  });

  testWidgets('troca de store limpa intenção de busca filtros e página', (tester) async {
    final storeA = store();
    final storeB = store();
    for (var index = 0; index < 13; index++) {
      storeA.upsertItem(
        AgendaItem.fixture(
          id: 'event-a-$index',
          title: 'Tenant A evento $index',
          audience: const AgendaAudience(institutionId: 'inst-a'),
          startsAt: DateTime(2026, 6, index + 1, 8),
          endsAt: DateTime(2026, 6, index + 1, 9),
        ),
      );
    }
    storeB.upsertItem(
      AgendaItem.fixture(
        id: 'event-b-only',
        title: 'Evento exclusivo B',
        audience: const AgendaAudience(institutionId: 'inst-horizonte'),
        startsAt: DateTime(2026, 7, 1, 8),
        endsAt: DateTime(2026, 7, 1, 9),
      ),
    );
    final key = GlobalKey();

    await tester.pumpWidget(
      app(
        AgendaEventsPage(key: key, store: storeA, onCreate: () {}, onOpen: (_) {}, onEdit: (_) {}),
      ),
    );
    await tester.enterText(find.byType(CoeloSearchField), 'Tenant A');
    final typeFilter = tester.widget<CoeloAdminSingleSelectField<AgendaItemType?>>(
      find.byType(CoeloAdminSingleSelectField<AgendaItemType?>),
    );
    typeFilter.onChanged(AgendaItemType.event);
    final statusFilter = tester.widget<CoeloAdminSingleSelectField<AgendaItemStatus?>>(
      find.byType(CoeloAdminSingleSelectField<AgendaItemStatus?>),
    );
    statusFilter.onChanged(AgendaItemStatus.published);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(CoeloAdminPagination),
      500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('agenda-events-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final pagination = tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination));
    pagination.onNext!();
    await tester.pump();
    expect(tester.widget<CoeloAdminPagination>(find.byType(CoeloAdminPagination)).currentPage, 2);

    await tester.pumpWidget(
      app(
        AgendaEventsPage(key: key, store: storeB, onCreate: () {}, onOpen: (_) {}, onEdit: (_) {}),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byType(CoeloSearchField),
      -500,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('agenda-events-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(tester.widget<CoeloSearchField>(find.byType(CoeloSearchField)).controller.text, isEmpty);
    expect(
      tester
          .widget<CoeloAdminSingleSelectField<AgendaItemType?>>(
            find.byType(CoeloAdminSingleSelectField<AgendaItemType?>),
          )
          .value,
      isNull,
    );
    expect(
      tester
          .widget<CoeloAdminSingleSelectField<AgendaItemStatus?>>(
            find.byType(CoeloAdminSingleSelectField<AgendaItemStatus?>),
          )
          .value,
      isNull,
    );
    expect(find.text('Evento exclusivo B'), findsOneWidget);
    expect(find.textContaining('Tenant A evento'), findsNothing);
    expect(find.byKey(const Key('agenda-events-page-1')), findsOneWidget);
  });

  testWidgets('eventos não transborda na matriz responsiva e texto ampliado', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final scale in [1.0, 2.0]) {
      for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1400);
        await tester.pumpWidget(
          app(
            AgendaEventsPage(
              key: ValueKey((width, scale)),
              store: store(),
              onCreate: () {},
              onOpen: (_) {},
              onEdit: (_) {},
            ),
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow at ${width}px and ${scale * 100}% text',
        );
        expect(find.byKey(const Key('agenda-event-card-grid')), findsOneWidget);
        await tester.tap(find.byKey(const Key('agenda-events-view-table')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('agenda-events-create-banner')), findsOneWidget);
        expect(find.byType(CoeloAdminResizableTable<AgendaItem>), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'table overflow at ${width}px and ${scale * 100}% text',
        );
      }
    }
  });

  testWidgets('permissão bloqueada no ancestral expõe origem sem permitir mutação', (tester) async {
    final prototype = store();
    prototype.setCapabilityRestricted('inst-horizonte', AgendaCapability.publishAgendaItems, true);
    await tester.pumpWidget(app(AgendaPermissionsPage(store: prototype)));
    expect(find.byType(CoeloAdminResizableTable<AgendaContext>), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(CoeloAdminToggleField), findsNothing);
    expect(find.textContaining('Bloqueado por'), findsWidgets);
    final semanticsFinder = find.byKey(
      const Key('agenda-permission-semantics-group-girassol-publishAgendaItems'),
    );
    final semantics = tester.getSemantics(semanticsFinder).getSemanticsData();
    expect(
      find.bySemanticsLabel(
        'Publicar eventos em Turma Girassol. Bloqueado por Centro Horizonte. Somente leitura.',
      ),
      findsOneWidget,
    );
    expect(semantics.hasAction(SemanticsAction.tap), isFalse);
  });

  testWidgets('permissão disponível permanece somente leitura', (tester) async {
    await tester.pumpWidget(app(AgendaPermissionsPage(store: store())));
    final semanticsFinder = find.byKey(
      const Key('agenda-permission-semantics-inst-horizonte-publishAgendaItems'),
    );
    final semantics = tester.getSemantics(semanticsFinder).getSemanticsData();

    expect(
      find.bySemanticsLabel(
        'Publicar eventos em Centro Horizonte. Permitido neste nível. Somente leitura.',
      ),
      findsOneWidget,
    );
    expect(semantics.hasAction(SemanticsAction.tap), isFalse);
    expect(find.byType(CoeloAdminToggleField), findsNothing);
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
          expect(table.rowHeight, 104);
        }
      }
    }
  });
}
