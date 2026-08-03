import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/app/shell/superadmin_activity_center.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('attendance notice opens the focused participant route', (tester) async {
    final controller = SuperadminActivityController.seeded([
      SuperadminActivity.attendanceNotice(
        id: 'attendance-notice',
        subject: 'Lia Horizonte',
        summary: 'Chegada atrasada · aguardando confirmação',
        destination: '/attendance/calls/call-progress?participant=participant-1',
        createdAt: DateTime(2026, 8, 3, 8, 15),
      ),
    ]);
    addTearDown(controller.dispose);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              Scaffold(body: SuperadminActivityCenter(controller: controller)),
        ),
        GoRoute(
          path: '/attendance/calls/:callId',
          builder: (context, state) => Text(
            '${state.pathParameters['callId']} · ${state.uri.queryParameters['participant']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(theme: CoeloTheme.light, routerConfig: router));
    await tester.tap(find.byKey(const Key('superadmin-notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('superadmin-activity-attendance-notice')));
    await tester.pumpAndSettle();

    expect(find.text('call-progress · participant-1'), findsOneWidget);
  });
}
