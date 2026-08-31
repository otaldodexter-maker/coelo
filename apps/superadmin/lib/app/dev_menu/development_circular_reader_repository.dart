import '../../features/principal_circulars/domain/circular.dart';
import '../../features/principal_circulars/domain/circular_repository.dart';

/// Local-only reader fixture. Productive routes use the unavailable repository.
final class DevelopmentCircularReaderRepository implements CircularRepository {
  const DevelopmentCircularReaderRepository();

  Future<T> _unavailable<T>() => Future<T>.error(const CircularUnavailable());

  @override
  Future<CircularDetail> getVisible(String circularId, {String? childContextId}) async {
    if (circularId != 'circular-published') throw const CircularNotAvailable();
    return CircularDetail(
      id: circularId,
      revisionId: 'development-revision-1',
      title: 'Renovação de matrícula',
      authorName: 'Coordenação Pedagógica',
      contextLabel: 'Ensino Fundamental',
      publishedAt: DateTime.utc(2026, 8, 21, 12),
      status: CircularStatus.published,
      responseState: CircularResponseState.unanswered,
      blocks: const [
        CircularTextBlock(
          id: 'development-text-1',
          text: 'Confirme a renovação para o próximo ano até 30 de setembro.',
        ),
      ],
    );
  }

  @override
  Future<CircularDraft?> loadDraft(CircularScope scope) => _unavailable();

  @override
  Future<PrincipalCursorPage<CircularSummary>> listProfile(
    CircularScope scope, {
    CircularCursor? cursor,
    int limit = 20,
  }) => _unavailable();

  @override
  Future<CircularSaveResult> saveDraft({
    required String requestId,
    required CircularScope scope,
    required CircularDraft draft,
  }) => _unavailable();

  @override
  Future<CircularSaveResult> publish({
    required String requestId,
    required String circularId,
    required int expectedVersion,
    DateTime? publishAt,
  }) => _unavailable();

  @override
  Future<CircularSaveResult> closeResponses({
    required String requestId,
    required String circularId,
    required int expectedVersion,
  }) => _unavailable();
}
