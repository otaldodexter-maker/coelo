import 'package:coelo_superadmin/features/circulars/data/development_circular_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const scope = CircularScope(institutionId: 'development-preview');
  final now = DateTime.utc(2026, 9);

  test('ships coherent linked data and enough records to exercise pagination', () {
    final repository = DevelopmentCircularRepository(now: () => now);

    expect(repository.items, hasLength(greaterThan(11)));
    expect(repository.items.map((item) => item.title).toSet(), hasLength(repository.items.length));
    expect(repository.items.any((item) => item.responseCount > 100), isTrue);
    expect(repository.items.map((item) => item.contextLabel).toSet(), hasLength(greaterThan(2)));
    for (final item in repository.items) {
      expect(repository.draftFor(item.id)?.title, item.title);
    }
  });

  test('creates, edits and publishes one mutable development circular', () async {
    final repository = DevelopmentCircularRepository(now: () => now);
    const initial = CircularDraft(
      id: '',
      title: 'Semana da Ciência',
      audiences: {CircularAudienceKind.families},
      blocks: [CircularTextBlock(id: 'body', text: 'Confira a programação das oficinas.')],
    );

    final created = await repository.saveDraft(requestId: 'create-1', scope: scope, draft: initial);
    expect(created.status, CircularStatus.draft);
    expect(repository.items.firstWhere((item) => item.id == created.id).title, 'Semana da Ciência');

    final draft = repository.draftFor(created.id)!;
    final edited = await repository.saveDraft(
      requestId: 'edit-1',
      scope: scope,
      draft: CircularDraft(
        id: draft.id,
        title: 'Semana de Ciência e Tecnologia',
        audiences: draft.audiences,
        blocks: draft.blocks,
        expectedVersion: draft.expectedVersion,
      ),
    );
    final published = await repository.publish(
      requestId: 'publish-1',
      circularId: edited.id,
      expectedVersion: edited.version,
    );

    expect(published.status, CircularStatus.published);
    final detail = await repository.getVisible(created.id);
    expect(detail.title, 'Semana de Ciência e Tecnologia');
    expect(detail.status, CircularStatus.published);
  });

  test('rejects stale edits instead of overwriting a newer development revision', () async {
    final repository = DevelopmentCircularRepository(now: () => now);
    final draft = repository.draftFor('festa-familia')!;
    await repository.saveDraft(requestId: 'first', scope: scope, draft: draft);

    await expectLater(
      repository.saveDraft(requestId: 'stale', scope: scope, draft: draft),
      throwsA(isA<CircularVersionConflict>()),
    );
  });
}
