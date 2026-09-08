import 'package:coelo_superadmin/features/principal_moments_publication/application/moments_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_page.dart';
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
        home: PrincipalMomentsPublicationPage(
          controller: MomentsPublicationController(
            repository: _ThrowingRepository(),
            context: MomentsPublicationContext.demo,
          ),
        ),
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
final class _ThrowingRepository implements MomentsPublicationRepository {
  final _inner = InMemoryMomentsPublicationRepository();

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async => throw TypeError();

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) =>
      _inner.saveDraft(context, draft);

  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) =>
      _inner.publish(context, draft);
}
