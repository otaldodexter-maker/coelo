import 'package:coelo_superadmin/features/principal_profile/domain/principal_profile_preview_data.dart';
import 'package:coelo_superadmin/features/principal_profile/domain/principal_profile_repository.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_preview_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Client acceptance for `principal.profile-edit`, narrowed to the editorial
/// text on purpose.
///
/// Authorisation is decided by the server through profile, hierarchy and RLS,
/// so the client renders the affordance only when the authorised projection
/// already granted it. The edit is a server re-projection, never a local
/// rewrite, and the version the operator saw travels with the write so a
/// concurrent change is refused instead of overwritten.
void main() {
  const scope = PrincipalProfileScope(institutionId: 'institution-coelo');

  Future<void> pump(
    WidgetTester tester, {
    required bool canEdit,
    PrincipalProfileRepository? repository,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalProfilePreviewPage(
          onOpenAgenda: () {},
          data: _profile(canEdit: canEdit),
          profileRepository: repository,
          profileScope: repository == null ? null : scope,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder editButton() => find.byKey(const Key('principal-profile-edit-bio'));

  Future<void> saveBio(WidgetTester tester, String text) async {
    await tester.tap(editButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-profile-bio-field')), text);
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-profile-bio-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('no affordance while the projection does not grant the edit', (tester) async {
    await pump(tester, canEdit: false, repository: _Repository());

    expect(editButton(), findsNothing);
    expect(find.text('Ver mais'), findsOneWidget);
  });

  testWidgets('no affordance without an edit transport, even when granted', (tester) async {
    await pump(tester, canEdit: true);

    // Not offered here is not the same as refused: with no transport there is
    // nothing to offer at all.
    expect(editButton(), findsNothing);
  });

  testWidgets('an empty biography cannot be saved', (tester) async {
    final repository = _Repository();
    await pump(tester, canEdit: true, repository: repository);

    await tester.tap(editButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-profile-bio-field')), '   ');
    await tester.pump();

    final save = tester.widget<FilledButton>(find.byKey(const Key('principal-profile-bio-save')));
    expect(save.onPressed, isNull);
    expect(repository.commands, isEmpty);
  });

  testWidgets('a biography past the cap cannot be saved', (tester) async {
    final repository = _Repository();
    await pump(tester, canEdit: true, repository: repository);

    await tester.tap(editButton());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('principal-profile-bio-field')),
      'a' * (PrincipalProfileBioPolicy.maximumCharacters + 1),
    );
    await tester.pump();

    final save = tester.widget<FilledButton>(find.byKey(const Key('principal-profile-bio-save')));
    expect(save.onPressed, isNull, reason: 'the refusal is explained, not truncated silently');
    expect(repository.commands, isEmpty);
  });

  testWidgets('cancelling sends nothing', (tester) async {
    final repository = _Repository();
    await pump(tester, canEdit: true, repository: repository);

    await tester.tap(editButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('principal-profile-bio-field')), 'Outro texto');
    await tester.pump();
    await tester.tap(find.byKey(const Key('principal-profile-bio-cancel')));
    await tester.pumpAndSettle();

    expect(repository.commands, isEmpty);
    expect(find.text(_originalBio), findsOneWidget);
  });

  testWidgets('an unchanged biography sends nothing', (tester) async {
    final repository = _Repository();
    await pump(tester, canEdit: true, repository: repository);

    await saveBio(tester, _originalBio);

    expect(repository.commands, isEmpty, reason: 'a no-op must not become a recorded revision');
  });

  testWidgets('a saved biography renders the server projection, not the typed text', (
    tester,
  ) async {
    final repository = _Repository(succeeds: true);
    await pump(tester, canEdit: true, repository: repository);

    await saveBio(tester, 'Texto digitado pelo operador');

    expect(repository.commands.single.bio, 'Texto digitado pelo operador');
    expect(repository.commands.single.institutionId, 'institution-coelo');
    expect(repository.commands.single.expectedVersion, 7);
    expect(repository.commands.single.requestId, isNotEmpty);
    // The double answers with a different text on purpose.
    expect(find.text('Texto normalizado pelo servidor'), findsOneWidget);
    expect(find.text('Texto digitado pelo operador'), findsNothing);
  });

  testWidgets('a retry replays the same intent instead of writing twice', (tester) async {
    final repository = _Repository();
    await pump(tester, canEdit: true, repository: repository);

    await saveBio(tester, 'Primeira tentativa');
    await saveBio(tester, 'Segunda tentativa');

    expect(repository.commands.length, 2);
    expect(repository.commands.first.requestId, repository.commands.last.requestId);
  });

  testWidgets('an unavailable command keeps the text and says so', (tester) async {
    final repository = _Repository();
    await pump(tester, canEdit: true, repository: repository);

    await saveBio(tester, 'Texto novo');

    expect(find.text(_originalBio), findsOneWidget);
    expect(find.text('A edicao do perfil aguarda o servico autorizado.'), findsOneWidget);
  });

  testWidgets('a conflict is reported without overwriting the newer text', (tester) async {
    final repository = _Repository(conflicts: true);
    await pump(tester, canEdit: true, repository: repository);

    await saveBio(tester, 'Texto novo');

    expect(find.text(_originalBio), findsOneWidget);
    expect(find.text('O perfil mudou. Recarregue e tente novamente.'), findsOneWidget);
  });

  testWidgets('a denied edit is reported without changing the text', (tester) async {
    final repository = _Repository(denies: true);
    await pump(tester, canEdit: true, repository: repository);

    await saveBio(tester, 'Texto novo');

    expect(find.text(_originalBio), findsOneWidget);
    expect(find.text('Voce nao pode editar este perfil.'), findsOneWidget);
  });
}

const _originalBio = 'Biografia autorizada da instituicao.';

PrincipalProfilePreviewData _profile({required bool canEdit}) => PrincipalProfilePreviewData(
  name: 'Colegio Coelo',
  typeLabel: 'Instituicao de Ensino',
  bio: _originalBio,
  metrics: PrincipalProfilePreviewData.horizon.metrics,
  highlights: PrincipalProfilePreviewData.horizon.highlights,
  links: PrincipalProfilePreviewData.horizon.links,
  nextEvent: PrincipalProfilePreviewData.horizon.nextEvent,
  canEdit: canEdit,
  version: 7,
);

final class _Repository implements PrincipalProfileRepository {
  _Repository({this.succeeds = false, this.conflicts = false, this.denies = false});

  final bool succeeds;
  final bool conflicts;
  final bool denies;
  final List<PrincipalProfileEditCommand> commands = [];

  @override
  Future<PrincipalProfileEditResult> editProfile(PrincipalProfileEditCommand command) async {
    commands.add(command);
    if (denies) throw const PrincipalProfileUnauthorized();
    if (conflicts) throw const PrincipalProfileConflict();
    if (!succeeds) throw const PrincipalProfileEditUnavailable();
    return const PrincipalProfileEditResult(bio: 'Texto normalizado pelo servidor', version: 8);
  }
}
