import 'dart:async';

import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final change in ['item', 'callback', 'dispose']) {
    testWidgets('feed preview invalidates after $change', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      var firstCalls = 0;
      var secondCalls = 0;
      void first() => firstCalls++;
      void second() => secondCalls++;
      final replacement = CircularSummary(
        id: 'circular-2',
        title: 'Circular B',
        excerpt: 'Outro contexto',
        authorName: 'Autor B',
        contextLabel: 'Contexto B',
        publishedAt: DateTime.utc(2026),
        attachmentCount: 0,
        questionCount: 0,
        responseState: CircularResponseState.unanswered,
      );
      Widget host(bool changed) => MaterialApp(
        home: Scaffold(
          body: changed && change == 'dispose'
              ? const Text('Origem')
              : PrincipalCircularFeedCard(
                  item: changed && change == 'item' ? replacement : _summary,
                  onOpen: changed && change == 'callback' ? second : first,
                ),
        ),
      );
      await tester.pumpWidget(host(false));
      await tester.tap(find.text('Ler circular'));
      await tester.pumpAndSettle();
      final read = tester
          .widget<FilledButton>(find.byKey(const Key('principal-circular-preview-read')))
          .onPressed!;
      await tester.pumpWidget(host(true));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('principal-circular-preview-dialog')), findsNothing);
      read();
      await tester.pumpAndSettle();
      expect(firstCalls, 0);
      expect(secondCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> pumpProfile(
    WidgetTester tester,
    _Repository repository, {
    CircularScope scope = const CircularScope(institutionId: 'institution-1'),
    ValueChanged<String>? onOpen,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PrincipalProfileCircularsTab(
          repository: repository,
          scope: scope,
          onOpen: onOpen ?? (_) {},
        ),
      ),
    ),
  );

  testWidgets('profile clears items and cursor when repository changes', (tester) async {
    final first = _Repository(
      () async => PrincipalCursorPage(
        items: [_summary],
        nextCursor: CircularCursor(publishedAt: DateTime.utc(2026), itemId: 'old-cursor'),
      ),
    );
    final pending = Completer<PrincipalCursorPage<CircularSummary>>();
    final second = _Repository(() => pending.future);
    await pumpProfile(tester, first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-circular-circular-1')), findsOneWidget);
    await pumpProfile(tester, second);
    expect(find.byKey(const Key('profile-circular-circular-1')), findsNothing);
    expect(second.cursors, [null]);
    pending.complete(const PrincipalCursorPage(items: [], nextCursor: null));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma Circular publicada por aqui.'), findsOneWidget);
  });

  testWidgets('equivalent profile scope does not reload and pagination is single flight', (
    tester,
  ) async {
    final pending = Completer<PrincipalCursorPage<CircularSummary>>();
    var calls = 0;
    final repository = _Repository(
      () => ++calls == 1
          ? Future.value(
              PrincipalCursorPage(
                items: [_summary],
                nextCursor: CircularCursor(publishedAt: DateTime.utc(2026), itemId: 'next'),
              ),
            )
          : pending.future,
    );
    await pumpProfile(tester, repository, scope: CircularScope(institutionId: 'institution-1'));
    await tester.pumpAndSettle();
    await pumpProfile(tester, repository, scope: CircularScope(institutionId: 'institution-1'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    final loadMore = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Carregar mais'))
        .onPressed!;
    loadMore();
    loadMore();
    expect(calls, 2);
    pending.complete(const PrincipalCursorPage(items: [], nextCursor: null));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-circular-circular-1')), findsOneWidget);
  });

  testWidgets('pagination denial closes profile preview and cannot reload from stale callback', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final pending = Completer<PrincipalCursorPage<CircularSummary>>();
    var calls = 0;
    final repository = _Repository(
      () => ++calls == 1
          ? Future.value(
              PrincipalCursorPage(
                items: [_summary],
                nextCursor: CircularCursor(publishedAt: DateTime.utc(2026), itemId: 'next'),
              ),
            )
          : pending.future,
    );
    final opened = <String>[];
    await pumpProfile(tester, repository, onOpen: opened.add);
    await tester.pumpAndSettle();
    final loadMore = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Carregar mais'))
        .onPressed!;
    loadMore();
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-circular-circular-1')));
    await tester.pumpAndSettle();
    final read = tester
        .widget<FilledButton>(find.byKey(const Key('principal-circular-preview-read')))
        .onPressed!;
    pending.completeError(const CircularUnauthorized());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-circular-preview-dialog')), findsNothing);
    expect(find.text('Você não tem acesso a estas Circulares.'), findsOneWidget);
    read();
    loadMore();
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets('profile ignores old pending page after scope changes: failure=$fails', (
      tester,
    ) async {
      final pending = Completer<PrincipalCursorPage<CircularSummary>>();
      var calls = 0;
      final repository = _Repository(
        () => ++calls == 1
            ? pending.future
            : Future.value(const PrincipalCursorPage(items: [], nextCursor: null)),
      );
      await pumpProfile(tester, repository);
      await pumpProfile(
        tester,
        repository,
        scope: const CircularScope(institutionId: 'institution-2'),
      );
      await tester.pump();
      if (fails) {
        pending.completeError(const CircularUnauthorized());
      } else {
        pending.complete(PrincipalCursorPage(items: [_summary], nextCursor: null));
      }
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byKey(const Key('profile-circular-circular-1')), findsNothing);
      expect(find.text('Nenhuma Circular publicada por aqui.'), findsOneWidget);
    });
  }

  testWidgets('profile scope swap closes preview and blocks captured read', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final first = _Repository(() async => PrincipalCursorPage(items: [_summary], nextCursor: null));
    final second = _Repository(() async => const PrincipalCursorPage(items: [], nextCursor: null));
    final opened = <String>[];
    await pumpProfile(tester, first, onOpen: opened.add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-circular-circular-1')));
    await tester.pumpAndSettle();
    final read = tester
        .widget<FilledButton>(find.byKey(const Key('principal-circular-preview-read')))
        .onPressed!;
    await pumpProfile(tester, second, onOpen: opened.add);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-circular-preview-dialog')), findsNothing);
    read();
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile tabs preserve Acontece Momentos Circulares Sobre order', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrincipalProfileContentTabs(
            selected: PrincipalProfileContentTab.circulars,
            onSelected: _ignoreTab,
          ),
        ),
      ),
    );
    expect(
      tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(PrincipalProfileContentTabs),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data),
      containsAllInOrder(['Acontece', 'Momentos', 'Circulares', 'Sobre']),
    );
    expect(
      tester.getSize(find.byKey(const Key('profile-tab-circulars'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('profile tab exposes loading, content and opening', (tester) async {
    final completer = Completer<PrincipalCursorPage<CircularSummary>>();
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalProfileCircularsTab(
          repository: _Repository(() => completer.future),
          scope: const CircularScope(institutionId: 'institution-1'),
          onOpen: (id) => opened = id,
        ),
      ),
    );
    expect(find.byKey(const Key('circulars-loading')), findsOneWidget);
    completer.complete(PrincipalCursorPage(items: [_summary], nextCursor: null));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-circular-circular-1')));
    expect(opened, 'circular-1');
  });

  testWidgets('feed card identifies Circular and response state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrincipalCircularFeedCard(item: _summary, onOpen: () {}),
        ),
      ),
    );
    expect(find.text('Circular'), findsOneWidget);
    expect(find.text('Resposta parcial'), findsOneWidget);
    expect(find.text('Ler circular'), findsOneWidget);
  });

  testWidgets('web feed preview starts hidden and opens in an accessible dialog', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrincipalCircularFeedCard(item: _summary, onOpen: () => opened = true),
        ),
      ),
    );

    expect(find.byKey(const Key('principal-circular-preview-dialog')), findsNothing);
    await tester.tap(find.text('Ler circular'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-circular-preview-dialog')), findsOneWidget);
    expect(opened, isFalse);

    await tester.tap(find.byKey(const Key('principal-circular-preview-read')));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(find.byKey(const Key('principal-circular-preview-dialog')), findsNothing);
  });

  testWidgets('web preview returns keyboard focus to its trigger when closed', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrincipalCircularFeedCard(item: _summary, onOpen: () {}),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-circular-preview-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('principal-circular-preview-close')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-circular-preview-dialog')), findsOneWidget);
  });

  testWidgets('profile tab keeps unauthorized distinct from empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrincipalProfileCircularsTab(
          repository: _Repository(() async => throw const CircularUnauthorized()),
          scope: const CircularScope(institutionId: 'institution-1'),
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Você não tem acesso a estas Circulares.'), findsOneWidget);
  });
}

void _ignoreTab(PrincipalProfileContentTab _) {}

final _summary = CircularSummary(
  id: 'circular-1',
  title: 'Renovação de matrícula',
  excerpt: 'Confirme a renovação para o próximo ano.',
  authorName: 'Colégio Coelo',
  contextLabel: 'Ensino Fundamental',
  publishedAt: DateTime.utc(2026, 8, 21),
  attachmentCount: 2,
  questionCount: 1,
  responseState: CircularResponseState.partial,
);

final class _Repository implements CircularRepository {
  _Repository(this.list);
  final Future<PrincipalCursorPage<CircularSummary>> Function() list;
  final cursors = <CircularCursor?>[];
  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) {
    cursors.add(cursor);
    return list();
  }

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) => throw UnimplementedError();
  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => throw UnimplementedError();
  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) =>
      throw UnimplementedError();
}
