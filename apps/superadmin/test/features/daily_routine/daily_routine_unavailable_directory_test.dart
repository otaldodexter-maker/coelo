import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a routine backend that does not exist is not a retryable failure', (tester) async {
    // This is what /rotina composes today: the production auth scope injects
    // UnavailableRoutineRepository, because no production implementation exists.
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: const DailyRoutineDirectoryPage(
          repository: UnavailableRoutineRepository(),
          logout: unavailableSuperadminLogout,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-unavailable')), findsOneWidget);
    expect(find.text('Rotina diária indisponível'), findsOneWidget);

    final panel = tester.widget<CoeloStatePanel>(
      find.byKey(const Key('daily-routine-unavailable')),
    );
    expect(
      panel.onAction,
      isNull,
      reason: 'retrying cannot succeed while the environment has no routine backend',
    );
    expect(panel.actionLabel, isNull);
    expect(find.text('Tentar novamente'), findsNothing);
  });
}
