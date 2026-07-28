import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/profile_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows personal data, access and security cards', (tester) async {
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meu perfil'), findsOneWidget);
    expect(find.text('Dados pessoais'), findsOneWidget);
    expect(find.text('Meu acesso'), findsOneWidget);
    expect(find.text('Segurança'), findsOneWidget);
    expect(find.byKey(const Key('account-avatar-initials')), findsOneWidget);
  });

  testWidgets('normalizes and validates custom avatar initials', (tester) async {
    final activities = SuperadminActivityController();
    final controller = AccountController(
      repository: InMemoryAccountProfileRepository(),
      activities: activities,
    );
    await controller.load();
    addTearDown(() {
      controller.dispose();
      activities.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: ProfilePage(controller: controller, logout: () async => const LogoutResult.success()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('account-initials-field')), 'abc');
    await tester.ensureVisible(find.byKey(const Key('account-save-profile')));
    await tester.tap(find.byKey(const Key('account-save-profile')));
    await tester.pump();

    expect(find.text('Use uma ou duas letras.'), findsOneWidget);
  });
}
