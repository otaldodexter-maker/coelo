import 'package:coelo_superadmin/features/principal_shared/presentation/principal_preview_app_bar.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps branding and actions in the approved semantic order', (tester) async {
    var bugReports = 0;
    var notifications = 0;
    var contextChanges = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          appBar: PrincipalPreviewAppBar(
            keyPrefix: 'test-principal',
            onReportBug: () => bugReports++,
            onOpenNotifications: () => notifications++,
            onOpenContext: () => contextChanges++,
          ),
        ),
      ),
    );

    final logo = find.byKey(const ValueKey('test-principal-logo'));
    final bug = find.byKey(const ValueKey('test-principal-bug'));
    final bell = find.byKey(const ValueKey('test-principal-notifications'));
    final avatar = find.byKey(const ValueKey('test-principal-context-avatar'));

    expect(tester.getCenter(logo).dx, lessThan(tester.getCenter(bug).dx));
    expect(tester.getCenter(bug).dx, lessThan(tester.getCenter(bell).dx));
    expect(tester.getCenter(bell).dx, lessThan(tester.getCenter(avatar).dx));

    for (final target in [bug, bell, avatar]) {
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin));
      expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin));
      await tester.tap(target);
    }

    expect((bugReports, notifications, contextChanges), (1, 1, 1));
    final logoSemantics = tester.widget<Semantics>(
      find.ancestor(of: logo, matching: find.byType(Semantics)).first,
    );
    expect(logoSemantics.properties.label, 'Coelo');
    expect(find.byTooltip('Reportar bug'), findsOneWidget);
    expect(find.byTooltip('Notificações, 1 não lida'), findsOneWidget);
    expect(find.byTooltip('Trocar contexto'), findsOneWidget);
  });
}
