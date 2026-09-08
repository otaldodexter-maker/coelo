import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('equivalent rebuild preserves the open report and submits once', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final drafts = <SupportReportDraft>[];
    Widget host() => MaterialApp(
      theme: CoeloTheme.light,
      home: SuperadminShell(
        logout: () async => const LogoutResult.success(),
        onBugReportSubmitted: drafts.add,
        showChatLauncher: false,
      ),
    );
    await tester.pumpWidget(host());
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-bug-description')), 'Texto preservado');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Texto preservado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('superadmin-bug-submit')));
    await tester.pumpAndSettle();
    expect(drafts.single.description, 'Texto preservado');
  });

  testWidgets('disposing header removes only its report below another route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final navigator = GlobalKey<NavigatorState>();
    Widget host(bool active) => MaterialApp(
      navigatorKey: navigator,
      theme: CoeloTheme.light,
      home: active
          ? SuperadminShell(
              logout: () async => const LogoutResult.success(),
              onBugReportSubmitted: (_) {},
              showChatLauncher: false,
            )
          : const Scaffold(body: Text('Origem')),
    );
    await tester.pumpWidget(host(true));
    await tester.tap(find.byKey(const Key('superadmin-report-bug')));
    await tester.pumpAndSettle();
    navigator.currentState!.push<void>(
      DialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) => const Dialog(child: Text('Outra rota')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(host(false));
    await tester.pumpAndSettle();
    expect(find.text('Outra rota'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Origem'), findsOneWidget);
    expect(find.byKey(const Key('superadmin-bug-report-dialog')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final change in ['screen', 'recipient', 'disabled', 'dispose']) {
    testWidgets('report cannot survive $change context change', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final first = <SupportReportDraft>[];
      final second = <SupportReportDraft>[];
      final firstSubmit = first.add;
      final secondSubmit = second.add;
      Widget host(bool changed) => MaterialApp(
        theme: CoeloTheme.light,
        home: changed && change == 'dispose'
            ? const Scaffold(body: Text('Origem'))
            : SuperadminShell(
                logout: () async => const LogoutResult.success(),
                title: changed && change == 'screen' ? 'Pessoas' : 'Instituições',
                currentDestination: changed && change == 'screen' ? 'people' : 'institutions',
                onBugReportSubmitted: changed && change == 'disabled'
                    ? null
                    : changed && change == 'recipient'
                    ? secondSubmit
                    : firstSubmit,
                showChatLauncher: false,
                child: const Text('Conteúdo'),
              ),
      );
      await tester.pumpWidget(host(false));
      await tester.tap(find.byKey(const Key('superadmin-report-bug')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('superadmin-bug-description')), 'Relato antigo');
      await tester.pump();
      final submit = tester
          .widget<FilledButton>(find.byKey(const Key('superadmin-bug-submit')))
          .onPressed!;
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('superadmin-bug-report-dialog')), findsNothing);
      submit();
      await tester.pumpAndSettle();
      expect(first, isEmpty);
      expect(second, isEmpty);
      expect(find.text('Relato enviado com sucesso.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
