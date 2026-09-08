import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/presentation/person_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/people/fake_person_directory_repository.dart';

/// A control that announces itself as a button has to answer the keyboard.
///
/// The status chip declares `Semantics(button: true)` and expands on focus to
/// reveal the status label, which is a real affordance. It was also a keyboard
/// stop that lit up, claimed to be pressable, and did nothing when pressed -
/// worse than being unreachable, because it looks like the product is broken,
/// and invisible to anyone testing with a mouse.
///
/// The same defect and the same fix as the institution status chip, found while
/// closing that one.
Future<LogoutResult> _logout() async => const LogoutResult.success();

void main() {
  Future<void> pumpDirectory(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PersonDirectoryPage(repository: FakePersonDirectoryRepository(), logout: _logout),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the status chip answers Enter, and keeps the label open after focus leaves', (
    tester,
  ) async {
    await pumpDirectory(tester);
    // Any chip will do; the first one on screen is the one a keyboard reaches.
    final chip = find.byWidgetPredicate(
      (widget) => widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('person-status-'),
    ).first;
    expect(chip, findsOneWidget);

    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    final collapsed = tester.getSize(chip).width;

    // Reach it the way a keyboard user does, rather than focusing it directly:
    // a stop nobody can Tab to would pass a direct-focus test and still be
    // unreachable.
    var stops = 0;
    while (stops < 40) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      stops++;
      if (tester.getSize(chip).width > collapsed) break;
    }
    expect(
      tester.getSize(chip).width,
      greaterThan(collapsed),
      reason: 'the chip must be reachable by Tab at all',
    );

    // Focus alone already expands it, so width while focused proves nothing.
    // What Enter has to do is pin it open once focus moves on.
    final expandedWhileFocused = tester.getSize(chip).width;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(
      tester.getSize(chip).width,
      expandedWhileFocused,
      reason: 'a control that says it is a button must do something when pressed',
    );
  });
}
