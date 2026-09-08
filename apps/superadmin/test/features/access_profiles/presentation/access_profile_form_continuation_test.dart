import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final disposed in [false, true]) {
    testWidgets('conflict reload respects form lifetime: disposed=$disposed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: AccessProfileFormPage(
            repository: repository,
            domain: AccessProfileDomain.platform,
            profileId: 'model',
            logout: unavailableSuperadminLogout,
            onCancel: () {},
            onSaved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(CoeloFormTextField, 'Nome do perfil'),
        'Nome revisado',
      );
      for (var step = 0; step < 3; step++) {
        await tester.ensureVisible(find.byKey(const Key('access-profile-continue')));
        await tester.tap(find.byKey(const Key('access-profile-continue')));
        await tester.pumpAndSettle();
      }
      await tester.enterText(
        find.widgetWithText(CoeloFormTextField, 'Motivo da alteração'),
        'Motivo sintético',
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('access-profile-save')));
      await tester.tap(find.byKey(const Key('access-profile-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Alterações em conflito'), findsOneWidget);
      expect(repository.reads, 1);
      if (disposed) {
        await tester.pumpWidget(
          MaterialApp(theme: CoeloTheme.light, home: const Text('Outro contexto')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AccessProfileFormPage), findsNothing);
      }
      await tester.tap(find.text('Recarregar referência'));
      await tester.pumpAndSettle();
      expect(repository.reads, disposed ? 1 : 2);
      expect(tester.takeException(), isNull);
    });
  }
}

final class _Repository implements AccessProfileRepository {
  int reads = 0;

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) async {
    reads++;
    return AccessProfile(
      id: profileId,
      domain: domain,
      code: 'model',
      name: 'Nome original',
      description: 'Descrição sintética.',
      status: AccessProfileStatus.active,
      maxScope: AccessProfileScope.platform,
      version: 1,
      membershipCount: 0,
    );
  }

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) async => throw const AccessProfileConflictException();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
