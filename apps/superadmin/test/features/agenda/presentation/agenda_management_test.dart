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

  Widget app(Widget child) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(body: child),
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
  });
}
