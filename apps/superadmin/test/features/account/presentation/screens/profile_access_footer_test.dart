import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/domain/account_profile.dart';
import 'package:coelo_superadmin/features/account/presentation/account_controller.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/profile_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (width, scale) in [(375.0, 1.0), (1440.0, 1.0), (375.0, 2.0), (1440.0, 2.0)]) {
    testWidgets('long access list keeps save visible at $width scale $scale', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final activities = SuperadminActivityController();
      final profile = AccountProfile.prototype().copyWith(
        access: AccountAccessSummary(
          role: 'Operador de teste',
          mfaEnabled: false,
          capabilities: List.generate(150, (i) => 'Permissão sintética $i'),
        ),
      );
      final controller = AccountController(
        repository: InMemoryAccountProfileRepository(initial: profile),
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ProfilePage(
            controller: controller,
            logout: () async => const LogoutResult.success(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final save = find.byKey(const Key('account-save-profile'));
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(1000));
      expect(tester.getTopLeft(save).dy, greaterThan(0));
      await tester.ensureVisible(find.byKey(const Key('account-access-search')));
      await tester.enterText(find.byKey(const Key('account-access-search')), 'sintética 149');
      await tester.pumpAndSettle();
      expect(find.text('Permissão sintética 149'), findsOneWidget);
      expect(find.text('Permissão sintética 148'), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('account-access-scroll'))).height,
        lessThanOrEqualTo(400),
      );
      await tester.enterText(find.byKey(const Key('account-access-search')), 'inexistente');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma permissão encontrada.'), findsOneWidget);
      expect(controller.profile!.access.capabilities, hasLength(150));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile keyboard keeps actions reachable and Tab traverses fields', (tester) async {
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
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
    final first = find.byKey(const Key('account-first-name-field'));
    await tester.ensureVisible(first);
    await tester.tap(first);
    await tester.enterText(first, 'Nome via teclado');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final last = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('account-last-name-field')),
        matching: find.byType(EditableText),
      ),
    );
    expect(last.focusNode.hasFocus, isTrue);
    final save = find.byKey(const Key('account-save-profile'));
    final cancel = find.byKey(const Key('account-reset-profile'));
    expect(save.hitTestable(), findsOneWidget);
    expect(cancel.hitTestable(), findsOneWidget);
    expect(tester.getBottomRight(cancel).dy, lessThanOrEqualTo(700));
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(controller.profile!.firstName, isNot('Nome via teclado'));
    expect(tester.takeException(), isNull);
  });
}
