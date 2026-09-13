import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final maria = SuperadminHeaderProfile(
    name: 'Maria Operadora',
    role: 'Operador interno',
    initials: 'MO',
    avatarBackgroundColor: CoeloPalette.orange50,
  );

  Widget shell(SuperadminHeaderProfile? profile) => MaterialApp(
    theme: CoeloTheme.light,
    home: SuperadminShell(
      logout: () async => const LogoutResult.success(),
      headerProfile: profile,
      showChatLauncher: false,
      child: const SizedBox.expand(),
    ),
  );

  testWidgets('uses the current profile and refreshes it after save', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(shell(maria));
    expect(find.text('Maria Operadora'), findsOneWidget);
    expect(find.text('Operador interno'), findsOneWidget);
    expect(find.text('Owner Coelo'), findsNothing);

    await tester.pumpWidget(
      shell(
        SuperadminHeaderProfile(
          name: 'Maria Atualizada',
          role: 'Operador interno',
          initials: 'MA',
          avatarBackgroundColor: CoeloPalette.orange50,
        ),
      ),
    );
    expect(find.text('Maria Atualizada'), findsOneWidget);
    expect(find.text('MA'), findsOneWidget);
  });

  testWidgets('keeps the real avatar initials in the compact header', (tester) async {
    await tester.binding.setSurfaceSize(const Size(700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(shell(maria));
    expect(find.text('MO'), findsOneWidget);
    expect(find.text('Owner Coelo'), findsNothing);
  });
}
