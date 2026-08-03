import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/prototype/superadmin_prototype_store.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_detail_panel.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_directory_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
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
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: AuditDirectoryPage(
        store: store ?? _store(),
        logout: unavailableSuperadminLogout,
        state: state,
      ),
    ),
  );
  await tester.pump();
}
