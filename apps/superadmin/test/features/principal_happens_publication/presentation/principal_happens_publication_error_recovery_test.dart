import 'package:coelo_superadmin/features/principal_happens_publication/domain/happens_publication.dart';
import 'package:coelo_superadmin/features/principal_happens_publication/presentation/principal_happens_publication_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The composer must survive an `Error`, not only an `Exception`.
///
/// The surface is disabled while the phase is busy, so a throw that no catch
/// handles leaves it locked with even Cancel unavailable. The production
/// repository decodes Supabase payloads with raw casts, so a `TypeError` there
/// is not a remote hypothesis.
void main() {
  testWidgets('an Error while loading reaches the failure panel, not a locked screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalHappensPublicationPage.demo(repository: _ThrowingRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não foi possível'),
      findsWidgets,
      reason: 'an unhandled Error must still land on an honest failure state',
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

/// Throws a real `Error`, the way a raw cast over an unexpected payload does.
final class _ThrowingRepository implements HappensPublicationRepository {
  final _inner = InMemoryHappensPublicationRepository();

  @override
  Future<HappensPostDraft?> loadDraft(HappensPublicationContext context) async => throw TypeError();

  @override
  Future<HappensPostDraft> saveDraft(HappensPublicationContext context, HappensPostDraft draft) =>
      _inner.saveDraft(context, draft);

  @override
  Future<HappensUploadIntent> prepareMedia(
    HappensPublicationContext context,
    String postId,
    HappensMediaDraft media,
    int displayOrder,
  ) => _inner.prepareMedia(context, postId, media, displayOrder);

  @override
  Future<HappensMediaDraft> finalizeMedia(HappensUploadIntent intent, HappensMediaDraft media) =>
      _inner.finalizeMedia(intent, media);

  @override
  Future<void> removeMedia(HappensPublicationContext context, HappensMediaDraft media) =>
      _inner.removeMedia(context, media);

  @override
  Future<HappensPublication> publish(HappensPublicationContext context, HappensPostDraft draft) =>
      _inner.publish(context, draft);
}
