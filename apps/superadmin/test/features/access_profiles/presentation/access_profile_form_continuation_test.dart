import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final destination in [false, true]) {
    for (final disposed in [false, true]) {
      testWidgets('exit confirmation lifetime: destination=$destination disposed=$disposed', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var cancellations = 0;
        final destinations = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            home: AccessProfileFormPage(
              repository: _Repository(),
              domain: AccessProfileDomain.platform,
              profileId: 'model',
              logout: unavailableSuperadminLogout,
              onCancel: () => cancellations++,
              onDestinationSelected: destinations.add,
              onSaved: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(CoeloFormTextField, 'Nome do perfil'),
          'Nome revisado',
        );
        await tester.pump();
        if (destination) {
          final navigate = tester
              .widget<SuperadminShell>(find.byType(SuperadminShell))
              .onDestinationSelected!;
          navigate('dashboard');
          navigate('dashboard');
        } else {
          final cancel = tester
              .widget<TextButton>(find.byKey(const Key('access-profile-cancel')))
              .onPressed!;
          cancel();
          cancel();
        }
        await tester.pumpAndSettle();
        expect(find.text('Sair sem salvar?'), findsOneWidget);
        if (disposed) {
          await tester.pumpWidget(
            MaterialApp(theme: CoeloTheme.light, home: const Text('Outro contexto')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AccessProfileFormPage), findsNothing);
        }
        if (disposed) {
          expect(find.text('Sair sem salvar?'), findsNothing);
        } else {
          await tester.tap(find.text('Sair sem salvar'));
        }
        await tester.pumpAndSettle();
        expect(cancellations, !disposed && !destination ? 1 : 0);
        expect(destinations, !disposed && destination ? ['dashboard'] : isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }
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
      if (disposed) {
        expect(find.text('Alterações em conflito'), findsNothing);
      } else {
        await tester.tap(find.text('Recarregar referência'));
      }
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
