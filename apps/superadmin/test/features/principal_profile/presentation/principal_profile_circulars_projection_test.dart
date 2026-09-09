import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_route_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proofs for the Circulares projection inside the Perfil, the sub-acceptance
/// named by `principal.profile-view` ("Principal / Perfil-circulares").
///
/// The Perfil only projects Circulares: the domain and its own screens belong to
/// the Publicações front, so nothing here creates a parallel repository.
void main() {
  const context = PrincipalRuntimeContext(
    membershipId: 'membership-1',
    personId: 'person-1',
    institutionId: 'institution-1',
    institutionName: 'Instituição Autorizada',
    roleCode: 'staff',
    scopeKind: 'unit',
    unitId: 'unit-1',
    unitName: 'Unidade Centro',
  );

  CircularSummary summary(String id, String title) => CircularSummary(
    id: id,
    title: title,
    excerpt: 'Resumo autorizado da circular.',
    authorName: 'Coordenação',
    contextLabel: 'Unidade Centro',
    publishedAt: DateTime.utc(2026, 9, 1, 12),
    attachmentCount: 0,
    questionCount: 0,
    responseState: CircularResponseState.unanswered,
  );

  Future<void> openCircularsTab(
    WidgetTester tester, {
    required CircularRepository? repository,
    ValueChanged<String>? onOpenCircular,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfileRoutePage(
          runtimeContext: context,
          circularRepository: repository,
          onOpenCircular: onOpenCircular,
          onOpenAgenda: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Circulares'));
    await tester.tap(find.text('Circulares'));
    await tester.pumpAndSettle();
  }

  testWidgets('projects the authorized circulars of the resolved context', (tester) async {
    final repository = _StubCircularRepository(
      items: [summary('circular-1', 'Reunião de pais'), summary('circular-2', 'Calendário')],
    );
    await openCircularsTab(tester, repository: repository);

    expect(find.text('Reunião de pais'), findsOneWidget);
    expect(find.text('Calendário'), findsOneWidget);
  });

  testWidgets('scopes the projection to the server-resolved context', (tester) async {
    final repository = _StubCircularRepository(items: [summary('circular-1', 'Reunião de pais')]);
    await openCircularsTab(tester, repository: repository);

    expect(repository.scopes, isNotEmpty);
    expect(repository.scopes.first.institutionId, 'institution-1');
    expect(repository.scopes.first.unitId, 'unit-1');
    expect(repository.scopes.first.groupId, isNull);
  });

  testWidgets('opens a circular by its identifier instead of duplicating the reader', (
    tester,
  ) async {
    final opened = <String>[];
    final repository = _StubCircularRepository(items: [summary('circular-1', 'Reunião de pais')]);
    await openCircularsTab(tester, repository: repository, onOpenCircular: opened.add);

    await tester.tap(find.text('Reunião de pais'));
    await tester.pumpAndSettle();

    expect(opened, ['circular-1']);
  });

  testWidgets('shows an empty state without borrowing fixtures', (tester) async {
    await openCircularsTab(tester, repository: _StubCircularRepository(items: const []));

    expect(find.text('Reunião de pais'), findsNothing);
    expect(find.text('Colégio Horizonte'), findsNothing);
  });

  testWidgets('fails closed when the projection denies the actor', (tester) async {
    await openCircularsTab(
      tester,
      repository: _StubCircularRepository(items: const [], failure: CircularUnauthorized()),
    );

    expect(find.text('Reunião de pais'), findsNothing);
  });

  testWidgets('blocks the tab when no authorized repository is composed', (tester) async {
    await openCircularsTab(tester, repository: null);

    expect(find.text('Contexto não autorizado'), findsOneWidget);
  });
}

final class _StubCircularRepository implements CircularRepository {
  _StubCircularRepository({required this.items, this.failure});

  final List<CircularSummary> items;
  final CircularFailure? failure;
  final List<CircularScope> scopes = [];

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) async {
    scopes.add(scope);
    final error = failure;
    if (error != null) throw error;
    return PrincipalCursorPage(items: items, nextCursor: null);
  }

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) =>
      Future.error(UnimplementedError());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
