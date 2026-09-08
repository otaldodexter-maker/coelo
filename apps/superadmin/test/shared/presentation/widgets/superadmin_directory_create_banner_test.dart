// C00 regression derived from C07 commit 6905435c (first-focus activation).
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_directory_create_banner.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final activation in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
      testWidgets('create banner has one working focus stop $brightness ${activation.keyLabel}', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(375, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final before = FocusNode(debugLabel: 'before banner');
        final after = FocusNode(debugLabel: 'after banner');
        addTearDown(before.dispose);
        addTearDown(after.dispose);
        var activations = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            darkTheme: CoeloTheme.dark,
            themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Column(
                children: [
                  TextButton(focusNode: before, onPressed: () {}, child: const Text('Antes')),
                  SuperadminDirectoryCreateBanner(
                    label: 'Criar instituição',
                    description: 'Adicionar uma instituição.',
                    onPressed: () => activations++,
                    bannerKey: const Key('create-banner'),
                    surfaceKey: const Key('create-banner-surface'),
                  ),
                  TextButton(focusNode: after, onPressed: () {}, child: const Text('Depois')),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        before.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(_focusWithin(find.byKey(const Key('create-banner'))), isTrue);
        await tester.sendKeyEvent(activation);
        await tester.pumpAndSettle();
        expect(activations, 1, reason: 'The first banner focus stop must activate exactly once.');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(after.hasPrimaryFocus, isTrue, reason: 'The banner must not add a second Tab stop.');
        expect(activations, 1);

        await tester.tap(find.byKey(const Key('create-banner')));
        await tester.pumpAndSettle();
        expect(activations, 2, reason: 'Pointer activation remains available exactly once.');
        expect(tester.takeException(), isNull);
      });
    }
  }
}

bool _focusWithin(Finder finder) {
  final element = finder.evaluate().single;
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  if (identical(focusContext, element)) return true;
  var inside = false;
  focusContext.visitAncestorElements((ancestor) {
    if (identical(ancestor, element)) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}
