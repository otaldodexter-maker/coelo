import 'dart:async';

import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => list();
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
