import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_detail_panel.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_directory_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses table wide and cards compact without mutation actions', (tester) async {
    await _pump(tester, 1440);
    expect(find.byType(CoeloAdminResizableTable<PrototypeAuditEvent>), findsOneWidget);
    expect(find.text('8 eventos'), findsOneWidget);
    for (final label in ['Criar', 'Editar', 'Excluir', 'Exportar']) {
      expect(find.text(label), findsNothing);
    }

    await _pump(tester, 375);
    expect(find.byType(CoeloAdminResizableTable<PrototypeAuditEvent>), findsNothing);
    expect(find.byKey(const Key('audit-card-audit-fixture-plan-updated')), findsOneWidget);
  });

  testWidgets('searches, opens minimized detail and hides sensitive values', (tester) async {
    final store = _store()
      ..recordAuditEvent(
        module: 'Convites',
        action: 'Reenviou',
        objectType: 'convite',
        objectId: 'convite-seguro',
        before: const {'recipient': 'responsavel@exemplo.com'},
        after: const {'link': 'https://app.coelo.me/invite/token-secreto'},
      );
    await _pump(tester, 1024, store: store);
    expect(find.text('9 eventos'), findsOneWidget);
    expect(find.textContaining('responsavel@exemplo.com'), findsNothing);
    expect(find.textContaining('token-secreto'), findsNothing);

    await tester.enterText(find.byKey(const Key('audit-search')), 'Reenviou');
    await tester.pump();
    expect(find.text('2 eventos'), findsOneWidget);
    await tester.tap(find.byKey(const Key('audit-card-audit-1')));
    await tester.pumpAndSettle();
    expect(find.byType(AuditDetailPanel), findsOneWidget);
    expect(find.text('MFA simulado'), findsOneWidget);
  });

  for (final state in AuditDirectoryState.values.where(
    (value) => value != AuditDirectoryState.content,
  )) {
    testWidgets('renders ${state.name}', (tester) async {
      await _pump(tester, 768, state: state);
      expect(find.byKey(Key('audit-state-${state.name}')), findsOneWidget);
    });
  }
  testWidgets('stays responsive across the required light and dark matrix', (tester) async {
    const configurations = [
      (375.0, Brightness.light),
      (768.0, Brightness.light),
      (1024.0, Brightness.dark),
      (1440.0, Brightness.dark),
    ];
    for (final (width, brightness) in configurations) {
      await _pump(tester, width, brightness: brightness);
      expect(tester.takeException(), isNull, reason: 'layout at $width px');
      expect(
        find.byType(CoeloAdminResizableTable<PrototypeAuditEvent>),
        width == 1440 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('audit-card-list')),
        width == 1440 ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('supports 200 percent text without overflow', (tester) async {
    await _pump(tester, 375, textScale: 2);
    expect(find.byKey(const Key('audit-card-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps cards keyboard accessible and exposes page size', (tester) async {
    await _pump(tester, 1440);

    await _pump(tester, 375);
    final card = find.byKey(const Key('audit-card-audit-fixture-plan-updated'));
    final cardSemantics = find.bySemanticsLabel(
      'Abrir evento de auditoria audit-fixture-plan-updated',
    );
    expect(cardSemantics, findsOneWidget);
    expect(
      tester.getSemantics(cardSemantics),
      matchesSemantics(
        label: 'Abrir evento de auditoria audit-fixture-plan-updated',
        isButton: true,
        hasTapAction: true,
      ),
    );
    var focused = false;
    for (var index = 0; index < 80 && !focused; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focusedContext = FocusManager.instance.primaryFocus?.context;
      if (focusedContext == null) continue;
      final focusedElement = find.byElementPredicate(
        (element) => identical(element, focusedContext),
      );
      focused = find.ancestor(of: focusedElement, matching: card).evaluate().isNotEmpty;
    }
    expect(focused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(AuditDetailPanel), findsOneWidget);
  });

  testWidgets('keeps page size reachable at the end of the compact list', (tester) async {
    await _pump(tester, 375);
    final list = find.byKey(const Key('audit-card-list'));
    await tester.drag(list, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coelo-admin-pagination-page-size')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

SuperadminPrototypeStore _store() => SuperadminPrototypeStore(
  activityController: SuperadminActivityController(),
  now: () => DateTime.utc(2026, 8, 3, 16),
);

Future<void> _pump(
  WidgetTester tester,
  double width, {
  SuperadminPrototypeStore? store,
  AuditDirectoryState state = AuditDirectoryState.content,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: AuditDirectoryPage(
        store: store ?? _store(),
        logout: unavailableSuperadminLogout,
        state: state,
        now: () => DateTime.utc(2026, 8, 3, 16),
      ),
    ),
  );
  await tester.pump();
}
