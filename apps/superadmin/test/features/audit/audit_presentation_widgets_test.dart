import 'package:coelo_superadmin/features/audit/presentation/widgets/audit_actor_summary.dart';
import 'package:coelo_superadmin/features/audit/presentation/widgets/audit_safe_diff.dart';
import 'package:coelo_superadmin/features/audit/presentation/widgets/audit_timeline.dart';
import 'package:coelo_superadmin/features/audit/domain/audit.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('actor summary identifies actor, role and trusted context', (tester) async {
    await tester.pumpWidget(
      _app(
        const AuditActorSummary(
          actorName: 'Operadora Coelo',
          actorRole: 'Suporte interno',
          actorContext: 'Plataforma',
        ),
      ),
    );

    expect(find.text('Operadora Coelo'), findsOneWidget);
    expect(find.text('Suporte interno'), findsOneWidget);
    expect(find.text('Plataforma'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Ator Operadora Coelo, Suporte interno, Plataforma'),
      findsOneWidget,
    );
  });

  testWidgets('safe diff renders only already minimized entries and an explicit empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            AuditSafeDiff(title: 'Antes', values: {'status': 'ativo'}),
            AuditSafeDiff(title: 'Depois', values: {}),
          ],
        ),
      ),
    );

    expect(find.text('status'), findsOneWidget);
    expect(find.text('ativo'), findsOneWidget);
    expect(find.text('Sem valores registrados.'), findsOneWidget);
    expect(find.textContaining('token'), findsNothing);
    expect(find.textContaining('CPF'), findsNothing);
  });

  testWidgets('safe diff remains usable at 200 percent text scale in dark mode', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(375, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _app(
        const AuditSafeDiff(title: 'Depois', values: {'resultado': 'Autorizado pelo servidor'}),
        dark: true,
        textScale: 2,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Autorizado pelo servidor'), findsOneWidget);
  });

  testWidgets('timeline exposes chronological events as accessible actions', (tester) async {
    final event = AuditEvent(
      id: 'event-1',
      actor: const AuditActor(id: 'actor-1', displayName: 'Operadora', roleCode: 'support'),
      actionCode: 'session.denied',
      resourceType: 'session',
      resourceId: 'session-1',
      outcome: AuditOutcome.denied,
      origin: 'edge_function',
      context: const AuditContext(kind: 'platform'),
      occurredAt: DateTime.utc(2026, 8, 11),
    );
    AuditEvent? selected;
    await tester.pumpWidget(
      _app(AuditTimeline(events: [event], onSelected: (value) => selected = value)),
    );

    final action = find.bySemanticsLabel('Abrir evento de auditoria event-1');
    expect(action, findsOneWidget);
    await tester.tap(action);
    expect(selected, same(event));
  });

  testWidgets('timeline safely labels a legacy event without resource identifiers', (tester) async {
    final event = AuditEvent(
      id: 'legacy-event',
      actor: const AuditActor(id: null, displayName: 'Sistema', roleCode: 'system'),
      resourceType: null,
      resourceId: null,
      actionCode: 'legacy.event',
      outcome: AuditOutcome.success,
      origin: 'database',
      context: const AuditContext(kind: 'global'),
      occurredAt: DateTime.utc(2026, 8, 11),
    );
    await tester.pumpWidget(_app(AuditTimeline(events: [event], onSelected: (_) {})));

    expect(find.text('Sem recurso registrado'), findsOneWidget);
  });
}

Widget _app(Widget child, {bool dark = false, double textScale = 1}) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(
    body: MediaQuery(
      data: const MediaQueryData().copyWith(textScaler: TextScaler.linear(textScale)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: child,
      ),
    ),
  ),
);
