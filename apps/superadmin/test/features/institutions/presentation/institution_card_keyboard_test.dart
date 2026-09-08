import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_directory_cards.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One card, one keyboard stop, and that stop acts.
///
/// The card used to wrap itself in a FocusableActionDetector purely for the
/// visual highlight, while the InkWell underneath carried its own implicit
/// focus. That is two stops per card: the first lit up and did nothing on
/// Enter, the second worked. On a directory of eleven cards it meant eleven
/// keyboard stops that looked identical to the real ones and were inert - the
/// kind of defect that reads as a broken product to someone navigating by
/// keyboard, and is invisible to someone using a mouse.
///
/// Reported by C07 through C06, verified against the approved
/// CoeloAdminInteractiveCard, which has always put the node on the InkWell.
void main() {
  List<InstitutionDirectoryItem> items({int count = 3}) =>
      demoInstitutionDirectoryItems.take(count).toList();

  Future<void> pumpCards(
    WidgetTester tester, {
    required List<InstitutionDirectoryItem> data,
    void Function(InstitutionDirectoryItem)? onOpen,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: InstitutionDirectoryCards(items: data, onEdit: onOpen ?? (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the first Tab lands on the card itself and Enter opens it', (tester) async {
    final data = items(count: 1);
    final opened = <String>[];
    await pumpCards(tester, data: data, onOpen: (item) => opened.add(item.id));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(opened, [data.single.id], reason: 'the very first stop must be the one that acts');
  });

  testWidgets('every stop inside a card does something when pressed', (tester) async {
    // A card exposes two stops on purpose: the card, which opens it, and the
    // status chip, which announces itself as a button and expands to reveal the
    // status label. Both must act. The defect was never the count - it was a
    // stop that lit up and did nothing, which reads as a broken product to
    // someone navigating by keyboard and is invisible to someone with a mouse.
    final data = items(count: 1);
    final opened = <String>[];
    await pumpCards(tester, data: data, onOpen: (item) => opened.add(item.id));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened.length, 1, reason: 'stop 1 is the card');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final chip = find.byKey(Key('institution-status-${data.single.id}'));
    expect(chip, findsOneWidget);
    // Focus alone already expands the chip, so width while focused proves
    // nothing. What Enter has to do is pin it: press, then move focus away and
    // see it stay open. Before this fix Enter did nothing and it collapsed.
    final expandedWhileFocused = tester.getSize(chip).width;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(chip).width,
      expandedWhileFocused,
      reason: 'stop 2 announces itself as a button, so Enter has to press it',
    );
    expect(opened.length, 1, reason: 'and it must not open the card by accident');
  });

  testWidgets('Tab reaches every card, one card per pair of stops', (tester) async {
    final data = items();
    final opened = <String>[];
    await pumpCards(tester, data: data, onOpen: (item) => opened.add(item.id));

    for (var index = 0; index < data.length; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      // Step over the card's own status chip to reach the next card.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }

    expect(
      opened,
      data.map((item) => item.id).toList(),
      reason: 'no card may be skipped and none may be reached twice',
    );
  });

  testWidgets('the focused card is the one that looks focused', (tester) async {
    // The highlight used to be driven by the wrapper. Moving the node onto the
    // InkWell means the visual state and the acting control are the same thing,
    // which is the property that stops them drifting apart again.
    final data = items(count: 2);
    await pumpCards(tester, data: data);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final focused = find.descendant(
      of: find.byKey(Key('institution-card-${data.first.id}')),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(focused).focusNode?.hasFocus, isTrue);
  });
}
