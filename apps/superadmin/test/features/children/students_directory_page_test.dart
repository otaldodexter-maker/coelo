import 'dart:async';

import 'package:coelo_api/children.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/children/presentation/students_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const institutionA = '10000000-0000-0000-0000-000000000001';
const institutionB = '10000000-0000-0000-0000-000000000002';
const contextA = '20000000-0000-0000-0000-000000000001';
const contextB = '20000000-0000-0000-0000-000000000002';

ChildDirectoryItem item({
  String context = contextA,
  String name = 'Sintética Um',
  String institution = institutionA,
  String institutionName = 'Instituição Sintética',
}) => ChildDirectoryItem(
  contextId: context,
  personId: '30000000-0000-0000-0000-000000000001',
  personName: name,
  institutionId: institution,
  institutionName: institutionName,
);

final class PendingRead {
  final requests = <ChildDirectoryRequest>[];
  final responses = <Completer<ChildDirectoryPage>>[];

  Future<ChildDirectoryPage> call(ChildDirectoryRequest request) {
    requests.add(request);
    final response = Completer<ChildDirectoryPage>();
    responses.add(response);
    return response.future;
  }
}

void main() {
  Widget app({
    PendingRead? read,
    bool sessionAvailable = true,
    String? institutionId = institutionA,
    int revision = 0,
    bool dark = false,
    double textScale = 1,
  }) => MaterialApp(
    theme: dark ? CoeloTheme.dark : CoeloTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: StudentsDirectoryPage(
      logout: unavailableSuperadminLogout,
      read: read?.call,
      sessionAvailable: sessionAvailable,
      institutionId: institutionId,
      revision: revision,
    ),
  );

  testWidgets('the list renders the authorized page and names its institution', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    expect(read.requests.single.institutionId, institutionA);
    read.responses.last.complete(ChildDirectoryPage(items: [item()], nextCursor: null));
    await tester.pumpAndSettle();
    expect(find.text('Sintética Um'), findsOneWidget);
    expect(find.text('Instituição Sintética'), findsOneWidget);
    expect(find.byKey(const Key('child-card-$contextA')), findsOneWidget);
  });

  testWidgets('without a session nothing is read and denial is announced', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read, sessionAvailable: false));
    await tester.pumpAndSettle();
    expect(read.requests, isEmpty);
    expect(find.byKey(const Key('child-directory-denied')), findsOneWidget);
  });

  testWidgets('the default composition is unavailable, never an empty list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StudentsDirectoryPage(logout: unavailableSuperadminLogout, sessionAvailable: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('child-directory-unavailable')), findsOneWidget);
    expect(find.byKey(const Key('child-directory-empty')), findsNothing);
  });

  testWidgets('an empty page says empty instead of failing', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    read.responses.last.complete(ChildDirectoryPage(items: const [], nextCursor: null));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('child-directory-empty')), findsOneWidget);
  });

  testWidgets('a denied read shows denial and keeps no previous data', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    read.responses.last.complete(ChildDirectoryPage(items: [item()], nextCursor: null));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('child-directory-reload')));
    await tester.pump();
    read.responses.last.completeError(const ChildDirectoryDeniedException());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('child-directory-denied')), findsOneWidget);
    expect(find.text('Sintética Um'), findsNothing);
  });

  testWidgets('a sanitized failure shows unavailable, not a server message', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    read.responses.last.completeError(StateError('raw server detail'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('child-directory-unavailable')), findsOneWidget);
    expect(find.textContaining('raw server detail'), findsNothing);
  });

  testWidgets('next page is offered only with a cursor and sends it once', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    const cursor = ChildDirectoryCursor(name: 'Sintética Um', contextId: contextA);
    read.responses.last.complete(ChildDirectoryPage(items: [item()], nextCursor: cursor));
    await tester.pumpAndSettle();
    final next = find.byKey(const Key('child-directory-next'));
    expect(tester.widget<FilledButton>(next).enabled, isTrue);
    await tester.tap(next);
    await tester.pump();
    expect(read.requests.last.after?.contextId, contextA);
    // While loading the control must not fire a second identical read.
    await tester.tap(next, warnIfMissed: false);
    await tester.pump();
    expect(read.requests, hasLength(2));
    read.responses.last.complete(
      ChildDirectoryPage(
        items: [item(context: contextB, name: 'Sintética Dois')],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sintética Dois'), findsOneWidget);
    expect(tester.widget<FilledButton>(next).enabled, isFalse);
  });

  testWidgets('reload restarts from the first page without a cursor', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    const cursor = ChildDirectoryCursor(name: 'Sintética Um', contextId: contextA);
    read.responses.last.complete(ChildDirectoryPage(items: [item()], nextCursor: cursor));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('child-directory-next')));
    await tester.pump();
    read.responses.last.complete(
      ChildDirectoryPage(
        items: [item(context: contextB, name: 'Sintética Dois')],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('child-directory-reload')));
    await tester.pump();
    expect(read.requests.last.after, isNull);
  });

  testWidgets('a new revision drops the loaded page instead of keeping it', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    read.responses.last.complete(ChildDirectoryPage(items: [item()], nextCursor: null));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(read: read, revision: 1));
    await tester.pump();
    expect(find.text('Sintética Um'), findsNothing);
    expect(find.byKey(const Key('child-directory-loading')), findsOneWidget);
  });

  testWidgets('switching institution re-reads with the new filter', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    read.responses.last.complete(ChildDirectoryPage(items: [item()], nextCursor: null));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(read: read, institutionId: institutionB));
    await tester.pump();
    expect(read.requests.last.institutionId, institutionB);
    expect(find.text('Sintética Um'), findsNothing);
  });

  testWidgets('the page offers no management action it cannot perform', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    read.responses.last.complete(ChildDirectoryPage(items: [item()], nextCursor: null));
    await tester.pumpAndSettle();
    for (final label in const ['Vincular', 'Transferir', 'Editar', 'Revogar']) {
      expect(find.text(label), findsNothing);
    }
  });

  for (final size in const [Size(375, 812), Size(768, 1024), Size(1440, 900)]) {
    for (final dark in const [false, true]) {
      for (final scale in const [1.0, 2.0]) {
        final label = '${size.width.toInt()} ${dark ? 'dark' : 'light'} ${scale}x';
        testWidgets('the list lays out without overflow at $label', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final read = PendingRead();
          await tester.pumpWidget(app(read: read, dark: dark, textScale: scale));
          await tester.pump();
          read.responses.last.complete(
            ChildDirectoryPage(
              items: [
                item(),
                item(context: contextB, name: 'Sintética Dois com nome bastante longo'),
              ],
              nextCursor: const ChildDirectoryCursor(name: 'Sintética Dois', contextId: contextB),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // At 200% on a narrow viewport the cards fall below the fold, so
          // reachability is proven by scrolling rather than by assuming they
          // are already on screen.
          await tester.scrollUntilVisible(
            find.text('Sintética Um'),
            120,
            scrollable: find.descendant(
              of: find.byKey(const Key('child-directory-content')),
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Sintética Um'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('reload and next page are reachable and activated by keyboard', (tester) async {
    final read = PendingRead();
    await tester.pumpWidget(app(read: read));
    await tester.pump();
    read.responses.last.complete(
      ChildDirectoryPage(
        items: [item()],
        nextCursor: const ChildDirectoryCursor(name: 'Sintética Um', contextId: contextA),
      ),
    );
    await tester.pumpAndSettle();
    final reload = find.byKey(const Key('child-directory-reload'));
    final next = find.byKey(const Key('child-directory-next'));

    bool focusedIn(Finder control) {
      final focused = primaryFocus?.context?.widget;
      return focused != null &&
          find.descendant(of: control, matching: find.byWidget(focused)).evaluate().isNotEmpty;
    }

    var reachedReload = false;
    var reachedNext = false;
    for (var step = 0; step < 24 && !(reachedReload && reachedNext); step += 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      // The shell keeps its own animations running, so settle by a bounded pump.
      await tester.pump(const Duration(milliseconds: 80));
      reachedReload = reachedReload || focusedIn(reload);
      reachedNext = reachedNext || focusedIn(next);
    }
    expect(reachedReload, isTrue);
    expect(reachedNext, isTrue);

    var activated = false;
    for (var step = 0; step < 24 && !activated; step += 1) {
      if (focusedIn(next)) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 80));
        activated = true;
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump(const Duration(milliseconds: 80));
    }
    expect(activated, isTrue);
    expect(read.requests.last.after?.contextId, contextA);
  });
}
