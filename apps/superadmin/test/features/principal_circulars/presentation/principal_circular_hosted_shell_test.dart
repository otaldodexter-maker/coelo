import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/presentation/principal_circular_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owner decision of 2026-09-09: hosted in the Superadmin the Circular reading
/// surface stays inside the shell content container in web and mobile, so the
/// compact state stops behaving as if it owned the whole window. The route
/// placement that keeps the host shell mounted lives in the router.
void main() {
  const hostChrome = Key('host-chrome');
  const hostInsets = EdgeInsets.only(top: 48, bottom: 24);

  Future<void> pumpHosted(
    WidgetTester tester, {
    required Size size,
    required bool embedded,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: true, padding: hostInsets, viewPadding: hostInsets),
          child: child!,
        ),
        home: Column(
          children: [
            const SizedBox(key: hostChrome, height: 56, width: double.infinity),
            Expanded(
              child: PrincipalCircularDetailPage(
                circularId: 'circular-1',
                childContextId: 'child-1',
                repository: _Repository(),
                responseRepository: const _ResponseRepository(),
                embedded: embedded,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compact reading keeps the host chrome and its contextual return', (tester) async {
    await pumpHosted(tester, size: const Size(375, 812), embedded: true);

    expect(find.byKey(hostChrome), findsOneWidget);
    expect(find.byKey(const Key('principal-circular-contextual-return')), findsOneWidget);
    expect(find.text('Renovação'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide reading keeps the host chrome alongside the reader', (tester) async {
    await pumpHosted(tester, size: const Size(1440, 900), embedded: true);

    expect(find.byKey(hostChrome), findsOneWidget);
    expect(find.text('Renovação'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact reading does not repeat the host system insets', (tester) async {
    const target = Key('principal-circular-contextual-return');
    await pumpHosted(tester, size: const Size(375, 812), embedded: false);
    final standalone = tester.getTopLeft(find.byKey(target)).dy;

    await pumpHosted(tester, size: const Size(375, 812), embedded: true);
    final hosted = tester.getTopLeft(find.byKey(target)).dy;

    expect(standalone - hosted, hostInsets.top);
    expect(tester.takeException(), isNull);
  });
}

final class _Repository implements CircularRepository {
  const _Repository();

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async =>
      CircularDetail(
        id: 'circular-1',
        revisionId: 'revision-1',
        title: 'Renovação',
        authorName: 'Colégio Coelo',
        contextLabel: 'Turma A',
        publishedAt: DateTime.utc(2026, 8, 21),
        status: CircularStatus.published,
        responseState: CircularResponseState.partial,
        responseSessionId: 'session-1',
        responseVersion: 4,
        blocks: const [CircularTextBlock(id: 'block-1', text: 'Conteúdo da Circular.')],
      );

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
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => throw UnimplementedError();
}

final class _ResponseRepository implements CircularResponseRepository {
  const _ResponseRepository();

  @override
  Future<CircularResponseSaveResult> saveDraft({
    required String requestId,
    required String revisionId,
    required String? childContextId,
    required Map<String, List<String>> answers,
    required int expectedVersion,
  }) => throw UnimplementedError();

  @override
  Future<CircularResponseSaveResult> submit({
    required String requestId,
    required String sessionId,
    required int expectedVersion,
  }) => throw UnimplementedError();
}
